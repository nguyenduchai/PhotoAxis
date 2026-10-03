import Foundation

public enum PerspectiveError: String, Error, Equatable, Sendable {
    case missingQuad, invalidQuad, tooSmall, invalidOutput, unstableMapping
    public var localizationKey: String { "perspective." + rawValue }
}

public enum PerspectiveOutput: Equatable, Sendable {
    case auto(swapped: Bool = false)
    case ratio(Double)
    case pixels(CanvasSize)
}

/// Named order is TL, TR, BR, BL in y-down document space. Never sorts vertices.
public struct PerspectiveQuad: Equatable, Sendable {
    public var points: [Point2D]
    public init(_ points: [Point2D]) { self.points = points }
    public static func full(_ canvas: CanvasSize) -> Self { .init(CropRegion.full(canvas).polygon) }

    public func validate(in canvas: CanvasSize) throws {
        guard points.count == 4, points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.x >= 0 && $0.y >= 0 && $0.x <= Double(canvas.width) && $0.y <= Double(canvas.height) }) else { throw PerspectiveError.invalidQuad }
        var area = 0.0
        for i in 0..<4 {
            let a = points[i], b = points[(i+1)%4], c = points[(i+2)%4]
            let ux = b.x-a.x, uy = b.y-a.y, vx = c.x-b.x, vy = c.y-b.y
            let length = hypot(ux,uy), nextLength = hypot(vx,vy), cross = ux*vy-uy*vx
            guard length >= 1, nextLength >= 1 else { throw PerspectiveError.tooSmall }
            guard cross > 0 else { throw PerspectiveError.invalidQuad }
            guard cross/(length*nextLength) >= 1e-4 else { throw PerspectiveError.tooSmall }
            area += a.x*b.y-b.x*a.y
        }
        guard area/2 >= 4 else { throw PerspectiveError.tooSmall }
    }

    public func outputSize(_ mode: PerspectiveOutput) throws -> CanvasSize {
        guard points.count == 4 else { throw PerspectiveError.missingQuad }
        func distance(_ a:Int,_ b:Int) -> Double { hypot(points[a].x-points[b].x,points[a].y-points[b].y) }
        var w = (distance(0,1)+distance(3,2))/2, h = (distance(0,3)+distance(1,2))/2
        switch mode {
        case .auto(let swapped): if swapped { swap(&w,&h) }
        case .ratio(let ratio):
            guard ratio.isFinite, ratio > 0 else { throw PerspectiveError.invalidOutput }
            w = sqrt(w*h*ratio); h = w/ratio
        case .pixels(let size): return size
        }
        guard w.isFinite, h.isFinite, w >= 0.5, h >= 0.5, w.rounded() <= 8000, h.rounded() <= 8000 else { throw PerspectiveError.invalidOutput }
        do { return try CanvasSize(width:Int(w.rounded()),height:Int(h.rounded())) }
        catch { throw PerspectiveError.invalidOutput }
    }

    /// Analytic unit-square to quadrilateral solution in normalized canvas space.
    /// Inverting gives the document -> output mapping shared by grid/preview/Apply.
    public func mapping(in canvas: CanvasSize, output: CanvasSize) throws -> ProjectiveTransform {
        try validate(in:canvas)
        let w = Double(canvas.width), h = Double(canvas.height)
        let q = points.map { Point2D(x:$0.x/w,y:$0.y/h) }
        let dx1=q[1].x-q[2].x, dx2=q[3].x-q[2].x, dx3=q[0].x-q[1].x+q[2].x-q[3].x
        let dy1=q[1].y-q[2].y, dy2=q[3].y-q[2].y, dy3=q[0].y-q[1].y+q[2].y-q[3].y
        let det=dx1*dy2-dx2*dy1
        guard abs(det) > 1e-12 else { throw PerspectiveError.unstableMapping }
        let g=(dx3*dy2-dx2*dy3)/det, k=(dx1*dy3-dx3*dy1)/det
        do {
            let unitToQuad=try ProjectiveTransform([q[1].x-q[0].x+g*q[1].x,q[3].x-q[0].x+k*q[3].x,q[0].x,
                q[1].y-q[0].y+g*q[1].y,q[3].y-q[0].y+k*q[3].y,q[0].y,g,k,1])
            let normalize=try ProjectiveTransform([1/w,0,0,0,1/h,0,0,0,1])
            let scale=try ProjectiveTransform([Double(output.width),0,0,0,Double(output.height),0,0,0,1])
            let mapping=try normalize.followed(by:unitToQuad.inverted()).followed(by:scale)
            try Self.validateDomain(points, mapping:mapping)
            let target=Self.full(output).points, inverse=try mapping.inverted()
            try Self.validateDomain(target,mapping:inverse)
            for i in 0..<4 {
                let p=try mapping.applying(to:points[i])
                guard hypot(p.x-target[i].x,p.y-target[i].y) <= 1e-5 else { throw PerspectiveError.unstableMapping }
            }
            return mapping
        } catch { throw PerspectiveError.unstableMapping }
    }

    public static func validateDomain(_ polygon:[Point2D], mapping:ProjectiveTransform) throws {
        let m=mapping.coefficients
        let d=polygon.map { m[6]*$0.x+m[7]*$0.y+m[8] }
        guard let scale=d.map({abs($0)}).max(), scale > 0,
              d.allSatisfy({$0 > scale*1e-8}) || d.allSatisfy({$0 < -scale*1e-8}) else { throw PerspectiveError.unstableMapping }
    }

    public func grid(in canvas:CanvasSize, output:CanvasSize) throws -> [[Point2D]] {
        let inverse=try mapping(in:canvas,output:output).inverted(), w=Double(output.width),h=Double(output.height)
        return try (1...2).flatMap { n -> [[Point2D]] in
            let t=Double(n)/3
            return try [[Point2D(x:w*t,y:0),.init(x:w*t,y:h)], [.init(x:0,y:h*t),.init(x:w,y:h*t)]].map { try $0.map {try inverse.applying(to:$0)} }
        }
    }
}

public extension PhotoDocumentModel {
    mutating func perspectiveCrop(_ quad:PerspectiveQuad, output:CanvasSize) throws {
        let mapping=try quad.mapping(in:canvas,output:output)
        var next=self
        for index in layers.indices {
            let layer=layers[index],size=try localSize(of:layer)
            let footprint=try LayerGeometry.support(size:size,transform:layer.transform,clips:layer.clip)
            let intersection=PolygonClip.intersection(footprint,quad.points)
            let inverse=try layer.transform.inverted()
            var clip=try intersection.map {try inverse.applying(to:$0)}
            for old in layer.clip {clip=PolygonClip.intersection(clip,old)}
            let transform=try layer.transform.followed(by:mapping)
            // Validate retained pixels. The inverse renderer has a bounded output extent
            // even if the projective pole crosses discarded source pixels.
            do { _=try LayerGeometry.bounds(size:size,transform:transform,clips:[clip]) }
            catch { throw PerspectiveError.unstableMapping }
            next.layers[index].clip=[clip];next.layers[index].transform=transform
        }
        next.canvas=output;next.revision &+= 1;self=next
    }
}

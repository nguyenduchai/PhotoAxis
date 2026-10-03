import Foundation

public struct LayerBounds: Equatable, Sendable {
    public let x, y, width, height: Double
    public var center: Point2D { .init(x: x + width / 2, y: y + height / 2) }
    public func contains(_ point: Point2D) -> Bool { point.x >= x && point.x <= x + width && point.y >= y && point.y <= y + height }
    public var corners: [Point2D] { [.init(x: x,y: y), .init(x: x+width,y: y), .init(x: x+width,y: y+height), .init(x: x,y: y+height)] }
}

public enum LayerGeometry {
    public static func corners(size: CanvasSize, transform: ProjectiveTransform) throws -> [Point2D] {
        let points = [Point2D(x: 0,y: 0), .init(x: Double(size.width),y: 0), .init(x: Double(size.width),y: Double(size.height)), .init(x: 0,y: Double(size.height))]
        let m = transform.coefficients
        let denominators = points.map { m[6] * $0.x + m[7] * $0.y + m[8] }
        guard denominators.allSatisfy({ $0 > 0 }) || denominators.allSatisfy({ $0 < 0 }) else { throw GeometryError.pointAtInfinity }
        return try points.map { try transform.applying(to: $0) }
    }
    /// Convex support after all local clips; discarded pixels need not have a finite mapping.
    public static func support(size: CanvasSize, transform: ProjectiveTransform, clips: [[Point2D]]) throws -> [Point2D] {
        var polygon=CropRegion.full(size).polygon
        for clip in clips {polygon=PolygonClip.intersection(polygon,clip)}
        guard !polygon.isEmpty else{return []}
        do {try PerspectiveQuad.validateDomain(polygon,mapping:transform)}
        catch {throw GeometryError.pointAtInfinity}
        return try polygon.map{try transform.applying(to:$0)}
    }
    public static func bounds(size: CanvasSize, transform: ProjectiveTransform, clips: [[Point2D]] = []) throws -> LayerBounds {
        let points: [Point2D]
        if let full=try? corners(size:size,transform:transform),full.allSatisfy({abs($0.x)<=1_000_000 && abs($0.y)<=1_000_000}) {points=full}
        else {
            // Keep original transform handles where finite; otherwise use retained support.
            points=try support(size:size,transform:transform,clips:clips)
            if points.isEmpty {return LayerBounds(x:0,y:0,width:0,height:0)}
        }
        let x = points.map(\.x).min()!, y = points.map(\.y).min()!
        let width = points.map(\.x).max()! - x, height = points.map(\.y).max()! - y
        // Bound preview geometry before submitting an unbounded extent to Core Image.
        guard points.allSatisfy({ abs($0.x) <= 1_000_000 && abs($0.y) <= 1_000_000 }),
              width >= 0.01, height >= 0.01 else { throw DocumentError.invalidValue }
        return LayerBounds(x: x, y: y, width: width, height: height)
    }
    public static func translation(x: Double, y: Double) throws -> ProjectiveTransform { try .init([1,0,x,0,1,y,0,0,1]) }
    public static func scale(x: Double, y: Double, around anchor: Point2D) throws -> ProjectiveTransform {
        guard x.isFinite, y.isFinite, abs(x) >= 0.000001, abs(y) >= 0.000001 else { throw DocumentError.invalidValue }
        return try .init([x,0,anchor.x*(1-x),0,y,anchor.y*(1-y),0,0,1])
    }
    public static func rotation(degrees: Double, around anchor: Point2D) throws -> ProjectiveTransform {
        guard degrees.isFinite else { throw DocumentError.invalidValue }
        let a = degrees * .pi / 180, c = cos(a), s = sin(a)
        return try .init([c,-s,anchor.x-c*anchor.x+s*anchor.y,s,c,anchor.y-s*anchor.x-c*anchor.y,0,0,1])
    }
    public static func angle(size: CanvasSize, transform: ProjectiveTransform, clips: [[Point2D]] = []) throws -> Double {
        let points = try (try? corners(size:size,transform:transform)) ?? support(size:size,transform:transform,clips:clips)
        guard points.count>=2 else{return 0}
        return atan2(points[1].y-points[0].y, points[1].x-points[0].x) * 180 / .pi
    }
    public static func contains(local point: Point2D, size: CanvasSize, clips: [[Point2D]]) -> Bool {
        guard point.x >= 0, point.y >= 0, point.x < Double(size.width), point.y < Double(size.height) else { return false }
        return clips.allSatisfy { polygon in
            guard polygon.count >= 3 else { return false }
            let crosses = polygon.indices.map { i -> Double in
                let a = polygon[i], b = polygon[(i+1)%polygon.count]
                return (b.x-a.x)*(point.y-a.y)-(b.y-a.y)*(point.x-a.x)
            }
            return crosses.allSatisfy { $0 >= -1e-8 } || crosses.allSatisfy { $0 <= 1e-8 }
        }
    }
}

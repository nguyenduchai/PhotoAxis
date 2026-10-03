import Foundation

public struct CropRegion: Equatable, Sendable {
    public var x, y, width, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x=x; self.y=y; self.width=width; self.height=height
    }
    public static func full(_ size: CanvasSize) -> Self { .init(x:0,y:0,width:Double(size.width),height:Double(size.height)) }
    public var polygon: [Point2D] { [.init(x:x,y:y),.init(x:x+width,y:y),.init(x:x+width,y:y+height),.init(x:x,y:y+height)] }
    public func validate(in canvas: CanvasSize) throws {
        guard [x,y,width,height].allSatisfy(\.isFinite), x >= 0, y >= 0, width >= 1, height >= 1,
              x+width <= Double(canvas.width)+1e-7, y+height <= Double(canvas.height)+1e-7 else { throw DocumentError.invalidValue }
    }
    public func outputSize() throws -> CanvasSize {
        guard width.isFinite,height.isFinite,(1...8000).contains(width),(1...8000).contains(height) else{throw DocumentError.invalidValue}
        return try CanvasSize(width:Int(width.rounded()),height:Int(height.rounded()))
    }
    public func fitted(ratio: Double?, in canvas: CanvasSize) -> Self {
        guard let ratio, ratio.isFinite, ratio > 0 else { return self }
        var w=min(width,Double(canvas.width)), h=min(height,Double(canvas.height))
        if w/h > ratio { w=h*ratio } else { h=w/ratio }
        return .init(x:max(0,min(Double(canvas.width)-w,x+(width-w)/2)),y:max(0,min(Double(canvas.height)-h,y+(height-h)/2)),width:w,height:h)
    }
}

/// Convex polygon intersection; winding-independent. Empty means fully clipped.
public enum PolygonClip {
    public static func intersection(_ subject: [Point2D], _ boundary: [Point2D]) -> [Point2D] {
        guard subject.count >= 3, boundary.count >= 3 else { return [] }
        let area=boundary.indices.reduce(0.0) { n,i in let a=boundary[i],b=boundary[(i+1)%boundary.count];return n+a.x*b.y-b.x*a.y }
        guard abs(area)>1e-10 else{return []}
        let sign=area > 0 ? 1.0 : -1.0
        var result=subject
        for i in boundary.indices {
            let a=boundary[i],b=boundary[(i+1)%boundary.count]
            func distance(_ p:Point2D)->Double { sign*((b.x-a.x)*(p.y-a.y)-(b.y-a.y)*(p.x-a.x)) }
            let input=result;result=[];guard var previous=input.last else{return []}
            var pd=distance(previous)
            for current in input {
                let cd=distance(current)
                if (cd >= 0) != (pd >= 0) {
                    let t=pd/(pd-cd);result.append(.init(x:previous.x+t*(current.x-previous.x),y:previous.y+t*(current.y-previous.y)))
                }
                if cd >= 0 {result.append(current)}
                previous=current;pd=cd
            }
        }
        return result
    }
}

public extension PhotoDocumentModel {
    mutating func crop(to region:CropRegion, output:CanvasSize? = nil) throws {
        try region.validate(in:canvas)
        let size=try output ?? region.outputSize()
        var next=self
        for index in layers.indices {
            let layer=layers[index], local=try localSize(of:layer)
            let corners=try LayerGeometry.support(size:local,transform:layer.transform,clips:layer.clip)
            let kept=PolygonClip.intersection(corners,region.polygon)
            let inverse=try layer.transform.inverted()
            var polygon=try kept.map{try inverse.applying(to:$0)}
            for old in layer.clip { polygon=PolygonClip.intersection(polygon,old) }
            next.layers[index].clip=[polygon]
        }
        let translation=try LayerGeometry.translation(x:-region.x,y:-region.y)
        let scale=try LayerGeometry.scale(x:Double(size.width)/region.width,y:Double(size.height)/region.height,around:.init(x:0,y:0))
        try next.mapDocument(translation.followed(by:scale),canvas:size)
        self=next
    }
    mutating func imageSize(_ size:CanvasSize, ppi:Double) throws {
        guard ppi.isFinite,ppi>0 else{throw DocumentError.invalidPPI}
        var next=self
        if size != canvas {
            try next.mapDocument(LayerGeometry.scale(x:Double(size.width)/Double(canvas.width),y:Double(size.height)/Double(canvas.height),around:.init(x:0,y:0)),canvas:size)
        }
        if next.ppi != ppi {next.ppi=ppi;next.revision &+= 1}
        self=next
    }
    mutating func canvasSize(_ size:CanvasSize, anchorX:Int, anchorY:Int) throws {
        guard (0...2).contains(anchorX),(0...2).contains(anchorY) else{throw DocumentError.invalidValue}
        guard size != canvas else{return}
        let x=Double(size.width-canvas.width)*Double(anchorX)/2, y=Double(size.height-canvas.height)*Double(anchorY)/2
        try mapDocument(LayerGeometry.translation(x:x,y:y),canvas:size)
    }
    mutating func rotateCanvas(quarterTurns:Int) throws {
        let turns=((quarterTurns%4)+4)%4,w=Double(canvas.width),h=Double(canvas.height)
        guard turns != 0 else{return}
        let matrix:ProjectiveTransform
        switch turns {
        case 1: matrix=try .init([0,-1,h,1,0,0,0,0,1])
        case 2: matrix=try .init([-1,0,w,0,-1,h,0,0,1])
        default: matrix=try .init([0,1,0,-1,0,w,0,0,1])
        }
        let size=try turns%2 == 1 ? CanvasSize(width:canvas.height,height:canvas.width) : canvas
        try mapDocument(matrix,canvas:size)
    }
    mutating func flipCanvas(horizontal:Bool) throws {
        try mapDocument(LayerGeometry.scale(x:horizontal ? -1:1,y:horizontal ? 1:-1,around:.init(x:Double(canvas.width)/2,y:Double(canvas.height)/2)),canvas:canvas)
    }
    private mutating func mapDocument(_ operation:ProjectiveTransform,canvas size:CanvasSize) throws {
        var mapped=layers
        for index in mapped.indices {
            let matrix=try mapped[index].transform.followed(by:operation)
            _=try LayerGeometry.bounds(size:localSize(of:mapped[index]),transform:matrix,clips:mapped[index].clip)
            mapped[index].transform=matrix
        }
        layers=mapped;canvas=size;revision &+= 1
    }
}

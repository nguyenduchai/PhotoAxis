import AppKit
import PhotoAxisCore

@MainActor
final class CropOverlay:NSView {
    var canvasRect=NSRect.zero
    var cropRect=NSRect.zero
    var grid=true
    override var isFlipped:Bool{true}
    override func hitTest(_ point:NSPoint)->NSView?{nil}
    var handles:[NSPoint] {let r=cropRect;return [.init(x:r.minX,y:r.minY),.init(x:r.midX,y:r.minY),.init(x:r.maxX,y:r.minY),.init(x:r.maxX,y:r.midY),.init(x:r.maxX,y:r.maxY),.init(x:r.midX,y:r.maxY),.init(x:r.minX,y:r.maxY),.init(x:r.minX,y:r.midY)]}
    override func draw(_ dirtyRect:NSRect) {
        NSGraphicsContext.saveGraphicsState();NSBezierPath(rect:bounds).addClip()
        let shade=NSBezierPath(rect:canvasRect);shade.appendRect(cropRect);shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.55).setFill();shade.fill()
        NSColor.white.setStroke();let border=NSBezierPath(rect:cropRect);border.lineWidth=1;border.stroke()
        if grid {
            let path=NSBezierPath()
            for n in 1...2 {let t=Double(n)/3;path.move(to:.init(x:cropRect.minX+cropRect.width*t,y:cropRect.minY));path.line(to:.init(x:cropRect.minX+cropRect.width*t,y:cropRect.maxY));path.move(to:.init(x:cropRect.minX,y:cropRect.minY+cropRect.height*t));path.line(to:.init(x:cropRect.maxX,y:cropRect.minY+cropRect.height*t))};path.stroke()
        }
        NSColor.white.setFill();for p in handles {NSBezierPath(rect:NSRect(x:p.x-4,y:p.y-4,width:8,height:8)).fill()}
        NSGraphicsContext.restoreGraphicsState()
    }
}

@MainActor
final class CropInteraction {
    weak var canvas:WelcomeCanvasView?
    private var start:Point2D?,original:CropRegion?,handle:Int?
    private var moving=false
    init(canvas:WelcomeCanvasView){self.canvas=canvas}
    func reset(){start=nil;original=nil;handle=nil;moving=false}
    private func point(_ p:NSPoint,_ d:PhotoDocument)->Point2D {
        let value=d.viewport.transform.documentPoint(fromView:.init(x:p.x,y:p.y))
        return .init(x:max(0,min(Double(d.model.canvas.width),value.x)),y:max(0,min(Double(d.model.canvas.height),value.y)))
    }
    func down(_ p:NSPoint) {
        guard let canvas,let d=canvas.document,!d.isInteractionLocked,canvas.presentedViewport == d.viewport else{return}
        if d.cropSession == nil {try? d.startCrop();canvas.updateCropOverlay()}
        guard let crop=d.cropSession else{return}
        start=point(p,d);original=crop.region
        handle=canvas.cropOverlay.handles.firstIndex{hypot(p.x-$0.x,p.y-$0.y)<=8}
        moving=handle == nil && canvas.cropOverlay.cropRect.contains(p)
    }
    func drag(_ p:NSPoint) {
        guard let d=canvas?.document,let state=d.cropSession,let start,let original else{return}
        let end=point(p,d),cw=Double(d.model.canvas.width),ch=Double(d.model.canvas.height)
        var rect:CropRegion
        if moving {
            rect = .init(x:max(0,min(cw-original.width,original.x+end.x-start.x)),y:max(0,min(ch-original.height,original.y+end.y-start.y)),width:original.width,height:original.height)
        } else {
            let positions:[(Double,Double)]=[(0,0),(0.5,0),(1,0),(1,0.5),(1,1),(0.5,1),(0,1),(0,0.5)]
            let (hx,hy)=handle.map{positions[$0]} ?? (1,1)
            let anchor=handle == nil ? start : Point2D(x:original.x+(1-hx)*original.width,y:original.y+(1-hy)*original.height)
            var w=hx == 0.5 ? original.width : max(1,abs(end.x-anchor.x)),h=hy == 0.5 ? original.height : max(1,abs(end.y-anchor.y))
            if let ratio=state.ratio {
                if hx == 0.5 {w=h*ratio} else {h=w/ratio}
                let maxW=hx == 0.5 ? 2*min(anchor.x,cw-anchor.x) : end.x>=anchor.x ? cw-anchor.x : anchor.x
                let maxH=hy == 0.5 ? 2*min(anchor.y,ch-anchor.y) : end.y>=anchor.y ? ch-anchor.y : anchor.y
                let factor=min(1,min(maxW/w,maxH/h));w*=factor;h*=factor
            }
            let x=hx == 0.5 ? anchor.x-w/2 : end.x>=anchor.x ? anchor.x : anchor.x-w
            let y=hy == 0.5 ? anchor.y-h/2 : end.y>=anchor.y ? anchor.y : anchor.y-h
            rect = .init(x:max(0,x),y:max(0,y),width:min(w,cw-max(0,x)),height:min(h,ch-max(0,y)))
        }
        d.moveCrop(to:rect)
    }
    func up(_ p:NSPoint){drag(p);reset()}
}

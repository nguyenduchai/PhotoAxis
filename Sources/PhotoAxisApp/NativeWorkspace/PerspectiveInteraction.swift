import AppKit
import PhotoAxisCore

@MainActor
final class PerspectiveOverlay:NSView {
    var canvasRect=NSRect.zero
    var corners:[NSPoint]=[]
    var gridLines:[[NSPoint]]=[]
    var isValid=false
    override var isFlipped:Bool {true}
    override func hitTest(_ point:NSPoint)->NSView? {nil}
    override func draw(_ dirtyRect:NSRect) {
        guard corners.count==4 else{return}
        NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
        NSBezierPath(rect:bounds).addClip()
        let path=NSBezierPath();path.move(to:corners[0]);corners.dropFirst().forEach{path.line(to:$0)};path.close()
        let shade=NSBezierPath(rect:canvasRect);shade.append(path);shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.55).setFill();shade.fill()
        let color:NSColor=isValid ? .white:.systemRed
        color.setStroke();path.lineWidth=1.5;path.stroke()
        let grid=NSBezierPath()
        for line in gridLines where line.count==2 {grid.move(to:line[0]);grid.line(to:line[1])}
        grid.lineWidth=1;grid.stroke()
        for (i,p) in corners.enumerated() {
            color.setFill();NSBezierPath(rect:NSRect(x:p.x-4,y:p.y-4,width:8,height:8)).fill()
            let name=["TL","TR","BR","BL"][i] as NSString
            name.draw(at:NSPoint(x:p.x+7,y:p.y+5),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:10,weight:.medium),.foregroundColor:color,.backgroundColor:NSColor.black.withAlphaComponent(0.7)])
        }
    }
}

@MainActor
final class PerspectiveInteraction {
    weak var canvas:WelcomeCanvasView?
    private var start:Point2D?,original:PerspectiveQuad?,handle:Int?
    private var moving=false
    init(canvas:WelcomeCanvasView){self.canvas=canvas}
    func reset(){start=nil;original=nil;handle=nil;moving=false}
    private func point(_ p:NSPoint,_ d:PhotoDocument)->Point2D {
        let value=d.viewport.transform.documentPoint(fromView:.init(x:p.x,y:p.y))
        return .init(x:max(0,min(Double(d.model.canvas.width),value.x)),y:max(0,min(Double(d.model.canvas.height),value.y)))
    }
    func down(_ p:NSPoint) {
        reset()
        guard let canvas,let d=canvas.document,let state=d.perspectiveSession,!state.showsPreview,!d.isInteractionLocked,canvas.presentedViewport==d.viewport else{return}
        start=point(p,d);original=state.quad
        handle=canvas.perspectiveOverlay.corners.firstIndex{hypot($0.x-p.x,$0.y-p.y)<=8}
        if let quad=state.quad,quad.points.count==4,canvas.perspectiveOverlay.corners.count==4 {
            let path=NSBezierPath();path.move(to:canvas.perspectiveOverlay.corners[0])
            canvas.perspectiveOverlay.corners.dropFirst().forEach{path.line(to:$0)};path.close()
            moving=handle==nil && path.contains(p)
        }
    }
    func drag(_ p:NSPoint) {
        guard let d=canvas?.document,let start,d.perspectiveSession?.showsPreview==false else{return}
        let end=point(p,d),cw=Double(d.model.canvas.width),ch=Double(d.model.canvas.height)
        var quad:PerspectiveQuad
        if var original,let handle {
            original.points[handle]=end;quad=original
        } else if let original,moving {
            let xs=original.points.map(\.x),ys=original.points.map(\.y)
            let dx=max(-xs.min()!,min(cw-xs.max()!,end.x-start.x)),dy=max(-ys.min()!,min(ch-ys.max()!,end.y-start.y))
            quad=PerspectiveQuad(original.points.map{.init(x:$0.x+dx,y:$0.y+dy)})
        } else {
            quad=PerspectiveQuad([.init(x:min(start.x,end.x),y:min(start.y,end.y)),.init(x:max(start.x,end.x),y:min(start.y,end.y)),.init(x:max(start.x,end.x),y:max(start.y,end.y)),.init(x:min(start.x,end.x),y:max(start.y,end.y))])
        }
        d.updatePerspective{$0.quad=quad}
    }
    func up(_ p:NSPoint){drag(p);reset()}
}

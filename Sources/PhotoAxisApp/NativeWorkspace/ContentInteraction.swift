import AppKit
import PhotoAxisCore

@MainActor final class ContentInteraction {
    weak var canvas:WelcomeCanvasView?
    let inlineEditor:NativeTextEditor
    var focusProperties:(()->Void)?
    private var shapeStart:Point2D?
    private var pickTask:Task<Void,Never>?
    private var pickToken=UUID()
    init(canvas:WelcomeCanvasView,localization:L10n) {
        self.canvas=canvas;inlineEditor=NativeTextEditor(localization:localization);inlineEditor.isHidden=true
        inlineEditor.focusCanvas={ [weak canvas] in canvas?.window?.makeFirstResponder(canvas) }
    }
    func reset(){shapeStart=nil;pickTask?.cancel();pickToken=UUID()}
    func refresh() {
        guard let c=canvas,let d=c.document,let state=d.contentSession,case .text=state.draft,!state.usesProperties,
              let box=try? state.candidate.bounds(of:state.layerID) else{inlineEditor.refresh(nil);return}
        if inlineEditor.superview !== c {c.addSubview(inlineEditor)}
        let v=d.viewport,point=v.transform.viewPoint(fromDocument:.init(x:box.x,y:box.y)),scale=v.zoom/v.backingScale
        inlineEditor.frame=NSRect(x:max(0,min(c.bounds.width-120,point.x)),y:max(0,min(c.bounds.height-80,point.y)),width:min(max(180,box.width*scale+18),max(180,c.bounds.width-20)),height:min(max(90,box.height*scale+18),max(90,c.bounds.height-20)))
        inlineEditor.refresh(d,scale:max(0.2,min(4,scale)))
    }
    func edit(_ id:UUID) {
        guard let c=canvas,let d=c.document else{return}
        do {
            try d.startContentEdit(id);refresh()
            if d.contentSession?.draft.isText==true,d.contentSession?.usesProperties==false{inlineEditor.focus()}
            else{focusProperties?()}
        }catch{NSSound.beep()}
    }
    private func point(_ view:NSPoint,_ d:PhotoDocument)->Point2D {
        let p=d.viewport.transform.documentPoint(fromView:.init(x:view.x,y:view.y))
        return .init(x:max(0,min(Double(d.model.canvas.width),p.x)),y:max(0,min(Double(d.model.canvas.height),p.y)))
    }
    func down(_ view:NSPoint,shift:Bool) {
        guard let c=canvas,let d=c.document,!d.isInteractionLocked else{return}
        let p=point(view,d)
        switch d.activeTool {
        case .type:
            pickTask?.cancel();let token=UUID();pickToken=token;let model=d.presentedModel,assets=d.assets
            pickTask=Task { [weak self,weak d] in
                guard let self,let d,let pipeline=c.imagePipeline else{return}
                let id=try? await pipeline.hitTest(model:model,assets:assets,point:p)
                guard !Task.isCancelled,pickToken==token,c.document===d,d.presentedModel==model else{return}
                if let id,let layer=model.layer(id),case .text=layer.content {edit(id)}
                else {do{try d.startText(at:p);refresh();inlineEditor.focus()}catch{NSSound.beep()}}
            }
        case .rectangle,.ellipse,.line:
            guard let kind=ShapeContent.Kind(rawValue:d.activeTool.rawValue) else{return}
            do{try d.startShape(kind:kind,at:p);shapeStart=p}catch{NSSound.beep()}
        case .eyedropper:
            guard !d.hasSession else{return}
            pickTask?.cancel();let token=UUID();pickToken=token;let model=d.model,assets=d.assets
            pickTask=Task { [weak self,weak d] in
                guard let self,let d,let pipeline=c.imagePipeline else{return}
                if let color=try? await pipeline.sample(model:model,assets:assets,point:p),!Task.isCancelled,pickToken==token,c.document===d,d.model==model{d.setForeground(color)}
            }
        default:break
        }
    }
    func drag(_ view:NSPoint,shift:Bool) {
        guard let d=canvas?.document,let start=shapeStart,let state=d.contentSession,case .shape(var shape)=state.draft else{return}
        let raw=point(view,d);var dx=raw.x-start.x,dy=raw.y-start.y
        if shift {
            if shape.kind == .line {
                let length=hypot(dx,dy),angle=(atan2(dy,dx)/(.pi/4)).rounded()*(.pi/4);dx=length*cos(angle);dy=length*sin(angle)
            }else{let length=max(abs(dx),abs(dy));dx=(dx<0 ? -1:1)*length;dy=(dy<0 ? -1:1)*length}
            let maxX=dx>0 ? Double(d.model.canvas.width)-start.x:start.x,maxY=dy>0 ? Double(d.model.canvas.height)-start.y:start.y
            let scale=min(1,abs(dx)>0 ? maxX/abs(dx):1,abs(dy)>0 ? maxY/abs(dy):1);dx*=scale;dy*=scale
        }
        guard hypot(dx,dy)>=1 else{d.contentSession?.isValid=false;d.changed?();return}
        do {
            let width=max(shape.kind == .line ? max(1,ceil(shape.strokeWidth)):1,abs(dx)),height=max(shape.kind == .line ? max(1,ceil(shape.strokeWidth)):1,abs(dy))
            shape.size=try CanvasSize(width:Int(ceil(width)),height:Int(ceil(height)))
            shape.lineStart = .init(x:dx>=0 ? 0:1,y:dy>=0 ? 0:1);shape.lineEnd = .init(x:dx>=0 ? 1:0,y:dy>=0 ? 1:0)
            if abs(dx)<1{shape.lineStart = .init(x:0.5,y:shape.lineStart.y);shape.lineEnd = .init(x:0.5,y:shape.lineEnd.y)};if abs(dy)<1{shape.lineStart = .init(x:shape.lineStart.x,y:0.5);shape.lineEnd = .init(x:shape.lineEnd.x,y:0.5)}
            d.updateContent(.shape(shape),transform:try LayerGeometry.translation(x:start.x+min(0,dx),y:start.y+min(0,dy)))
        }catch{d.contentSession?.isValid=false;d.changed?()}
    }
    func up(_ view:NSPoint,shift:Bool){guard shapeStart != nil else{return};drag(view,shift:shift);shapeStart=nil}
}

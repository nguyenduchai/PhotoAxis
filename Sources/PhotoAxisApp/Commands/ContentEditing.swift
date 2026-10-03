import AppKit
import PhotoAxisCore

struct ContentSession {
    let layerID:UUID,previousSelection:UUID?,command:DocumentCommand
    var candidate:PhotoDocumentModel
    var draft:LayerContent
    var isValid=true
    var isComposing=false
    var usesProperties=false
}

extension PhotoDocument {
    func startText(at point:Point2D) throws {
        guard resolveSession(),!isInteractionLocked else{throw DocumentError.activeSession}
        let text=try ContentRasterizer.measured(textDefaults)
        try startContent(.text(text),at:point,command:.createText,name:localization.text("type.newLayer"))
    }
    func startShape(kind:ShapeContent.Kind,at point:Point2D)throws {
        guard resolveSession(),!isInteractionLocked else{throw DocumentError.activeSession}
        var shape=shapeDefaults;shape.kind=kind;shape.size=try CanvasSize(width:1,height:1)
        if kind == .line && shape.strokeWidth==0{shape.strokeWidth=2;shape.stroke=foreground}
        try startContent(.shape(shape),at:point,command:.createShape,name:localization.text("tool."+kind.rawValue))
        contentSession?.isValid=false
    }
    private func startContent(_ content:LayerContent,at point:Point2D,command:DocumentCommand,name:String)throws {
        var candidate=model
        let old=selectedLayerID,id=try candidate.insertContent(content,name:name,transform:LayerGeometry.translation(x:point.x,y:point.y),above:old)
        selectedLayerID=id;contentSession=ContentSession(layerID:id,previousSelection:old,command:command,candidate:candidate,draft:content)
        changed?()
    }
    func startContentEdit(_ id:UUID)throws {
        if contentSession?.layerID==id{return}
        guard resolveSession(),!isInteractionLocked,let layer=model.layer(id),!layer.isLocked else{throw DocumentError.lockedLayer}
        let command:DocumentCommand
        switch layer.content {case .text:command = .editText;case .shape:command = .editShape;case .image,.paint:throw DocumentError.invalidValue}
        let old=selectedLayerID;selectedLayerID=id
        contentSession=ContentSession(layerID:id,previousSelection:old,command:command,candidate:model,draft:layer.content,usesProperties:!layer.transform.isAffine)
        changed?()
    }
    func updateContent(_ content:LayerContent,transform:ProjectiveTransform?=nil) {
        guard var state=contentSession else{return}
        state.draft=content
        do {
            let validated:LayerContent
            if case .text(let t)=content{validated = .text(try ContentRasterizer.measured(t))}else{validated=content}
            var candidate=state.candidate;try candidate.setContent(state.layerID,validated)
            if let transform{try candidate.setTransform(state.layerID,transform)}
            state.draft=validated;state.candidate=candidate;state.isValid=true
        }catch{state.isValid=false}
        contentSession=state;changed?()
    }
    func setForeground(_ color:RGBAColor) {guard color.isValid else{return};foreground=color;textDefaults.color=color;shapeDefaults.fill=color;changed?()}
    func swapColors(){let old=foreground;setForeground(background);background=old;changed?()}
    func resetColors(){background = .white;setForeground(.black)}
}

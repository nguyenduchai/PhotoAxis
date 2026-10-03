import AppKit
import PhotoAxisCore

struct PerspectiveState {
    var quad:PerspectiveQuad?
    var previousTool:ToolKind
    var mode=0 // Auto, Ratio, W x H
    var ratioPreset=0 // Custom, Original, 1:1, 4:3, 3:2, 16:9, A4
    var widthText="",heightText=""
    var autoSwapped=false
    var grid=true
    var showsPreview=false
    var editingViewport:ViewportState?
    var output:CanvasSize?
    var candidate:PhotoDocumentModel?
    var error:PerspectiveError? = .missingQuad
    var isValid:Bool { candidate != nil && error == nil }
}

extension PhotoDocument {
    func startPerspective() throws {
        if perspectiveSession != nil { return }
        guard resolveSession(),!isInteractionLocked else { throw DocumentError.activeSession }
        perspectiveSession=PerspectiveState(previousTool:activeTool,widthText:String(model.canvas.width),heightText:String(model.canvas.height))
        changed?()
    }
    func updatePerspective(_ change:(inout PerspectiveState)->Void) {
        guard var state=perspectiveSession else { return }
        change(&state)
        state.candidate=nil;state.output=nil
        do {
            guard let quad=state.quad else { throw PerspectiveError.missingQuad }
            try quad.validate(in:model.canvas)
            let mode:PerspectiveOutput
            switch state.mode {
            case 0: mode = .auto(swapped:state.autoSwapped)
            case 1:
                guard let w=DocumentNumber.parse(state.widthText,language:Locale.current.identifier),let h=DocumentNumber.parse(state.heightText,language:Locale.current.identifier),w>0,h>0 else {throw PerspectiveError.invalidOutput}
                mode = .ratio(w/h)
            default:
                guard let w=Int(state.widthText),let h=Int(state.heightText),let size=try? CanvasSize(width:w,height:h) else {throw PerspectiveError.invalidOutput}
                mode = .pixels(size)
            }
            let output=try quad.outputSize(mode)
            var candidate=model;try candidate.perspectiveCrop(quad,output:output)
            state.output=output;state.candidate=candidate;state.error=nil
        } catch { state.error=(error as? PerspectiveError) ?? .unstableMapping }
        if !state.isValid && state.showsPreview {
            if let editing=state.editingViewport {viewport=editing}
            state.showsPreview=false;state.editingViewport=nil
        } else if state.showsPreview,let output=state.output { viewport.fit(output) }
        perspectiveSession=state;changed?()
    }
    func previewPerspective(_ enabled:Bool) {
        guard var state=perspectiveSession, enabled != state.showsPreview, !enabled || state.isValid else { return }
        if enabled {state.editingViewport=viewport;viewport.fit(state.output!)}
        else if let editing=state.editingViewport {viewport=editing;state.editingViewport=nil}
        state.showsPreview=enabled;perspectiveSession=state;changed?()
    }
    func resetPerspective() {updatePerspective {$0.quad = .full(model.canvas)}}
    func clearPerspective() {updatePerspective {$0.mode=0;$0.autoSwapped=false}}
    func swapPerspective() {
        updatePerspective { state in
            if state.mode==0 {state.autoSwapped.toggle()}
            else {swap(&state.widthText,&state.heightText);state.ratioPreset=0}
        }
    }
}

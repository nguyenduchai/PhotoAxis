import AppKit
import PhotoAxisCore

/// Pointer coordinates are converted once at the AppKit boundary. A gesture keeps
/// its starting matrix; each preview composes a canvas-space operation onto it.
@MainActor
final class CanvasEditing {
    weak var canvas: WelcomeCanvasView?
    private var pickTask: Task<Void,Never>?
    private var pickID = UUID()
    private var pending: (start: NSPoint, latest: NSPoint, released: Bool, shift: Bool)?
    private var gesture: Gesture?
    private var keyboardMove = false
    private struct Gesture {
        let document: PhotoDocument
        let start: Point2D
        let matrix: ProjectiveTransform
        let bounds: LayerBounds
        let handle: Int? // nil translates; 0...7 resize; 8 rotates.
        let commitsOnRelease: Bool
        let angle: Double
    }
    init(canvas: WelcomeCanvasView) { self.canvas = canvas }
    func cancelPendingPick() { pickID = UUID(); pickTask?.cancel(); pending = nil }
    func resetPointer() {
        cancelPendingPick()
        if gesture?.commitsOnRelease == true { gesture?.document.cancelSession() }
        gesture = nil; keyboardMove = false
    }
    private func point(_ view: NSPoint, document: PhotoDocument) -> Point2D {
        document.viewport.transform.documentPoint(fromView: .init(x:view.x,y:view.y))
    }
    func down(_ view: NSPoint, shift: Bool) {
        guard let canvas, let document = canvas.document, !document.isInteractionLocked,
              canvas.presentedViewport == document.viewport else { return }
        resetPointer()
        let handle = canvas.overlay.hitHandle(view)
        if document.toolSession?.command == .transform || handle != nil {
            guard document.canEditSelection, let bounds = try? document.presentedModel.bounds(of: document.selectedLayerID!),
                  handle != nil || bounds.contains(point(view,document:document)) else { return }
            do { try document.startTransform(); begin(view,document:document,handle:handle,commit:false) } catch { NSSound.beep() }
        } else if document.activeTool == .move {
            if document.autoSelect, let pipeline = canvas.imagePipeline {
                let token = UUID(); pickID = token; pending = (view,view,false,shift)
                let model = document.model, assets = document.assets, hit = point(view,document:document)
                pickTask = Task { [weak self, weak document] in
                    let id = try? await pipeline.hitTest(model:model,assets:assets,point:hit)
                    guard let self, let document, !Task.isCancelled, pickID == token, canvas.document === document,
                          document.activeTool == .move, document.model.revision == model.revision, let state = pending else { return }
                    pending = nil
                    guard let id else { return }
                    document.selectLayer(id)
                    begin(state.start,document:document,handle:nil,commit:true)
                    dragged(state.latest,shift:state.shift)
                    if state.released { up(state.latest,shift:state.shift) }
                }
            } else { begin(view,document:document,handle:nil,commit:true) }
        }
    }
    private func begin(_ view:NSPoint, document:PhotoDocument, handle:Int?, commit:Bool) {
        guard document.canEditSelection, let layer = document.selectedLayer,
              let bounds = try? document.presentedModel.bounds(of:layer.id) else { return }
        if commit { do { try document.beginSession(.move) } catch { return } }
        let angle = (try? LayerGeometry.angle(size:document.presentedModel.localSize(of:layer),transform:layer.transform,clips:layer.clip)) ?? 0
        gesture = Gesture(document:document,start:point(view,document:document),matrix:layer.transform,bounds:bounds,handle:handle,commitsOnRelease:commit,angle:angle)
    }
    func dragged(_ view:NSPoint, shift:Bool) {
        if pending != nil { pending?.latest = view; pending?.shift = shift; return }
        guard let gesture else { return }
        let document = gesture.document, current = point(view,document:gesture.document)
        do {
            let operation: ProjectiveTransform
            if let handle = gesture.handle, handle == 8 {
                let center = gesture.bounds.center
                let start = atan2(gesture.start.y-center.y,gesture.start.x-center.x)
                let end = atan2(current.y-center.y,current.x-center.x)
                var degrees = (end-start)*180 / .pi
                if shift { degrees = ((gesture.angle + degrees) / 15).rounded()*15 - gesture.angle }
                operation = try LayerGeometry.rotation(degrees:degrees,around:center)
            } else if let handle = gesture.handle {
                let b = gesture.bounds
                let normalized: [(Double,Double)] = [(0,0),(0.5,0),(1,0),(1,0.5),(1,1),(0.5,1),(0,1),(0,0.5)]
                let (hx,hy) = normalized[handle]
                let anchor = Point2D(x:b.x+(1-hx)*b.width,y:b.y+(1-hy)*b.height)
                let start = Point2D(x:b.x+hx*b.width,y:b.y+hy*b.height)
                var sx = hx == 0.5 ? 1 : max(0.0001,(current.x-anchor.x)/(start.x-anchor.x))
                var sy = hy == 0.5 ? 1 : max(0.0001,(current.y-anchor.y)/(start.y-anchor.y))
                if document.linkedProportions != shift {
                    let ratio = hx == 0.5 ? sy : hy == 0.5 ? sx : abs(sx-1) >= abs(sy-1) ? sx : sy
                    sx = ratio; sy = ratio
                }
                operation = try LayerGeometry.scale(x:sx,y:sy,around:anchor)
            } else { operation = try LayerGeometry.translation(x:current.x-gesture.start.x,y:current.y-gesture.start.y) }
            let matrix = try gesture.matrix.followed(by:operation)
            try document.preview { try $0.setTransform($1,matrix) }
        } catch { document.invalidateSession() }
    }
    func up(_ view:NSPoint, shift:Bool) {
        if pending != nil { pending?.latest = view; pending?.shift = shift; pending?.released = true; return }
        dragged(view,shift:shift)
        if gesture?.commitsOnRelease == true { gesture?.document.applySession() }
        gesture = nil
    }
    /// Releasing the mouse while Space pans ends the gesture at its last edit,
    /// without turning the viewport displacement into a layer displacement.
    func finishPointer() {
        cancelPendingPick()
        if gesture?.commitsOnRelease == true { gesture?.document.applySession() }
        gesture = nil
    }
    func keyDown(_ event:NSEvent) -> Bool {
        guard let document = canvas?.document else { return false }
        switch event.keyCode {
        case 36,76: document.applySession(); return true
        case 53: resetPointer(); document.cancelSession(); return true
        case 51,117:
            guard document.resolveSession() else { return true }
            do { try document.deleteSelected() } catch { NSSound.beep() }; return true
        case 123...126:
            guard !document.hasAdjustmentSession else {return true}
            guard document.canEditSelection else { return true }
            do {
                if document.toolSession == nil { try document.beginSession(.move); keyboardMove = true }
                let amount = event.modifierFlags.contains(.shift) ? 10.0 : 1
                let dx = event.keyCode == 123 ? -amount : event.keyCode == 124 ? amount : 0
                let dy = event.keyCode == 126 ? -amount : event.keyCode == 125 ? amount : 0
                try document.previewMove(x:dx,y:dy,fromOriginal:false)
            } catch { NSSound.beep() }; return true
        default: return false
        }
    }
    func keyUp(_ event:NSEvent) {
        if (123...126).contains(event.keyCode) { finishKeyboardMove() }
    }
    func finishKeyboardMove() { if keyboardMove { keyboardMove = false; canvas?.document?.applySession() } }
}

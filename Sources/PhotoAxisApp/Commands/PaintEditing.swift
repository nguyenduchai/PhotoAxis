import AppKit
import PhotoAxisCore

struct BrushSettings {
    var diameter = 40.0
    var hardness = 0.8
    var opacity = 1.0
    var aligned = true
}
struct PaintSession {
    let original: PhotoDocumentModel
    let previousSelection: UUID?
    let source: EmbeddedImage?
    let command: DocumentCommand
    var stroke: PaintStroke
    var candidate: PhotoDocumentModel
    var layerID: UUID
}

extension PhotoDocument {
    var canPaint: Bool {
        guard !isInteractionLocked, !hasSession || paintSession != nil else { return false }
        if let layer = selectedLayer, case .paint = layer.content { return !layer.isLocked && layer.isVisible }
        return model.layers.count < DocumentLimits.maximumLayers
    }
    func startPaint(at point: Point2D, source: EmbeddedImage? = nil, offset: Point2D? = nil) throws {
        guard canPaint, !hasSession else { throw DocumentError.activeSession }
        let kind: PaintStroke.Kind = activeTool == .cloneStamp ? .clone : .brush
        let stroke = PaintStroke(kind:kind,points:[point],diameter:brushSettings.diameter,hardness:brushSettings.hardness,
                                 opacity:brushSettings.opacity,color:foreground,sourceID:source?.descriptor.id,sourceOffset:offset)
        var candidate = model
        let id = try candidate.appendPaint(stroke,selectedID:selectedLayerID,source:source?.descriptor,name:localization.text("paint.layer"))
        paintSession = PaintSession(original:model,previousSelection:selectedLayerID,source:source,command:kind == .brush ? .brush:.cloneStamp,
                                    stroke:stroke,candidate:candidate,layerID:id)
        if let source { retainPaintAsset(source) }
        selectedLayerID = id; changed?()
    }
    func extendPaint(to point: Point2D) throws {
        guard var state = paintSession else { throw DocumentError.activeSession }
        if let last = state.stroke.points.last, hypot(last.x-point.x,last.y-point.y) < 0.25 { return }
        var stroke = state.stroke; stroke.points.append(point)
        var candidate = state.original
        let id = try candidate.appendPaint(stroke,selectedID:state.previousSelection,source:state.source?.descriptor,name:localization.text("paint.layer"))
        if id != state.layerID, let content = candidate.layer(id)?.content {
            candidate = state.candidate; try candidate.setContent(state.layerID,content)
        }
        state.stroke = stroke; state.candidate = candidate; paintSession = state; changed?()
    }
    func finishPaint() {
        guard let state = paintSession else { return }
        if commit(state.candidate,command:state.command) { paintSession = nil }; changed?()
    }
}

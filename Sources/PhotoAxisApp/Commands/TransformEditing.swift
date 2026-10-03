import AppKit
import PhotoAxisCore

enum TransformField: String, CaseIterable { case x, y, width, height, angle }

extension PhotoDocument {
    func startTransform() throws {
        if toolSession?.command == .transform { return }
        guard resolveSession() else { throw DocumentError.activeSession }
        try beginSession(.transform)
    }
    func transformValue(_ field: TransformField) throws -> Double {
        guard let layer = selectedLayer else { throw DocumentError.missingLayer }
        let bounds = try presentedModel.bounds(of: layer.id)
        switch field {
        case .x: return bounds.x
        case .y: return bounds.y
        case .width: return bounds.width
        case .height: return bounds.height
        case .angle: return try LayerGeometry.angle(size: presentedModel.localSize(of: layer), transform: layer.transform, clips:layer.clip)
        }
    }
    func setTransformValue(_ field: TransformField, _ value: Double) throws {
        guard value.isFinite else { throw DocumentError.invalidValue }
        try startTransform()
        let linked = linkedProportions
        try preview { model, id in
            let layer = model.layer(id)!, bounds = try model.bounds(of: id)
            let operation: ProjectiveTransform
            switch field {
            case .x: operation = try LayerGeometry.translation(x: value - bounds.x, y: 0)
            case .y: operation = try LayerGeometry.translation(x: 0, y: value - bounds.y)
            case .width:
                guard value >= 0.01 else { throw DocumentError.invalidValue }
                operation = try LayerGeometry.scale(x: value / bounds.width, y: linked ? value / bounds.width : 1, around: .init(x: bounds.x, y: bounds.y))
            case .height:
                guard value >= 0.01 else { throw DocumentError.invalidValue }
                operation = try LayerGeometry.scale(x: linked ? value / bounds.height : 1, y: value / bounds.height, around: .init(x: bounds.x, y: bounds.y))
            case .angle:
                let angle = try LayerGeometry.angle(size: model.localSize(of: layer), transform: layer.transform, clips:layer.clip)
                operation = try LayerGeometry.rotation(degrees: value - angle, around: bounds.center)
            }
            try model.setTransform(id, layer.transform.followed(by: operation))
        }
    }
    func flip(horizontal: Bool) throws {
        try startTransform()
        try preview { model, id in
            let bounds = try model.bounds(of: id)
            let operation = try LayerGeometry.scale(x: horizontal ? -1 : 1, y: horizontal ? 1 : -1, around: bounds.center)
            try model.setTransform(id, model.layer(id)!.transform.followed(by: operation))
        }
    }
    func centerSelected() throws {
        guard let id = selectedLayerID, resolveSession() else { return }
        try perform(.align) { model in
            let bounds = try model.bounds(of: id)
            let move = try LayerGeometry.translation(x: Double(model.canvas.width)/2-bounds.center.x, y: Double(model.canvas.height)/2-bounds.center.y)
            try model.setTransform(id, model.layer(id)!.transform.followed(by: move))
        }
    }
    func previewMove(x: Double, y: Double, fromOriginal: Bool) throws {
        try preview({ model, id in
            try model.setTransform(id, model.layer(id)!.transform.followed(by: LayerGeometry.translation(x: x, y: y)))
        }, fromOriginal: fromOriginal)
    }
}

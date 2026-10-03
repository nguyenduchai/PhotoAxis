import PhotoAxisCore

extension PhotoDocument {
    var hasAdjustmentSession: Bool { toolSession?.command == .adjustments }
    func startAdjustments() throws {
        if hasAdjustmentSession {return}
        guard selectedLayer.map({if case .image=$0.content{return true};return false}) == true else {throw DocumentError.invalidValue}
        guard resolveSession() else {throw DocumentError.activeSession}
        try beginSession(.adjustments)
    }
    func previewAdjustment(_ field: ImageAdjustmentField, value: Double) throws {
        try startAdjustments()
        try preview { model,id in
            var adjustment=model.layer(id)!.adjustments;adjustment[field]=value
            try model.setAdjustments(id,adjustment)
        }
    }
    func setAdjustmentsEnabled(_ enabled: Bool) throws {
        guard resolveSession(),let id=selectedLayerID else {throw DocumentError.activeSession}
        try perform(.adjustments) {model in
            var adjustment=model.layer(id)!.adjustments;adjustment.enabled=enabled;try model.setAdjustments(id,adjustment)
        }
    }
    func resetAdjustments() throws {
        guard resolveSession(),let id=selectedLayerID else {throw DocumentError.activeSession}
        try perform(.adjustments) {try $0.setAdjustments(id,ImageAdjustments())}
    }
}

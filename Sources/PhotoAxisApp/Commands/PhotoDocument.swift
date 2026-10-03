import AppKit
import PhotoAxisCore

@MainActor
final class PhotoDocument: NSDocument {
    private(set) var model: PhotoDocumentModel
    private(set) var assets: [String: EmbeddedImage] = [:]
    private(set) var history: DocumentHistory
    var viewport = ViewportState()
    var selectedLayerID: UUID?
    var activeTool: ToolKind = .hand
    var autoSelect = true
    var showTransformControls = true
    var linkedProportions = true
    var importInProgress = false
    var lifecycleLocked = false
    var investigationSession: InvestigationSession?
    /// Opening checkpoint for direct before/after review. COW data stays separate
    /// from History pruning and is released with the tab.
    private(set) var analysisBaseline: ProjectSnapshot?
    func retainAnalysisBaseline() { if analysisBaseline == nil { analysisBaseline = snapshot() } }
    var auditFailed: ((String) -> Void)?
    var investigationUnavailable: Bool { model.investigation != nil && investigationSession == nil }
    var isInteractionLocked: Bool { importInProgress || lifecycleLocked || investigationUnavailable }
    var changed: (() -> Void)?
    var foreground:RGBAColor = .black
    var background:RGBAColor = .white
    var textDefaults=TextContent(text:"",fontName:"Helvetica",fontSize:48,color:.black)
    var shapeDefaults=ShapeContent(kind:.rectangle,size:try! CanvasSize(width:1,height:1),fill:.black)
    var brushSettings = BrushSettings()
    var paintMessageKey = "paint.help"
    var paintSession: PaintSession?
    struct GeometrySession { let original: PhotoDocumentModel; let viewport: ViewportState; let command: DocumentCommand; var candidate: PhotoDocumentModel? }
    var geometrySession: GeometrySession?
    var contentSession:ContentSession?
    var cropSession: CropState?
    var perspectiveSession: PerspectiveState?
    var hasSession: Bool { geometrySession != nil || paintSession != nil || toolSession != nil || cropSession != nil || perspectiveSession != nil || contentSession != nil }
    var sessionIsValid: Bool { geometrySession.map { $0.candidate != nil } ?? (paintSession != nil || (contentSession.map { $0.isValid && !$0.isComposing } ?? perspectiveSession?.isValid ?? cropSession?.isValid ?? toolSession?.isValid ?? false)) }
    private(set) var toolSession: EditingSession?
    struct EditingSession {
        let command: DocumentCommand
        let layerID: UUID
        let original: PhotoDocumentModel
        var preview: PhotoDocumentModel
        var isValid = true
    }
    private var rebuildingUndo = false
    let localization: L10n
    var presentedModel: PhotoDocumentModel {
        if let geometrySession { return geometrySession.candidate ?? geometrySession.original }
        if let paintSession { return paintSession.candidate }
        if let state=perspectiveSession,state.showsPreview,let candidate=state.candidate {return candidate}
        return contentSession?.candidate ?? toolSession?.preview ?? model
    }
    var selectedLayer: PhotoLayer? { selectedLayerID.flatMap { presentedModel.layer($0) } }
    var canEditSelection: Bool { !isInteractionLocked && selectedLayer.map { !$0.isLocked } == true }

    init(model: PhotoDocumentModel, localization: L10n = L10n(choice: .system)) {
        self.model = model; history = DocumentHistory(model: model); self.localization = localization
        super.init()
        undoManager = UndoManager(); undoManager?.groupsByEvent = false
        selectedLayerID = model.layers.last?.id
    }
    override var isDocumentEdited: Bool { history.isDirty }
    override class var autosavesInPlace: Bool { false }
    override var displayName: String! { get { model.name } set {} }
    override func data(ofType typeName: String) throws -> Data { throw CocoaError(.featureUnsupported) }
    override func read(from data: Data, ofType typeName: String) throws { throw CocoaError(.featureUnsupported) }
    func markSaved(stateID: UUID) { history.markSaved(stateID: stateID); changed?() }
    func snapshot() -> ProjectSnapshot { ProjectSnapshot(model:model,assets:assets,stateID:history.stateID) }
    convenience init(loaded snapshot: ProjectSnapshot, url: URL?, localization: L10n) {
        self.init(model:snapshot.model,localization:localization)
        assets = snapshot.assets; fileURL = url; history = DocumentHistory(model:snapshot.model,stateID:snapshot.stateID)
        if url != nil { history.markSaved(stateID:history.stateID) }
    }
    func selectLayer(_ id: UUID) {
        guard model.layer(id) != nil, id == selectedLayerID || resolveSession() else { return }
        selectedLayerID = id; changed?()
    }
    func perform(_ command: DocumentCommand, _ operation: (inout PhotoDocumentModel) throws -> Void) throws {
        guard !hasSession, !isInteractionLocked else { throw DocumentError.activeSession }
        var next = model; try operation(&next)
        guard commit(next, command: command) else { if next != model { throw InvestigationError.auditUnavailable }; return }
    }
    @discardableResult func commit(_ next: PhotoDocumentModel, command: DocumentCommand) -> Bool {
        var newHistory = history
        guard newHistory.record(next, command: command, sourceBytes: assets.mapValues { $0.data.count }) else { return true }
        if model.investigation != nil {
            do {
                guard let investigationSession else { throw InvestigationError.missingCase }
                try investigationSession.record(command.rawValue, before: model, after: next, assets: assets)
            } catch { auditFailed?(localization.text((error as? InvestigationError)?.localizationKey ?? "investigation.error.auditUnavailable")); return false }
        }
        history = newHistory
        model = next; validateSelection(); reclaimAssets(); rebuildUndo(); changed?()
        return true
    }
    func place(_ asset: EmbeddedImage, recordHistory: Bool = true) throws {
        guard model.investigation == nil else { throw InvestigationError.protectedDestination }
        guard !hasSession else { throw DocumentError.activeSession }
        var next = model
        let id = try next.place(asset.descriptor, name: asset.name, above: selectedLayerID)
        assets[asset.descriptor.id] = asset; selectedLayerID = id
        if recordHistory { commit(next, command: .importImage) }
        else { model = next; history = DocumentHistory(model: next); rebuildUndo(); changed?() }
    }
    func duplicateSelected() throws {
        guard let id = selectedLayerID else { return }
        var copyID: UUID?
        try perform(.duplicate) { model in
            copyID = try model.duplicate(id, name: String(format: localization.text("layer.copyName"), model.layer(id)!.name))
        }
        selectedLayerID = copyID; changed?()
    }
    func deleteSelected() throws { guard let id = selectedLayerID else { return }; try perform(.delete) { try $0.delete(id) } }
    func beginSession(_ command: DocumentCommand) throws {
        guard !hasSession, !isInteractionLocked, let id = selectedLayerID, let selectedLayer else { throw DocumentError.activeSession }
        guard !selectedLayer.isLocked else { throw DocumentError.lockedLayer }
        toolSession = EditingSession(command: command, layerID: id, original: model, preview: model); changed?()
    }
    func preview(_ operation: (inout PhotoDocumentModel, UUID) throws -> Void, fromOriginal: Bool = false) throws {
        guard var session = toolSession else { throw DocumentError.activeSession }
        var next = fromOriginal ? session.original : session.preview
        do {
            try operation(&next, session.layerID); session.preview = next; session.isValid = true
            toolSession = session; changed?()
        } catch { toolSession?.isValid = false; changed?(); throw error }
    }
    func invalidateSession() { toolSession?.isValid = false; cropSession?.isValid = false; changed?() }
    func applySession() {
        if let state = geometrySession {
            guard let candidate = state.candidate else { return }
            if commit(candidate,command:state.command) { geometrySession = nil; viewport.fit(model.canvas) }; changed?(); return
        }
        if paintSession != nil { finishPaint(); return }
        if let state=contentSession {
            guard state.isValid,!state.isComposing else{return}
            if case .text(let text)=state.draft {
                guard !text.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{cancelSession();return}
                textDefaults=text;textDefaults.text=""
            } else if case .shape(let shape)=state.draft{shapeDefaults=shape}
            if commit(state.candidate,command:state.command) { contentSession=nil };changed?();return
        }
        if let state=perspectiveSession {
            guard state.isValid,let candidate=state.candidate else{return}
            if commit(candidate,command:.perspectiveCrop) { perspectiveSession=nil;activeTool=state.previousTool;viewport.fit(model.canvas) };changed?();return
        }
        if let crop=cropSession {
            guard crop.isValid else{return}
            do {
                var next=model;try next.crop(to:crop.region,output:crop.output)
                if commit(next,command:.crop) { cropSession=nil;activeTool=crop.previousTool;viewport.fit(model.canvas) };changed?()
            } catch {invalidateSession()}
            return
        }
        guard let session = toolSession, session.isValid else { return }
        if commit(session.preview, command: session.command) { toolSession = nil }; changed?()
    }
    func cancelSession() { guard hasSession else { return }; if let state = geometrySession { viewport = state.viewport }; geometrySession = nil; if let state = paintSession { selectedLayerID = state.previousSelection }; paintSession = nil; reclaimAssets(); if let state=contentSession{selectedLayerID=state.previousSelection};contentSession=nil; if let crop=cropSession {activeTool=crop.previousTool}; if let state=perspectiveSession {activeTool=state.previousTool;if let editing=state.editingViewport {viewport=editing}}; perspectiveSession=nil; toolSession = nil; cropSession = nil; changed?() }
    /// Switching tabs never calls this. Commands that replace/edit the session target do.
    func resolveSession() -> Bool {
        guard hasSession else { return true }
        let alert = NSAlert(); alert.messageText = localization.text("transform.resolveTitle")
        alert.informativeText = localization.text("transform.resolveBody")
        alert.addButton(withTitle: localization.text("action.cancel"))
        alert.addButton(withTitle: localization.text("transform.discard"))
        alert.addButton(withTitle: localization.text("action.apply")).isEnabled = sessionIsValid
        switch alert.runModal() {
        case .alertSecondButtonReturn: cancelSession(); return true
        case .alertThirdButtonReturn: applySession(); return !hasSession
        default: return false
        }
    }
    func jumpHistory(to index: Int) {
        guard !hasSession, !isInteractionLocked, (0...history.entries.count).contains(index) else { return }
        while history.cursor > index { let previous = history.cursor; undoManager?.undo(); if history.cursor == previous { break } }
        while history.cursor < index { let previous = history.cursor; undoManager?.redo(); if history.cursor == previous { break } }
    }
    private func validateSelection() {
        if selectedLayerID.flatMap({ model.layer($0) }) == nil { selectedLayerID = model.layers.last?.id }
    }
    func retainPaintAsset(_ asset: EmbeddedImage) { assets[asset.descriptor.id] = asset }
    private func reclaimAssets() { let ids = history.retainedSourceIDs.union(model.sources.keys); assets = assets.filter { ids.contains($0.key) } }
    private func registerRestore(to index: Int, from: Int, command: DocumentCommand) {
        undoManager?.registerUndo(withTarget: self) { document in
            // NSDocument UndoManager is used synchronously on the main actor.
            // Older Foundation SDKs declare this callback @Sendable without isolation.
            MainActor.assumeIsolated {
                document.registerRestore(to: from, from: index, command: command)
                if !document.rebuildingUndo {
                    if document.model.investigation != nil {
                        do {
                            guard let session = document.investigationSession else { throw InvestigationError.missingCase }
                            let next = index == 0 ? document.history.base : document.history.entries[index - 1].after
                            try session.record(index < document.history.cursor ? "undo" : "redo", before: document.model, after: next, assets: document.assets)
                        } catch {
                            document.auditFailed?(document.localization.text((error as? InvestigationError)?.localizationKey ?? "investigation.error.auditUnavailable"))
                            DispatchQueue.main.async { document.rebuildUndo() }; return
                        }
                    }
                    document.history.select(index); document.model = document.history.current
                    document.validateSelection(); document.changed?()
                }
            }
        }
        undoManager?.setActionName(localization.text(command.localizationKey))
    }
    private func rebuildUndo() {
        guard let manager = undoManager else { return }
        manager.removeAllActions(); rebuildingUndo = true
        for (index, entry) in history.entries.enumerated() {
            manager.beginUndoGrouping(); registerRestore(to: index, from: index + 1, command: entry.command); manager.endUndoGrouping()
        }
        for _ in history.cursor..<history.entries.count { manager.undo() }
        rebuildingUndo = false
    }
    var importBudget: ImportBudget {
        ImportBudget(remainingPixels: DocumentLimits.maximumUniqueSourcePixels - model.uniqueSourcePixels,
            knownSources: Set(model.sources.keys), layerCount: model.layers.count)
    }
}

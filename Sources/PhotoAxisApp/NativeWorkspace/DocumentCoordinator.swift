import AppKit
import PhotoAxisCore
import UniformTypeIdentifiers

/// Sole lifecycle authority for workspace tabs. NSDocument holds dirty state/undo;
/// Documents are intentionally not registered with NSDocumentController: its automatic
/// quit review would race this coordinator. P09/P11 extend this same authority.
@MainActor
final class DocumentCoordinator {
    private(set) var documents: [PhotoDocument] = []
    private(set) var activeID: UUID?
    var active: PhotoDocument? { documents.first { $0.model.id == activeID } }
    var changed: (() -> Void)?
    var progressChanged: ((String?) -> Void)?
    var report: ((String) -> Void)?
    var confirmResize: ((ImageImportError) -> Bool)?
    var investigationSessionFor: ((InvestigationReference) -> InvestigationSession?)?
    var protectInvestigationDestination: ((URL) throws -> Void)?
    private let preferences: WorkspacePreferences?
    private let opensLegacyProjectsAsCopies: Bool
    let pipeline: ImagePipeline
    let projectStore: ProjectStore
    let exportStore: ExportStore
    let recoveryStore: RecoveryStore
    var recoveryNotice: ((String) -> Void)?
    enum CloseChoice { case cancel, discard, save }
    var confirmClose: ((PhotoDocument) -> CloseChoice)?
    private var recoveryLoop: Task<Void,Never>?
    private var recoveredStates: [UUID:UUID] = [:]
    private var recoveryReported = false
    private(set) var projectTask: Task<Bool,Never>?
    private var isChoosingSaveLocation = false
    private(set) var isClosing = false
    var isSaving: Bool { projectTask != nil || isChoosingSaveLocation }
    private let localization: L10n
    private(set) var importTask: Task<Void, Never>?
    private var importID: UUID?
    var isImporting: Bool { importTask != nil }
    init(localization: L10n, pipeline: ImagePipeline = ImagePipeline(), recoveryRoot: URL? = nil, preferences: WorkspacePreferences? = nil, opensLegacyProjectsAsCopies: Bool = false) {
        self.opensLegacyProjectsAsCopies = opensLegacyProjectsAsCopies
        self.preferences = preferences
        self.localization = localization; self.pipeline = pipeline; projectStore = ProjectStore(pipeline:pipeline)
        exportStore = ExportStore(pipeline:pipeline)
        recoveryStore = RecoveryStore(root:recoveryRoot ?? RecoveryStore.defaultRoot,pipeline:pipeline)
        if opensLegacyProjectsAsCopies { protectInvestigationDestination = Self.protectLegacyDestination }
    }
    /// Production no longer manages cases. Never write into an old case archive,
    /// including a destination reached through a symlink.
    static func protectLegacyDestination(_ destination: URL) throws {
        func inspect(_ value: URL) throws {
            var path = value
            while path.path != "/" {
                guard path.pathExtension.lowercased() != "paxcase" else { throw InvestigationError.protectedDestination }
                path.deleteLastPathComponent()
            }
        }
        try inspect(destination.standardizedFileURL)
        // Foundation may not resolve a parent symlink if the final file does not
        // exist yet. Resolve the nearest existing ancestor before adding the tail.
        var ancestor = destination.standardizedFileURL, tail: [String] = []
        while ancestor.path != "/", !FileManager.default.fileExists(atPath: ancestor.path) {
            tail.append(ancestor.lastPathComponent); ancestor.deleteLastPathComponent()
        }
        var resolved = ancestor.resolvingSymlinksInPath().standardizedFileURL
        for component in tail.reversed() { resolved.appendPathComponent(component) }
        try inspect(resolved)
    }

    private func ordinaryCopy(_ snapshot: ProjectSnapshot) -> ProjectSnapshot {
        guard opensLegacyProjectsAsCopies, snapshot.model.investigation != nil else { return snapshot }
        var model = snapshot.model; model.investigation = nil
        return ProjectSnapshot(model: model, assets: snapshot.assets, stateID: snapshot.stateID)
    }

    func add(_ document: PhotoDocument) throws {
        guard documents.count < DocumentLimits.maximumDocuments else { throw CocoaError(.validationMultipleErrors) }
        if !opensLegacyProjectsAsCopies { document.retainAnalysisBaseline() }
        if let preferences { document.brushSettings = preferences.brushDefaults }
        document.changed = { [weak self] in self?.changed?() }
        document.auditFailed = { [weak self] in self?.report?($0) }
        documents.append(document)
        select(document.model.id)
    }
    func create(name: String, size: CanvasSize, ppi: Double, background: DocumentBackground) throws {
        try add(PhotoDocument(model: PhotoDocumentModel(name: name, canvas: size, ppi: ppi,
            background: background, backgroundName: localization.text("document.background")), localization: localization))
    }
    func select(_ id: UUID) {
        guard documents.contains(where: { $0.model.id == id }) else { return }
        activeID = id; changed?()
        let ids = Set(active?.assets.keys.map { $0 } ?? [])
        Task { await pipeline.retainCache(for: ids) }
    }
    func remove(_ id: UUID) {
        guard let index = documents.firstIndex(where: { $0.model.id == id }) else { return }
        let document = documents.remove(at: index)
        document.close()
        if activeID == id { activeID = documents.isEmpty ? nil : documents[min(index, documents.count - 1)].model.id }
        changed?()
        let ids = Set(active?.assets.keys.map { $0 } ?? [])
        Task { await pipeline.retainCache(for: ids) }
    }
    func startRecovery() {
        guard recoveryLoop == nil else { return }
        recoveryLoop = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for:.seconds(self?.preferences?.files.recoverySeconds ?? 10)) } catch { break }
                guard let self else { break }; await flushRecovery()
            }
        }
    }
    func stopRecovery() { recoveryLoop?.cancel(); recoveryLoop = nil }
    private func recoveryFailure(_ error:Error) {
        guard !recoveryReported else { return }; recoveryReported = true
        recoveryNotice?(localization.text("recovery.failed"))
    }
    func flushRecovery() async {
        guard !isClosing else { return }
        for document in documents {
            guard !isClosing, documents.contains(where:{$0 === document}) else { continue }
            let snapshot = document.snapshot() // committed model only, never presentedModel
            do {
                if document.isDocumentEdited {
                    guard recoveredStates[document.model.id] != snapshot.stateID else { continue }
                    if try await recoveryStore.write(snapshot), documents.contains(where:{$0 === document}), document.history.stateID == snapshot.stateID {
                        recoveredStates[document.model.id] = snapshot.stateID
                    }
                } else {
                    try await recoveryStore.discard(document.model.id,stateID:snapshot.stateID)
                    recoveredStates[document.model.id] = nil
                }
            } catch is CancellationError { return }
            catch { recoveryFailure(error) }
        }
    }
    func recoveryEntries() async -> [RecoveryEntry] {
        do { return try await recoveryStore.list() } catch { recoveryFailure(error); return [] }
    }
    func openRecovered(_ entry:RecoveryEntry) async -> Bool {
        guard documents.count < DocumentLimits.maximumDocuments, !documents.contains(where:{$0.model.id == entry.id}) else { report?(localization.text("recovery.alreadyOpen")); return false }
        do {
            var snapshot = ordinaryCopy(try await recoveryStore.open(entry))
            let session = snapshot.model.investigation.flatMap { investigationSessionFor?($0) }
            if let session { snapshot = try await session.store.openSnapshot(session.itemID, projects: projectStore) }
            let document = PhotoDocument(loaded:snapshot,url:nil,localization:localization); document.investigationSession = session
            try add(document)
            if document.investigationUnavailable { report?(localization.text("investigation.error.missingCase")) }
            recoveredStates[entry.id] = snapshot.stateID; return true
        } catch { recoveryFailure(error); return false }
    }
    func discardRecovery(_ entry:RecoveryEntry) async -> Bool {
        do { try await recoveryStore.discard(entry.id); recoveredStates[entry.id] = nil; return true }
        catch { recoveryFailure(error); return false }
    }
    private func mayClose(_ document: PhotoDocument) async -> Bool {
        guard document.isDocumentEdited else { return true }
        let choice: CloseChoice
        if let confirmClose { choice = confirmClose(document) }
        else {
            let alert = NSAlert()
            alert.messageText = String(format: localization.text("document.closeTitle"), document.model.name)
            alert.informativeText = localization.text("project.closeBody")
            alert.addButton(withTitle: localization.text("action.cancel"))
            alert.addButton(withTitle: localization.text("document.dontSave"))
            alert.addButton(withTitle: localization.text("action.save"))
            switch alert.runModal() {
            case .alertSecondButtonReturn: choice = .discard
            case .alertThirdButtonReturn: choice = .save
            default: choice = .cancel
            }
        }
        switch choice {
        case .discard: return true
        case .save: return await save(document,saveAs:false) && !document.isDocumentEdited
        case .cancel: return false
        }
    }
    func requestClose(_ id: UUID) {
        guard !isClosing, !isChoosingSaveLocation, let document = documents.first(where: { $0.model.id == id }) else { return }
        Task { _ = await closeDocuments([document]) }
    }
    func requestCloseAll() async -> Bool { await closeDocuments(documents) }
    private func closeDocuments(_ targets:[PhotoDocument]) async -> Bool {
        guard !isClosing, !isChoosingSaveLocation else { return false }
        isClosing = true
        defer { targets.forEach { $0.lifecycleLocked = false }; isClosing = false; changed?() }
        // Resolve sessions before freezing edits. A user-approved Apply is a real
        // committed edit even if a subsequent close prompt is cancelled.
        for document in targets { guard document.resolveSession() else { return false } }
        cancelImportJob()
        targets.forEach { $0.lifecycleLocked = true }; changed?()
        // Wait for the current atomic Save/Export; the visible Cancel task action
        // can still cancel it. Never close underneath a SavePanel.
        if let projectTask { _ = await projectTask.value }
        for document in targets { guard await mayClose(document) else { return false } }
        var groups: [ObjectIdentifier: (InvestigationCaseStore, [UUID])] = [:]
        for document in targets where document.isDocumentEdited {
            if let session = document.investigationSession {
                let key = ObjectIdentifier(session.store)
                var group = groups[key] ?? (session.store, []); group.1.append(session.itemID); groups[key] = group
            }
        }
        do { for group in groups.values { try group.0.discardMany(group.1) } }
        catch { report?(localization.text("investigation.error.auditUnavailable")); return false }
        // Don't Save cleanup happens only after ALL decisions have succeeded.
        for document in targets {
            do { try await recoveryStore.discard(document.model.id); recoveredStates[document.model.id] = nil }
            catch { recoveryFailure(error); return false }
        }
        for document in targets { remove(document.model.id) }
        return true
    }
    private func cancelImportJob() { documents.forEach { $0.importInProgress = false }; importID = nil; importTask?.cancel(); importTask = nil }
    func cancelImport() { projectTask?.cancel(); documents.forEach { $0.importInProgress = false }; importID = nil; importTask?.cancel(); importTask = nil; progressChanged?(nil); changed?() }

    func save(_ document: PhotoDocument, saveAs: Bool, destination: URL? = nil) async -> Bool {
        guard !isSaving, !isImporting, !document.investigationUnavailable, document.resolveSession() else { return false }
        if saveAs && document.model.investigation != nil { report?(localization.text("investigation.managedSave")); return false }
        let url: URL
        if let session = document.investigationSession {
            let managed = session.store.projectURL(session.itemID)
            guard destination == nil || destination?.standardizedFileURL == managed.standardizedFileURL else { report?(localization.text("investigation.error.protectedDestination")); return false }
            url = managed
        }
        else if let destination { url = destination }
        else if !saveAs, let existing = document.fileURL { url = existing }
        else {
            isChoosingSaveLocation = true; changed?()
            defer { isChoosingSaveLocation = false; changed?() }
            let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension:"paxis") ?? .data]
            panel.canCreateDirectories = true; panel.nameFieldStringValue = document.model.name + ".paxis"
            panel.title = localization.text("action.saveAs"); panel.message = localization.text("project.saveHelp")
            let response: NSApplication.ModalResponse
            if let window = NSApp.keyWindow { response = await panel.beginSheetModal(for:window) }
            else { response = panel.runModal() }
            guard response == .OK, let selected = panel.url else { return false }; url = selected
        }
        let snapshot = document.snapshot()
        do {
            if let session = document.investigationSession {
                try await session.store.verifyOriginal(try session.store.item(session.itemID))
                try session.store.mutate("workingSaveStarted", itemID: session.itemID, details: ["snapshotSHA256": InvestigationDigest.hash(try ProjectSchema(snapshot.model).encoded())])
            } else { try protectInvestigationDestination?(url) }
        } catch { report?(localization.text("investigation.error.integrity")); return false }
        progressChanged?(String(format:localization.text("project.saving"),document.model.name))
        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            defer { projectTask = nil; progressChanged?(nil); changed?() }
            do {
                if let session = document.investigationSession {
                    document.fileURL = try await session.store.saveWorking(session.itemID, snapshot: snapshot, projects: projectStore)
                } else { try await projectStore.save(snapshot,to:url); document.fileURL = url }
                document.markSaved(stateID:snapshot.stateID)
                do { try await recoveryStore.discard(document.model.id,stateID:snapshot.stateID); recoveredStates[document.model.id] = nil }
                catch { recoveryFailure(error) }
                return true
            } catch is CancellationError { return false }
            catch { report?(String(format:localization.text("project.writeError"), error.localizedDescription)); return false }
        }
        projectTask = task; changed?(); return await task.value
    }
    func export(_ snapshot: ProjectSnapshot, options: ExportOptions, destination: URL? = nil) async -> Bool {
        guard !isSaving, !isImporting, !isClosing else { return false }
        let investigationSession = snapshot.model.investigation.flatMap { investigationSessionFor?($0) }
        if snapshot.model.investigation != nil {
            // Investigation sharing has its own reviewed/flattened export path.
            report?(localization.text(investigationSession == nil ? "investigation.error.missingCase" : "investigation.useSharing")); return false
        }
        let url: URL
        if let destination { url = destination }
        else {
            isChoosingSaveLocation = true; changed?(); defer { isChoosingSaveLocation = false; changed?() }
            let panel = NSSavePanel(); panel.allowedContentTypes = [options.format == .png ? .png : .jpeg]
            panel.title = localization.text("action.export"); panel.message = localization.text("export.saveHelp")
            panel.nameFieldStringValue = snapshot.model.name + (options.format == .png ? ".png" : ".jpg")
            let response: NSApplication.ModalResponse
            if let window = NSApp.keyWindow { response = await panel.beginSheetModal(for:window) } else { response = panel.runModal() }
            guard response == .OK, let selected = panel.url else { return false }; url = selected
        }
        progressChanged?(String(format:localization.text("export.progress"),snapshot.model.name))
        do { try protectInvestigationDestination?(url) } catch { report?(localization.text("investigation.error.protectedDestination")); return false }
        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }; defer { projectTask = nil; progressChanged?(nil); changed?() }
            do { try await exportStore.write(snapshot,options:options,to:url); return true }
            catch is CancellationError { return false }
            catch { report?(String(format:localization.text("export.writeError"),error.localizedDescription)); return false }
        }
        projectTask = task; changed?(); return await task.value
    }

    func startImport(_ inputs: [ImageInput], into targetID: UUID?) {
        guard importTask == nil, !isClosing, !isSaving else { report?(localization.text("import.busy")); return }
        if let target = targetID.flatMap({ id in documents.first { $0.model.id == id } }) {
            guard target.model.investigation == nil else { report?(localization.text("investigation.useIntake")); return }
            guard target.resolveSession() else { return }; target.importInProgress = true
        }
        let job = UUID(); importID = job
        importTask = Task { [weak self] in
            guard let self else { return }
            var messages: [String] = []
            for (index, input) in inputs.enumerated() {
                guard !Task.isCancelled, importID == job else { break }
                let target = targetID.flatMap { id in documents.first { $0.model.id == id } }
                if targetID != nil && target == nil { break } // Closed target never redirects into another tab.
                if targetID == nil && documents.count >= DocumentLimits.maximumDocuments {
                    messages.append(String(format: localization.text("import.fileError"), input.name, localization.text("document.tabLimit"))); continue
                }
                progressChanged?(String(format: localization.text("import.progress"), index + 1, inputs.count, input.name))
                do {
                    if case .file(let url) = input, url.pathExtension.lowercased() == "paxis", targetID == nil {
                        let original = try await projectStore.open(url)
                        let detached = opensLegacyProjectsAsCopies && original.model.investigation != nil
                        var snapshot = ordinaryCopy(original)
                        let session = snapshot.model.investigation.flatMap { investigationSessionFor?($0) }
                        if let session { snapshot = try await session.store.openSnapshot(session.itemID, projects: projectStore) }
                        guard !Task.isCancelled, importID == job else { break }
                        if let existing = documents.first(where: { $0.model.id == snapshot.model.id }) {
                            if detached || existing.fileURL?.standardizedFileURL == url.standardizedFileURL { select(existing.model.id) }
                            else { throw ProjectError.invalidDocument }
                        } else {
                            let document = PhotoDocument(loaded:snapshot,url:detached ? nil : url,localization:localization); document.investigationSession = session
                            try add(document)
                            if document.investigationUnavailable { report?(localization.text("investigation.error.missingCase")) }
                        }
                        let missing = snapshot.model.layers.compactMap { layer -> String? in
                            if case .text(let text) = layer.content, ContentRasterizer.missingFont(text) { return text.fontName }; return nil
                        }
                        for font in Set(missing).sorted() { messages.append(String(format:localization.text("type.missingFont"),font)) }
                        continue
                    }
                    let budget = target?.importBudget ?? ImportBudget()
                    let asset: EmbeddedImage
                    do { asset = try await pipeline.prepare(input, budget: budget) }
                    catch let error as ImageImportError {
                        guard !Task.isCancelled, importID == job else { break }
                        if case .resizeRequired = error, confirmResize?(error) == true {
                            asset = try await pipeline.prepare(input, budget: budget, allowResize: true)
                        } else { throw error }
                    }
                    guard !Task.isCancelled, importID == job else { break }
                    if let targetID {
                        guard let live = documents.first(where: { $0.model.id == targetID }), live === target else { break }
                        try live.place(asset) // Recheck quotas atomically on the current model.
                    } else {
                        let document = PhotoDocument(model: try PhotoDocumentModel(name: input.name, canvas: asset.descriptor.size, ppi: asset.ppi), localization: localization)
                        try document.place(asset, recordHistory: false); try add(document)
                    }
                    if asset.convertedToSDR { messages.append(String(format: localization.text("import.fileError"), input.name, localization.text("import.sdr"))) }
                    changed?()
                } catch is CancellationError { break }
                catch {
                    let key = (error as? ProjectError)?.localizationKey ?? (error as? ImageImportError)?.key ?? "import.unreadable"
                    messages.append(String(format: localization.text("import.fileError"), input.name, localization.text(key)))
                }
            }
            guard importID == job else { return }
            documents.forEach { $0.importInProgress = false }; importTask = nil; importID = nil; progressChanged?(nil); changed?()
            if !messages.isEmpty { report?(messages.joined(separator: "\n\n")) }
        }
        changed?()
    }
}

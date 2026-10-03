import AppKit
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore

@MainActor
final class InvestigationController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let localization: L10n
    let coordinator: DocumentCoordinator
    var workingOpened: (() -> Void)?
    private(set) var store: InvestigationCaseStore?
    private var stores: [UUID: InvestigationCaseStore] = [:]
    let sourcePanel = InvestigationWorkspacePanel(), analysisPanel = InvestigationWorkspacePanel(), outputPanel = InvestigationWorkspacePanel()
    private weak var workspace: WorkspaceView?
    private let caseSelector = NSPopUpButton()
    private var synchronizing = false
    private var pending: CheckedContinuation<[String]?, Never>?
    private var pendingPanel: InvestigationWorkspacePanel?
    private var parameterFields: [String: NSTextField] = [:]
    private var parameterOutputs: [() -> String] = []
    private var parameterTitle = ""
    private var requestID = UUID()
    private var activeContext: String?
    private var openImageContexts: [UUID: OpenImageAnalysis] = [:]
    private let analysisTarget = NSTextField(wrappingLabelWithString: "")
    private let outputTarget = NSTextField(wrappingLabelWithString: "")
    var analysisStore: InvestigationCaseStore? {
        guard let document = coordinator.active else { return nil }
        if let session = document.investigationSession { return session.store }
        guard let context = openImageContexts[document.model.id], context.matches(document) else { return nil }
        return context.store
    }
    var analysisItem: EvidenceItem? {
        guard let document = coordinator.active, let store = analysisStore else { return nil }
        let id = document.investigationSession?.itemID ?? openImageContexts[document.model.id]?.itemID
        return store.value.items.first { $0.id == id }
    }
    private var canAnalyze: Bool {
        guard let document = coordinator.active else { return false }
        return !document.isInteractionLocked && !document.hasSession && !coordinator.isSaving && !coordinator.isClosing && !coordinator.isImporting
    }
    /// Freeze the committed active canvas; recheck after each async capture so
    /// switching tabs or editing cannot silently target an older case selection.
    func prepareActiveImage() async throws -> (InvestigationCaseStore, EvidenceItem) {
        guard canAnalyze, let document = coordinator.active else { throw InvestigationError.missingCase }
        if let store = analysisStore, let item = analysisItem { return (store, item) }
        let context = try await OpenImageAnalysis.capture(document, coordinator: coordinator, localization: localization)
        guard coordinator.active === document, context.matches(document), canAnalyze else { throw CancellationError() }
        openImageContexts[document.model.id] = context
        context.store.changed = { [weak self] in self?.updateButtons() }
        updateButtons()
        return (context.store, try context.store.item(context.itemID))
    }
    private var capture: InvestigationCaptureView?
    private var annotationUsesSource = false
    var hasPendingParameters: Bool { pending != nil }
    private var ocrSupported = false
    private let table = NSTableView()
    private let detail = NSTextView()
    private let heading = NSTextField(labelWithString: "")
    private var buttons: [NSButton] = []
    private var busy = false { didSet {
        updateButtons(); table.isEnabled = !busy
        for panel in [sourcePanel, analysisPanel, outputPanel] { if busy { panel.status.stringValue = localization.text("investigation.processing") } else if panel.status.stringValue == localization.text("investigation.processing") { panel.status.stringValue = "" } }
    } }
    var selectedItem: EvidenceItem? { guard let store, store.value.items.indices.contains(table.selectedRow) else { return nil }; return store.value.items[table.selectedRow] }
    init(coordinator: DocumentCoordinator, localization: L10n) {
        self.coordinator = coordinator; self.localization = localization
        super.init()
        let create = button("investigation.create", #selector(createCase)), open = button("investigation.open", #selector(openCase))
        let intake = button("investigation.import", #selector(importPhotos)), edit = button("investigation.editIntake", #selector(editIntake))
        let editImage = button("investigation.editImage", #selector(openWorking)), verify = button("investigation.verify", #selector(verifyCase))
        let compare = button("investigation.compare", #selector(compareImages)), annotate = button("investigation.annotate", #selector(annotateImage))
        let mask = button("investigation.redact", #selector(reviewRedactions)), png = button("investigation.exportPNG", #selector(exportPNG))
        let pdf = button("investigation.exportPDF", #selector(exportPDF)), catalog = button("investigation.exportCatalog", #selector(exportCatalog))
        let log = button("investigation.exportLog", #selector(exportLog)), caseInfo = button("investigation.editCase", #selector(editCase))
        let ocr = button("investigation.ocr", #selector(recognizeText)), review = button("investigation.reviewOCR", #selector(reviewOCR))
        let video = button("investigation.importVideo", #selector(importVideo)), frame = button("investigation.extractFrame", #selector(extractFrame))
        let calibrate = button("investigation.calibrate", #selector(calibrate)), measure = button("investigation.measure", #selector(measure))
        let analysis = button("investigation.exportAnalysis", #selector(exportAnalysis))
        let column = NSTableColumn(identifier: .init("photos")); column.title = localization.text("investigation.photos"); column.width = 280
        table.addTableColumn(column); table.dataSource = self; table.delegate = self; table.allowsMultipleSelection = false
        table.target = self; table.action = #selector(openWorking)
        table.setAccessibilityIdentifier("investigation.photos")
        let list = NSScrollView(); list.documentView = table; list.hasVerticalScroller = true; list.borderType = .bezelBorder
        list.heightAnchor.constraint(equalToConstant: 170).isActive = true
        detail.isEditable = false; detail.isSelectable = true; detail.font = .systemFont(ofSize: 11)
        detail.setAccessibilityIdentifier("investigation.details")
        let info = NSScrollView(); info.documentView = detail; info.hasVerticalScroller = true; info.borderType = .bezelBorder
        info.heightAnchor.constraint(equalToConstant: 220).isActive = true
        heading.font = .boldSystemFont(ofSize: 13); heading.lineBreakMode = .byTruncatingTail
        caseSelector.target = self; caseSelector.action = #selector(changeCase)
        caseSelector.setAccessibilityIdentifier("workspace.caseSelector")
        sourcePanel.append(heading); sourcePanel.append(caseSelector)
        for button in [create, open, caseInfo, intake, video] { sourcePanel.append(button) }
        sourcePanel.append(list)
        for button in [editImage, edit, verify] { sourcePanel.append(button) }; sourcePanel.append(info)
        analysisTarget.setAccessibilityIdentifier("investigation.activeImage")
        outputTarget.setAccessibilityIdentifier("investigation.outputImage")
        analysisPanel.append(analysisTarget); outputPanel.append(outputTarget)
        sourcePanel.append(button("investigation.saveCurrentAnalysis", #selector(saveCurrentAnalysis)))
        analysisPanel.append(button("investigation.saveCurrentAnalysis", #selector(saveCurrentAnalysis)))
        for button in [compare, annotate, ocr, review, frame, calibrate, measure] { analysisPanel.append(button) }
        for button in [mask, png, pdf, catalog, log, analysis] { outputPanel.append(button) }
        outputPanel.append(NSTextField(wrappingLabelWithString: localization.text("investigation.notice")))
        outputPanel.append(NSTextField(wrappingLabelWithString: localization.text("investigation.analysisExportHelp")))
        coordinator.investigationSessionFor = { [weak self] reference in self?.session(reference) }
        coordinator.protectInvestigationDestination = { [weak self] url in
            var parent = url.standardizedFileURL.resolvingSymlinksInPath()
            while parent.path != "/" {
                if parent.pathExtension.lowercased() == "paxcase" { throw InvestigationError.protectedDestination }
                parent.deleteLastPathComponent()
            }
            for store in self?.stores.values ?? Dictionary<UUID, InvestigationCaseStore>().values { try store.protectDestination(url) }
        }
        refresh()
        Task { let available = await Task.detached { (try? InvestigationAnalysisEngine.ocrLanguage()) != nil }.value
            ocrSupported = available; updateButtons()
        }
    }
    func attach(to workspace: WorkspaceView) {
        self.workspace = workspace
        workspace.sidebar.installPages([sourcePanel, analysisPanel, outputPanel])
        workspace.sidebar.pageChanged = { [weak self] _ in self?.cancelParameters(); self?.workspace?.dismissPresentation() }
        workspace.presentationDismissed = { [weak self] in self?.capture = nil }
    }
    func synchronizeActiveDocument() {
        let active = coordinator.active
        let context = active.map { $0.model.id.uuidString + InvestigationDigest.hash((try? ProjectSchema($0.model).encoded()) ?? Data()) }
        if activeContext != context { cancelParameters(); workspace?.dismissPresentation(); activeContext = context }
        let liveIDs = Set(coordinator.documents.map { $0.model.id })
        openImageContexts = openImageContexts.filter { liveIDs.contains($0.key) }
        updateButtons()
        guard let session = active?.investigationSession else { return }
        if store !== session.store { use(session.store) }
        if let row = session.store.value.items.firstIndex(where: { $0.id == session.itemID }), table.selectedRow != row {
            synchronizing = true; table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false); synchronizing = false
            displayDetails(); updateButtons()
        }
    }
    @objc private func changeCase() {
        guard let id = caseSelector.selectedItem?.representedObject as? UUID, let store = stores[id], !busy else { return }
        use(store); workspace?.dismissPresentation(); openWorking()
    }
    private func button(_ key: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: localization.text(key), target: self, action: action)
        button.setAccessibilityIdentifier(key); button.setAccessibilityLabel(localization.text(key)); buttons.append(button); return button
    }
    func session(_ reference: InvestigationReference) -> InvestigationSession? {
        guard let store = stores[reference.caseID], store.value.items.contains(where: { $0.id == reference.itemID }) else { return nil }
        return InvestigationSession(store: store, itemID: reference.itemID)
    }
    func use(_ store: InvestigationCaseStore) {
        if self.store !== store { cancelParameters() }
        self.store = store; stores[store.value.id] = store
        caseSelector.removeAllItems()
        for candidate in stores.values.sorted(by: { $0.value.code < $1.value.code }) {
            caseSelector.addItem(withTitle: candidate.value.code + " — " + candidate.value.title)
            caseSelector.lastItem?.representedObject = candidate.value.id
            if candidate === store { caseSelector.select(caseSelector.lastItem) }
        }
        store.changed = { [weak self] in self?.refresh() }; refresh()
    }
    private func refresh() {
        heading.stringValue = store.map { $0.value.code + " — " + $0.value.title } ?? localization.text("investigation.noCase")
        synchronizing = true; defer { synchronizing = false }
        let selected = table.selectedRow; table.reloadData()
        if let store, !store.value.items.isEmpty { table.selectRowIndexes(IndexSet(integer: min(max(0, selected), store.value.items.count - 1)), byExtendingSelection: false) }
        displayDetails()
        updateButtons()
    }
    private func updateButtons() {
        caseSelector.isEnabled = !busy && pending == nil
        let item = analysisItem, targetStore = analysisStore
        let description: String
        if let document = coordinator.active {
            let mode = document.investigationSession != nil ? localization.text("investigation.currentCaseImage") : localization.text(openImageContexts[document.model.id].map { $0.matches(document) && !$0.isTemporary } == true ? "investigation.currentSavedCanvasImage" : "investigation.currentCanvasImage")
            description = document.model.name + "\n" + mode
        } else { description = localization.text("investigation.noActiveImage") }
        for label in [analysisTarget, outputTarget] { label.stringValue = description; label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor }
        for button in buttons {
            let key = button.accessibilityIdentifier() ?? ""
            var enabled = !busy && pending == nil
            switch key {
            case "investigation.create", "investigation.open": break
            case "investigation.import", "investigation.importVideo", "investigation.editCase", "investigation.verify": enabled = enabled && store != nil
            case "investigation.editIntake", "investigation.editImage": enabled = enabled && selectedItem != nil
            case "investigation.extractFrame": enabled = enabled && store?.value.analysis?.videos.isEmpty == false
            case "investigation.reviewOCR": enabled = enabled && canAnalyze && targetStore?.value.analysis?.ocr.contains(where: { $0.itemID == item?.id }) == true
            case "investigation.measure": enabled = enabled && canAnalyze && targetStore?.value.analysis?.calibrations.contains(where: { $0.itemID == item?.id && $0.modelSHA256 == item.map { InvestigationDigest.hash($0.currentModelJSON) } }) == true
            case "investigation.ocr":
                enabled = enabled && canAnalyze && ocrSupported
                button.toolTip = ocrSupported ? nil : localization.text("investigation.error.ocrUnavailable")
            case "investigation.saveCurrentAnalysis": enabled = enabled && canAnalyze && coordinator.active?.model.investigation == nil
            default: enabled = enabled && canAnalyze
            }
            button.isEnabled = enabled
        }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { store?.value.items.count ?? 0 }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let store, store.value.items.indices.contains(row) else { return nil }
        let item = store.value.items[row]; return item.code + "  " + item.originalName
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        displayDetails(); updateButtons()
        guard !synchronizing, !busy else { return }
        cancelParameters(); workspace?.dismissPresentation(); openWorking()
    }
    private func displayDetails() {
        guard let store else { detail.string = localization.text("investigation.noCase"); return }
        var text = localization.text("investigation.caseSummary") + "\n" + store.value.title + "\n" + store.value.examiner + "\n"
        if let item = selectedItem {
            text += "\n\(item.code) — \(item.originalName)\n\(item.caption)\n"
            text += "\nSHA-256 (original): \(item.originalSHA256)\nSHA-256 (working source): \(item.workingSourceSHA256)\nBytes: \(item.originalByteCount)\n"
            text += "\n" + localization.text("investigation.intake") + "\n" + intakeFields(item.intake).map { localization.text($0.0) + ": " + $0.1 }.joined(separator: "\n")
            text += "\n\n" + localization.text("investigation.metadata") + "\n" + item.originalMetadataJSON
            text += "\n\n" + localization.text("investigation.regions") + "\n" + String(item.redactions.count)
        }
        if let analysis = store.value.analysis {
            text += "\n" + localization.text("investigation.analysis") + ": OCR \(analysis.ocr.filter { $0.itemID == selectedItem?.id }.count), "
            text += localization.text("investigation.measure") + " \(analysis.measurements.filter { result in analysis.calibrations.contains { $0.id == result.calibrationID && $0.itemID == selectedItem?.id } }.count)\n"
        }
        text += "\n" + localization.text("investigation.log") + "\n"
        for event in store.value.events.suffix(15) where selectedItem == nil || event.payload.itemID == nil || event.payload.itemID == selectedItem?.id {
            text += "#\(event.payload.sequence) \(event.payload.recordedAt) | \(event.payload.operation) | \(event.payload.operatorName)\n"
        }
        detail.string = text
    }
    private func alert(_ message: String) { for panel in [sourcePanel, analysisPanel, outputPanel] { panel.status.stringValue = message }; workspace?.setImportProgress(message); workspace?.cancelImportButton.isHidden = true }
    private func failure(_ error: Error) { if error is CancellationError { return }; alert(localization.text((error as? InvestigationError)?.localizationKey ?? (error as? ImageImportError)?.key ?? "investigation.error.auditUnavailable")) }
    @objc private func editCase() { Task { await editCaseFlow() } }
    private func editCaseFlow() async {
        guard let store, !busy, let values = await parameters("investigation.editCase", fields: [("investigation.code", store.value.code), ("investigation.caseTitle", store.value.title), ("investigation.examiner", store.value.examiner)]) else { return }
        do {
            try store.mutate("caseInformationAmended", details: ["previousCode": store.value.code, "previousTitle": store.value.title, "previousOperator": store.value.examiner,
                                                               "code": values[0], "title": values[1], "operator": values[2]]) { value in
                value.code = values[0]; value.title = values[1]; value.examiner = values[2]
            }
        } catch { failure(error) }
    }
    private func parameters(_ title: String, fields: [(String, String)], help: String = "") async -> [String]? {
        cancelParameters()
        annotationUsesSource = false
        parameterTitle = title; parameterFields = [:]; parameterOutputs = []; requestID = UUID()
        let page = ["investigation.redact", "investigation.exportPDF"].contains(title) ? 3 : ["investigation.create", "investigation.editCase", "investigation.intake", "investigation.editIntake", "investigation.saveCurrentAnalysis"].contains(title) ? 1 : 2
        let panel = [sourcePanel, analysisPanel, outputPanel][page - 1]; pendingPanel = panel
        panel.clearEditor(); workspace?.revealPanel(page)
        let heading = NSTextField(wrappingLabelWithString: localization.text(title)); heading.font = .boldSystemFont(ofSize: 13)
        panel.editor.addArrangedSubview(heading)
        let note = NSTextField(wrappingLabelWithString: help); note.font = .systemFont(ofSize: 11); panel.editor.addArrangedSubview(note)
        for (key, value) in fields {
            panel.editor.addArrangedSubview(NSTextField(labelWithString: localization.text(key)))
            let input: NSView
            if key == "investigation.annotationKind" || key == "investigation.measureKind" || key == "investigation.unit" || key == "investigation.perPage" {
                let menu = NSPopUpButton()
                let values: [String] = key == "investigation.annotationKind" ? InvestigationAnnotation.allCases.map(\.rawValue) : key == "investigation.measureKind" ? EvidenceMeasurementKind.allCases.map(\.rawValue) : key == "investigation.unit" ? EvidenceUnit.allCases.map(\.rawValue) : ["1", "2", "4"]
                menu.addItems(withTitles: values.map { key == "investigation.annotationKind" ? localization.text("investigation.annotation." + $0) : key == "investigation.measureKind" ? localization.text("investigation.measure." + $0) : $0 })
                menu.target = self; menu.action = #selector(parameterOptionChanged)
                menu.selectItem(at: values.firstIndex(of: value) ?? 0); parameterOutputs.append { values[menu.indexOfSelectedItem] }; input = menu
            } else {
                let field = NSTextField(string: value); parameterFields[key] = field; parameterOutputs.append { field.stringValue }; input = field
            }
            input.setAccessibilityIdentifier(key); input.setAccessibilityLabel(localization.text(key))
            panel.editor.addArrangedSubview(input); input.widthAnchor.constraint(equalTo: panel.editor.widthAnchor).isActive = true
        }
        if fields.contains(where: { ["investigation.x", "investigation.regions", "investigation.referencePoints", "investigation.measurePoints"].contains($0.0) }) {
            let pick = NSButton(title: localization.text("workspace.pickCanvas"), target: self, action: #selector(pickCoordinates))
            pick.setAccessibilityIdentifier("workspace.pickCanvas"); panel.editor.addArrangedSubview(pick)
            let reset = NSButton(title: localization.text("action.reset"), target: self, action: #selector(resetCapture)); panel.editor.addArrangedSubview(reset)
            panel.editor.addArrangedSubview(NSTextField(wrappingLabelWithString: localization.text("workspace.captureHelp")))
        }
        let apply = NSButton(title: localization.text("action.apply"), target: self, action: #selector(applyParameters))
        apply.keyEquivalent = "\r"
        apply.setAccessibilityIdentifier("workspace.applyParameters")
        let cancel = NSButton(title: localization.text("action.cancel"), target: self, action: #selector(cancelParameters))
        cancel.keyEquivalent = "\u{1b}"
        cancel.setAccessibilityIdentifier("workspace.cancelParameters")
        panel.editor.addArrangedSubview(NSStackView(views: [cancel, apply])); panel.showEditor()
        return await withCheckedContinuation { continuation in pending = continuation; updateButtons() }
    }
    @objc func applyParameters() {
        guard let continuation = pending else { return }
        let values = parameterOutputs.map { $0() }; pending = nil; pendingPanel?.clearEditor(); pendingPanel = nil
        workspace?.dismissPresentation(); updateButtons(); continuation.resume(returning: values)
    }
    @objc func cancelParameters() {
        requestID = UUID(); guard let continuation = pending else { return }
        pending = nil; pendingPanel?.clearEditor(); pendingPanel = nil; workspace?.dismissPresentation(); updateButtons(); continuation.resume(returning: nil)
    }
    @objc private func parameterOptionChanged() {
        let usesSource = parameterTitle == "investigation.annotate" && parameterOutputs.first?() == "magnifier"
        if usesSource != annotationUsesSource {
            annotationUsesSource = usesSource; requestID = UUID(); workspace?.dismissPresentation()
            for key in ["x", "y", "width", "height"] { parameterFields["investigation." + key]?.stringValue = "" }
        }
    }
    @objc private func resetCapture() { capture?.resetSelection() }
    @objc private func pickCoordinates() {
        guard let store = analysisStore, let item = analysisItem, pending != nil else { return }
        let request = requestID, title = parameterTitle, magnifier = annotationUsesSource
        Task { do {
            let source = title == "investigation.ocr"
            let snapshot: ProjectSnapshot
            if magnifier, coordinator.active?.investigationSession == nil, let document = coordinator.active { snapshot = document.snapshot() }
            else { snapshot = try await (source ? store.intakeSnapshot(item.id, projects: coordinator.projectStore) : store.openSnapshot(item.id, projects: coordinator.projectStore)) }
            let image: CGImage, size: CanvasSize
            if magnifier {
                guard let layer = snapshot.model.layers.first(where: { if case .image = $0.content { return true }; return false }),
                      case .image(let sourceID) = layer.content, let asset = snapshot.assets[sourceID] else { throw InvestigationError.integrity }
                image = try await coordinator.pipeline.normalizedImage(asset); size = asset.descriptor.size
            } else {
                image = try await coordinator.pipeline.exportImage(snapshot: snapshot, options: ExportOptions(size: snapshot.model.canvas, ppi: snapshot.model.ppi), previewEdge: 2000); size = snapshot.model.canvas
            }
            guard requestID == request, pending != nil else { return }
            let mode: InvestigationCaptureView.Mode = title == "investigation.redact" ? .rectangles : ["investigation.calibrate", "investigation.measure"].contains(title) ? .points : .rectangle
            let view = InvestigationCaptureView(image: image, sourceSize: size, mode: mode, regions: title == "investigation.redact" ? item.redactions : [])
            view.selectionChanged = { [weak self] regions, points in
                guard let self, self.requestID == request else { return }
                if mode == .points {
                    self.parameterFields[title == "investigation.calibrate" ? "investigation.referencePoints" : "investigation.measurePoints"]?.stringValue = points.map { "\($0.x),\($0.y)" }.joined(separator: ";")
                } else if mode == .rectangles {
                    self.parameterFields["investigation.regions"]?.stringValue = regions.map { "\($0.x),\($0.y),\($0.width),\($0.height)" }.joined(separator: ";")
                } else if let region = regions.last {
                    for (key, value) in zip(["x", "y", "width", "height"], [region.x, region.y, region.width, region.height]) { self.parameterFields["investigation." + key]?.stringValue = String(value) }
                }
            }
            view.apply = { [weak self] in self?.applyParameters() }; view.cancel = { [weak self] in self?.cancelParameters() }
            view.setAccessibilityLabel(localization.text("workspace.regionPicker")); view.setAccessibilityHelp(localization.text("workspace.captureHelp"))
            capture = view; workspace?.showPresentation(view)
        } catch { failure(error) } }
    }
    @objc private func saveCurrentAnalysis() {
        guard !busy, canAnalyze, coordinator.active?.model.investigation == nil else { return }; busy = true
        Task { defer { busy = false }; do {
            _ = try await prepareActiveImage()
            guard let document = coordinator.active, let context = openImageContexts[document.model.id],
                  let values = await parameters("investigation.saveCurrentAnalysis", fields: [("investigation.code", ""),
                    ("investigation.caseTitle", document.model.name), ("investigation.examiner", "")],
                    help: localization.text("investigation.saveCurrentAnalysisHelp")) else { return }
            let panel = NSSavePanel(); panel.nameFieldStringValue = "Phan-tich-anh.paxcase"; panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url, context.matches(coordinator.active) else { return }
            let destination = url.pathExtension.lowercased() == "paxcase" ? url : url.appendingPathExtension("paxcase")
            try protectNewCaseDestination(destination)
            let saved = try await context.save(to: destination, code: values[0], title: values[1], examiner: values[2])
            openImageContexts[document.model.id] = saved; use(saved.store)
            alert(localization.text("investigation.currentAnalysisSaved"))
        } catch { failure(error) } }
    }
    func protectNewCaseDestination(_ destination: URL) throws {
        guard destination.pathExtension.lowercased() == "paxcase",
              !FileManager.default.fileExists(atPath: destination.path) else { throw InvestigationError.protectedDestination }
        // Export protection rejects a .paxcase target itself. For a NEW case,
        // protect its parent against nesting in any existing case package.
        try coordinator.protectInvestigationDestination?(destination.deletingLastPathComponent())
    }
    @objc private func createCase() { Task { await createCaseFlow() } }
    private func createCaseFlow() async {
        guard !busy, let values = await parameters("investigation.create", fields: [("investigation.code", ""), ("investigation.caseTitle", ""), ("investigation.examiner", "")]) else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Ho-so.paxcase"; panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { use(try InvestigationCaseStore(root: url.pathExtension.lowercased() == "paxcase" ? url : url.appendingPathExtension("paxcase"), creating: InvestigationCase(code: values[0], title: values[1], examiner: values[2]))) }
        catch { failure(error) }
    }
    @objc private func openCase() {
        guard !busy else { return }; let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try open(url: url) } catch { failure(error) }
    }
    func open(url: URL) throws {
        if let existing = stores.values.first(where: { $0.root == url.standardizedFileURL }) { use(existing); workspace?.revealPanel(1); return }
        let opened = try InvestigationCaseStore(root: url)
        guard stores[opened.value.id] == nil else { throw InvestigationError.locked }
        use(opened); workspace?.revealPanel(1)
    }
    private func intakeFields(_ intake: EvidenceIntake) -> [(String, String)] {
        [("investigation.source", intake.source), ("investigation.provider", intake.provider), ("investigation.receiver", intake.receiver),
         ("investigation.receivedAt", intake.receivedAt), ("investigation.handover", intake.handover)]
    }
    private func intake(_ values: [String]) -> EvidenceIntake { EvidenceIntake(source: values[0], provider: values[1], receiver: values[2], receivedAt: values[3], handover: values[4]) }
    @objc private func importPhotos() { Task { await importPhotosFlow() } }
    private func importPhotosFlow() async {
        guard let store, !busy else { return }
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.allowedContentTypes = [.jpeg, .png, .heic]
        guard panel.runModal() == .OK, !panel.urls.isEmpty, let values = await parameters("investigation.intake", fields: intakeFields(EvidenceIntake(receiver: store.value.examiner)), help: localization.text("investigation.intakeHelp")) else { return }
        let urls = panel.urls, received = intake(values); busy = true
        Task { defer { busy = false; refresh() }; var messages: [String] = []
            for url in urls {
                do {
                    do { _ = try await store.importFile(url, intake: received, pipeline: coordinator.pipeline, projects: coordinator.projectStore) }
                    catch let error as ImageImportError {
                        if case .resizeRequired = error {
                            let confirm = NSAlert(); confirm.messageText = localization.text("import.resizeTitle"); confirm.informativeText = localization.text("investigation.resizeHelp")
                            confirm.addButton(withTitle: localization.text("action.cancel")); confirm.addButton(withTitle: localization.text("import.resizeCopy"))
                            guard confirm.runModal() == .alertSecondButtonReturn else { continue }
                            _ = try await store.importFile(url, intake: received, pipeline: coordinator.pipeline, projects: coordinator.projectStore, allowResize: true)
                        } else { throw error }
                    }
                } catch { messages.append(url.lastPathComponent + ": " + localization.text((error as? InvestigationError)?.localizationKey ?? (error as? ImageImportError)?.key ?? "investigation.error.auditUnavailable")) }
            }
            if !messages.isEmpty { alert(messages.joined(separator: "\n")) }
        }
    }
    @objc private func editIntake() { Task { await editIntakeFlow() } }
    private func editIntakeFlow() async {
        guard let store, let item = selectedItem, !busy, let values = await parameters("investigation.editIntake", fields: intakeFields(item.intake) + [("investigation.caption", item.caption)]) else { return }
        do { try store.updateIntake(item.id, caption: values[5], intake: intake(Array(values.prefix(5)))) } catch { failure(error) }
    }
    func openItem(_ id: UUID) async throws -> PhotoDocument {
        guard let store, !coordinator.isClosing, !coordinator.isSaving, !coordinator.isImporting else { throw InvestigationError.missingCase }
        if let existing = coordinator.documents.first(where: { $0.model.id == id }), existing.investigationSession != nil { coordinator.select(id); return existing }
        let snapshot = try await store.openSnapshot(id, projects: coordinator.projectStore), item = try store.item(id)
        // An orphan/recovery tab may hold unsaved edits. Never discard it to attach a case.
        if coordinator.documents.contains(where: { $0.model.id == id }) { throw InvestigationError.locked }
        let document = PhotoDocument(loaded: snapshot, url: item.hasUnsavedChanges ? nil : store.projectURL(id), localization: localization)
        document.fileURL = store.projectURL(id); document.investigationSession = InvestigationSession(store: store, itemID: id)
        try coordinator.add(document); try store.mutate("workingOpened", itemID: id)
        return document
    }
    @objc private func openWorking() { guard let item = selectedItem, !busy else { return }; busy = true; Task { defer { busy = false }; do { _ = try await openItem(item.id); workingOpened?() } catch { failure(error) } } }
    @objc private func verifyCase() {
        guard let store, !busy else { return }; busy = true
        Task { defer { busy = false }; do { for item in store.value.items { _ = try await store.openSnapshot(item.id, projects: coordinator.projectStore) }
            for video in store.value.analysis?.videos ?? [] { try await store.verifyVideo(video) }; try store.mutate("integrityChecked"); alert(localization.text("investigation.verified")) } catch { failure(error) } }
    }
    private var selectionAnchor: String {
        (analysisStore?.value.id.uuidString ?? "") + (analysisItem?.id.uuidString ?? "") + (activeContext ?? "") + (analysisItem.map { InvestigationDigest.hash($0.currentModelJSON) } ?? "")
    }
    @objc private func compareImages() {
        guard !busy, canAnalyze else { return }; busy = true
        Task { defer { busy = false }; do {
            let (store, item) = try await prepareActiveImage(), anchor = selectionAnchor
            let snapshot = try await store.openSnapshot(item.id, projects: coordinator.projectStore)
            let image = try await coordinator.pipeline.exportImage(snapshot: snapshot, options: ExportOptions(size: snapshot.model.canvas, ppi: snapshot.model.ppi), previewEdge: 2000)
            let originalURL = store.originalURL(item)
            let original: CGImage
            if let document = coordinator.active, document.investigationSession == nil,
               let baseline = openImageContexts[document.model.id]?.baseline {
                original = try await coordinator.pipeline.exportImage(snapshot: baseline, options: ExportOptions(size: baseline.model.canvas, ppi: baseline.model.ppi), previewEdge: 2000)
            } else { original = try await Task.detached { () throws -> CGImage in
                guard let source = CGImageSourceCreateWithURL(originalURL as CFURL, nil), let image = CGImageSourceCreateThumbnailAtIndex(source, 0,
                    [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 2000,
                     kCGImageSourceDecodeRequest: kCGImageSourceDecodeToSDR] as CFDictionary) else { throw InvestigationError.integrity }; return image
            }.value }
            let controller = InvestigationComparisonPanel(original: original, processed: image, localization: localization,
                helpKey: coordinator.active?.investigationSession == nil ? "investigation.currentCompareHelp" : "investigation.compareHelp")
            guard anchor == selectionAnchor else { return }; workspace?.showPresentation(controller)
        } catch { failure(error) } }
    }
    @objc private func annotateImage() {
        guard !busy, canAnalyze, let document = coordinator.active else { return }; busy = true
        Task { defer { busy = false }; do {
            _ = try await prepareActiveImage()
            guard document.resolveSession(), let values = await parameters("investigation.annotate", fields: [("investigation.annotationKind", "arrow"), ("investigation.x", "10"), ("investigation.y", "10"),
                ("investigation.width", "80"), ("investigation.height", "60"), ("investigation.label", "1")], help: localization.text("investigation.annotationHelp")) else { return }
            guard let kind = InvestigationAnnotation(rawValue: values[0]), let x = Int(values[1]), let y = Int(values[2]), let w = Int(values[3]), let h = Int(values[4]) else { throw InvestigationError.invalidCase }
            let text = try ContentRasterizer.measured(TextContent(text: values[5], fontName: "Helvetica", fontSize: 28, color: RGBAColor(red: 1, green: 0.1, blue: 0.1)))
            let source = document.model.layers.first { if case .image = $0.content { return true }; return false }?.id
            try document.perform(.annotation) { model in _ = try model.addInvestigationAnnotation(kind, region: EvidenceRegion(x: x, y: y, width: w, height: h), text: text,
                name: localization.text("investigation.annotationName") + " " + values[5], sourceLayerID: source) }
            workspace?.revealPanel(0)
        } catch { failure(error) } }
    }
    @objc private func reviewRedactions() { Task { await reviewRedactionsFlow() } }
    private func reviewRedactionsFlow() async {
        guard !busy, canAnalyze else { return }
        busy = true; defer { busy = false }
        do {
        let (store, item) = try await prepareActiveImage()
        guard let values = await parameters("investigation.redact", fields: [("investigation.regions", item.redactions.map { "\($0.x),\($0.y),\($0.width),\($0.height)" }.joined(separator: ";"))], help: localization.text("investigation.redactHelp")) else { return }
            let regions = try values[0].split(separator: ";").map { part -> EvidenceRegion in
                let numbers = part.split(separator: ",", omittingEmptySubsequences: false).map { Int($0.trimmingCharacters(in: .whitespaces)) }
                guard numbers.count == 4, numbers.allSatisfy({ $0 != nil }) else { throw InvestigationError.invalidCase }
                return EvidenceRegion(x: numbers[0]!, y: numbers[1]!, width: numbers[2]!, height: numbers[3]!)
            }
            try store.setRedactions(item.id, regions: regions)
        } catch { failure(error) }
    }
    private func destination(_ name: String, type: UTType) -> URL? {
        let panel = NSSavePanel(); panel.allowedContentTypes = [type]; panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return nil }; return url
    }
    private func sharingImage(_ item: EvidenceItem, store: InvestigationCaseStore, edge: Int?) async throws -> CGImage {
        let snapshot = try await store.openSnapshot(item.id, projects: coordinator.projectStore)
        guard item.redactionModelSHA256 == InvestigationDigest.hash(item.currentModelJSON),
              try ProjectSchema(snapshot.model).encoded() == item.currentModelJSON else { throw InvestigationError.staleRedactions }
        let image = try await coordinator.pipeline.exportImage(snapshot: snapshot, options: ExportOptions(size: snapshot.model.canvas, ppi: snapshot.model.ppi), previewEdge: edge)
        return try InvestigationSharing.redacted(image, modelSize: snapshot.model.canvas, regions: item.redactions)
    }
    @objc private func exportPNG() {
        guard !busy, canAnalyze else { return }; busy = true
        Task { defer { busy = false }; do {
            let (store, item) = try await prepareActiveImage()
            guard let url = destination(item.code + "-chia-se.png", type: .png) else { return }
            try store.protectDestination(url); try coordinator.protectInvestigationDestination?(url)
            try store.mutate("sharingStarted", itemID: item.id, details: ["format": "PNG", "fileName": url.lastPathComponent])
            let image = try await sharingImage(item, store: store, edge: nil), ppi = try item.model.ppi
            let bytes = try await Task.detached { try InvestigationSharing.pngBytes(image, ppi: ppi) }.value
            try await InvestigationSharing.write(bytes, to: url)
            try store.mutate("sharingCompleted", itemID: item.id, details: ["format": "PNG", "sha256": InvestigationDigest.hash(bytes), "fileName": url.lastPathComponent,
                "modelSHA256": InvestigationDigest.hash(item.currentModelJSON), "redactionsSHA256": InvestigationDigest.hash(try InvestigationDigest.encode(item.redactions))])
            alert(localization.text("investigation.exported"))
        } catch { failure(error) } }
    }
    @objc private func exportPDF() { Task { await exportPDFFlow() } }
    private func exportPDFFlow() async {
        guard !busy, canAnalyze else { return }
        busy = true; defer { busy = false }
        do {
        let (store, _) = try await prepareActiveImage()
        guard let values = await parameters("investigation.exportPDF", fields: [("investigation.perPage", "2")], help: localization.text("investigation.pdfHelp")),
              let perPage = Int(values[0]), [1, 2, 4].contains(perPage), let url = destination("Ban-anh.pdf", type: .pdf) else { return }
            try store.protectDestination(url); try coordinator.protectInvestigationDestination?(url)
            let value = store.value
            try store.mutate("sharingStarted", details: ["format": "PDF", "perPage": String(perPage), "fileName": url.lastPathComponent])
            let pages = try InvestigationSharing.PDFPages(title: value.title, caseCode: value.code, examiner: value.examiner, perPage: perPage, count: value.items.count, language: localization.language)
            for start in stride(from: 0, to: value.items.count, by: perPage) {
                var plates: [InvestigationSharing.Plate] = []
                for item in value.items[start..<min(start + perPage, value.items.count)] {
                    let image = try await sharingImage(item, store: store, edge: 2000)
                    plates.append(.init(code: item.code, caption: item.caption, originalSHA256: item.originalSHA256, image: image))
                }
                try await pages.append(plates)
            }
            let bytes = try await pages.finish()
            try await InvestigationSharing.write(bytes, to: url)
            try store.mutate("sharingCompleted", details: ["format": "PDF", "sha256": InvestigationDigest.hash(bytes), "fileName": url.lastPathComponent, "perPage": String(perPage),
                                                         "inputLedgerSHA256": value.events.last?.sha256 ?? ""])
            alert(localization.text("investigation.exported"))
        } catch { failure(error) }
    }
    @objc private func exportCatalog() {
        guard !busy, canAnalyze else { return }; busy = true
        Task { defer { busy = false }; do {
            let (store, _) = try await prepareActiveImage()
            guard let url = destination("Danh-muc-nguon.json", type: .json) else { return }
            try store.protectDestination(url); try coordinator.protectInvestigationDestination?(url)
            struct Source: Encodable { let code, originalName, originalSHA256, caption: String; let originalByteCount: Int; let intake: EvidenceIntake }
            let sources = store.value.items.map { Source(code: $0.code, originalName: $0.originalName, originalSHA256: $0.originalSHA256, caption: $0.caption, originalByteCount: $0.originalByteCount, intake: $0.intake) }
            for item in store.value.items { try await store.verifyOriginal(item) }
            let bytes = try InvestigationDigest.encode(sources)
            try store.mutate("catalogExportStarted", details: ["fileName": url.lastPathComponent])
            try await InvestigationSharing.write(bytes, to: url)
            try store.mutate("catalogExportCompleted", details: ["fileName": url.lastPathComponent, "sha256": InvestigationDigest.hash(bytes)])
            alert(localization.text("investigation.exported"))
        } catch { failure(error) } }
    }
    @objc private func exportLog() {
        guard !busy, canAnalyze else { return }; busy = true
        Task { defer { busy = false }; do {
            let (store, _) = try await prepareActiveImage()
            guard let url = destination("Nhat-ky-xu-ly.json", type: .json) else { return }
            try store.protectDestination(url); try coordinator.protectInvestigationDestination?(url)
            try store.mutate("processingLogExportStarted", details: ["fileName": url.lastPathComponent])
            struct Log: Encodable { let formatIdentifier = "photoaxis.processing-log"; let formatVersion = 1; let caseID: UUID; let code, title: String; let events: [InvestigationEvent] }
            let bytes = try InvestigationDigest.encode(Log(caseID: store.value.id, code: store.value.code, title: store.value.title, events: store.value.events))
            try await InvestigationSharing.write(bytes, to: url)
            try store.mutate("processingLogExportCompleted", details: ["fileName": url.lastPathComponent, "sha256": InvestigationDigest.hash(bytes)])
            alert(localization.text("investigation.exported"))
        } catch { failure(error) } }
    }
}

extension InvestigationController {
    private func points(_ text: String) throws -> [Point2D] {
        let values = try text.split(separator: ";", omittingEmptySubsequences: false).map { part -> Point2D in
            let pair = part.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pair.count == 2, let x = Double(pair[0]), let y = Double(pair[1]), x.isFinite, y.isFinite else { throw InvestigationError.invalidCase }; return Point2D(x: x, y: y)
        }
        guard values.count <= 64 else { throw InvestigationError.limit }; return values
    }
    @objc private func recognizeText() {
        guard !busy, canAnalyze else { return }; busy = true
        Task { defer { busy = false }; do {
            let (store, item) = try await prepareActiveImage(), anchor = selectionAnchor
            let snapshot = try await store.intakeSnapshot(item.id, projects: coordinator.projectStore), source = snapshot.assets[item.workingSourceSHA256]!
            let size = source.descriptor.size
            guard let values = await parameters("investigation.ocr", fields: [("investigation.x", "0"), ("investigation.y", "0"), ("investigation.width", String(size.width)), ("investigation.height", String(size.height))], help: localization.text("investigation.ocrHelp")) else { return }
            let numbers = values.compactMap(Int.init); guard numbers.count == 4 else { throw InvestigationError.invalidCase }
            let region = EvidenceRegion(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
            let record = try await store.recognize(item.id, region: region, pipeline: coordinator.pipeline, projects: coordinator.projectStore)
            guard anchor == selectionAnchor else { return }
            try await showOCR(record, store: store)
        } catch { failure(error) } }
    }
    @objc private func reviewOCR() {
        guard let store = analysisStore, let item = analysisItem, !busy, let record = store.value.analysis?.ocr.last(where: { $0.itemID == item.id }) else { return }; busy = true
        Task { defer { busy = false }; do { try await showOCR(record, store: store) } catch { failure(error) } }
    }
    private func showOCR(_ record: EvidenceOCR, store: InvestigationCaseStore) async throws {
        let anchor = selectionAnchor
        let snapshot = try await store.intakeSnapshot(record.itemID, projects: coordinator.projectStore)
        guard let source = snapshot.assets[record.sourceSHA256] else { throw InvestigationError.integrity }
        let image = try await coordinator.pipeline.normalizedImage(source)
        let summary = "SHA-256: \(record.originalSHA256)\n\(record.language) / Vision revision \(record.revision)\nROI: \(record.region.x),\(record.region.y),\(record.region.width),\(record.region.height)\n" + record.lines.prefix(8).map { "\($0.region.x),\($0.region.y),\($0.region.width),\($0.region.height): \($0.confidence)" }.joined(separator: "\n")
        let review = InvestigationReviewPanel(localization: localization, title: localization.text("investigation.reviewOCR"), image: image, sourceSize: record.sourceSize, summary: summary,
                                                  regions: [record.region] + record.lines.map(\.region), recognized: record.recognizedText,
                                                  confirmedText: record.confirmations.last?.text ?? record.recognizedText, onConfirm: { text in try store.confirmOCR(record.id, text: text) })
        guard anchor == selectionAnchor else { return }; workspace?.showPresentation(review)
    }
    @objc private func importVideo() { Task { await importVideoFlow() } }
    private func importVideoFlow() async {
        guard let store, !busy else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let fields = await parameters("investigation.intake", fields: intakeFields(EvidenceIntake(receiver: store.value.examiner)), help: localization.text("investigation.videoHelp")) else { return }
        busy = true
        Task { defer { busy = false }; do {
            _ = try await store.importVideo(url, intake: intake(fields)); alert(localization.text("investigation.videoImported"))
        } catch { failure(error) } }
    }
    @objc private func extractFrame() { Task { await extractFrameFlow() } }
    private func extractFrameFlow() async {
        guard let store, !busy, let videos = store.value.analysis?.videos, !videos.isEmpty else { return }
        let help = localization.text("investigation.frameHelp") + "\n" + videos.enumerated().map { "\($0.offset + 1): \($0.element.originalName) (\($0.element.duration.seconds) s)" }.joined(separator: "\n")
        guard let fields = await parameters("investigation.extractFrame", fields: [("investigation.videoNumber", "1"), ("investigation.frameIndex", "0"), ("investigation.timeOffset", "0"), ("investigation.offsetReason", "")], help: help),
              let number = Int(fields[0]), number >= 1, number <= videos.count, let index = Int(fields[1]), let offset = Double(fields[2]) else { return }
        busy = true
        Task { defer { busy = false }; do {
            let item = try await store.extractFrame(videos[number - 1].id, index: index, offset: offset, reason: fields[3], pipeline: coordinator.pipeline, projects: coordinator.projectStore)
            refresh(); if let row = store.value.items.firstIndex(where: { $0.id == item.id }) { table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
            _ = try await openItem(item.id); workingOpened?()
        } catch { failure(error) } }
    }
    @objc private func calibrate() { Task { await calibrateFlow() } }
    private func calibrateFlow() async {
        guard !busy, canAnalyze else { return }
        busy = true; defer { busy = false }
        do {
        let (store, item) = try await prepareActiveImage()
        guard let fields = await parameters("investigation.calibrate", fields: [("investigation.referencePoints", ""), ("investigation.knownLength", ""), ("investigation.unit", "mm"), ("investigation.assumption", "")], help: localization.text("investigation.calibrationHelp")) else { return }
            guard let length = Double(fields[1]), let unit = EvidenceUnit(rawValue: fields[2]) else { throw InvestigationError.invalidCase }
            let calibration = try EvidenceCalibration(itemID: item.id, originalSHA256: item.originalSHA256, modelSHA256: InvestigationDigest.hash(item.currentModelJSON), canvas: item.model.canvas,
                                                      reference: points(fields[0]), knownLength: length, unit: unit, assumption: fields[3], operatorName: store.value.examiner)
            try store.addCalibration(calibration)
            try await showMeasurement(calibration, result: nil, store: store)
        } catch { failure(error) }
    }
    @objc private func measure() { Task { await measureFlow() } }
    private func measureFlow() async {
        guard let store = analysisStore, let item = analysisItem, !busy, let calibration = store.value.analysis?.calibrations.last(where: { $0.itemID == item.id && $0.modelSHA256 == InvestigationDigest.hash(item.currentModelJSON) }),
              let fields = await parameters("investigation.measure", fields: [("investigation.measureKind", "distance"), ("investigation.measurePoints", "")], help: localization.text("investigation.measureHelp")) else { return }
        do {
            guard let kind = EvidenceMeasurementKind(rawValue: fields[0]) else { throw InvestigationError.invalidCase }
            let result = try store.measure(calibrationID: calibration.id, kind: kind, points: points(fields[1])); busy = true
            Task { defer { busy = false }; do { try await showMeasurement(calibration, result: result, store: store) } catch { failure(error) } }
        } catch { failure(error) }
    }
    private func showMeasurement(_ calibration: EvidenceCalibration, result: EvidenceMeasurement?, store: InvestigationCaseStore) async throws {
        let anchor = selectionAnchor
        let snapshot = try await store.openSnapshot(calibration.itemID, projects: coordinator.projectStore)
        guard InvestigationDigest.hash(try ProjectSchema(snapshot.model).encoded()) == calibration.modelSHA256 else { throw InvestigationError.staleCalibration }
        let image = try await coordinator.pipeline.exportImage(snapshot: snapshot, options: ExportOptions(size: snapshot.model.canvas, ppi: snapshot.model.ppi), previewEdge: 2000)
        func coordinates(_ values: [Point2D]) -> String { values.map { String(format: "(%.6g, %.6g)", $0.x, $0.y) }.joined(separator: "; ") }
        var summary = localization.text("investigation.calibrationSummary") + "\n\(calibration.knownLength) \(calibration.unit.rawValue) / \(coordinates(calibration.reference))\n\(calibration.unitsPerPixel) \(calibration.unit.rawValue)/px\n\(calibration.assumption)\nSHA-256(model): \(calibration.modelSHA256)"
        if let result { summary += "\n\n" + localization.text("investigation.measure." + result.kind.rawValue) + ": " + String(format: "%.6g", result.result) + " " + calibration.unit.rawValue + (result.kind == .area ? "²" : "") + "\n\(coordinates(result.points))" }
        let preview = InvestigationReviewPanel(localization: localization, title: localization.text("investigation.measure"), image: image, sourceSize: calibration.canvas, summary: summary,
                                                   reference: calibration.reference, points: result?.points ?? [], closed: result?.kind == .area)
        guard anchor == selectionAnchor else { return }; workspace?.showPresentation(preview)
    }
    @objc private func exportAnalysis() {
        guard !busy, canAnalyze else { return }; busy = true
        Task { defer { busy = false }; do {
            let (store, _) = try await prepareActiveImage()
            guard let url = destination("Phan-tich-truy-vet.json", type: .json) else { return }
            try store.protectDestination(url); try coordinator.protectInvestigationDestination?(url)
            for item in store.value.items { try await store.verifyOriginal(item) }
            for video in store.value.analysis?.videos ?? [] { try await store.verifyVideo(video) }
            try store.mutate("analysisExportStarted", details: ["fileName": url.lastPathComponent]); let bytes = try store.analysisBytes()
            try await InvestigationSharing.write(bytes, to: url)
            try store.mutate("analysisExportCompleted", details: ["fileName": url.lastPathComponent, "sha256": InvestigationDigest.hash(bytes)])
            alert(localization.text("investigation.exported"))
        } catch { failure(error) } }
    }
}

import AppKit
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore

@MainActor
final class InvestigationController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    let localization: L10n
    let coordinator: DocumentCoordinator
    var workingOpened: (() -> Void)?
    private(set) var store: InvestigationCaseStore?
    private var stores: [UUID: InvestigationCaseStore] = [:]
    private var reviewWindows: [InvestigationReviewController] = []
    private var ocrSupported = false
    private let activity = NSTextField(labelWithString: "")
    private let progress = NSProgressIndicator()
    private var comparisonWindows: [InvestigationComparisonController] = []
    private let table = NSTableView()
    private let detail = NSTextView()
    private let heading = NSTextField(labelWithString: "")
    private var buttons: [NSButton] = []
    private var busy = false { didSet {
        updateButtons(); table.isEnabled = !busy; activity.isHidden = !busy; progress.isHidden = !busy
        if busy { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
    } }
    var selectedItem: EvidenceItem? { guard let store, store.value.items.indices.contains(table.selectedRow) else { return nil }; return store.value.items[table.selectedRow] }
    init(coordinator: DocumentCoordinator, localization: L10n) {
        self.coordinator = coordinator; self.localization = localization
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1120, height: 860), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(window: window); window.title = localization.text("investigation.title"); window.minSize = CGSize(width: 1040, height: 780); window.center()
        window.setAccessibilityIdentifier("investigation.window")
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
        let analysisRow = NSStackView(views: [ocr, review, video, frame]); analysisRow.spacing = 8
        let measureRow = NSStackView(views: [calibrate, measure, analysis]); measureRow.spacing = 8
        let top = NSStackView(views: [create, open, caseInfo, intake]); top.spacing = 8
        let actions = NSStackView(views: [edit, editImage, verify]); actions.spacing = 8
        let bottom = NSStackView(views: [compare, annotate, mask, png, pdf]); bottom.spacing = 8
        let records = NSStackView(views: [catalog, log]); records.spacing = 8
        let column = NSTableColumn(identifier: .init("photos")); column.title = localization.text("investigation.photos"); column.width = 280
        table.addTableColumn(column); table.dataSource = self; table.delegate = self; table.allowsMultipleSelection = false
        table.setAccessibilityIdentifier("investigation.photos")
        let list = NSScrollView(); list.documentView = table; list.hasVerticalScroller = true; list.borderType = .bezelBorder
        detail.isEditable = false; detail.isSelectable = true; detail.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        detail.setAccessibilityIdentifier("investigation.details")
        let info = NSScrollView(); info.documentView = detail; info.hasVerticalScroller = true; info.borderType = .bezelBorder
        let body = NSStackView(views: [list, info]); body.spacing = 12; body.distribution = .fill
        let notice = NSTextField(wrappingLabelWithString: localization.text("investigation.notice")); notice.textColor = .secondaryLabelColor
        heading.font = .boldSystemFont(ofSize: 16)
        progress.style = .spinning; progress.isIndeterminate = true; progress.isHidden = true; progress.controlSize = .small
        activity.stringValue = localization.text("investigation.processing"); activity.isHidden = true; activity.textColor = .secondaryLabelColor
        activity.setAccessibilityIdentifier("investigation.processing")
        let header = NSStackView(views: [heading, progress, activity]); header.spacing = 10
        let stack = NSStackView(views: [header, top, actions, body, bottom, records, analysisRow, measureRow, notice]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false; window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20), stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -20),
            body.widthAnchor.constraint(equalTo: stack.widthAnchor), body.heightAnchor.constraint(greaterThanOrEqualToConstant: 280), list.widthAnchor.constraint(equalToConstant: 300)])
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
    required init?(coder: NSCoder) { fatalError("Use init(coordinator:localization:)") }
    private func button(_ key: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: localization.text(key), target: self, action: action)
        button.setAccessibilityIdentifier(key); button.setAccessibilityLabel(localization.text(key)); buttons.append(button); return button
    }
    func session(_ reference: InvestigationReference) -> InvestigationSession? {
        guard let store = stores[reference.caseID], store.value.items.contains(where: { $0.id == reference.itemID }) else { return nil }
        return InvestigationSession(store: store, itemID: reference.itemID)
    }
    func use(_ store: InvestigationCaseStore) {
        self.store = store; stores[store.value.id] = store
        store.changed = { [weak self] in self?.refresh() }; refresh()
    }
    private func refresh() {
        heading.stringValue = store.map { $0.value.code + " — " + $0.value.title } ?? localization.text("investigation.noCase")
        let selected = table.selectedRow; table.reloadData()
        if let store, !store.value.items.isEmpty { table.selectRowIndexes(IndexSet(integer: min(max(0, selected), store.value.items.count - 1)), byExtendingSelection: false) }
        displayDetails()
        updateButtons()
    }
    private func updateButtons() {
        for (index, button) in buttons.enumerated() {
            let needsItem = [3, 4, 6, 7, 8, 9].contains(index)
            button.isEnabled = !busy && (index < 2 || store != nil) && (!needsItem || selectedItem != nil)
            if [10, 11].contains(index), store?.value.items.isEmpty != false { button.isEnabled = false }
            if index == 14 { button.isEnabled = button.isEnabled && selectedItem != nil && ocrSupported; button.toolTip = ocrSupported ? nil : localization.text("investigation.error.ocrUnavailable") }
            if index == 15 { button.isEnabled = button.isEnabled && store?.value.analysis?.ocr.contains(where: { $0.itemID == selectedItem?.id }) == true }
            if index == 17 { button.isEnabled = button.isEnabled && store?.value.analysis?.videos.isEmpty == false }
            if index == 18 { button.isEnabled = button.isEnabled && selectedItem != nil }
            if index == 19 { button.isEnabled = button.isEnabled && store?.value.analysis?.calibrations.contains(where: { $0.itemID == selectedItem?.id && $0.modelSHA256 == selectedItem.map { InvestigationDigest.hash($0.currentModelJSON) } }) == true }
        }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { store?.value.items.count ?? 0 }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let store, store.value.items.indices.contains(row) else { return nil }
        let item = store.value.items[row]; return item.code + "  " + item.originalName
    }
    func tableViewSelectionDidChange(_ notification: Notification) { displayDetails(); updateButtons() }
    private func displayDetails() {
        guard let store else { detail.string = localization.text("investigation.noCase"); return }
        var text = localization.text("investigation.caseSummary") + "\n" + store.value.title + "\n" + store.value.examiner + "\n"
        if let item = selectedItem {
            text += "\n\(item.code) — \(item.originalName)\n\(item.caption)\n"
            text += "\nSHA-256 (original): \(item.originalSHA256)\nSHA-256 (working source): \(item.workingSourceSHA256)\nBytes: \(item.originalByteCount)\n"
            text += "\n" + localization.text("investigation.intake") + "\n" + String(decoding: (try? InvestigationDigest.encode(item.intake)) ?? Data(), as: UTF8.self)
            text += "\n\n" + localization.text("investigation.metadata") + "\n" + item.originalMetadataJSON
            text += "\n\n" + localization.text("investigation.regions") + "\n" + String(decoding: (try? InvestigationDigest.encode(item.redactions)) ?? Data(), as: UTF8.self)
        }
        if let analysis = store.value.analysis {
            text += "\n\n" + localization.text("investigation.analysis") + "\n" + String(decoding: (try? InvestigationDigest.encode(analysis)) ?? Data(), as: UTF8.self)
        }
        text += "\n\n" + localization.text("investigation.log") + "\n"
        for event in store.value.events.suffix(100) {
            let p = event.payload
            if selectedItem == nil || p.itemID == nil || p.itemID == selectedItem?.id {
                text += "#\(p.sequence) \(p.recordedAt) | \(p.operation) | \(p.operatorName) | \(p.appVersion)\n"
                text += p.details.filter { $0.key != "caseStateSHA256" }.sorted { $0.key < $1.key }.map { $0.key + ": " + $0.value }.joined(separator: "\n") + "\n"
                if let state = p.modelAfterJSON { text += String(decoding: state, as: UTF8.self) + "\n" }
            }
        }
        detail.string = text
    }
    private func alert(_ message: String) { let alert = NSAlert(); alert.messageText = localization.text("investigation.title"); alert.informativeText = message; alert.addButton(withTitle: localization.text("action.close")); alert.runModal() }
    private func failure(_ error: Error) { alert(localization.text((error as? InvestigationError)?.localizationKey ?? (error as? ImageImportError)?.key ?? "investigation.error.auditUnavailable")) }
    @objc private func editCase() {
        guard let store, !busy, let values = form("investigation.editCase", fields: [("investigation.code", store.value.code), ("investigation.caseTitle", store.value.title), ("investigation.examiner", store.value.examiner)]) else { return }
        do {
            try store.mutate("caseInformationAmended", details: ["previousCode": store.value.code, "previousTitle": store.value.title, "previousOperator": store.value.examiner,
                                                               "code": values[0], "title": values[1], "operator": values[2]]) { value in
                value.code = values[0]; value.title = values[1]; value.examiner = values[2]
            }
        } catch { failure(error) }
    }
    private func form(_ title: String, fields: [(String, String)], help: String = "") -> [String]? {
        let alert = NSAlert(); alert.messageText = localization.text(title); alert.informativeText = help
        alert.addButton(withTitle: localization.text("action.cancel")); alert.addButton(withTitle: localization.text("action.apply"))
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 7
        var outputs: [() -> String] = []
        for (key, value) in fields {
            let label = NSTextField(labelWithString: localization.text(key)), input: NSView
            if key == "investigation.annotationKind" {
                let menu = NSPopUpButton(); let kinds = InvestigationAnnotation.allCases
                menu.addItems(withTitles: kinds.map { localization.text("investigation.annotation." + $0.rawValue) })
                menu.selectItem(at: kinds.firstIndex { $0.rawValue == value } ?? 0)
                input = menu; outputs.append { kinds[menu.indexOfSelectedItem].rawValue }
            } else if key == "investigation.unit" {
                let menu = NSPopUpButton(); menu.addItems(withTitles: EvidenceUnit.allCases.map(\.rawValue)); menu.selectItem(withTitle: value); input = menu; outputs.append { menu.titleOfSelectedItem ?? "mm" }
            } else if key == "investigation.measureKind" {
                let kinds = EvidenceMeasurementKind.allCases, menu = NSPopUpButton(); menu.addItems(withTitles: kinds.map { localization.text("investigation.measure." + $0.rawValue) }); input = menu
                menu.selectItem(at: kinds.firstIndex { $0.rawValue == value } ?? 0); outputs.append { kinds[menu.indexOfSelectedItem].rawValue }
            } else if key == "investigation.perPage" {
                let menu = NSPopUpButton(); menu.addItems(withTitles: ["1", "2", "4"]); input = menu
                menu.selectItem(withTitle: value); outputs.append { menu.titleOfSelectedItem ?? "2" }
            } else {
                let field = NSTextField(string: value); input = field; outputs.append { field.stringValue }
            }
            input.setAccessibilityIdentifier(key); input.setAccessibilityLabel(localization.text(key)); input.widthAnchor.constraint(equalToConstant: 440).isActive = true
            let row = NSStackView(views: [label, input]); row.orientation = .vertical; row.alignment = .leading; row.spacing = 3
            stack.addArrangedSubview(row)
        }
        stack.frame = CGRect(x: 0, y: 0, width: 440, height: fields.count * 52)
        alert.accessoryView = stack
        guard alert.runModal() == .alertSecondButtonReturn else { return nil }; return outputs.map { $0() }
    }
    @objc private func createCase() {
        guard !busy, let values = form("investigation.create", fields: [("investigation.code", ""), ("investigation.caseTitle", ""), ("investigation.examiner", "")]) else { return }
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
        if let existing = stores.values.first(where: { $0.root == url.standardizedFileURL }) { use(existing); showWindow(nil); window?.makeKeyAndOrderFront(nil); return }
        let opened = try InvestigationCaseStore(root: url)
        guard stores[opened.value.id] == nil else { throw InvestigationError.locked }
        use(opened); showWindow(nil); window?.makeKeyAndOrderFront(nil)
    }
    private func intakeFields(_ intake: EvidenceIntake) -> [(String, String)] {
        [("investigation.source", intake.source), ("investigation.provider", intake.provider), ("investigation.receiver", intake.receiver),
         ("investigation.receivedAt", intake.receivedAt), ("investigation.handover", intake.handover)]
    }
    private func intake(_ values: [String]) -> EvidenceIntake { EvidenceIntake(source: values[0], provider: values[1], receiver: values[2], receivedAt: values[3], handover: values[4]) }
    @objc private func importPhotos() {
        guard let store, !busy else { return }
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.allowedContentTypes = [.jpeg, .png, .heic]
        guard panel.runModal() == .OK, !panel.urls.isEmpty, let values = form("investigation.intake", fields: intakeFields(EvidenceIntake(receiver: store.value.examiner)), help: localization.text("investigation.intakeHelp")) else { return }
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
    @objc private func editIntake() {
        guard let store, let item = selectedItem, !busy, let values = form("investigation.editIntake", fields: intakeFields(item.intake) + [("investigation.caption", item.caption)]) else { return }
        do { try store.updateIntake(item.id, caption: values[5], intake: intake(Array(values.prefix(5)))) } catch { failure(error) }
    }
    func openItem(_ id: UUID) async throws -> PhotoDocument {
        guard let store, !coordinator.isClosing, !coordinator.isSaving, !coordinator.isImporting else { throw InvestigationError.missingCase }
        if let existing = coordinator.documents.first(where: { $0.model.id == id }), existing.investigationSession != nil { coordinator.select(id); return existing }
        let snapshot = try await store.openSnapshot(id, projects: coordinator.projectStore), item = try store.item(id)
        if let existing = coordinator.documents.first(where: { $0.model.id == id }) { coordinator.remove(existing.model.id) }
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
    @objc private func compareImages() {
        guard let store, let item = selectedItem, !busy else { return }; busy = true
        Task { defer { busy = false }; do {
            let snapshot = try await store.openSnapshot(item.id, projects: coordinator.projectStore)
            let image = try await coordinator.pipeline.exportImage(snapshot: snapshot, options: ExportOptions(size: snapshot.model.canvas, ppi: snapshot.model.ppi), previewEdge: 2000)
            let originalURL = store.originalURL(item)
            let original = try await Task.detached { () throws -> CGImage in
                guard let source = CGImageSourceCreateWithURL(originalURL as CFURL, nil), let image = CGImageSourceCreateThumbnailAtIndex(source, 0,
                    [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 2000,
                     kCGImageSourceDecodeRequest: kCGImageSourceDecodeToSDR] as CFDictionary) else { throw InvestigationError.integrity }; return image
            }.value
            let controller = InvestigationComparisonController(original: original, processed: image, localization: localization)
            comparisonWindows.append(controller); controller.showWindow(nil)
        } catch { failure(error) } }
    }
    @objc private func annotateImage() {
        guard let item = selectedItem, !busy else { return }; busy = true
        Task { defer { busy = false }; do {
            let document = try await openItem(item.id)
            guard document.resolveSession(), let values = form("investigation.annotate", fields: [("investigation.annotationKind", "arrow"), ("investigation.x", "10"), ("investigation.y", "10"),
                ("investigation.width", "80"), ("investigation.height", "60"), ("investigation.label", "1")], help: localization.text("investigation.annotationHelp")) else { return }
            guard let kind = InvestigationAnnotation(rawValue: values[0]), let x = Int(values[1]), let y = Int(values[2]), let w = Int(values[3]), let h = Int(values[4]) else { throw InvestigationError.invalidCase }
            let text = try ContentRasterizer.measured(TextContent(text: values[5], fontName: "Helvetica", fontSize: 28, color: RGBAColor(red: 1, green: 0.1, blue: 0.1)))
            let source = document.model.layers.first { if case .image = $0.content { return true }; return false }?.id
            try document.perform(.annotation) { model in _ = try model.addInvestigationAnnotation(kind, region: EvidenceRegion(x: x, y: y, width: w, height: h), text: text,
                name: localization.text("investigation.annotationName") + " " + values[5], sourceLayerID: source) }
        } catch { failure(error) } }
    }
    @objc private func reviewRedactions() {
        guard let store, let item = selectedItem, !busy,
              let values = form("investigation.redact", fields: [("investigation.regions", item.redactions.map { "\($0.x),\($0.y),\($0.width),\($0.height)" }.joined(separator: ";"))], help: localization.text("investigation.redactHelp")) else { return }
        do {
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
        guard let store, let item = selectedItem, !busy, let url = destination(item.code + "-chia-se.png", type: .png) else { return }; busy = true
        Task { defer { busy = false }; do {
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
    @objc private func exportPDF() {
        guard let store, !busy, !store.value.items.isEmpty, let values = form("investigation.exportPDF", fields: [("investigation.perPage", "2")], help: localization.text("investigation.pdfHelp")),
              let perPage = Int(values[0]), [1, 2, 4].contains(perPage), let url = destination("Ban-anh.pdf", type: .pdf) else { return }
        busy = true
        Task { defer { busy = false }; do {
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
        } catch { failure(error) } }
    }
    @objc private func exportCatalog() {
        guard let store, !busy, let url = destination("Danh-muc-nguon.json", type: .json) else { return }
        busy = true
        Task { defer { busy = false }; do {
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
        guard let store, !busy, let url = destination("Nhat-ky-xu-ly.json", type: .json) else { return }
        busy = true
        Task { defer { busy = false }; do {
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
        guard let store, let item = selectedItem, !busy else { return }; busy = true
        Task { defer { busy = false }; do {
            let snapshot = try await store.intakeSnapshot(item.id, projects: coordinator.projectStore), source = snapshot.assets[item.workingSourceSHA256]!
            let size = source.descriptor.size
            guard let values = form("investigation.ocr", fields: [("investigation.x", "0"), ("investigation.y", "0"), ("investigation.width", String(size.width)), ("investigation.height", String(size.height))], help: localization.text("investigation.ocrHelp")) else { return }
            let numbers = values.compactMap(Int.init); guard numbers.count == 4 else { throw InvestigationError.invalidCase }
            let region = EvidenceRegion(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
            let record = try await store.recognize(item.id, region: region, pipeline: coordinator.pipeline, projects: coordinator.projectStore)
            try await showOCR(record, store: store)
        } catch { failure(error) } }
    }
    @objc private func reviewOCR() {
        guard let store, let item = selectedItem, !busy, let record = store.value.analysis?.ocr.last(where: { $0.itemID == item.id }) else { return }; busy = true
        Task { defer { busy = false }; do { try await showOCR(record, store: store) } catch { failure(error) } }
    }
    private func showOCR(_ record: EvidenceOCR, store: InvestigationCaseStore) async throws {
        let snapshot = try await store.intakeSnapshot(record.itemID, projects: coordinator.projectStore)
        guard let source = snapshot.assets[record.sourceSHA256] else { throw InvestigationError.integrity }
        let image = try await coordinator.pipeline.normalizedImage(source)
        let summary = "SHA-256: \(record.originalSHA256)\n\(record.language) / Vision revision \(record.revision)\nROI: \(record.region.x),\(record.region.y),\(record.region.width),\(record.region.height)\n" + record.lines.prefix(8).map { "\($0.region.x),\($0.region.y),\($0.region.width),\($0.region.height): \($0.confidence)" }.joined(separator: "\n")
        let review = InvestigationReviewController(localization: localization, title: localization.text("investigation.reviewOCR"), image: image, sourceSize: record.sourceSize, summary: summary,
                                                  regions: [record.region] + record.lines.map(\.region), recognized: record.recognizedText,
                                                  confirmedText: record.confirmations.last?.text ?? record.recognizedText, onConfirm: { text in try store.confirmOCR(record.id, text: text) })
        reviewWindows.append(review); review.showWindow(nil); review.window?.makeKeyAndOrderFront(nil)
    }
    @objc private func importVideo() {
        guard let store, !busy else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let fields = form("investigation.intake", fields: intakeFields(EvidenceIntake(receiver: store.value.examiner)), help: localization.text("investigation.videoHelp")) else { return }
        busy = true
        Task { defer { busy = false }; do {
            _ = try await store.importVideo(url, intake: intake(fields)); alert(localization.text("investigation.videoImported"))
        } catch { failure(error) } }
    }
    @objc private func extractFrame() {
        guard let store, !busy, let videos = store.value.analysis?.videos, !videos.isEmpty else { return }
        let help = localization.text("investigation.frameHelp") + "\n" + videos.enumerated().map { "\($0.offset + 1): \($0.element.originalName) (\($0.element.duration.seconds) s)" }.joined(separator: "\n")
        guard let fields = form("investigation.extractFrame", fields: [("investigation.videoNumber", "1"), ("investigation.frameIndex", "0"), ("investigation.timeOffset", "0"), ("investigation.offsetReason", "")], help: help),
              let number = Int(fields[0]), number >= 1, number <= videos.count, let index = Int(fields[1]), let offset = Double(fields[2]) else { return }
        busy = true
        Task { defer { busy = false }; do {
            let item = try await store.extractFrame(videos[number - 1].id, index: index, offset: offset, reason: fields[3], pipeline: coordinator.pipeline, projects: coordinator.projectStore)
            refresh(); if let row = store.value.items.firstIndex(where: { $0.id == item.id }) { table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
            _ = try await openItem(item.id); workingOpened?()
        } catch { failure(error) } }
    }
    @objc private func calibrate() {
        guard let store, let item = selectedItem, !busy,
              let fields = form("investigation.calibrate", fields: [("investigation.referencePoints", ""), ("investigation.knownLength", ""), ("investigation.unit", "mm"), ("investigation.assumption", "")], help: localization.text("investigation.calibrationHelp")) else { return }
        do {
            guard let length = Double(fields[1]), let unit = EvidenceUnit(rawValue: fields[2]) else { throw InvestigationError.invalidCase }
            let calibration = try EvidenceCalibration(itemID: item.id, originalSHA256: item.originalSHA256, modelSHA256: InvestigationDigest.hash(item.currentModelJSON), canvas: item.model.canvas,
                                                      reference: points(fields[0]), knownLength: length, unit: unit, assumption: fields[3], operatorName: store.value.examiner)
            try store.addCalibration(calibration); busy = true
            Task { defer { busy = false }; do { try await showMeasurement(calibration, result: nil, store: store) } catch { failure(error) } }
        } catch { failure(error) }
    }
    @objc private func measure() {
        guard let store, let item = selectedItem, !busy, let calibration = store.value.analysis?.calibrations.last(where: { $0.itemID == item.id && $0.modelSHA256 == InvestigationDigest.hash(item.currentModelJSON) }),
              let fields = form("investigation.measure", fields: [("investigation.measureKind", "distance"), ("investigation.measurePoints", "")], help: localization.text("investigation.measureHelp")) else { return }
        do {
            guard let kind = EvidenceMeasurementKind(rawValue: fields[0]) else { throw InvestigationError.invalidCase }
            let result = try store.measure(calibrationID: calibration.id, kind: kind, points: points(fields[1])); busy = true
            Task { defer { busy = false }; do { try await showMeasurement(calibration, result: result, store: store) } catch { failure(error) } }
        } catch { failure(error) }
    }
    private func showMeasurement(_ calibration: EvidenceCalibration, result: EvidenceMeasurement?, store: InvestigationCaseStore) async throws {
        let snapshot = try await store.openSnapshot(calibration.itemID, projects: coordinator.projectStore)
        guard InvestigationDigest.hash(try ProjectSchema(snapshot.model).encoded()) == calibration.modelSHA256 else { throw InvestigationError.staleCalibration }
        let image = try await coordinator.pipeline.exportImage(snapshot: snapshot, options: ExportOptions(size: snapshot.model.canvas, ppi: snapshot.model.ppi), previewEdge: 2000)
        func coordinates(_ values: [Point2D]) -> String { values.map { String(format: "(%.6g, %.6g)", $0.x, $0.y) }.joined(separator: "; ") }
        var summary = localization.text("investigation.calibrationSummary") + "\n\(calibration.knownLength) \(calibration.unit.rawValue) / \(coordinates(calibration.reference))\n\(calibration.unitsPerPixel) \(calibration.unit.rawValue)/px\n\(calibration.assumption)\nSHA-256(model): \(calibration.modelSHA256)"
        if let result { summary += "\n\n" + localization.text("investigation.measure." + result.kind.rawValue) + ": " + String(format: "%.6g", result.result) + " " + calibration.unit.rawValue + (result.kind == .area ? "²" : "") + "\n\(coordinates(result.points))" }
        let preview = InvestigationReviewController(localization: localization, title: localization.text("investigation.measure"), image: image, sourceSize: calibration.canvas, summary: summary,
                                                   reference: calibration.reference, points: result?.points ?? [], closed: result?.kind == .area)
        reviewWindows.append(preview); preview.showWindow(nil); preview.window?.makeKeyAndOrderFront(nil)
    }
    @objc private func exportAnalysis() {
        guard let store, !busy else { return }
        let warning = NSAlert(); warning.messageText = localization.text("investigation.exportAnalysis"); warning.informativeText = localization.text("investigation.analysisExportHelp")
        warning.addButton(withTitle: localization.text("action.cancel")); warning.addButton(withTitle: localization.text("action.apply"))
        guard warning.runModal() == .alertSecondButtonReturn, let url = destination("Phan-tich-truy-vet.json", type: .json) else { return }
        busy = true
        Task { defer { busy = false }; do {
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

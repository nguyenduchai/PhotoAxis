import AppKit
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore

/// Only OCR and photo sheets replace the former investigation pages. Privacy is
/// an ordinary image edit, committed through the existing document/Undo pipeline.
@MainActor
final class DocumentUtilitiesController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSTextViewDelegate {
    let coordinator: DocumentCoordinator
    let localization: L10n
    let ocrPanel = UtilityPanel(identifier: "utility.ocr"), sheetPanel = UtilityPanel(identifier: "utility.sheet"), privacyPanel = UtilityPanel(identifier: "utility.privacy")
    let ocrText = NSTextView(), photos = NSTableView()
    let sheetTitle = NSTextField(string: ""), sheetNote = NSTextField(string: ""), caption = NSTextField(string: "")
    let perPage = NSPopUpButton(), orientation = NSPopUpButton(), pageChoice = NSPopUpButton()
    let fileNames = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let privacyMode = NSPopUpButton(), strength = NSSlider(value: 50, minValue: 1, maxValue: 100, target: nil, action: nil)
    let regionInfo = NSTextField(wrappingLabelWithString: "")
    private(set) var entries: [PhotoSheetEntry] = []
    private(set) var privacyRegions: [EvidenceRegion] = []
    private(set) var ocrRegion: EvidenceRegion?
    private var controls: [String: NSButton] = [:]
    private weak var workspace: WorkspaceView?
    private let privacyEngine = PrivacyEngine()
    private var ocrTask: Task<Void, Never>?, captureTask: Task<Void, Never>?, privacyTask: Task<Void, Never>?, sheetTask: Task<Void, Never>?, sheetPreviewTask: Task<Void, Never>?
    private var previewGeneration = UUID(), captureGeneration = UUID(), sheetGeneration = UUID(), ocrGeneration = UUID(), privacyGeneration = UUID()
    private var capture: UtilityCanvasView?, previewOriginal: CGImage?
    private var activeContext: String?
    private var ocrBusy = false, privacyBusy = false, sheetBusy = false, transitioning = false
    private var renderedPrivacy = false
    private var sheetPage = 0
    private var updatingFields = false
    var recognition: @Sendable (CGImage, EvidenceRegion, OCRCancellation) throws -> InvestigationAnalysisEngine.RecognizedText = {
        try InvestigationAnalysisEngine.recognizeText(image: $0, region: $1, cancellation: $2)
    }
    init(coordinator: DocumentCoordinator, localization: L10n) {
        self.coordinator = coordinator; self.localization = localization
        super.init()
        buildOCR(); buildSheet(); buildPrivacy(); synchronizeActiveDocument()
    }
    deinit { ocrTask?.cancel(); captureTask?.cancel(); privacyTask?.cancel(); sheetTask?.cancel(); sheetPreviewTask?.cancel() }
    private func button(_ key: String, _ action: Selector) -> NSButton {
        let value = NSButton(title: localization.text(key), target: self, action: action)
        value.bezelStyle = .rounded; value.font = .systemFont(ofSize: 11)
        value.setAccessibilityIdentifier(key); value.setAccessibilityLabel(localization.text(key)); controls[key] = value
        return value
    }
    private func row(_ views: [NSView]) -> NSStackView {
        let value = NSStackView(views: views); value.orientation = .horizontal; value.spacing = 6; value.distribution = .fillEqually
        return value
    }
    private func field(_ panel: UtilityPanel, _ key: String, _ value: NSTextField) {
        panel.note(localization.text(key)); value.font = .systemFont(ofSize: 12); value.delegate = self
        value.setAccessibilityIdentifier(key); value.setAccessibilityLabel(localization.text(key)); panel.append(value)
    }
    private func option(_ panel: UtilityPanel, _ key: String, _ popup: NSPopUpButton, values: [String], action: Selector) {
        panel.note(localization.text(key)); popup.addItems(withTitles: values); popup.target = self; popup.action = action
        popup.setAccessibilityIdentifier(key); popup.setAccessibilityLabel(localization.text(key)); panel.append(popup)
    }
    private func buildOCR() {
        ocrPanel.note(localization.text("utility.ocrTitle"), heading: true); ocrPanel.note(localization.text("ocr.help"))
        ocrPanel.append(button("ocr.selectRegion", #selector(selectOCRRegion)))
        ocrPanel.append(button("ocr.wholeImage", #selector(wholeOCRImage)))
        regionInfo.font = .systemFont(ofSize: 11); regionInfo.setAccessibilityIdentifier("ocr.regionInfo"); ocrPanel.append(regionInfo)
        ocrPanel.append(button("ocr.run", #selector(runOCR))); ocrPanel.append(button("ocr.cancel", #selector(cancelOCR)))
        ocrPanel.note(localization.text("ocr.result"))
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        ocrText.delegate = self; ocrText.font = .systemFont(ofSize: 14); ocrText.isRichText = false; ocrText.isEditable = true
        ocrText.autoresizingMask = [.width]; ocrText.textContainer?.widthTracksTextView = true
        ocrText.setAccessibilityIdentifier("ocr.text"); ocrText.setAccessibilityLabel(localization.text("ocr.result"))
        scroll.documentView = ocrText; scroll.heightAnchor.constraint(equalToConstant: 220).isActive = true; ocrPanel.append(scroll)
        ocrPanel.append(row([button("ocr.copy", #selector(copyOCR)), button("ocr.save", #selector(saveOCR))])); ocrPanel.append(ocrPanel.status)
    }
    private func buildSheet() {
        sheetPanel.note(localization.text("utility.sheetTitle"), heading: true); sheetPanel.note(localization.text("sheet.help"))
        sheetPanel.append(button("sheet.addCurrent", #selector(addCurrentPhoto)))
        sheetPanel.append(button("sheet.addFiles", #selector(addPhotoFiles))); sheetPanel.append(button("sheet.cancelImport", #selector(cancelSheetImport)))
        let column = NSTableColumn(identifier: .init("photo")); column.width = 270; column.title = localization.text("sheet.photos")
        photos.addTableColumn(column); photos.headerView = nil; photos.rowHeight = 42; photos.delegate = self; photos.dataSource = self
        photos.allowsMultipleSelection = false; photos.setAccessibilityIdentifier("sheet.photos")
        let list = NSScrollView(); list.hasVerticalScroller = true; list.documentView = photos; list.borderType = .bezelBorder
        list.heightAnchor.constraint(equalToConstant: 170).isActive = true; sheetPanel.append(list)
        sheetPanel.append(row([button("sheet.up", #selector(movePhotoUp)), button("sheet.down", #selector(movePhotoDown)), button("sheet.remove", #selector(removePhoto))]))
        field(sheetPanel, "sheet.caption", caption)
        field(sheetPanel, "sheet.title", sheetTitle); sheetTitle.stringValue = localization.text("sheet.defaultTitle")
        field(sheetPanel, "sheet.note", sheetNote)
        option(sheetPanel, "sheet.perPage", perPage, values: ["1", "2", "4", "6"], action: #selector(sheetOptionsChanged)); perPage.selectItem(at: 1)
        option(sheetPanel, "sheet.orientation", orientation, values: [localization.text("sheet.portrait"), localization.text("sheet.landscape")], action: #selector(sheetOptionsChanged))
        fileNames.title = localization.text("sheet.fileNames"); fileNames.target = self; fileNames.action = #selector(sheetOptionsChanged)
        fileNames.setAccessibilityIdentifier("sheet.fileNames"); sheetPanel.append(fileNames)
        option(sheetPanel, "sheet.page", pageChoice, values: [], action: #selector(changeSheetPage))
        sheetPanel.append(button("sheet.exportPDF", #selector(exportSheetPDF))); sheetPanel.append(button("sheet.exportPNG", #selector(exportSheetPNG)))
        sheetPanel.note(localization.text("sheet.exportHelp")); sheetPanel.append(sheetPanel.status)
    }
    private func buildPrivacy() {
        privacyPanel.note(localization.text("utility.privacyTitle"), heading: true); privacyPanel.note(localization.text("privacy.help"))
        option(privacyPanel, "privacy.mode", privacyMode, values: PrivacyStyle.allCases.map { localization.text("privacy.mode." + $0.rawValue) }, action: #selector(privacyOptionsChanged))
        privacyPanel.note(localization.text("privacy.strength")); strength.isContinuous = true; strength.target = self; strength.action = #selector(privacyOptionsChanged)
        strength.setAccessibilityIdentifier("privacy.strength"); strength.setAccessibilityLabel(localization.text("privacy.strength")); privacyPanel.append(strength)
        privacyPanel.append(button("privacy.select", #selector(selectPrivacyRegions)))
        privacyPanel.append(button("privacy.findFaces", #selector(findFaces)))
        privacyPanel.append(row([button("privacy.removeLast", #selector(removeLastPrivacy)), button("privacy.clear", #selector(clearPrivacy))]))
        privacyPanel.append(button("privacy.apply", #selector(applyPrivacy))); privacyPanel.append(button("privacy.cancel", #selector(cancelPrivacy)))
        privacyPanel.note(localization.text("privacy.sharingHelp")); privacyPanel.append(privacyPanel.status)
    }
    func attach(to workspace: WorkspaceView) {
        self.workspace = workspace; workspace.sidebar.installPages([ocrPanel, sheetPanel, privacyPanel])
        workspace.sidebar.pageChanged = { [weak self] page in self?.changePage(page) }
        workspace.presentationDismissed = { [weak self] in
            guard let self else { return }; capture = nil; previewOriginal = nil
            guard !transitioning else { return }
            cancelInteractive(); workspace.sidebar.showPage(0)
        }
        synchronizeActiveDocument()
    }
    private var context: String? { coordinator.active.map { $0.model.id.uuidString + ":" + $0.history.stateID.uuidString } }
    private var canUseImage: Bool { coordinator.active.map { !$0.hasSession && !$0.isInteractionLocked } ?? false }
    func synchronizeActiveDocument() {
        if activeContext != context {
            cancelInteractive(); activeContext = context; ocrRegion = nil; privacyRegions = []; ocrText.string = ""
            capture = nil; previewOriginal = nil; renderedPrivacy = false
        }
        regionInfo.stringValue = ocrRegion.map { String(format: localization.text("ocr.regionFormat"), $0.x, $0.y, $0.width, $0.height) } ?? localization.text("ocr.fullRegion")
        updateControls()
    }
    private func updateControls() {
        for key in ["ocr.run", "ocr.selectRegion", "ocr.wholeImage"] { controls[key]?.isEnabled = canUseImage && !ocrBusy }
        controls["ocr.cancel"]?.isHidden = !ocrBusy
        for key in ["ocr.copy", "ocr.save"] { controls[key]?.isEnabled = !ocrBusy && !ocrText.string.isEmpty }
        ocrText.isEditable = !ocrBusy
        for key in ["privacy.select", "privacy.findFaces"] { controls[key]?.isEnabled = canUseImage && !privacyBusy }
        controls["privacy.apply"]?.isEnabled = canUseImage && !privacyBusy && renderedPrivacy && !privacyRegions.isEmpty
        for key in ["privacy.clear", "privacy.removeLast"] { controls[key]?.isEnabled = !privacyBusy && !privacyRegions.isEmpty }
        controls["privacy.cancel"]?.isEnabled = privacyBusy || capture != nil || !privacyRegions.isEmpty
        privacyMode.isEnabled = !privacyBusy; strength.isEnabled = !privacyBusy && selectedPrivacyStyle != .cover
        controls["sheet.addCurrent"]?.isEnabled = canUseImage && !sheetBusy && entries.count < PhotoSheetEngine.maximumPhotos
        controls["sheet.addFiles"]?.isEnabled = !sheetBusy && entries.count < PhotoSheetEngine.maximumPhotos
        controls["sheet.cancelImport"]?.isHidden = !sheetBusy
        let selection = entries.indices.contains(photos.selectedRow)
        for key in ["sheet.up", "sheet.down", "sheet.remove"] { controls[key]?.isEnabled = selection && !sheetBusy }
        controls["sheet.up"]?.isEnabled = selection && photos.selectedRow > 0 && !sheetBusy
        controls["sheet.down"]?.isEnabled = selection && photos.selectedRow + 1 < entries.count && !sheetBusy
        for key in ["sheet.exportPDF", "sheet.exportPNG"] { controls[key]?.isEnabled = !entries.isEmpty && !sheetBusy }
        caption.isEnabled = selection && !sheetBusy
        for control in [sheetTitle, sheetNote] { control.isEnabled = !sheetBusy }
        for control in [perPage, orientation, pageChoice] { control.isEnabled = !sheetBusy }
        fileNames.isEnabled = !sheetBusy; photos.isEnabled = !sheetBusy
        if !canUseImage {
            let key = coordinator.active == nil ? "utility.noImage" : "utility.finishDraft"
            if !ocrBusy { ocrPanel.status.stringValue = localization.text(key) }
            if !privacyBusy { privacyPanel.status.stringValue = localization.text(key) }
        }
    }
    private func changePage(_ page: Int) {
        cancelInteractive(); transitioning = true; workspace?.dismissPresentation(); transitioning = false
        if page == 2 { scheduleSheetPreview() }
        else if page == 3, canUseImage { prepareCapture(privacy: true) }
        updateControls()
    }
    private func cancelInteractive() {
        ocrGeneration = UUID(); ocrTask?.cancel(); ocrTask = nil; ocrBusy = false
        captureGeneration = UUID(); captureTask?.cancel(); captureTask = nil
        privacyGeneration = UUID(); previewGeneration = UUID(); privacyTask?.cancel(); privacyTask = nil; privacyBusy = false
        renderedPrivacy = false
    }
    private func failure(_ error: Error, panel: UtilityPanel) {
        if error is CancellationError { panel.status.stringValue = localization.text("action.cancel") }
        else if let error = error as? InvestigationError { panel.status.stringValue = localization.text(error.localizationKey) }
        else if error is PhotoSheetError { panel.status.stringValue = localization.text("sheet.captionTooLong") }
        else if let error = error as? ImageImportError { panel.status.stringValue = localization.text(error.key) }
        else { panel.status.stringValue = localization.text("utility.error") + " " + error.localizedDescription }
    }
    @objc func runOCR() {
        guard canUseImage, !ocrBusy, let document = coordinator.active else { return }
        let snapshot = document.snapshot(), anchor = context, token = UUID(), region = ocrRegion ?? EvidenceRegion(x: 0, y: 0, width: snapshot.model.canvas.width, height: snapshot.model.canvas.height)
        let recognize = recognition
        ocrGeneration = token; ocrBusy = true; ocrText.string = ""; ocrPanel.status.stringValue = localization.text("ocr.processing"); updateControls()
        ocrTask = Task { [weak self] in
            guard let self else { return }
            defer { if ocrGeneration == token { ocrBusy = false; ocrTask = nil; updateControls() } }
            do {
                let image = try await coordinator.pipeline.renderDocument(model: snapshot.model, assets: snapshot.assets)
                try Task.checkCancellation()
                let result = try await OCRExecution.run { try recognize(image, region, $0) }
                try Task.checkCancellation(); guard context == anchor, ocrGeneration == token else { return }
                ocrText.string = result.text; ocrPanel.status.stringValue = localization.text(result.text.isEmpty ? "ocr.noText" : "ocr.completed")
            } catch { if context == anchor, ocrGeneration == token { failure(error, panel: ocrPanel) } }
        }
    }
    @objc func cancelOCR() {
        ocrGeneration = UUID(); ocrTask?.cancel(); ocrTask = nil; ocrBusy = false
        ocrPanel.status.stringValue = localization.text("ocr.cancelled"); updateControls()
    }
    @objc private func selectOCRRegion() { guard canUseImage, !ocrBusy else { return }; prepareCapture(privacy: false) }
    @objc private func wholeOCRImage() { ocrRegion = nil; if workspace?.sidebar.selectedPage == 1 { capture?.regions = [] }; synchronizeActiveDocument() }
    @objc private func copyOCR() { guard !ocrText.string.isEmpty else { return }; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(ocrText.string, forType: .string) }
    @objc private func saveOCR() {
        guard !ocrText.string.isEmpty, let url = destination("OCR.txt", type: .plainText) else { return }
        let text = ocrText.string
        Task { do { try coordinator.protectInvestigationDestination?(url); try await InvestigationSharing.write(Data(text.utf8), to: url); ocrPanel.status.stringValue = localization.text("utility.exported") } catch { failure(error, panel: ocrPanel) } }
    }
    private func prepareCapture(privacy: Bool) {
        guard canUseImage, let document = coordinator.active else { return }
        let snapshot = document.snapshot(), anchor = context, generation = UUID(); captureGeneration = generation
        captureTask?.cancel()
        let panel = privacy ? privacyPanel : ocrPanel; panel.status.stringValue = localization.text("utility.preparing")
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                let image = try await coordinator.pipeline.exportImage(snapshot: snapshot, options: ExportOptions(size: snapshot.model.canvas, ppi: snapshot.model.ppi), previewEdge: 2000)
                try Task.checkCancellation(); guard context == anchor, captureGeneration == generation, workspace?.sidebar.selectedPage == (privacy ? 3 : 1) else { return }
                let picker = UtilityCanvasView(image: image, sourceSize: snapshot.model.canvas, selectable: true, multiple: privacy)
                picker.regions = privacy ? privacyRegions : ocrRegion.map { [$0] } ?? []
                picker.setAccessibilityIdentifier(privacy ? "privacy.canvas" : "ocr.canvas")
                picker.setAccessibilityLabel(localization.text(privacy ? "privacy.help" : "ocr.selectRegion"))
                picker.selectionChanged = { [weak self] regions in
                    guard let self else { return }
                    if privacy { privacyRegions = regions; schedulePrivacyPreview() }
                    else { ocrRegion = regions.first; synchronizeActiveDocument() }
                }
                picker.selectionLimit = { [weak self] in self?.privacyPanel.status.stringValue = self?.localization.text("privacy.regionLimit") ?? "" }
                picker.cancel = { [weak self] in if privacy { self?.cancelPrivacy() } else { self?.wholeOCRImage() } }
                capture = picker; previewOriginal = image; workspace?.showPresentation(picker)
                if privacy { schedulePrivacyPreview() } else { panel.status.stringValue = localization.text("ocr.selectHelp") }
                updateControls()
            } catch { if context == anchor, captureGeneration == generation { failure(error, panel: panel) } }
        }
    }
    private var selectedPrivacyStyle: PrivacyStyle { PrivacyStyle.allCases[max(0, privacyMode.indexOfSelectedItem)] }
    @objc private func selectPrivacyRegions() { guard canUseImage, !privacyBusy else { return }; prepareCapture(privacy: true) }
    @objc func privacyOptionsChanged() { schedulePrivacyPreview() }
    private func schedulePrivacyPreview() {
        guard let image = previewOriginal, let canvas = coordinator.active?.model.canvas, workspace?.sidebar.selectedPage == 3 else { return }
        let regions = privacyRegions, style = selectedPrivacyStyle, value = strength.doubleValue, anchor = context, generation = UUID()
        previewGeneration = generation; renderedPrivacy = false; privacyTask?.cancel(); updateControls()
        privacyTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(65)); try Task.checkCancellation()
                let preview = try await privacyEngine.preview(image: image, modelSize: canvas, regions: regions, style: style, strength: value)
                try Task.checkCancellation(); guard context == anchor, previewGeneration == generation else { return }
                capture?.updateImage(preview); capture?.regions = regions; renderedPrivacy = true
                privacyPanel.status.stringValue = String(format: localization.text("privacy.regionsFormat"), regions.count) + " " + localization.text("privacy.reviewFaces"); updateControls()
            } catch { if previewGeneration == generation { failure(error, panel: privacyPanel) } }
        }
    }
    @objc private func removeLastPrivacy() { if !privacyRegions.isEmpty { privacyRegions.removeLast() }; capture?.regions = privacyRegions; schedulePrivacyPreview() }
    @objc private func clearPrivacy() { privacyRegions = []; capture?.regions = []; schedulePrivacyPreview() }
    @objc func cancelPrivacy() {
        privacyTask?.cancel(); previewGeneration = UUID(); privacyGeneration = UUID(); privacyBusy = false
        privacyRegions = []; renderedPrivacy = false; capture?.regions = []
        if let previewOriginal { capture?.updateImage(previewOriginal) }
        privacyPanel.status.stringValue = localization.text("privacy.cancelled"); updateControls()
    }
    @objc private func findFaces() {
        guard canUseImage, !privacyBusy else { return }
        if previewOriginal == nil { prepareCapture(privacy: true); return }
        guard let image = previewOriginal, let canvas = coordinator.active?.model.canvas else { return }
        let anchor = context, generation = UUID(); privacyGeneration = generation; privacyBusy = true
        privacyPanel.status.stringValue = localization.text("privacy.finding"); updateControls()
        privacyTask = Task { [weak self] in
            guard let self else { return }
            defer { if privacyGeneration == generation { privacyBusy = false; updateControls() } }
            do {
                let regions = try await privacyEngine.faces(image: image, modelSize: canvas)
                try Task.checkCancellation(); guard context == anchor, privacyGeneration == generation else { return }
                privacyRegions = regions; capture?.regions = regions; schedulePrivacyPreview()
                privacyPanel.status.stringValue = localization.text(regions.isEmpty ? "privacy.noFaces" : "privacy.reviewFaces")
            } catch { if context == anchor, privacyGeneration == generation { failure(error, panel: privacyPanel) } }
        }
    }
    @objc func applyPrivacy() {
        guard canUseImage, !privacyBusy, renderedPrivacy, !privacyRegions.isEmpty, let document = coordinator.active else { return }
        let snapshot = document.snapshot(), regions = privacyRegions, style = selectedPrivacyStyle, value = strength.doubleValue, anchor = context, generation = UUID()
        privacyGeneration = generation; privacyBusy = true; privacyPanel.status.stringValue = localization.text("utility.preparing"); updateControls()
        privacyTask?.cancel()
        privacyTask = Task { [weak self, weak document] in
            guard let self, let document else { return }
            defer { if privacyGeneration == generation { privacyBusy = false; updateControls() } }
            do {
                let patches: [PrivacyPatch]
                if style == .cover { patches = regions.map { PrivacyPatch(region: $0, asset: nil) } }
                else {
                    let image = try await coordinator.pipeline.renderDocument(model: snapshot.model, assets: snapshot.assets)
                    patches = try await privacyEngine.patches(image: image, regions: regions, style: style, strength: value, ppi: snapshot.model.ppi)
                }
                try Task.checkCancellation(); guard context == anchor, privacyGeneration == generation else { return }
                try document.applyPrivacy(patches, style: style)
                privacyRegions = []; renderedPrivacy = false
                transitioning = true; workspace?.dismissPresentation(); transitioning = false; workspace?.sidebar.showPage(0)
                privacyPanel.status.stringValue = localization.text("privacy.applied")
            } catch { if context == anchor, privacyGeneration == generation { failure(error, panel: privacyPanel) } }
        }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard entries.indices.contains(row) else { return nil }
        let value = NSTextField(wrappingLabelWithString: "\(row + 1). " + entries[row].name)
        value.font = .systemFont(ofSize: 12); value.setAccessibilityLabel("\(row + 1). " + entries[row].name)
        value.setAccessibilityIdentifier("sheet.photo.\(row)"); return value
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        updatingFields = true; caption.stringValue = entries.indices.contains(photos.selectedRow) ? entries[photos.selectedRow].caption : ""; updatingFields = false; updateControls()
    }
    func textDidChange(_ notification: Notification) { updateControls() }
    func controlTextDidChange(_ notification: Notification) {
        guard !updatingFields else { return }
        if notification.object as? NSTextField === caption, entries.indices.contains(photos.selectedRow) { entries[photos.selectedRow].caption = caption.stringValue }
        if [sheetTitle, sheetNote, caption].contains(where: { $0 === notification.object as? NSTextField }) { scheduleSheetPreview() }
    }
    var sheetSettings: PhotoSheetSettings { PhotoSheetSettings(title: sheetTitle.stringValue, note: sheetNote.stringValue, perPage: [1, 2, 4, 6][max(0, perPage.indexOfSelectedItem)], landscape: orientation.indexOfSelectedItem == 1, showsFileNames: fileNames.state == .on) }
    private func refreshPhotos(selected: Int) {
        photos.reloadData()
        if !entries.isEmpty { photos.selectRowIndexes(IndexSet(integer: min(max(0, selected), entries.count - 1)), byExtendingSelection: false) }
        else { photos.deselectAll(nil); caption.stringValue = "" }
        updateControls(); scheduleSheetPreview()
    }
    func appendPhoto(_ entry: PhotoSheetEntry) throws {
        let candidates = entries + [entry]; try PhotoSheetEngine.validate(candidates, settings: sheetSettings)
        entries = candidates; refreshPhotos(selected: entries.count - 1)
    }
    @objc private func addCurrentPhoto() {
        guard canUseImage, !sheetBusy, let document = coordinator.active else { return }
        let snapshot = document.snapshot(); startAdding {
            let size = try ImagePipeline.reducedSize(width: snapshot.model.canvas.width, height: snapshot.model.canvas.height, pixelBudget: 4_000_000)
            let image = try await self.coordinator.pipeline.exportImage(snapshot: snapshot, options: ExportOptions(size: size, ppi: snapshot.model.ppi))
            let data = try InvestigationSharing.pngBytes(image, ppi: snapshot.model.ppi)
            return [PhotoSheetEntry(name: snapshot.model.name, pixels: size, data: data)]
        }
    }
    @objc private func addPhotoFiles() {
        guard !sheetBusy else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.png, .jpeg, .heic, .heif]; panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.message = localization.text("sheet.chooseFiles"); guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        guard entries.count + urls.count <= PhotoSheetEngine.maximumPhotos else { sheetPanel.status.stringValue = localization.text("sheet.limit"); return }
        startAdding {
            var output: [PhotoSheetEntry] = []
            for url in urls {
                try Task.checkCancellation()
                let asset = try await self.coordinator.pipeline.prepare(.file(url), budget: ImportBudget(remainingPixels: 4_000_000), allowResize: true)
                let image = try await self.coordinator.pipeline.normalizedImage(asset)
                let data = try InvestigationSharing.pngBytes(image, ppi: 72)
                output.append(PhotoSheetEntry(name: url.lastPathComponent, pixels: asset.descriptor.size, data: data))
                guard output.reduce(0, { $0 + $1.data.count }) + self.entries.reduce(0, { $0 + $1.data.count }) <= PhotoSheetEngine.maximumBytes else { throw DocumentError.resourceLimit }
            }
            return output
        }
    }
    private func startAdding(_ operation: @escaping @MainActor () async throws -> [PhotoSheetEntry]) {
        sheetBusy = true; sheetPanel.status.stringValue = localization.text("sheet.adding"); updateControls()
        sheetTask = Task { [weak self] in
            guard let self else { return }; defer { sheetBusy = false; sheetTask = nil; updateControls() }
            do {
                let output = try await operation(); try Task.checkCancellation()
                let candidates = entries + output; try PhotoSheetEngine.validate(candidates, settings: sheetSettings)
                entries = candidates; refreshPhotos(selected: entries.count - output.count)
            } catch { failure(error, panel: sheetPanel) }
        }
    }
    @objc private func cancelSheetImport() { sheetTask?.cancel() }
    @objc private func movePhotoUp() { reorderPhoto(delta: -1) }
    @objc private func movePhotoDown() { reorderPhoto(delta: 1) }
    func reorderPhoto(delta: Int) {
        let index = photos.selectedRow, next = index + delta
        guard !sheetBusy, entries.indices.contains(index), entries.indices.contains(next) else { return }
        entries.swapAt(index, next); refreshPhotos(selected: next)
    }
    @objc private func removePhoto() {
        let row = photos.selectedRow; guard !sheetBusy, entries.indices.contains(row) else { return }
        entries.remove(at: row); refreshPhotos(selected: row)
    }
    @objc private func sheetOptionsChanged() { sheetPage = 0; scheduleSheetPreview() }
    @objc private func changeSheetPage() { sheetPage = max(0, pageChoice.indexOfSelectedItem); scheduleSheetPreview() }
    private func scheduleSheetPreview() {
        sheetPreviewTask?.cancel(); let token = UUID(); sheetGeneration = token
        let settings = sheetSettings, entries = entries
        let count = PhotoSheetEngine.pageCount(entries.count, perPage: settings.perPage)
        sheetPage = min(max(0, sheetPage), max(0, count - 1)); pageChoice.removeAllItems()
        for page in 0..<count { pageChoice.addItem(withTitle: String(format: localization.text("sheet.pageFormat"), page + 1, count)) }
        if count > 0 { pageChoice.selectItem(at: sheetPage) }
        guard !entries.isEmpty else {
            sheetPanel.status.stringValue = localization.text("sheet.empty")
            if workspace?.sidebar.selectedPage == 2 { transitioning = true; workspace?.dismissPresentation(); transitioning = false }
            return
        }
        guard workspace?.sidebar.selectedPage == 2 else { return }
        let index = sheetPage, language = localization.language
        sheetPanel.status.stringValue = localization.text("utility.preparing")
        sheetPreviewTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(90)); try Task.checkCancellation()
                let task = Task.detached(priority: .userInitiated) { try PhotoSheetEngine.page(entries: entries, settings: settings, index: index, dpi: 90, language: language) }
                let image = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
                try Task.checkCancellation(); guard sheetGeneration == token, workspace?.sidebar.selectedPage == 2 else { return }
                let preview = UtilityCanvasView(image: image, sourceSize: try CanvasSize(width: image.width, height: image.height))
                preview.setAccessibilityIdentifier("sheet.preview"); preview.setAccessibilityLabel(localization.text("sheet.preview"))
                workspace?.showPresentation(preview)
                sheetPanel.status.stringValue = String(format: localization.text("sheet.summary"), entries.count, count)
            } catch { if sheetGeneration == token { failure(error, panel: sheetPanel) } }
        }
    }
    private func destination(_ name: String, type: UTType) -> URL? {
        let panel = NSSavePanel(); panel.allowedContentTypes = [type]; panel.canCreateDirectories = true; panel.nameFieldStringValue = name
        guard panel.runModal() == .OK else { return nil }; return panel.url
    }
    @objc private func exportSheetPDF() {
        guard !sheetBusy, !entries.isEmpty, let url = destination("Bang-anh.pdf", type: .pdf) else { return }
        exportSheet(to: url, png: false)
    }
    @objc private func exportSheetPNG() {
        guard !sheetBusy, !entries.isEmpty, let url = destination("Bang-anh-\(sheetPage + 1).png", type: .png) else { return }
        exportSheet(to: url, png: true)
    }
    private func exportSheet(to url: URL, png: Bool) {
        let entries = entries, settings = sheetSettings, language = localization.language, page = sheetPage
        sheetBusy = true; updateControls(); sheetPanel.status.stringValue = localization.text("utility.preparing")
        sheetTask = Task { [weak self] in
            guard let self else { return }; defer { sheetBusy = false; sheetTask = nil; updateControls() }
            do {
                try coordinator.protectInvestigationDestination?(url)
                let task = Task.detached(priority: .userInitiated) {
                    if png {
                        let image = try PhotoSheetEngine.page(entries: entries, settings: settings, index: page, dpi: 300, language: language)
                        return try InvestigationSharing.pngBytes(image, ppi: 300)
                    }
                    return try PhotoSheetEngine.pdf(entries: entries, settings: settings, language: language)
                }
                let bytes = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
                try Task.checkCancellation(); try await InvestigationSharing.write(bytes, to: url)
                sheetPanel.status.stringValue = localization.text("utility.exported")
            } catch { failure(error, panel: sheetPanel) }
        }
    }
}

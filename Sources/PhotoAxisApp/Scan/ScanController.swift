import AppKit
import PhotoAxisCore

private final class ScanSurface: NSView { override var isFlipped: Bool { true } }

final class ScanImageView: NSView {
    override var isFlipped: Bool { true }
    var image: NSImage? { didSet { needsDisplay = true } }
    var quad: PerspectiveQuad? { didSet { needsDisplay = true } }
    var canvas: CanvasSize?
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.12, alpha: 1).setFill(); bounds.fill()
        guard let image else { return }
        let factor = min(bounds.width/image.size.width, bounds.height/image.size.height)
        let rect = NSRect(x: (bounds.width-image.size.width*factor)/2, y: (bounds.height-image.size.height*factor)/2,
                          width: image.size.width*factor, height: image.size.height*factor)
        NSColor.white.setFill(); rect.fill()
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        if let quad, let canvas {
            let path = NSBezierPath(); path.lineWidth = 2; NSColor.systemOrange.setStroke()
            for (index,p) in quad.points.enumerated() {
                let point = NSPoint(x: rect.minX+p.x/Double(canvas.width)*rect.width, y: rect.minY+p.y/Double(canvas.height)*rect.height)
                if index == 0 { path.move(to: point) } else { path.line(to: point) }
            }
            path.close(); path.stroke()
        }
    }
}

@MainActor final class ScanController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    let beforeView = ScanImageView(), afterView = ScanImageView()
    let mode = NSPopUpButton(), paperSize = NSPopUpButton()
    let sliders = (0..<7).map { _ in NSSlider() }
    let ppi = NSTextField(), width = NSTextField(), height = NSTextField(), angle = NSTextField()
    let enabled = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let autoPage = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let autoDeskew = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let notice = NSTextField(wrappingLabelWithString: ""), applyButton = NSButton(), previewButton = NSButton()
    private let photoDocument: PhotoDocument, pipeline: ImagePipeline, localization: L10n
    private let original: ProjectSnapshot, layerID: UUID, detector = ScanDetector()
    private var batchFiles: [URL]?
    let pageList = NSTableView()
    private var task: Task<Void,Never>?, generation = 0
    private var quad: PerspectiveQuad?, originalImage: CGImage?, readyRecipe: ScanRecipe?
    private var batchRunning = false
    var finished: (() -> Void)?

    init(document photoDocument: PhotoDocument, pipeline: ImagePipeline, localization: L10n, batchFiles: [URL]? = nil) throws {
        guard photoDocument.resolveSession(), let id = photoDocument.selectedLayerID, let layer = photoDocument.model.layer(id),
              case .image = layer.content, !layer.isLocked, !photoDocument.isInteractionLocked else { throw DocumentError.invalidValue }
        self.photoDocument = photoDocument; self.pipeline = pipeline; self.localization = localization; self.batchFiles = batchFiles
        original = photoDocument.snapshot(); layerID = id
        try photoDocument.beginSession(.scan)
        let panel = NSPanel(contentRect: NSRect(x: 0,y: 0,width: 1100,height: 740), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = localization.text(batchFiles == nil ? "scan.title" : "scan.batch")
        panel.isReleasedWhenClosed = false
        let root = ScanSurface(frame: panel.contentView!.bounds); panel.contentView = root
        super.init(window: panel)
        let before = NSTextField(labelWithString: localization.text("scan.before")), after = NSTextField(labelWithString: localization.text("scan.after"))
        before.frame = NSRect(x: 18,y: 15,width: 350,height: 25); after.frame = NSRect(x: 393,y: 15,width: 350,height: 25)
        if batchFiles != nil { before.stringValue = String(format:localization.text("scan.sample"),original.model.name); before.toolTip = before.stringValue }
        root.addSubview(before); root.addSubview(after)
        beforeView.frame = NSRect(x: 18,y: 45,width: 355,height: 540); afterView.frame = NSRect(x: 393,y: 45,width: 355,height: 540)
        beforeView.setAccessibilityLabel(localization.text("scan.before")); afterView.setAccessibilityLabel(localization.text("scan.after"))
        root.addSubview(beforeView); root.addSubview(afterView)
        let scroll = NSScrollView(frame: NSRect(x: 770,y: 15,width: 312,height: 590)); scroll.hasVerticalScroller = true
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false; scroll.documentView = stack; root.addSubview(scroll)
        NSLayoutConstraint.activate([stack.widthAnchor.constraint(equalToConstant: 290)])
        func add(_ control: NSView) { stack.addArrangedSubview(control); control.widthAnchor.constraint(equalToConstant: 285).isActive = true }
        func row(_ key: String, _ control: NSControl) {
            let label = NSTextField(labelWithString: localization.text(key)); label.font = .systemFont(ofSize: 11)
            control.setAccessibilityLabel(localization.text(key)); control.toolTip = localization.text(key)
            add(label); add(control)
        }
        enabled.title = localization.text("scan.enabled"); enabled.state = .on; enabled.target = self; enabled.action = #selector(changed); add(enabled)
        mode.addItems(withTitles: ["scan.color","scan.gray","scan.blackWhite"].map { localization.text($0) })
        mode.target = self; mode.action = #selector(changed); row("scan.mode", mode)
        let setting = layer.scan ?? ScanSettings()
        mode.selectItem(at: ScanSettings.Mode.allCases.firstIndex(of: setting.mode)!); enabled.state = setting.enabled ? .on : .off
        let values = [setting.paper,setting.denoise,setting.sharpness,setting.threshold,setting.radius,setting.curveX,setting.curveY]
        let labels = ["scan.paper","scan.denoise","scan.sharpness","scan.threshold","scan.radius","scan.curveX","scan.curveY"]
        for i in sliders.indices {
            let slider = sliders[i]; slider.minValue = i >= 5 ? -1 : i == 4 ? 0.005 : 0
            slider.maxValue = i == 3 ? 0.4 : i == 4 ? 0.1 : 1; slider.doubleValue = values[i]
            slider.isContinuous = false; slider.target = self; slider.action = #selector(changed); row(labels[i], slider)
        }
        if batchFiles == nil {
            for (key, selector) in [("scan.detect",#selector(detectPage)),("scan.deskew",#selector(detectAngle)),("scan.clearPage",#selector(clearPage))] {
                let button = NSButton(title: localization.text(key), target: self, action: selector); button.bezelStyle = .rounded; add(button)
            }
        }
        angle.stringValue = "0"; angle.target = self; angle.action = #selector(changed); row("scan.angle", angle)
        paperSize.addItems(withTitles: ["scan.originalSize","scan.a4","scan.a4Landscape","scan.letter","scan.customSize"].map { localization.text($0) })
        paperSize.target = self; paperSize.action = #selector(changed); row("scan.outputSize", paperSize)
        for (key, field, value) in [("document.width",width,String(original.model.canvas.width)),("document.height",height,String(original.model.canvas.height)),("document.ppi",ppi,"300")] {
            field.stringValue = value; field.target = self; field.action = #selector(changed); row(key, field)
        }
        if batchFiles != nil {
            autoPage.title = localization.text("scan.autoPage"); autoDeskew.title = localization.text("scan.autoDeskew")
            for box in [autoPage,autoDeskew] { box.state = .on; box.target = self; box.action = #selector(changed); box.toolTip = box.title; add(box) }
            add(NSTextField(labelWithString:localization.text("scan.pageOrder")))
            let column = NSTableColumn(identifier:NSUserInterfaceItemIdentifier("ScanPages")); column.width = 275; pageList.addTableColumn(column)
            pageList.headerView = nil; pageList.dataSource = self; pageList.delegate = self; pageList.rowHeight = 24
            pageList.setAccessibilityLabel(localization.text("scan.pageOrder"))
            let list = NSScrollView(); list.hasVerticalScroller = true; list.documentView = pageList; list.heightAnchor.constraint(equalToConstant:150).isActive = true; add(list)
            for (key,selector) in [("scan.pageUp",#selector(movePageUp)),("scan.pageDown",#selector(movePageDown))] {
                let button = NSButton(title:localization.text(key),target:self,action:selector); button.bezelStyle = .rounded; add(button)
            }
        }
        let help = NSTextField(wrappingLabelWithString: localization.text("scan.help")); help.font = .systemFont(ofSize: 11); add(help)
        notice.frame = NSRect(x: 18,y: 615,width: 1064,height: 55); notice.font = .systemFont(ofSize: 12); root.addSubview(notice)
        previewButton.title = localization.text("scan.preview"); previewButton.bezelStyle = .rounded; previewButton.target = self; previewButton.action = #selector(preview)
        previewButton.frame = NSRect(x: 640,y: 687,width: 145,height: 32); root.addSubview(previewButton)
        let cancel = NSButton(title: localization.text("action.cancel"), target: self, action: #selector(cancel)); cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        cancel.frame = NSRect(x: 793,y: 687,width: 120,height: 32); root.addSubview(cancel)
        applyButton.title = localization.text(batchFiles == nil ? "action.apply" : "scan.runBatch"); applyButton.bezelStyle = .rounded
        applyButton.target = self; applyButton.action = #selector(apply); applyButton.keyEquivalent = "\r"
        applyButton.frame = NSRect(x: 921,y: 687,width: 161,height: 32); applyButton.isEnabled = false; root.addSubview(applyButton)
        panel.initialFirstResponder = previewButton
        NotificationCenter.default.addObserver(self, selector: #selector(textChanged(_:)), name: NSControl.textDidChangeNotification, object: nil)
        preview()
    }
    required init?(coder: NSCoder) { fatalError("Use init(photoDocument:pipeline:localization:)") }
    deinit { NotificationCenter.default.removeObserver(self) }
    func recipe() throws -> ScanRecipe {
        var result = ScanRecipe(); var settings = ScanSettings()
        settings.enabled = enabled.state == .on; settings.mode = ScanSettings.Mode.allCases[mode.indexOfSelectedItem]
        settings.paper = sliders[0].doubleValue; settings.denoise = sliders[1].doubleValue; settings.sharpness = sliders[2].doubleValue
        settings.threshold = sliders[3].doubleValue; settings.radius = sliders[4].doubleValue; settings.curveX = sliders[5].doubleValue; settings.curveY = sliders[6].doubleValue
        try settings.validate(); result.settings = settings; result.quad = quad
        guard let dpi = DocumentNumber.parse(ppi.stringValue, language: Locale.current.identifier), (36...1200).contains(dpi),
              let degrees = DocumentNumber.parse(angle.stringValue, language: Locale.current.identifier), (-15...15).contains(degrees) else { throw ScanError.invalidOptions }
        result.ppi = dpi; result.degrees = degrees
        switch paperSize.indexOfSelectedItem {
        case 1: result.size = try CanvasSize(width: Int((210/25.4*dpi).rounded()), height: Int((297/25.4*dpi).rounded()))
        case 2: result.size = try CanvasSize(width: Int((297/25.4*dpi).rounded()), height: Int((210/25.4*dpi).rounded()))
        case 3: result.size = try CanvasSize(width: Int((8.5*dpi).rounded()), height: Int((11*dpi).rounded()))
        case 4:
            guard let w = Int(width.stringValue), let h = Int(height.stringValue) else { throw ScanError.invalidOptions }
            result.size = try CanvasSize(width: w,height: h)
        default: break
        }
        return result
    }
    @objc func changed() {
        guard !batchRunning else { return }
        generation += 1; task?.cancel(); readyRecipe = nil; applyButton.isEnabled = false
        width.isEnabled = paperSize.indexOfSelectedItem == 4; height.isEnabled = width.isEnabled
        notice.stringValue = localization.text("scan.needsPreview")
    }
    @objc private func textChanged(_ notification: Notification) {
        guard let field = notification.object as? NSControl, field.window === window else { return }
        changed()
    }
    private func fail(_ error: Error) {
        readyRecipe = nil; applyButton.isEnabled = false
        let key = error is CancellationError ? "scan.cancelled" : error as? ScanError == .noPage ? "scan.noPage" : error as? ScanError == .noTextAngle ? "scan.noAngle" : "scan.error"
        notice.stringValue = localization.text(key)
    }
    @objc func preview() {
        guard !batchRunning else { return }
        changed(); let token = generation
        notice.stringValue = localization.text("scan.processing")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let recipe = try recipe()
                if originalImage == nil {
                    originalImage = try await pipeline.exportImage(snapshot: original, options: ExportOptions(size: original.model.canvas, ppi: recipe.ppi), previewEdge: 1200)
                }
                try Task.checkCancellation()
                guard generation == token else { return }
                guard photoDocument.toolSession?.command == .scan, photoDocument.model == original.model else { throw DocumentError.activeSession }
                var previewRecipe = recipe
                if batchFiles != nil {
                    previewRecipe = try await detector.analyze(recipe,image:originalImage!,canvas:original.model.canvas,autoPage:autoPage.state == .on,autoDeskew:autoDeskew.state == .on).recipe
                    try Task.checkCancellation(); guard generation == token else { return }
                }
                beforeView.image = NSImage(cgImage: originalImage!, size: .zero); beforeView.canvas = original.model.canvas; beforeView.quad = previewRecipe.quad
                try photoDocument.preview({ model,id in model = try previewRecipe.candidate(model, layerID: id) }, fromOriginal: true)
                let model = photoDocument.presentedModel
                let snapshot = ProjectSnapshot(model: model, assets: original.assets, stateID: original.stateID)
                var options = ExportOptions(size: model.canvas, ppi: recipe.ppi); options.transparency = false
                let result = try await pipeline.exportImage(snapshot: snapshot, options: options, previewEdge: 1200)
                try Task.checkCancellation(); guard generation == token else { return }
                afterView.image = NSImage(cgImage: result, size: .zero)
                readyRecipe = recipe; applyButton.isEnabled = true
                notice.stringValue = String(format: localization.text("scan.ready"), model.canvas.width, model.canvas.height, Int(recipe.ppi))
            } catch { if generation == token { photoDocument.invalidateSession(); fail(error) } }
        }
    }
    @objc func detectPage() { detect(angleOnly: false) }
    @objc func detectAngle() { detect(angleOnly: true) }
    @objc func clearPage() { guard !batchRunning else { return }; quad = nil; angle.stringValue = "0"; preview() }
    private func detect(angleOnly: Bool) {
        guard !batchRunning else { return }
        changed(); let token = generation; notice.stringValue = localization.text("scan.processing")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let image = try await pipeline.exportImage(snapshot: original, options: ExportOptions(size: original.model.canvas, ppi: original.model.ppi), previewEdge: 1600)
                if angleOnly {
                    let value = try await detector.deskew(in: image)
                    try Task.checkCancellation(); guard generation == token else { return }
                    angle.stringValue = DocumentNumber.format(value, language: Locale.current.identifier)
                } else {
                    let page = try await detector.page(in: image, canvas: original.model.canvas)
                    try Task.checkCancellation(); guard generation == token else { return }
                    quad = page.quad; angle.stringValue = "0"
                }
                preview()
            } catch { if generation == token { fail(error) } }
        }
    }
    @objc func apply() {
        guard let recipe = readyRecipe, !batchRunning else { return }
        guard photoDocument.toolSession?.command == .scan, photoDocument.model == original.model else { fail(DocumentError.activeSession); return }
        if let files = batchFiles {
            let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
            panel.message = localization.text("scan.outputFolder")
            panel.beginSheetModal(for: window!) { [weak self] response in
                guard let self, response == .OK, let parent = panel.url else { return }
                runBatch(files, recipe: recipe, parent: parent)
            }
        } else {
            photoDocument.applySession()
            if photoDocument.hasSession { notice.stringValue = localization.text("scan.error"); return }
            photoDocument.viewport.fit(photoDocument.model.canvas); photoDocument.changed?(); finish()
        }
    }
    private func runBatch(_ files: [URL], recipe: ScanRecipe, parent: URL) {
        batchRunning = true; applyButton.isEnabled = false; previewButton.isEnabled = false
        setBatchControls(enabled: false)
        let page = autoPage.state == .on, skew = autoDeskew.state == .on
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let output = try await ScanBatchStore().run(files, recipe: recipe, autoPage: page, autoDeskew: skew, parent: parent) { [weak self] n,total,name in
                    await self?.batchProgress(n, total, name)
                }
                batchRunning = false; photoDocument.cancelSession()
                NSWorkspace.shared.activateFileViewerSelecting([output]); finish()
            } catch { batchRunning = false; previewButton.isEnabled = true; setBatchControls(enabled: true); fail(error) }
        }
    }
    private func setBatchControls(enabled value: Bool) {
        for control in [enabled,mode,paperSize,ppi,angle,autoPage,autoDeskew] as [NSControl] { control.isEnabled = value }
        for slider in sliders { slider.isEnabled = value }
        width.isEnabled = value && paperSize.indexOfSelectedItem == 4; height.isEnabled = width.isEnabled
        pageList.isEnabled = value
    }
    private func batchProgress(_ n: Int, _ total: Int, _ name: String) { notice.stringValue = String(format: localization.text("scan.progress"), n,total,name) }
    func numberOfRows(in tableView: NSTableView) -> Int { batchFiles?.count ?? 0 }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let files = batchFiles else { return nil }
        let label = NSTextField(labelWithString:"\(row+1). \(files[row].lastPathComponent)"); label.lineBreakMode = .byTruncatingMiddle; label.toolTip = files[row].lastPathComponent; return label
    }
    @objc func movePageUp() { movePage(-1) }
    @objc func movePageDown() { movePage(1) }
    private func movePage(_ delta: Int) {
        guard !batchRunning, var files = batchFiles else { return }
        let row = pageList.selectedRow, target = row+delta
        guard files.indices.contains(row), files.indices.contains(target) else { return }
        files.swapAt(row,target); batchFiles = files; pageList.reloadData(); pageList.selectRowIndexes(IndexSet(integer:target),byExtendingSelection:false)
    }
    @objc func cancel() {
        generation += 1; task?.cancel()
        if batchRunning { notice.stringValue = localization.text("scan.cancelling"); return }
        photoDocument.cancelSession(); finish()
    }
    private func finish() {
        task?.cancel(); NotificationCenter.default.removeObserver(self)
        if let window, let parent = window.sheetParent { parent.endSheet(window) }
        else { close() }
        finished?()
    }
}

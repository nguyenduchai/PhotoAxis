import AppKit
import UniformTypeIdentifiers
import PhotoAxisCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSWindowDelegate {
    private let preferences = WorkspacePreferences()
    private var workspace: WorkspaceWindowController?
    private var settings: SettingsWindowController?
    private var localization: L10n!
    private var documents: DocumentCoordinator!
    private var sizeSheet:DocumentSizeController?
    private var scanSheet: ScanController?
    private var exportSheet:ExportController?
    private var newSheet: NewDocumentController?
    private var recoverySheet: RecoveryController?
    private var reviewingRecovery = false
    private var investigation: InvestigationController?
    private var pendingURLs: [URL] = []
    private var launchLanguage: InterfaceLanguage = .system

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        launchLanguage = preferences.language
        localization = L10n(choice: launchLanguage)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        documents = DocumentCoordinator(localization: localization, preferences: preferences)
        investigation = InvestigationController(coordinator: documents, localization: localization)
        investigation?.workingOpened = { [weak self] in self?.showWorkspace() }
        showWorkspace()
        connectDocuments()
        NSApp.mainMenu = makeMenu()
        NSApp.activate(ignoringOtherApps: true)
        documents.startRecovery(); reviewingRecovery = true
        Task { [weak self] in
            guard let self else { return }
            let entries = await documents.recoveryEntries()
            if !entries.isEmpty, let window = workspace?.window {
                let sheet = RecoveryController(entries:entries,localization:localization); recoverySheet = sheet
                sheet.openRecovered = { [weak self,weak sheet] entry in
                    Task { if await self?.documents.openRecovered(entry) == true { sheet?.completed(entry) } }
                }
                sheet.discard = { [weak self,weak sheet] entry in
                    Task { if await self?.documents.discardRecovery(entry) == true { sheet?.completed(entry) } }
                }
                window.beginSheet(sheet.window!) { [weak self] _ in self?.recoverySheet = nil; self?.finishRecoveryReview() }
            } else { finishRecoveryReview() }
        }
    }

    private func finishRecoveryReview() {
        reviewingRecovery = false
        if !pendingURLs.isEmpty { openURLs(pendingURLs); pendingURLs = [] }
        workspace?.window?.makeFirstResponder(workspace?.workspaceView.canvas)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWorkspace() }
        return true
    }

    private func showWorkspace() {
        if workspace == nil { workspace = WorkspaceWindowController(preferences: preferences, localization: localization) }
        workspace?.showWindow(nil)
        workspace?.window?.makeKeyAndOrderFront(nil)
        workspace?.window?.makeFirstResponder(workspace?.workspaceView.canvas)
    }

    private func connectDocuments() {
        guard let workspace else { return }
        workspace.window?.delegate = self
        let root = workspace.workspaceView
        investigation?.attach(to: root)
        documents.changed = { [weak self] in
            guard let self else { return }
            root.refreshDocuments(documents)
            investigation?.synchronizeActiveDocument()
            workspace.window?.title = documents.active.map { $0.model.name + " — PhotoAxis" } ?? "PhotoAxis"
            workspace.window?.isDocumentEdited = documents.active?.isDocumentEdited ?? false
        }
        documents.progressChanged = { [weak root] in root?.setImportProgress($0) }
        documents.report = { [weak self] in self?.showImportReport($0) }
        documents.recoveryNotice = { [weak self,weak root] message in
            root?.setImportProgress(message); root?.cancelImportButton.isHidden = true; self?.showImportReport(message)
        }
        documents.confirmResize = { [weak self] error in
            guard let self, case .resizeRequired(let w, let h, let pw, let ph) = error else { return false }
            let alert = NSAlert(); alert.messageText = localization.text("import.resizeTitle")
            alert.informativeText = String(format: localization.text("import.resizeBody"), w, h, pw, ph)
            alert.addButton(withTitle: localization.text("action.cancel")); alert.addButton(withTitle: localization.text("import.resizeCopy"))
            return alert.runModal() == .alertSecondButtonReturn
        }
        root.sidebar.placeImage = { [weak self] in self?.placeImages() }
        root.canvas.newDocument = { [weak self] in self?.makeDocument() }
        root.canvas.openImages = { [weak self] in self?.openImages() }
        root.canvas.importImages = { [weak self] inputs in guard let self else { return }; documents.startImport(inputs, into: documents.activeID) }
        root.canvas.renderFailed = { [weak root] message in root?.setImportProgress(message); root?.cancelImportButton.isHidden = true }
        root.canvas.toolChanged = { [weak root] tool in root?.tools.updateNavigationTools(tool); root?.optionsBar.display(root?.coordinator?.active) }
        root.tools.selectTool = { [weak root] tool in root?.canvas.selectTool(tool); root?.window?.makeFirstResponder(root?.canvas) }
        root.tabBar.select = { [weak self] id in self?.documents.select(id); root.window?.makeFirstResponder(root.canvas) }
        root.tabBar.closeTab = { [weak self] id in self?.documents.requestClose(id) }
        root.tabBar.openDroppedFiles = { [weak self] inputs in self?.documents.startImport(inputs, into: nil) }
        root.refreshDocuments(documents)
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        guard documents != nil, !reviewingRecovery else { pendingURLs.append(contentsOf: urls); return }
        showWorkspace(); openURLs(urls)
    }
    private func openURLs(_ urls: [URL]) {
        for url in urls where url.pathExtension.lowercased() == "paxcase" {
            do { try investigation?.open(url: url) } catch { showImportReport(localization.text((error as? InvestigationError)?.localizationKey ?? "investigation.error.invalidCase")) }
        }
        let images = urls.filter { $0.pathExtension.lowercased() != "paxcase" }
        if !images.isEmpty { documents.startImport(images.map { .file($0) }, into: nil) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let documents else { return .terminateNow }
        guard !documents.isClosing, workspace?.window?.attachedSheet == nil else { return .terminateCancel }
        Task { let close = await documents.requestCloseAll(); sender.reply(toApplicationShouldTerminate:close) }
        return .terminateLater
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !documents.isClosing, sender.attachedSheet == nil else { return false }
        Task { if await documents.requestCloseAll() { sender.orderOut(nil) } }; return false
    }
    @objc private func saveProject() { guard let document = documents.active else { return }; Task { _ = await documents.save(document,saveAs:false) } }
    @objc private func saveProjectAs() { guard let document = documents.active else { return }; Task { _ = await documents.save(document,saveAs:true) } }
    @objc private func exportImage() {
        guard let document = documents.active, !documents.isSaving, !documents.isImporting,
              document.resolveSession(), let window = workspace?.window, exportSheet == nil else { return }
        let sheet = ExportController(snapshot:document.snapshot(),pipeline:documents.pipeline,localization:localization)
        exportSheet = sheet
        var requested: (ProjectSnapshot,ExportOptions)?
        sheet.confirmed = { requested = ($0,$1) }
        window.beginSheet(sheet.window!) { [weak self] _ in
            guard let self else { return }; exportSheet = nil
            window.makeFirstResponder(workspace?.workspaceView.canvas)
            if let requested { Task { _ = await documents.export(requested.0,options:requested.1) } }
        }
    }
    @objc private func closeDocument() {
        if NSApp.keyWindow === workspace?.window, let id = documents.activeID { documents.requestClose(id) }
        else { NSApp.keyWindow?.performClose(nil) }
    }
    @objc private func makeDocument() {
        showWorkspace()
        guard documents.documents.count < DocumentLimits.maximumDocuments else { showImportReport(localization.text("document.tabLimit")); return }
        guard newSheet == nil, let window = workspace?.window else { return }
        let sheet = NewDocumentController(localization: localization)
        sheet.create = { [weak self] name, size, ppi, background in try self?.documents.create(name: name, size: size, ppi: ppi, background: background) }
        newSheet = sheet
        window.beginSheet(sheet.window!) { [weak self] _ in self?.newSheet = nil; self?.workspace?.window?.makeFirstResponder(self?.workspace?.workspaceView.canvas) }
    }
    @objc private func openImages() { chooseImages(place: false) }
    @objc private func placeImages() { chooseImages(place: true) }
    private func chooseImages(place: Bool) {
        showWorkspace(); guard let window = workspace?.window else { return }
        let targetID = place ? documents.activeID : nil
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.message = localization.text(place ? "import.openHelp" : "project.openHelp")
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self else { return }
            if place { documents.startImport(panel.urls.map { .file($0) }, into: targetID) } else { openURLs(panel.urls) }
        }
    }
    private func showImportReport(_ message: String) {
        let alert = NSAlert(); alert.messageText = localization.text("import.report"); alert.informativeText = message
        alert.addButton(withTitle: localization.text("action.close")); alert.runModal()
    }
    @objc private func imageSize(){showSize(canvas:false)}
    @objc private func scanDocument() {
        guard let document = documents.active, let window = workspace?.window, window.attachedSheet == nil, scanSheet == nil else { return }
        do {
            let sheet = try ScanController(document: document, pipeline: documents.pipeline, localization: localization)
            scanSheet = sheet
            window.beginSheet(sheet.window!) { [weak self] _ in self?.scanSheet = nil; self?.workspace?.window?.makeFirstResponder(self?.workspace?.workspaceView.canvas) }
        } catch { showImportReport(localization.text("scan.selectImage")) }
    }
    @objc private func scanBatch() {
        showWorkspace()
        guard let window = workspace?.window, window.attachedSheet == nil, scanSheet == nil else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.png,.jpeg,.heic,.heif]; panel.message = localization.text("scan.chooseBatch")
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, !panel.urls.isEmpty, panel.urls.count <= 50 else { return }
            let files = panel.urls
            Task { [weak self] in
                guard let self else { return }
                do {
                    let pipeline = ImagePipeline(), asset = try await pipeline.prepare(.file(files[0]), budget: ImportBudget())
                    let document = PhotoDocument(model: try PhotoDocumentModel(name: asset.name, canvas: asset.descriptor.size, ppi: asset.ppi), localization: localization)
                    try document.place(asset, recordHistory: false)
                    guard window.attachedSheet == nil, scanSheet == nil else { return }
                    let sheet = try ScanController(document: document, pipeline: pipeline, localization: localization, batchFiles: files)
                    scanSheet = sheet
                    window.beginSheet(sheet.window!) { [weak self] _ in self?.scanSheet = nil }
                } catch { showImportReport(localization.text("scan.error")) }
            }
        }
    }
    @objc private func canvasSize(){showSize(canvas:true)}
    private func showSize(canvas:Bool) {
        guard let document=documents.active,!documents.isImporting,document.resolveSession(),let window=workspace?.window,sizeSheet==nil else{return}
        let sheet=DocumentSizeController(document:document,canvas:canvas,localization:localization);sizeSheet=sheet
        window.beginSheet(sheet.window!) { [weak self] _ in self?.sizeSheet=nil;self?.workspace?.window?.makeFirstResponder(self?.workspace?.workspaceView.canvas) }
    }
    @objc private func geometryAction(_ sender:NSMenuItem) {
        guard let document=documents.active,document.resolveSession() else{return}
        do {try document.perform(sender.tag<3 ? .rotateCanvas:.flipCanvas){model in
            if sender.tag<3 {try model.rotateCanvas(quarterTurns:sender.tag+1)}else{try model.flipCanvas(horizontal:sender.tag==3)}
        };document.viewport.fit(document.model.canvas);document.changed?()}catch{NSSound.beep()}
    }
    @objc private func fitCanvas() { workspace?.workspaceView.canvas.fit() }
    @objc private func actualPixels() { workspace?.workspaceView.canvas.zoom(to: 1) }
    @objc private func zoomIn() { if let zoom = documents.active?.viewport.zoom { workspace?.workspaceView.canvas.zoom(to: zoom * 2) } }
    @objc private func zoomOut() { if let zoom = documents.active?.viewport.zoom { workspace?.workspaceView.canvas.zoom(to: zoom / 2) } }

    @objc private func showSettings() {
        if settings == nil {
            settings = SettingsWindowController(preferences: preferences, localization: localization, launchLanguage: launchLanguage)
            settings?.layoutChanged = { [weak self] in self?.workspace?.reloadLayout() }
        }
        if settings?.window?.isVisible != true { settings?.refreshLayoutControls() }
        settings?.showWindow(nil)
        settings?.window?.makeKeyAndOrderFront(nil)
    }
    @objc private func resetWorkspace() { workspace?.resetWorkspace(); settings?.refreshLayoutControls() }
    @objc private func togglePanels() { workspace?.togglePanel() }
    @objc private func toggleTools() { workspace?.toggleToolsColumns() }
    @objc private func toggleChrome() { workspace?.toggleChrome() }
    @objc private func toggleRulers() { workspace?.toggleRulers() }
    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = localization.text("help.title")
        alert.informativeText = localization.text("help.body")
        alert.addButton(withTitle: localization.text("action.close"))
        alert.runModal()
    }

    private var editingText: Bool { NSApp.keyWindow?.firstResponder is NSTextView }
    @objc private func undoAction() {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView { editor.undoManager?.undo(); return }
        guard let document = documents.active, document.resolveSession() else { return }
        document.jumpHistory(to: max(0,document.history.cursor-1))
    }
    @objc private func redoAction() {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView { editor.undoManager?.redo(); return }
        guard let document = documents.active, document.resolveSession() else { return }
        document.jumpHistory(to: min(document.history.entries.count,document.history.cursor+1))
    }
    @objc private func duplicateLayer() {
        guard !editingText, let document = documents.active, document.resolveSession() else { return }
        do { try document.duplicateSelected() } catch { NSSound.beep() }
    }
    @objc private func deleteLayer() {
        guard !editingText, let document = documents.active, document.resolveSession() else { return }
        do { try document.deleteSelected() } catch { NSSound.beep() }
    }
    @objc private func transformLayer() {
        guard !editingText, let document = documents.active else { return }
        workspace?.workspaceView.canvas.selectTool(.move)
        do { try document.startTransform(); workspace?.window?.makeFirstResponder(workspace?.workspaceView.canvas) } catch { NSSound.beep() }
    }

    @objc private func editType(){guard let id=documents.active?.selectedLayerID else{return};workspace?.workspaceView.canvas.contentEditing.edit(id)}
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(scanDocument) {
            guard let document = documents.active, let layer = document.selectedLayer, case .image = layer.content else { return false }
            return !layer.isLocked && !document.isInteractionLocked && workspace?.window?.attachedSheet == nil
        }
        if menuItem.action == #selector(scanBatch) { return !documents.isImporting && workspace?.window?.attachedSheet == nil }
        if documents.isClosing || workspace?.window?.attachedSheet != nil { return false }
        switch menuItem.action {
        case #selector(saveProject), #selector(saveProjectAs), #selector(exportImage): return documents.active != nil && !documents.isImporting && !documents.isSaving && !documents.isClosing && exportSheet == nil
        case #selector(undoAction):
            let manager = editingText ? NSApp.keyWindow?.firstResponder?.undoManager : documents.active?.undoManager
            menuItem.title = manager?.canUndo == true ? String(format: localization.text("action.undoNamed"), manager!.undoActionName) : localization.text("action.undo")
            return manager?.canUndo == true && !documents.isImporting
        case #selector(redoAction):
            let manager = editingText ? NSApp.keyWindow?.firstResponder?.undoManager : documents.active?.undoManager
            menuItem.title = manager?.canRedo == true ? String(format: localization.text("action.redoNamed"), manager!.redoActionName) : localization.text("action.redo")
            return manager?.canRedo == true && !documents.isImporting
        case #selector(editType):return documents.active?.selectedLayer?.content.isText==true && documents.active?.canEditSelection==true
        case #selector(imageSize),#selector(canvasSize),#selector(geometryAction(_:)):return documents.active != nil && !documents.isImporting
        case #selector(duplicateLayer): return !editingText && documents.active?.selectedLayer != nil && !documents.isImporting && (documents.active?.model.layers.count ?? 50) < 50
        case #selector(deleteLayer), #selector(transformLayer): return !editingText && documents.active?.canEditSelection == true

        case #selector(togglePanels): menuItem.state = preferences.layout.panelCollapsed ? .off : .on
        case #selector(toggleTools): menuItem.state = preferences.layout.toolColumns == 2 ? .on : .off
        case #selector(toggleRulers): menuItem.state = preferences.layout.rulersVisible ? .on : .off
        case #selector(toggleChrome): menuItem.state = workspace?.workspaceView.chromeHidden == true ? .off : .on
        case #selector(placeImages): return documents.active != nil && !documents.isImporting
        case #selector(openImages): return !documents.isImporting
        case #selector(makeDocument): return documents.documents.count < DocumentLimits.maximumDocuments
        case #selector(fitCanvas), #selector(actualPixels), #selector(zoomIn), #selector(zoomOut): return documents.active != nil
        default: break
        }
        return true
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        func submenu(_ key: String) -> NSMenu {
            let title = key == "PhotoAxis" ? key : localization.text(key)
            let child = NSMenu(title: title)
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = child; menu.addItem(item)
            return child
        }
        func item(_ parent: NSMenu, _ key: String, _ action: Selector?, _ shortcut: String = "",
                  modifiers: NSEvent.ModifierFlags = [.command], owned: Bool = false) {
            let entry = parent.addItem(withTitle: localization.text(key), action: action, keyEquivalent: shortcut)
            entry.keyEquivalentModifierMask = modifiers
            if owned { entry.target = self }
            if action == nil { entry.isEnabled = false; entry.toolTip = localization.text("feature.unavailable") }
        }
        let app = submenu("PhotoAxis")
        item(app, "menu.about", #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        app.addItem(.separator())
        item(app, "menu.settings", #selector(showSettings), ",", owned: true)
        app.addItem(.separator())
        item(app, "menu.hide", #selector(NSApplication.hide(_:)), "h")
        item(app, "menu.quit", #selector(NSApplication.terminate(_:)), "q")
        let file = submenu("menu.file")
        item(file, "action.new", #selector(makeDocument), "n", owned: true)
        item(file, "action.open", #selector(openImages), "o", owned: true)
        item(file, "action.place", #selector(placeImages), owned: true)
        file.addItem(.separator())
        item(file, "action.save", #selector(saveProject), "s", owned:true)
        item(file, "action.saveAs", #selector(saveProjectAs), "s", modifiers: [.command, .shift], owned:true)
        item(file, "action.export", #selector(exportImage), "s", modifiers: [.command, .shift, .option], owned:true)
        item(file, "action.recovery", nil)
        file.addItem(.separator())
        item(file, "menu.close", #selector(closeDocument), "w", owned: true)
        let edit = submenu("menu.edit")
        item(edit, "action.undo", #selector(undoAction), "z", owned: true); item(edit, "action.redo", #selector(redoAction), "z", modifiers: [.command, .shift], owned: true)
        edit.addItem(.separator())
        item(edit, "action.cut", #selector(NSText.cut(_:)), "x")
        item(edit, "action.copy", #selector(NSText.copy(_:)), "c")
        item(edit, "action.paste", #selector(NSText.paste(_:)), "v")
        item(edit, "action.selectAll", #selector(NSText.selectAll(_:)), "a")
        let image = submenu("menu.image")
        item(image,"image.size",#selector(imageSize),owned:true);item(image,"image.canvasSize",#selector(canvasSize),owned:true)
        item(image,"scan.title",#selector(scanDocument),owned:true);item(image,"scan.batch",#selector(scanBatch),owned:true)
        for (tag,key) in ["image.rotate90","image.rotate180","image.rotate270","image.flipH","image.flipV"].enumerated() {
            item(image,key,#selector(geometryAction(_:)),owned:true);image.items.last?.tag=tag
        }
        let layer = submenu("menu.layer")
        item(layer, "layer.duplicate", #selector(duplicateLayer), "j", owned: true); item(layer, "layer.delete", #selector(deleteLayer), owned: true)
        item(layer, "layer.transform", #selector(transformLayer), "t", owned: true)
        let type = submenu("menu.type")
        item(type,"type.edit",#selector(editType)); for key in ["type.font", "type.size"] { item(type,key,#selector(editType)) }
        let view = submenu("menu.view")
        item(view, "view.fit", #selector(fitCanvas), "0", owned: true); item(view, "view.actual", #selector(actualPixels), "1", owned: true)
        item(view, "view.zoomIn", #selector(zoomIn), "+", owned: true); item(view, "view.zoomOut", #selector(zoomOut), "-", owned: true)
        view.addItem(.separator())
        item(view, "view.rulers", #selector(toggleRulers), "r", owned: true)
        item(view, "workspace.showChrome", #selector(toggleChrome), owned: true)
        let window = submenu("menu.window")
        item(window, "workspace.showPanels", #selector(togglePanels), owned: true)
        item(window, "tools.twoColumns", #selector(toggleTools), owned: true)
        item(window, "workspace.reset", #selector(resetWorkspace), owned: true)
        window.addItem(.separator())
        item(window, "menu.minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        NSApp.windowsMenu = window
        let help = submenu("menu.help")
        item(help, "help.title", #selector(showHelp), owned: true)
        NSApp.helpMenu = help
        return menu
    }
}

import AppKit
import PhotoAxisCore

@MainActor
final class WorkspaceWindowController: NSWindowController {
    let workspaceView: WorkspaceView
    let preferences: WorkspacePreferences
    var stateChanged: (() -> Void)?

    init(preferences: WorkspacePreferences, localization: L10n, restoreFrame: Bool = true) {
        self.preferences = preferences
        workspaceView = WorkspaceView(preferences: preferences, localization: localization)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 778),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "PhotoAxis"
        window.identifier = .init("workspace.window")
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 1100, height: 700)
        window.isReleasedWhenClosed = false
        window.backgroundColor = WorkspaceStyle.canvas
        window.contentView = workspaceView
        window.setFrame(NSRect(x: 0, y: 0, width: 1280, height: 800), display: false)
        window.center()
        if restoreFrame { window.setFrameAutosaveName("PhotoAxis.Workspace") }
        super.init(window: window)
        workspaceView.layoutChanged = { [weak self] in self?.stateChanged?() }
    }
    required init?(coder: NSCoder) { fatalError("Use init(preferences:localization:)") }

    func reloadLayout() { workspaceView.updatePresentationPreferences(); workspaceView.needsLayout = true; workspaceView.layoutSubtreeIfNeeded(); stateChanged?() }
    @objc func resetWorkspace() { preferences.resetPresentation(); workspaceView.chromeHidden = false; reloadLayout() }
    @objc func toggleToolsColumns() {
        var layout = preferences.layout; layout.toolColumns = layout.toolColumns == 1 ? 2 : 1; preferences.layout = layout
        reloadLayout()
    }
    @objc func togglePanel() {
        var layout = preferences.layout; layout.panelCollapsed.toggle(); preferences.layout = layout
        workspaceView.chromeHidden = false; reloadLayout()
    }
    @objc func toggleRulers() {
        var layout = preferences.layout; layout.rulersVisible.toggle(); preferences.layout = layout; reloadLayout()
    }
    @objc func toggleChrome() { workspaceView.chromeHidden.toggle(); reloadLayout() }
}

@MainActor
final class WorkspaceView: SurfaceView {
    private(set) var presentation: NSView?
    let presentationHost = SurfaceView()
    let returnToEditor: NSButton
    private var presentationContext: String?
    var presentationDismissed: (() -> Void)?
    let optionsBar: OptionsBarView
    let tools: ToolsRailView
    let sidebar: SidebarView
    let canvas: WelcomeCanvasView
    let divider = SidebarDivider(frame: .zero)
    let tabBar = DocumentTabsView()
    let statusBar = SurfaceView(color: WorkspaceStyle.panel)
    let horizontalRuler = RulerView(vertical: false)
    let verticalRuler = RulerView(vertical: true)
    let rulerCorner = SurfaceView(color:WorkspaceStyle.toolbar)
    let rulerUnitLabel = WorkspaceStyle.label("px",size:10,secondary:true)
    let restorePanelButton: WorkspaceButton
    private let tabLabel: NSTextField
    private let statusLabel: NSTextField
    private var taskProgress: String?
    let zoomLabel: NSTextField
    let cancelImportButton: NSButton
    private let localization: L10n
    weak var coordinator: DocumentCoordinator?
    private let colorLabel: NSTextField
    private let collapsedRail = SurfaceView(color: WorkspaceStyle.toolbar)
    let preferences: WorkspacePreferences
    var chromeHidden = false { didSet { needsLayout = true } }
    var layoutChanged: (() -> Void)?

    init(preferences: WorkspacePreferences, localization: L10n) {
        self.preferences = preferences
        self.localization = localization
        returnToEditor = NSButton(title: localization.text("workspace.returnEditor"), target: nil, action: nil)
        cancelImportButton = NSButton(title: localization.text("import.cancel"), target: nil, action: nil)
        optionsBar = OptionsBarView(localization: localization)
        tools = ToolsRailView(localization: localization)
        sidebar = SidebarView(localization: localization)
        canvas = WelcomeCanvasView(localization: localization)
        tabLabel = WorkspaceStyle.label(localization.text("workspace.empty"), size: 11, secondary: true)
        statusLabel = WorkspaceStyle.label(localization.text("workspace.empty"), size: 11, secondary: true)
        statusLabel.identifier = .init("workspace.taskStatus")
        zoomLabel = NSTextField(string: "— %")
        zoomLabel.font = .systemFont(ofSize: 11); zoomLabel.isEnabled = false
        zoomLabel.setAccessibilityLabel(localization.text("view.zoom"))
        colorLabel = WorkspaceStyle.label("sRGB", size: 11, secondary: true)
        restorePanelButton = WorkspaceButton(title: localization.text("workspace.expandPanels"), symbol: "chevron.left.2")
        super.init(color: WorkspaceStyle.canvas)
        identifier = .init("workspace.root")
        canvas.toggleChrome = { [weak self] in self?.chromeHidden.toggle(); self?.layoutChanged?() }
        tools.changeColumns = { [weak self] in
            guard let self else { return }
            var layout = preferences.layout; layout.toolColumns = layout.toolColumns == 1 ? 2 : 1
            preferences.layout = layout; needsLayout = true; layoutChanged?()
        }
        sidebar.collapse = { [weak self] in self?.setCollapsed(true) }
        restorePanelButton.target = self; restorePanelButton.action = #selector(expandPanel)
        restorePanelButton.toolTip = localization.text("workspace.expandPanels")
        divider.setAccessibilityLabel(localization.text("settings.panelWidth"))
        divider.setAccessibilityElement(true)
        divider.toolTip = localization.text("workspace.resizeHelp")
        divider.resize = { [weak self] width in
            guard let self else { return }
            var layout = preferences.layout; layout.panelWidth = width; preferences.layout = layout
            needsLayout = true; layoutChanged?()
        }
        for child in [optionsBar, tools, canvas, tabBar, statusBar, horizontalRuler, verticalRuler, rulerCorner, sidebar, divider, collapsedRail] { addSubview(child) }
        rulerCorner.addSubview(rulerUnitLabel); rulerUnitLabel.alignment = .center
        updatePresentationPreferences()
        presentationHost.isHidden = true; addSubview(presentationHost)
        returnToEditor.target = self; returnToEditor.action = #selector(dismissPresentation)
        returnToEditor.setAccessibilityIdentifier("workspace.returnEditor")
        presentationHost.addSubview(returnToEditor)
        tabBar.addSubview(tabLabel)
        zoomLabel.target = self; zoomLabel.action = #selector(changeZoom)
        cancelImportButton.target = self; cancelImportButton.action = #selector(cancelImport)
        cancelImportButton.bezelStyle = .rounded; cancelImportButton.isHidden = true
        optionsBar.paintSettingsChanged = { [weak self] in
            if let self, let p = canvas.paintCursor.point { canvas.painting.cursor(p) }
        }
        optionsBar.paintAlignmentChanged = { [weak self] in self?.canvas.painting.resetAlignment() }
        optionsBar.focusCanvas = { [weak self] in self?.window?.makeFirstResponder(self?.canvas) }
        optionsBar.fitCanvas = { [weak canvas] in canvas?.fit() }
        optionsBar.actualPixels = { [weak canvas] in canvas?.zoom(to: 1) }
        sidebar.editContent={ [weak self] id in self?.canvas.contentEditing.edit(id) }
        canvas.contentEditing.focusProperties={ [weak self] in
            guard let self else{return};sidebar.showPage(0);sidebar.inspectorTabs.selectedSegment=0;sidebar.changeInspector()
            if preferences.layout.panelCollapsed{setCollapsed(false);layoutSubtreeIfNeeded()}
            layoutSubtreeIfNeeded()
            sidebar.contentControls.focusContentEditor()
        }
        sidebar.contentControls.propertiesEditor.focusCanvas={ [weak self] in self?.window?.makeFirstResponder(self?.canvas) }
        canvas.viewportChanged = { [weak self] in self?.updateNavigation() }
        for child in [zoomLabel, statusLabel, colorLabel, cancelImportButton] { statusBar.addSubview(child) }
        collapsedRail.addSubview(restorePanelButton)
    }
    required init?(coder: NSCoder) { fatalError("Use init(preferences:localization:)") }
    func refreshDocuments(_ coordinator: DocumentCoordinator) {
        self.coordinator = coordinator
        if let presentationContext, presentationContext != contextKey { dismissPresentation() }
        tabBar.update(coordinator.documents, activeID: coordinator.activeID, localization: localization)
        tabLabel.isHidden = !coordinator.documents.isEmpty
        canvas.display(coordinator.active, pipeline: coordinator.pipeline)
        sidebar.display(coordinator.active, pipeline: coordinator.pipeline)
        tools.updateNavigationTools(coordinator.active?.activeTool);tools.displayColors(coordinator.active)
        optionsBar.display(coordinator.active)
        updateNavigation()
    }
    private var contextKey: String {
        guard let document = coordinator?.active else { return "none" }
        return document.model.id.uuidString + InvestigationDigest.hash((try? ProjectSchema(document.model).encoded()) ?? Data())
    }
    func showPresentation(_ view: NSView) {
        presentation?.removeFromSuperview(); presentation = view; presentationContext = contextKey
        view.frame = NSRect(x: 0, y: 36, width: canvas.frame.width, height: max(0, canvas.frame.height - 36))
        presentationHost.addSubview(view); presentationHost.isHidden = false; canvas.isHidden = true
        needsLayout = true; layoutSubtreeIfNeeded(); window?.makeFirstResponder(view)
    }
    @objc func dismissPresentation() {
        presentation?.removeFromSuperview(); presentation = nil; presentationContext = nil
        presentationHost.isHidden = true; canvas.isHidden = false; presentationDismissed?()
        window?.makeFirstResponder(canvas)
    }
    func revealPanel(_ page: Int) {
        chromeHidden = false; setCollapsed(false); sidebar.showPage(page); layoutSubtreeIfNeeded()
    }
    func updateNavigation() {
        let document = coordinator?.active
        zoomLabel.isEnabled = document != nil
        if window?.firstResponder !== window?.fieldEditor(false, for: zoomLabel) {
            zoomLabel.stringValue = document.map { DocumentNumber.format($0.viewport.zoom * 100, language: Locale.current.identifier) + " %" } ?? "— %"
        }
        horizontalRuler.viewport = document?.viewport; verticalRuler.viewport = document?.viewport
        horizontalRuler.ppi = document?.presentedModel.ppi ?? 72; verticalRuler.ppi = horizontalRuler.ppi
        if let taskProgress {
            statusLabel.stringValue = taskProgress
        } else {
            statusLabel.stringValue = document.map { String(format: localization.text("document.status"), locale: Locale.current, $0.model.canvas.width, $0.model.canvas.height, $0.model.ppi, localization.text($0.isDocumentEdited ? "document.unsaved" : "document.saved")) } ?? localization.text("workspace.empty")
        }
    }
    func setImportProgress(_ message: String?) {
        taskProgress = message
        cancelImportButton.isHidden = message == nil
        if let message { statusLabel.stringValue = message; statusLabel.toolTip = message } else { statusLabel.toolTip = nil; updateNavigation() }
    }
    @objc private func cancelImport() { coordinator?.cancelImport() }
    @objc private func changeZoom() {
        guard let value = DocumentNumber.parse(zoomLabel.stringValue, language: Locale.current.identifier), (5...1600).contains(value) else {
            zoomLabel.toolTip = localization.text("document.invalidZoom"); NSSound.beep(); return
        }
        canvas.zoom(to: value / 100); window?.makeFirstResponder(canvas); updateNavigation()
    }
    @objc private func expandPanel() { setCollapsed(false) }
    private func setCollapsed(_ collapsed: Bool) {
        var layout = preferences.layout; layout.panelCollapsed = collapsed; preferences.layout = layout
        needsLayout = true; layoutChanged?()
    }

    func updatePresentationPreferences() {
        horizontalRuler.unit = preferences.rulerUnit; verticalRuler.unit = preferences.rulerUnit
        rulerUnitLabel.stringValue = preferences.rulerUnit.rawValue
        rulerUnitLabel.toolTip = localization.text("settings.rulerHelp")
        canvas.canvasAppearance = preferences.canvasAppearance
    }

    override func layout() {
        super.layout()
        guard bounds.width >= 100, bounds.height >= 100 else { return }
        let layout = preferences.layout
        let toolWidth: CGFloat = chromeHidden ? 0 : layout.toolColumns == 2 ? 72 : 44
        let sidebarWidth: CGFloat = chromeHidden ? 0 : layout.panelCollapsed ? 28 : layout.panelWidth
        let dividerWidth: CGFloat = chromeHidden || layout.panelCollapsed ? 0 : 5
        let centerWidth = bounds.width - toolWidth - sidebarWidth - dividerWidth
        let bottom = bounds.height - 24
        optionsBar.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 36)
        tools.frame = NSRect(x: 0, y: 36, width: toolWidth, height: bottom - 36)
        tools.columnCount = layout.toolColumns; tools.isHidden = chromeHidden
        sidebar.isHidden = chromeHidden || layout.panelCollapsed
        sidebar.frame = NSRect(x: bounds.width - sidebarWidth, y: 36, width: sidebarWidth, height: bottom - 36)
        divider.isHidden = chromeHidden || layout.panelCollapsed
        divider.frame = NSRect(x: sidebar.frame.minX - dividerWidth, y: 36, width: dividerWidth, height: bottom - 36)
        divider.currentWidth = layout.panelWidth
        collapsedRail.isHidden = chromeHidden || !layout.panelCollapsed
        collapsedRail.frame = NSRect(x: bounds.width - sidebarWidth, y: 36, width: sidebarWidth, height: bottom - 36)
        restorePanelButton.frame = NSRect(x: 1, y: 2, width: 26, height: 26)
        tabBar.frame = NSRect(x: toolWidth, y: 36, width: centerWidth, height: 28)
        tabBar.layoutSubtreeIfNeeded()
        tabLabel.frame = NSRect(x: 14, y: 6, width: max(0, centerWidth - 28), height: 18)
        let rulerWidth = layout.rulersVisible ? RulerView.verticalWidth : 0
        let rulerHeight = layout.rulersVisible ? RulerView.horizontalHeight : 0
        horizontalRuler.isHidden = !layout.rulersVisible; verticalRuler.isHidden = !layout.rulersVisible; rulerCorner.isHidden = !layout.rulersVisible
        horizontalRuler.frame = NSRect(x:toolWidth+rulerWidth,y:64,width:max(0,centerWidth-rulerWidth),height:rulerHeight)
        verticalRuler.frame = NSRect(x:toolWidth,y:64+rulerHeight,width:rulerWidth,height:max(0,bottom-64-rulerHeight))
        rulerCorner.frame = NSRect(x:toolWidth,y:64,width:rulerWidth,height:rulerHeight)
        rulerUnitLabel.frame = NSRect(x:4,y:5,width:max(0,rulerWidth-8),height:18)
        canvas.frame = NSRect(x:toolWidth+rulerWidth,y:64+rulerHeight,width:max(0,centerWidth-rulerWidth),height:max(0,bottom-64-rulerHeight))
        presentationHost.frame = canvas.frame
        returnToEditor.frame = NSRect(x: 8, y: 4, width: max(180, returnToEditor.intrinsicContentSize.width), height: 28)
        presentation?.frame = NSRect(x: 0, y: 36, width: canvas.frame.width, height: max(0, canvas.frame.height - 36))
        statusBar.frame = NSRect(x: 0, y: bottom, width: bounds.width, height: 24)
        zoomLabel.frame = NSRect(x: toolWidth + 8, y: 2, width: 75, height: 21)
        statusLabel.frame = NSRect(x: toolWidth + 95, y: 4, width: max(0, bounds.width - toolWidth - 310), height: 17)
        cancelImportButton.frame = NSRect(x: bounds.width - 210, y: 0, width: 145, height: 24)
        colorLabel.frame = NSRect(x: bounds.width - 55, y: 4, width: 44, height: 17)
    }
}

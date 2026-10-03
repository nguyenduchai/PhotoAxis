import AppKit
import PhotoAxisCore

@MainActor
final class ColorPreviewView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(colors: [.white, NSColor(srgbRed: 0.18, green: 0.43, blue: 0.64, alpha: 1)])?.draw(in: bounds, angle: 0)
        NSGradient(starting: .clear, ending: .black)?.draw(in: bounds, angle: -90)
    }
}

@MainActor
final class SidebarView: SurfaceView {
    let pageSelector = NSPopUpButton()
    private(set) var pageButtons: [NSButton] = []
    let pageHelp = NSTextField(wrappingLabelWithString: "")
    private let headerHeight: CGFloat = 100
    private let editingBody = SurfaceView()
    private var pages: [NSView] = []
    var pageChanged: ((Int) -> Void)?
    var selectedPage: Int { pageSelector.indexOfSelectedItem }
    let collapseButton: WorkspaceButton
    let inspectorTabs: NSSegmentedControl
    let inspectorMessage: NSTextField
    var collapse: (() -> Void)?
    var placeImage: (() -> Void)?
    private let localization: L10n
    private let colorTitle: NSTextField
    private let colorPreview = ColorPreviewView()
    let colorControls:ColorControlsView
    let contentControls:ContentControlsView
    let adjustmentControls:AdjustmentControlsView
    var editContent:((UUID)->Void)?
    private let colorFields: [NSView]
    private let layersTitle: NSTextField
    let layerList = LayerSelectionList(frame: .zero)
    private var document: PhotoDocument?
    private let layersMessage: NSTextField
    private let blend = NSPopUpButton()
    private let opacityTitle: NSTextField
    private let opacity = NSTextField(string: "100 %")
    let opacitySlider = TransactionSlider()
    let historyList = HistoryListView(frame: .zero)
    private let layerActions: [NSButton]
    private var ownsOpacitySession = false
    private var dividerY: [CGFloat] = []

    init(localization: L10n) {
        self.localization = localization
        adjustmentControls=AdjustmentControlsView(localization:localization);colorControls=ColorControlsView(localization:localization);contentControls=ContentControlsView(localization:localization)
        colorTitle = WorkspaceStyle.label(localization.text("panel.color"))
        layersTitle = WorkspaceStyle.label(localization.text("panel.layers"))
        collapseButton = WorkspaceButton(title: localization.text("workspace.collapsePanels"), symbol: "chevron.right.2")
        inspectorTabs = NSSegmentedControl(labels: [localization.text("panel.properties"), localization.text("panel.history")], trackingMode: .selectOne, target: nil, action: nil)
        inspectorMessage = NSTextField(wrappingLabelWithString: localization.text("panel.noLayer"))
        layersMessage = NSTextField(wrappingLabelWithString: localization.text("panel.noLayers"))
        opacityTitle = WorkspaceStyle.label(localization.text("layer.opacity"), size: 11)
        colorFields = ["R", "G", "B"].flatMap { channel -> [NSView] in
            let field = NSTextField(string: "0")
            field.isEnabled = false; field.font = .systemFont(ofSize: 11)
            field.setAccessibilityLabel(localization.text("color." + channel))
            return [WorkspaceStyle.label(channel, size: 11), field]
        }
        layerActions = [("layer.add", "plus"), ("layer.rename", "pencil"), ("layer.up", "arrow.up"), ("layer.down", "arrow.down"), ("layer.duplicate", "square.on.square"), ("layer.delete", "trash")].map { key, symbol in
            let button = WorkspaceButton(title: localization.text(key), symbol: symbol)
            button.isEnabled = false; button.toolTip = localization.text("feature.noDocument")
            return button
        }
        super.init()
        identifier = .init("workspace.sidebar")
        contentControls.editContent={ [weak self] id in self?.editContent?(id) }
        layerList.editContent={ [weak self] id in self?.editContent?(id) }
        addSubview(editingBody)
        pageSelector.addItems(withTitles: ["workspace.edit", "workspace.sources", "workspace.analysis", "workspace.output"].map { localization.text($0) })
        pageSelector.target = self; pageSelector.action = #selector(selectPage)
        pageSelector.setAccessibilityIdentifier("workspace.panelPage")
        pageSelector.isHidden = true
        for (i,key) in ["workspace.edit","workspace.sources","workspace.analysis","workspace.output"].enumerated() {
            let button = NSButton(title:localization.text(key),target:self,action:#selector(selectPageButton(_:)))
            button.tag = i; button.bezelStyle = .regularSquare; button.setButtonType(.pushOnPushOff)
            button.font = .systemFont(ofSize:11,weight:.medium)
            button.image = NSImage(systemSymbolName:["slider.horizontal.3","tray.full","viewfinder","square.and.arrow.up"][i],accessibilityDescription:nil)
            button.imagePosition = .imageLeading; button.imageScaling = .scaleProportionallyDown
            button.identifier = .init("workspace.page."+["edit","sources","analysis","output"][i])
            button.setAccessibilityLabel(localization.text(key)); pageButtons.append(button); addSubview(button)
        }
        pageHelp.font = .systemFont(ofSize:10); pageHelp.textColor = .secondaryLabelColor
        pageHelp.identifier = .init("workspace.pageHelp"); addSubview(pageHelp)
        showPage(0)
        editingBody.addSubview(colorControls);editingBody.addSubview(contentControls);editingBody.addSubview(adjustmentControls)
        layerList.isHidden = true; historyList.isHidden = true
        for (index, button) in layerActions.enumerated() { button.tag = index; button.target = self; button.action = #selector(layerAction(_:)) }
        opacity.target = self; opacity.action = #selector(changeOpacity)
        opacitySlider.minValue = 0; opacitySlider.maxValue = 100; opacitySlider.isContinuous = true
        opacitySlider.target = self; opacitySlider.action = #selector(slideOpacity)
        opacitySlider.setAccessibilityLabel(localization.text("layer.opacity"))
        opacitySlider.begin = { [weak self] in self?.beginOpacity() }
        opacitySlider.end = { [weak self] in
            guard let self, ownsOpacitySession else { return }
            ownsOpacitySession = false; document?.applySession()
        }
        collapseButton.target = self; collapseButton.action = #selector(collapsePanels)
        collapseButton.identifier = .init("sidebar.collapse")
        collapseButton.toolTip = localization.text("workspace.collapsePanels")
        inspectorTabs.target = self; inspectorTabs.action = #selector(changeInspector)
        inspectorTabs.selectedSegment = 0; inspectorTabs.segmentStyle = .texturedSquare
        inspectorTabs.controlSize = .small
        inspectorTabs.setAccessibilityLabel(localization.text("panel.inspector"))
        inspectorTabs.identifier = .init("sidebar.inspectorTabs")
        for message in [inspectorMessage, layersMessage] {
            message.font = .systemFont(ofSize: 12); message.textColor = .secondaryLabelColor
            message.alignment = .center
        }
        colorPreview.isHidden=true;colorFields.forEach{$0.isHidden=true}
        colorPreview.setAccessibilityElement(false)
        colorPreview.setAccessibilityRole(.image)
        colorPreview.setAccessibilityLabel(localization.text("color.preview"))
        colorPreview.toolTip = localization.text("feature.unavailable")
        blend.addItem(withTitle: localization.text("layer.normal")); blend.isEnabled = false
        blend.controlSize = .small; blend.setAccessibilityLabel(localization.text("layer.blendMode"))
        opacity.isEnabled = false; opacity.font = .systemFont(ofSize: 11)
        opacity.setAccessibilityLabel(localization.text("layer.opacity"))
        for child in [colorTitle, collapseButton, colorPreview, inspectorTabs, inspectorMessage,
                      layersTitle, layersMessage, layerList, historyList, blend, opacityTitle, opacity, opacitySlider] + colorFields + layerActions { editingBody.addSubview(child) }
    }
    required init?(coder: NSCoder) { fatalError("Use init(localization:)") }
    func installPages(_ views: [NSView]) {
        pages.forEach { $0.removeFromSuperview() }; pages = views
        for page in pages { addSubview(page) }; showPage(selectedPage)
    }
    func showPage(_ index: Int) {
        guard (0...pages.count).contains(index) else { return }
        pageSelector.selectItem(at: index); editingBody.isHidden = index != 0
        for (i,button) in pageButtons.enumerated() { button.state = i == index ? .on:.off }
        pageHelp.stringValue = localization.text(["workspace.editHelp","workspace.sourcesHelp","workspace.analysisHelp","workspace.outputHelp"][index])
        for (i, page) in pages.enumerated() { page.isHidden = index != i + 1 }
        needsLayout = true
    }
    @objc private func selectPage() { showPage(selectedPage); pageChanged?(selectedPage) }
    @objc func selectPageButton(_ sender: NSButton) {
        let old = selectedPage; showPage(sender.tag)
        if selectedPage != old { pageChanged?(selectedPage) }
    }
    @objc private func collapsePanels() { collapse?() }
    @objc func changeInspector() {
        historyList.isHidden = document == nil || inspectorTabs.selectedSegment != 1
        inspectorMessage.isHidden = !historyList.isHidden
        if let document, inspectorTabs.selectedSegment == 0 {
            inspectorMessage.stringValue = String(format: localization.text("document.properties"), locale: Locale.current, document.model.canvas.width, document.model.canvas.height, document.model.ppi, document.model.layers.count)
        } else { inspectorMessage.stringValue = localization.text(inspectorTabs.selectedSegment == 0 ? "panel.noLayer" : "panel.noHistory") }
        contentControls.refresh(document)
        if inspectorTabs.selectedSegment==1{contentControls.isHidden=true}
        adjustmentControls.refresh(document)
        if inspectorTabs.selectedSegment==1 || !contentControls.isHidden {adjustmentControls.isHidden=true}
        if !contentControls.isHidden || !adjustmentControls.isHidden{inspectorMessage.isHidden=true}
    }

    func display(_ document: PhotoDocument?, pipeline: ImagePipeline? = nil) {
        self.document = document;colorControls.refresh(document); layerList.update(document, localization: localization, pipeline: pipeline)
        historyList.update(document, localization: localization)
        let editable = document?.canEditSelection == true
        opacity.isEnabled = editable; if !opacitySlider.trackingGesture {opacitySlider.isEnabled = editable}
        if opacity.currentEditor() == nil { opacity.stringValue = DocumentNumber.format((document?.selectedLayer?.opacity ?? 1) * 100, language: Locale.current.identifier) + " %" }
        if !opacitySlider.trackingGesture {opacitySlider.doubleValue = (document?.selectedLayer?.opacity ?? 1) * 100}
        for (index, button) in layerActions.enumerated() {
            button.isEnabled = document != nil && document?.isInteractionLocked == false && (index == 0 || (index == 4 ? document?.selectedLayer != nil : editable))
        }
        layerList.isHidden = document == nil || document?.model.layers.isEmpty == true
        layersMessage.isHidden = !layerList.isHidden
        for button in layerActions { button.toolTip = button.isEnabled ? button.accessibilityLabel() : localization.text(document == nil ? "feature.noDocument" : "layer.invalid") }
        changeInspector()
    }
    private func beginOpacity() {
        ownsOpacitySession = false
        guard let document, document.resolveSession() else { return }
        do { try document.beginSession(.opacity); ownsOpacitySession = true } catch { NSSound.beep() }
    }
    @objc private func slideOpacity() {
        guard let document else { return }
        let value = opacitySlider.doubleValue / 100
        if !opacitySlider.trackingGesture { beginOpacity() }
        guard ownsOpacitySession, document.toolSession?.command == .opacity else { return }
        do {
            try document.preview { try $0.setOpacity($1, value) }
            if !opacitySlider.trackingGesture { ownsOpacitySession = false; document.applySession() }
        } catch { NSSound.beep() }
    }
    @objc private func changeOpacity() {
        guard let value = DocumentNumber.parse(opacity.stringValue, language: Locale.current.identifier), (0...100).contains(value),
              let document, let id = document.selectedLayerID, document.resolveSession() else { NSSound.beep(); return }
        do { try document.perform(.opacity) { try $0.setOpacity(id,value/100) } } catch { NSSound.beep() }
    }
    @objc private func layerAction(_ sender:NSButton) {
        guard let document, document.resolveSession() else { return }
        do {
            switch sender.tag {
            case 0: placeImage?()
            case 1: layerList.renameSelected()
            case 2,3:
                guard let id = document.selectedLayerID, let old = document.model.layers.firstIndex(where:{$0.id==id}) else {return}
                let next = min(document.model.layers.count-1,max(0,old+(sender.tag==2 ? 1 : -1)))
                try document.perform(.reorder) { try $0.reorder(id,to:next) }
            case 4: try document.duplicateSelected()
            case 5: try document.deleteSelected()
            default: break
            }
        } catch { NSSound.beep() }
    }
    override func layout() {
        super.layout()
        guard bounds.width >= 100, bounds.height >= 100 else { return }
        let buttonWidth = (bounds.width-22)/2
        for (i,button) in pageButtons.enumerated() {
            button.frame = NSRect(x:8+CGFloat(i%2)*(buttonWidth+6),y:4+CGFloat(i/2)*29,width:buttonWidth,height:26)
        }
        pageHelp.frame = NSRect(x:10,y:64,width:bounds.width-20,height:32)
        editingBody.frame = NSRect(x:0,y:headerHeight,width:bounds.width,height:bounds.height-headerHeight)
        for page in pages { page.frame = editingBody.frame }
        let width = editingBody.bounds.width, height = editingBody.bounds.height
        let colorHeight: CGFloat = 168
        let inspectorHeight = max(150, (height - colorHeight) * 0.44)
        let layerY = colorHeight + inspectorHeight
        dividerY = [28, colorHeight, layerY, layerY + 28, height - 30]
        colorTitle.frame = NSRect(x: 12, y: 6, width: width - 52, height: 18)
        collapseButton.frame = NSRect(x: width - 30, y: 1, width: 26, height: 25)
        colorControls.frame=NSRect(x:12,y:36,width:width-24,height:126)
        contentControls.frame=NSRect(x:8,y:colorHeight+34,width:width-16,height:inspectorHeight-40)
        adjustmentControls.frame=contentControls.frame
        colorPreview.frame = NSRect(x: 12, y: 39, width: width - 24, height: 98)
        for channel in 0..<3 {
            let x = 12 + CGFloat(channel) * (width - 24) / 3
            colorFields[channel * 2].frame = NSRect(x: x, y: 150, width: 14, height: 18)
            colorFields[channel * 2 + 1].frame = NSRect(x: x + 16, y: 147, width: (width - 24) / 3 - 22, height: 22)
        }
        inspectorTabs.frame = NSRect(x: 6, y: colorHeight + 4, width: width - 12, height: 26)
        inspectorMessage.frame = NSRect(x: 20, y: colorHeight + 70, width: width - 40, height: 64)
        historyList.frame = NSRect(x: 8,y: colorHeight + 34,width: width - 16,height: inspectorHeight - 40)
        layersTitle.frame = NSRect(x: 12, y: layerY + 6, width: width - 24, height: 18)
        let opacityWidth = max(50, opacityTitle.intrinsicContentSize.width)
        blend.frame = NSRect(x: 8, y: layerY + 35, width: width - opacityWidth - 80, height: 24)
        opacityTitle.frame = NSRect(x: blend.frame.maxX + 4, y: layerY + 40, width: opacityWidth, height: 18)
        opacity.frame = NSRect(x: width - 62, y: layerY + 36, width: 54, height: 22)
        opacitySlider.frame = NSRect(x: 12,y: layerY + 62,width: width-24,height: 18)
        layerList.frame = NSRect(x: 8, y: layerY + 84, width: width - 16, height: max(0, height - layerY - 118))
        layersMessage.frame = NSRect(x: 20, y: layerY + 90, width: width - 40, height: 58)
        for (index, button) in layerActions.enumerated() {
            button.frame = NSRect(x: width - CGFloat(layerActions.count - index) * 32 - 8, y: height - 28, width: 28, height: 26)
        }
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        WorkspaceStyle.divider.setFill()
        for y in (selectedPage == 0 ? dividerY : []) { NSRect(x: 0, y: y + headerHeight, width: bounds.width, height: 1).fill() }
    }
}

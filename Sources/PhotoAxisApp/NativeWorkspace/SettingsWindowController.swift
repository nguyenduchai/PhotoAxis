import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    let preferences: WorkspacePreferences
    let localization: L10n
    let languagePopup = NSPopUpButton(frame:.zero,pullsDown:false)
    let widthField = NSTextField(string:"")
    let columns = NSSegmentedControl(labels:[],trackingMode:.selectOne,target:nil,action:nil)
    let restartNotice: NSTextField
    let validationNotice: NSTextField
    private(set) var selectedCategory = 0
    private(set) var categoryButtons: [NSButton] = []
    let appearanceChoices = NSSegmentedControl(labels:[],trackingMode:.selectOne,target:nil,action:nil)
    let brushOutline = NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let recoveryInterval = NSPopUpButton(), exportFormat = NSPopUpButton()
    let jpegQuality = NSTextField(string:"")
    let exportLinked = NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let fileValidation = NSTextField(wrappingLabelWithString:"")
    private let sidebar = SurfaceView(color:WorkspaceStyle.toolbar)
    private let pageTitle = NSTextField(labelWithString:"")
    private let categoryKeys = ["settings.general","settings.workspace","settings.canvas","settings.brush","settings.interface","settings.files"]
    let rulers = NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let panelVisible = NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let rulerUnits = NSPopUpButton(), canvasBackground = NSPopUpButton(), gridSizes = NSPopUpButton()
    let transparency = NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let brushFields = (0..<3).map { _ in NSTextField(string:"") }
    let brushSliders = (0..<3).map { _ in NSSlider() }
    let brushAligned = NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let brushValidation: NSTextField
    private let widthStepper = NSStepper()
    private let root = SurfaceView()
    private var pages: [NSScrollView] = []
    private let resetButton = NSButton()
    private let footer: NSTextField
    private let separator = NSBox()
    var layoutChanged: (() -> Void)?
    private let initialLanguage: InterfaceLanguage
    private let formatter: NumberFormatter

    init(preferences:WorkspacePreferences,localization:L10n,launchLanguage:InterfaceLanguage? = nil) {
        self.preferences = preferences; self.localization = localization
        initialLanguage = launchLanguage ?? preferences.language
        restartNotice = NSTextField(wrappingLabelWithString:localization.text("settings.restart"))
        validationNotice = NSTextField(wrappingLabelWithString:localization.text("settings.widthError"))
        brushValidation = NSTextField(wrappingLabelWithString:localization.text("settings.brushError"))
        footer = WorkspaceStyle.label(localization.text("settings.saved"),size:11,secondary:true)
        formatter = NumberFormatter(); formatter.locale = .current; formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0; formatter.isLenient = false
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:940,height:660),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.title = localization.text("menu.settings"); window.tabbingMode = .disallowed; window.isReleasedWhenClosed = false
        window.identifier = .init("settings.window"); window.minSize = NSSize(width:880,height:560)
        super.init(window:window); buildContent(); refreshLayoutControls(); window.center()
    }
    required init?(coder:NSCoder) { fatalError("Use init(preferences:localization:)") }

    private func label(_ key:String,secondary:Bool = false) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString:localization.text(key))
        field.font = .systemFont(ofSize:secondary ? 11:12); field.textColor = secondary ? .secondaryLabelColor:WorkspaceStyle.text
        return field
    }
    private func identify(_ view:NSView,_ key:String) { view.identifier = .init(key); view.setAccessibilityLabel(localization.text(key)) }
    private func row(_ key:String,_ control:NSView) -> NSStackView {
        let caption = label(key); caption.widthAnchor.constraint(equalToConstant:156).isActive = true
        let row = NSStackView(views:[caption,control]); row.orientation = .horizontal; row.spacing = 16; row.alignment = .centerY
        control.setContentCompressionResistancePriority(.required,for:.horizontal)
        return row
    }
    private func card(_ key:String,_ children:[NSView]) -> NSView {
        let card = SurfaceView(color:WorkspaceStyle.toolbar); card.layer?.cornerRadius = 3
        card.layer?.borderWidth = 1; card.surfaceBorderColor = WorkspaceStyle.divider
        let title = label(key); title.font = .systemFont(ofSize:13,weight:.semibold)
        let stack = NSStackView(views:[title]+children); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(stack)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo:card.topAnchor,constant:16),stack.leadingAnchor.constraint(equalTo:card.leadingAnchor,constant:16),stack.trailingAnchor.constraint(equalTo:card.trailingAnchor,constant:-16),stack.bottomAnchor.constraint(equalTo:card.bottomAnchor,constant:-16)])
        for child in stack.arrangedSubviews { child.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive = true }
        return card
    }
    private func page(_ children:[NSView]) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let content = SurfaceView(); scroll.documentView = content; content.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView(views:children); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(stack)
        NSLayoutConstraint.activate([content.widthAnchor.constraint(equalTo:scroll.contentView.widthAnchor),stack.topAnchor.constraint(equalTo:content.topAnchor),stack.leadingAnchor.constraint(equalTo:content.leadingAnchor),stack.trailingAnchor.constraint(equalTo:content.trailingAnchor),stack.bottomAnchor.constraint(equalTo:content.bottomAnchor)])
        for child in children { child.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive = true }
        pages.append(scroll); root.addSubview(scroll); return scroll
    }
    private func popup(_ popup:NSPopUpButton,_ titles:[String],key:String,action:Selector) {
        popup.addItems(withTitles:titles.map { localization.text($0) }); identify(popup,key)
        popup.target = self; popup.action = action; popup.widthAnchor.constraint(equalToConstant:220).isActive = true
    }
    private func checkbox(_ button:NSButton,_ key:String,action:Selector) {
        button.title = localization.text(key); identify(button,key); button.target = self; button.action = action
    }
    private func buildContent() {
        window?.contentView = root
        root.autoresizingMask = [.width,.height]
        root.addSubview(sidebar)
        let title = label("settings.title"); title.font = .systemFont(ofSize:16,weight:.semibold)
        title.frame = NSRect(x:20,y:22,width:178,height:28); sidebar.addSubview(title)
        for (row,index) in [0,4,1,2,3,5].enumerated() {
            let button = NSButton(title:localization.text(categoryKeys[index]),target:self,action:#selector(chooseCategory(_:)))
            button.tag = index; button.bezelStyle = .regularSquare; button.setButtonType(.pushOnPushOff)
            button.isBordered = false; button.alignment = .left; button.font = .systemFont(ofSize:12)
            button.frame = NSRect(x:12,y:70+row*38,width:190,height:32)
            identify(button,categoryKeys[index]); sidebar.addSubview(button); categoryButtons.append(button)
        }
        pageTitle.font = .systemFont(ofSize:18,weight:.semibold); pageTitle.textColor = WorkspaceStyle.text
        root.addSubview(pageTitle)
        languagePopup.addItems(withTitles:[localization.text("language.system"),"Tiếng Việt","English"])
        languagePopup.target = self; languagePopup.action = #selector(changeLanguage); identify(languagePopup,"settings.language")
        languagePopup.widthAnchor.constraint(equalToConstant:220).isActive = true
        restartNotice.font = .systemFont(ofSize:11); restartNotice.textColor = .systemOrange
        let info = label("settings.aboutHelp",secondary:true)
        let version = NSTextField(labelWithString:"PhotoAxis \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "1.0.0") (\(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "9")) · macOS 14+ · Apple Silicon")
        version.font = .monospacedDigitSystemFont(ofSize:11,weight:.medium)
        _ = page([card("settings.interface",[row("settings.language",languagePopup),restartNotice]),card("settings.about",[version,info,label("settings.shortcuts",secondary:true)])])

        widthField.target = self; widthField.action = #selector(changeWidth); widthField.delegate = self; widthField.tag = -1
        identify(widthField,"settings.panelWidth"); widthField.widthAnchor.constraint(equalToConstant:80).isActive = true
        widthStepper.minValue = 260; widthStepper.maxValue = 420; widthStepper.increment = 8
        widthStepper.target = self; widthStepper.action = #selector(stepWidth(_:)); identify(widthStepper,"settings.panelWidth")
        let widthControls = NSStackView(views:[widthField,widthStepper,label("settings.widthRange",secondary:true)]); widthControls.spacing = 8; widthControls.alignment = .centerY
        columns.segmentCount = 2; columns.setLabel(localization.text("tools.oneColumn"),forSegment:0); columns.setLabel(localization.text("tools.twoColumns"),forSegment:1)
        columns.target = self; columns.action = #selector(changeColumns); identify(columns,"settings.toolColumns")
        checkbox(panelVisible,"settings.panelVisible",action:#selector(changeWorkspace))
        checkbox(rulers,"settings.rulers",action:#selector(changeWorkspace))
        popup(rulerUnits,["settings.unit.px","settings.unit.mm","settings.unit.cm","settings.unit.in"],key:"settings.rulerUnit",action:#selector(changeWorkspace))
        validationNotice.font = .systemFont(ofSize:11); validationNotice.textColor = .systemOrange; validationNotice.isHidden = true
        _ = page([card("settings.panels",[row("settings.panelWidth",widthControls),validationNotice,row("settings.toolColumns",columns),panelVisible]),card("settings.rulers",[rulers,row("settings.rulerUnit",rulerUnits),label("settings.rulerHelp",secondary:true)])])

        popup(canvasBackground,["settings.background.dark","settings.background.medium","settings.background.light"],key:"settings.background",action:#selector(changeCanvas))
        popup(gridSizes,["settings.grid.small","settings.grid.medium","settings.grid.large"],key:"settings.gridSize",action:#selector(changeCanvas))
        checkbox(transparency,"settings.transparency",action:#selector(changeCanvas))
        _ = page([card("settings.canvas",[row("settings.background",canvasBackground),transparency,row("settings.gridSize",gridSizes),label("settings.canvasHelp",secondary:true)])])

        var brushRows: [NSView] = []
        for (i,key) in ["settings.brushSize","settings.brushHardness","settings.brushOpacity"].enumerated() {
            let field = brushFields[i], slider = brushSliders[i]; field.tag = i; field.delegate = self; identify(field,key)
            field.widthAnchor.constraint(equalToConstant:66).isActive = true
            slider.tag = i; slider.minValue = i == 0 ? 1:0; slider.maxValue = i == 0 ? 1000:100
            slider.isContinuous = true; slider.target = self; slider.action = #selector(changeBrushSlider(_:)); slider.identifier = .init(key+".slider")
            slider.widthAnchor.constraint(equalToConstant:150).isActive = true
            let controls = NSStackView(views:[field,slider,WorkspaceStyle.label(i == 0 ? "px":"%",size:11,secondary:true)]); controls.spacing = 8; controls.alignment = .centerY
            brushRows.append(row(key,controls))
        }
        checkbox(brushAligned,"settings.brushAligned",action:#selector(changeBrushAligned))
        brushValidation.font = .systemFont(ofSize:11); brushValidation.textColor = .systemOrange; brushValidation.isHidden = true
        _ = page([card("settings.brush",[label("settings.brushHelp",secondary:true)]+brushRows+[brushAligned,brushValidation,brushOutline,label("settings.cursorHelp",secondary:true)])])
        checkbox(brushOutline,"settings.brushOutline",action:#selector(changeBrushOutline))
        appearanceChoices.segmentCount = 3
        for (i,key) in ["settings.theme.system","settings.theme.dark","settings.theme.light"].enumerated() { appearanceChoices.setLabel(localization.text(key),forSegment:i) }
        appearanceChoices.target = self; appearanceChoices.action = #selector(changeAppearance)
        identify(appearanceChoices,"settings.theme")
        _ = page([card("settings.theme",[appearanceChoices,label("settings.themeHelp",secondary:true)]),card("settings.display",[label("settings.displayHelp",secondary:true)])])
        popup(recoveryInterval,["settings.recovery.10","settings.recovery.30","settings.recovery.60"],key:"settings.recoveryInterval",action:#selector(changeFiles))
        popup(exportFormat,["settings.format.png","settings.format.jpeg"],key:"settings.exportFormat",action:#selector(changeFiles))
        jpegQuality.delegate = self; jpegQuality.widthAnchor.constraint(equalToConstant:80).isActive = true
        identify(jpegQuality,"settings.jpegQuality")
        checkbox(exportLinked,"settings.exportLinked",action:#selector(changeFiles))
        fileValidation.stringValue = localization.text("settings.fileError"); fileValidation.textColor = .systemOrange; fileValidation.isHidden = true
        _ = page([card("settings.recovery",[row("settings.recoveryInterval",recoveryInterval),label("settings.recoveryHelp",secondary:true)]),card("settings.exportDefaults",[row("settings.exportFormat",exportFormat),row("settings.jpegQuality",jpegQuality),exportLinked,fileValidation,label("settings.exportHelp",secondary:true)])])
        separator.boxType = .separator; root.addSubview(separator)
        resetButton.title = localization.text("settings.resetSection"); resetButton.bezelStyle = .rounded
        resetButton.target = self; resetButton.action = #selector(resetSection); resetButton.identifier = .init("settings.resetSection")
        root.addSubview(resetButton); root.addSubview(footer)
        let done = NSButton(title:localization.text("settings.done"),target:self,action:#selector(finish))
        done.bezelStyle = .rounded; done.keyEquivalent = "\r"; done.identifier = .init("settings.done")
        done.frame = NSRect(x:root.bounds.width-110,y:root.bounds.height-50,width:90,height:30)
        done.autoresizingMask = [.minXMargin,.minYMargin]; root.addSubview(done)
        root.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self,selector:#selector(resize),name:NSView.frameDidChangeNotification,object:root)
        resize(); changeCategory()
    }
    @objc private func resize() {
        let w = root.bounds.width, h = root.bounds.height
        sidebar.frame = NSRect(x:0,y:0,width:214,height:max(0,h-60))
        pageTitle.frame = NSRect(x:238,y:22,width:max(0,w-262),height:30)
        for page in pages { page.frame = NSRect(x:238,y:70,width:max(0,w-262),height:max(0,h-150)) }
        separator.frame = NSRect(x:0,y:h-60,width:w,height:1)
        footer.frame = NSRect(x:20,y:h-45,width:max(0,w-350),height:18)
        resetButton.frame = NSRect(x:w-318,y:h-50,width:194,height:30)
    }
    @objc private func finish() { window?.makeFirstResponder(nil); close() }
    @objc private func chooseCategory(_ sender:NSButton) { selectCategory(sender.tag) }
    func selectCategory(_ index:Int) {
        guard pages.indices.contains(index) else { return }
        window?.makeFirstResponder(nil); selectedCategory = index; changeCategory()
    }
    func changeCategory() {
        for (i,page) in pages.enumerated() { page.isHidden = i != selectedCategory }
        pageTitle.stringValue = localization.text(categoryKeys[selectedCategory])
        for button in categoryButtons {
            button.state = button.tag == selectedCategory ? .on:.off
            button.contentTintColor = button.state == .on ? .controlAccentColor:WorkspaceStyle.text
        }
    }
    @objc func changeAppearance() {
        guard InterfaceAppearance.allCases.indices.contains(appearanceChoices.selectedSegment) else { return }
        preferences.interfaceAppearance = InterfaceAppearance.allCases[appearanceChoices.selectedSegment]
        preferences.interfaceAppearance.apply(); layoutChanged?()
    }
    @objc func changeBrushOutline() { preferences.showsBrushOutline = brushOutline.state == .on; layoutChanged?() }
    @objc func changeFiles() {
        guard let quality = Int(jpegQuality.stringValue), (1...100).contains(quality) else { fileValidation.isHidden = false; return }
        var files = preferences.files
        if [10,30,60].indices.contains(recoveryInterval.indexOfSelectedItem) { files.recoverySeconds = [10,30,60][recoveryInterval.indexOfSelectedItem] }
        files.exportJPEG = exportFormat.indexOfSelectedItem == 1; files.jpegQuality = quality
        files.linkExportDimensions = exportLinked.state == .on
        preferences.files = files; fileValidation.isHidden = true
    }
    @objc func changeLanguage() {
        guard InterfaceLanguage.allCases.indices.contains(languagePopup.indexOfSelectedItem) else { return }
        preferences.language = InterfaceLanguage.allCases[languagePopup.indexOfSelectedItem]
        restartNotice.isHidden = preferences.language == initialLanguage
    }
    @objc func changeWidth() {
        let text = widthField.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty, text.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }),
              let number = formatter.number(from:text), (260...420).contains(number.doubleValue), number.doubleValue.rounded() == number.doubleValue else { validationNotice.isHidden = false; return }
        var layout = preferences.layout; layout.panelWidth = number.doubleValue; preferences.layout = layout
        widthStepper.doubleValue = number.doubleValue; validationNotice.isHidden = true; layoutChanged?()
    }
    @objc private func stepWidth(_ sender:NSStepper) { widthField.stringValue = formatter.string(from:NSNumber(value:sender.doubleValue)) ?? "300"; changeWidth() }
    @objc func changeColumns() { var layout = preferences.layout; layout.toolColumns = columns.selectedSegment+1; preferences.layout = layout; layoutChanged?() }
    @objc func changeWorkspace() {
        var layout = preferences.layout; layout.rulersVisible = rulers.state == .on; layout.panelCollapsed = panelVisible.state != .on; preferences.layout = layout
        if RulerUnit.allCases.indices.contains(rulerUnits.indexOfSelectedItem) { preferences.rulerUnit = RulerUnit.allCases[rulerUnits.indexOfSelectedItem] }
        layoutChanged?()
    }
    @objc func changeCanvas() {
        var appearance = preferences.canvasAppearance
        if CanvasAppearance.Background.allCases.indices.contains(canvasBackground.indexOfSelectedItem) { appearance.background = CanvasAppearance.Background.allCases[canvasBackground.indexOfSelectedItem] }
        if CanvasAppearance.GridSize.allCases.indices.contains(gridSizes.indexOfSelectedItem) { appearance.gridSize = CanvasAppearance.GridSize.allCases[gridSizes.indexOfSelectedItem] }
        appearance.showsTransparency = transparency.state == .on; preferences.canvasAppearance = appearance
        gridSizes.isEnabled = appearance.showsTransparency; layoutChanged?()
    }
    func controlTextDidChange(_ notification:Notification) {
        guard let field = notification.object as? NSTextField else { return }
        if field === jpegQuality { changeFiles(); return }
        if field === widthField { changeWidth(); return }
        guard brushFields.contains(field), let value = DocumentNumber.parse(field.stringValue,language:Locale.current.identifier), value.isFinite,
              (brushSliders[field.tag].minValue...brushSliders[field.tag].maxValue).contains(value) else { brushValidation.isHidden = false; return }
        storeBrush(field.tag,value:value); brushSliders[field.tag].doubleValue = value; brushValidation.isHidden = true
    }
    private func storeBrush(_ index:Int,value:Double) {
        var defaults = preferences.brushDefaults
        switch index { case 0: defaults.diameter = value; case 1: defaults.hardness = value/100; default: defaults.opacity = value/100 }
        preferences.brushDefaults = defaults
    }
    @objc func changeBrushSlider(_ sender:NSSlider) {
        storeBrush(sender.tag,value:sender.doubleValue)
        brushFields[sender.tag].stringValue = DocumentNumber.format(sender.doubleValue,language:Locale.current.identifier); brushValidation.isHidden = true
    }
    @objc func changeBrushAligned() { var defaults = preferences.brushDefaults; defaults.aligned = brushAligned.state == .on; preferences.brushDefaults = defaults }
    @objc func resetSection() {
        window?.makeFirstResponder(nil)
        switch selectedCategory {
        case 0: preferences.language = .system
        case 1: preferences.resetLayout(); preferences.rulerUnit = .pixels
        case 2: preferences.canvasAppearance = CanvasAppearance()
        case 3: preferences.brushDefaults = BrushSettings(); preferences.showsBrushOutline = true
        case 4: preferences.interfaceAppearance = .system; preferences.interfaceAppearance.apply()
        case 5: preferences.files = FilePreferences()
        default: return
        }
        refreshLayoutControls(); layoutChanged?()
    }
    func refreshLayoutControls() {
        languagePopup.selectItem(at:InterfaceLanguage.allCases.firstIndex(of:preferences.language) ?? 0)
        restartNotice.isHidden = preferences.language == initialLanguage
        if window?.isVisible != true || widthField.currentEditor() == nil { widthField.stringValue = formatter.string(from:NSNumber(value:preferences.layout.panelWidth)) ?? "300" }
        widthStepper.doubleValue = preferences.layout.panelWidth; columns.selectedSegment = preferences.layout.toolColumns-1
        rulers.state = preferences.layout.rulersVisible ? .on:.off; panelVisible.state = preferences.layout.panelCollapsed ? .off:.on
        rulerUnits.selectItem(at:RulerUnit.allCases.firstIndex(of:preferences.rulerUnit) ?? 0)
        let appearance = preferences.canvasAppearance
        canvasBackground.selectItem(at:CanvasAppearance.Background.allCases.firstIndex(of:appearance.background) ?? 0)
        gridSizes.selectItem(at:CanvasAppearance.GridSize.allCases.firstIndex(of:appearance.gridSize) ?? 1)
        transparency.state = appearance.showsTransparency ? .on:.off; gridSizes.isEnabled = appearance.showsTransparency
        let defaults = preferences.brushDefaults
        for (i,value) in [defaults.diameter,defaults.hardness*100,defaults.opacity*100].enumerated() {
            if window?.isVisible != true || brushFields[i].currentEditor() == nil { brushFields[i].stringValue = DocumentNumber.format(value,language:Locale.current.identifier) }
            brushSliders[i].doubleValue = value
        }
        brushAligned.state = defaults.aligned ? .on:.off
        brushOutline.state = preferences.showsBrushOutline ? .on:.off
        appearanceChoices.selectedSegment = InterfaceAppearance.allCases.firstIndex(of:preferences.interfaceAppearance) ?? 0
        let files = preferences.files
        recoveryInterval.selectItem(at:[10,30,60].firstIndex(of:files.recoverySeconds) ?? 0)
        exportFormat.selectItem(at:files.exportJPEG ? 1:0); exportLinked.state = files.linkExportDimensions ? .on:.off
        if jpegQuality.currentEditor() == nil { jpegQuality.stringValue = String(files.jpegQuality) }
        fileValidation.isHidden = true
        validationNotice.isHidden = true; brushValidation.isHidden = true
    }
}

import AppKit
import PhotoAxisCore

@MainActor
final class OptionsBarView: SurfaceView {
    var fitCanvas: (() -> Void)?
    var actualPixels: (() -> Void)?
    var focusCanvas: (() -> Void)?
    let applyButton: NSButton
    let cancelButton: NSButton
    let overflowButton: ToolGroupButton
    let toolLabel: NSTextField
    private let options = NSStackView(frame: NSRect(x: 0, y: 0, width: 600, height: 22))
    private let localization: L10n
    private(set) var usesOverflow = false
    private weak var document: PhotoDocument?
    private var mode = ""
    private var cropControls:CropOptionsView?
    private var perspectiveControls:PerspectiveOptionsView?
    private var transformControls: TransformOptionsView?
    private let popover = NSPopover()

    init(localization: L10n) {
        self.localization = localization
        applyButton = NSButton(title: localization.text("action.apply"), target: nil, action: nil)
        cancelButton = NSButton(title: localization.text("action.cancel"), target: nil, action: nil)
        overflowButton = ToolGroupButton(title: localization.text("options.more"), symbol: "ellipsis")
        toolLabel = WorkspaceStyle.label("")
        super.init(color: WorkspaceStyle.toolbar)
        identifier = .init("workspace.options")
        for button in [applyButton, cancelButton] {
            button.bezelStyle = .rounded; button.controlSize = .small
            button.font = .systemFont(ofSize: 12)
            button.isEnabled = false
            button.toolTip = localization.text("options.noSession")
            button.setAccessibilityLabel(button.title)
        }
        applyButton.identifier = .init("options.apply")
        cancelButton.identifier = .init("options.cancel")
        applyButton.target = self; applyButton.action = #selector(apply)
        cancelButton.target = self; cancelButton.action = #selector(cancel)
        options.orientation = .horizontal; options.spacing = 12; options.alignment = .centerY
        for child in [toolLabel, options, overflowButton, cancelButton, applyButton] { addSubview(child) }
        configure(for: .move)
    }
    required init?(coder: NSCoder) { fatalError("Use init(localization:)") }

    func configure(for tool: ToolKind) {
        mode = ""; transformControls = nil;cropControls=nil;perspectiveControls=nil
        toolLabel.stringValue = localization.text(tool.key)
        options.arrangedSubviews.forEach { options.removeArrangedSubview($0); $0.removeFromSuperview() }
        if tool == .hand || tool == .zoom {
            for (key, selector) in [("view.fit", #selector(fit)), ("view.actual", #selector(actual))] {
                let button = NSButton(title: localization.text(key), target: self, action: selector)
                button.bezelStyle = .rounded; button.controlSize = .small
                options.addArrangedSubview(button)
            }
            options.addArrangedSubview(WorkspaceStyle.label(localization.text(tool == .hand ? "document.handHelp" : "document.zoomHelp"), size: 11, secondary: true))
            overflowButton.flyout = nil; needsLayout = true; return
        }
        if [.type,.rectangle,.ellipse,.line,.eyedropper].contains(tool) {
            let key=tool == .type ? "type.help":tool == .eyedropper ? "color.sampleHelp":"shape.help"
            options.addArrangedSubview(WorkspaceStyle.label(localization.text(key),size:11,secondary:true));overflowButton.flyout=nil;needsLayout=true;return
        }
        let keys = tool == .perspectiveCrop
            ? ["options.mode", "options.width", "options.height", "options.swap", "options.grid", "options.preview", "action.reset"]
            : ["options.autoSelect", "options.transformControls"]
        let menu = NSMenu(); menu.autoenablesItems = false
        for key in keys {
            let label = localization.text(key)
            let button = NSButton(checkboxWithTitle: label, target: nil, action: nil)
            button.font = .systemFont(ofSize: 11); button.isEnabled = false
            button.toolTip = localization.text("feature.noDocument")
            button.setAccessibilityLabel(label)
            options.addArrangedSubview(button)
            let item = menu.addItem(withTitle: label, action: nil, keyEquivalent: "")
            item.isEnabled = false
        }
        overflowButton.flyout = menu
        overflowButton.toolTip = localization.text("options.more")
        needsLayout = true
    }

    func display(_ document: PhotoDocument?) {
        self.document = document
        let next = document?.contentSession != nil ? (document?.contentSession?.draft.isText == true ? "type":"shape") : document?.perspectiveSession != nil ? "perspective" : document?.cropSession != nil ? "crop" : document?.toolSession?.command == .transform ? "transform" : document?.activeTool.rawValue ?? "empty"
        if mode != next {
            configure(for: document?.activeTool ?? .move)
            if next == "type" || next == "shape" {
                toolLabel.stringValue=localization.text(next == "type" ? "tool.type":"panel.properties")
                options.arrangedSubviews.forEach{options.removeArrangedSubview($0);$0.removeFromSuperview()}
                options.addArrangedSubview(WorkspaceStyle.label(localization.text(next == "type" ? "type.help":"shape.help"),size:11,secondary:true))
            } else if next == "perspective" {
                toolLabel.stringValue=localization.text("tool.perspectiveCrop")
                options.arrangedSubviews.forEach{options.removeArrangedSubview($0);$0.removeFromSuperview()}
                let controls=PerspectiveOptionsView(localization:localization);controls.focusCanvas={ [weak self] in self?.focusCanvas?() }
                perspectiveControls=controls;options.addArrangedSubview(controls)
                let menu=NSMenu();let item=menu.addItem(withTitle:localization.text("options.more"),action:#selector(showPerspectivePopover),keyEquivalent:"");item.target=self;overflowButton.flyout=menu
            } else if next == "crop" {
                toolLabel.stringValue = localization.text("tool.crop")
                options.arrangedSubviews.forEach{options.removeArrangedSubview($0);$0.removeFromSuperview()}
                let controls=CropOptionsView(localization:localization);controls.focusCanvas={ [weak self] in self?.focusCanvas?() }
                cropControls=controls;options.addArrangedSubview(controls)
                let menu=NSMenu();let item=menu.addItem(withTitle:localization.text("options.more"),action:#selector(showCropPopover),keyEquivalent:"");item.target=self;overflowButton.flyout=menu
            } else if next == "transform" {
                options.arrangedSubviews.forEach { options.removeArrangedSubview($0); $0.removeFromSuperview() }
                let controls = TransformOptionsView(localization: localization)
                controls.focusCanvas = { [weak self] in self?.focusCanvas?() }
                transformControls = controls; options.addArrangedSubview(controls)
                toolLabel.stringValue = localization.text("layer.transform")
                let menu = NSMenu(); let item = menu.addItem(withTitle: localization.text("transform.more"), action: #selector(showTransformPopover), keyEquivalent: "")
                item.target = self; overflowButton.flyout = menu
            } else if next == "move" {
                options.arrangedSubviews.forEach { options.removeArrangedSubview($0); $0.removeFromSuperview() }
                for (key, selector, enabled) in [("options.autoSelect", #selector(toggleAuto(_:)), true), ("options.transformControls", #selector(toggleControls(_:)), true)] {
                    let button = NSButton(checkboxWithTitle: localization.text(key), target: self, action: selector)
                    button.isEnabled = enabled; button.font = .systemFont(ofSize: 11)
                    button.state = (key == "options.autoSelect" ? document?.autoSelect : document?.showTransformControls) == true ? .on : .off
                    options.addArrangedSubview(button)
                }
                let center = NSButton(title: localization.text("transform.center"), target: self, action: #selector(centerLayer))
                center.bezelStyle = .rounded; center.controlSize = .small; center.isEnabled = document?.canEditSelection == true
                options.addArrangedSubview(center)
            }
            mode = next
        }
        if next == "move" {
            for case let button as NSButton in options.arrangedSubviews {
                if button.action == #selector(toggleAuto(_:)) { button.state = document?.autoSelect == true ? .on : .off }
                else if button.action == #selector(toggleControls(_:)) { button.state = document?.showTransformControls == true ? .on : .off }
                else { button.isEnabled = document?.canEditSelection == true }
            }
        }
        perspectiveControls?.refresh(document)
        (popover.contentViewController?.view as? PerspectiveOptionsView)?.refresh(document)
        cropControls?.refresh(document)
        (popover.contentViewController?.view as? CropOptionsView)?.refresh(document)
        transformControls?.refresh(document)
        (popover.contentViewController?.view as? TransformOptionsView)?.refresh(document)
        applyButton.isEnabled = document?.sessionIsValid == true
        cancelButton.isEnabled = document?.hasSession == true
        let hint = document?.hasAdjustmentSession == true ? (document?.sessionIsValid == true ? "adjustment.help":"adjustment.invalid") : document?.contentSession != nil ? (document?.sessionIsValid==true ? "content.help":"content.invalid") : document?.perspectiveSession != nil ? (document?.perspectiveSession?.error?.localizationKey ?? "perspective.help") : document?.hasSession != true ? "options.noSession" : document?.cropSession != nil ? (document?.sessionIsValid == true ? "tool.crop":"crop.invalid") : document?.sessionIsValid == false ? "transform.invalid" : "layer.transform"
        applyButton.toolTip = localization.text(hint); cancelButton.toolTip = localization.text(hint)
        needsLayout = true
    }
    @objc private func apply() { focusCanvas?(); document?.applySession() }
    @objc private func cancel() { focusCanvas?(); document?.cancelSession() }
    @objc private func toggleAuto(_ sender:NSButton) { document?.autoSelect = sender.state == .on }
    @objc private func toggleControls(_ sender:NSButton) { document?.showTransformControls = sender.state == .on; document?.changed?() }
    @objc private func centerLayer() { do { try document?.centerSelected() } catch { NSSound.beep() } }
    @objc private func showPerspectivePopover() {
        let controls=PerspectiveOptionsView(localization:localization);controls.refresh(document)
        controls.focusCanvas={ [weak self] in self?.focusCanvas?() }
        let controller=NSViewController();controller.view=controls;popover.contentViewController=controller;popover.contentSize=NSSize(width:1040,height:38);popover.behavior = .transient
        popover.show(relativeTo:overflowButton.bounds,of:overflowButton,preferredEdge:.maxY)
    }
    @objc private func showCropPopover() {
        let controls=CropOptionsView(localization:localization);controls.refresh(document)
        controls.focusCanvas={ [weak self] in self?.popover.close();self?.focusCanvas?() }
        let controller=NSViewController();controller.view=controls;popover.contentViewController=controller;popover.contentSize=NSSize(width:700,height:36);popover.behavior = .transient
        popover.show(relativeTo:overflowButton.bounds,of:overflowButton,preferredEdge:.maxY)
    }
    @objc private func showTransformPopover() {
        let controls = TransformOptionsView(localization: localization); controls.refresh(document)
        controls.focusCanvas = { [weak self] in self?.popover.close(); self?.focusCanvas?() }
        let controller = NSViewController(); controller.view = controls
        popover.contentViewController = controller; popover.contentSize = NSSize(width: 650,height: 34); popover.behavior = .transient
        popover.show(relativeTo: overflowButton.bounds,of: overflowButton,preferredEdge: .maxY)
    }

    @objc private func fit() { fitCanvas?() }
    @objc private func actual() { actualPixels?() }
    override func layout() {
        super.layout()
        let applyWidth = max(82, applyButton.intrinsicContentSize.width + 16)
        let cancelWidth = max(68, cancelButton.intrinsicContentSize.width + 16)
        applyButton.frame = NSRect(x: bounds.width - applyWidth - 10, y: 6, width: applyWidth, height: 24)
        cancelButton.frame = NSRect(x: applyButton.frame.minX - cancelWidth - 8, y: 6, width: cancelWidth, height: 24)
        let labelWidth = min(180, toolLabel.intrinsicContentSize.width + 12)
        toolLabel.frame = NSRect(x: 14, y: 10, width: labelWidth, height: 18)
        let available = max(0, cancelButton.frame.minX - toolLabel.frame.maxX - 30)
        usesOverflow = options.fittingSize.width > available
        options.isHidden = usesOverflow
        overflowButton.isHidden = !usesOverflow
        options.frame = NSRect(x: toolLabel.frame.maxX + 16, y: 7, width: available, height: 22)
        overflowButton.frame = NSRect(x: toolLabel.frame.maxX + 12, y: 4, width: 32, height: 28)
    }
}

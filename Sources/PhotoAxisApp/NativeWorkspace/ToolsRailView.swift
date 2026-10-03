import AppKit
import PhotoAxisCore

@MainActor
final class ToolsRailView: SurfaceView {
    let columnsButton: WorkspaceButton
    var selectTool: ((ToolKind) -> Void)?
    var changeColumns: (() -> Void)?
    var columnCount = 1 { didSet { needsLayout = true } }
    private let localization: L10n
    private let slots: [NSButton]
    private weak var document:PhotoDocument?
    private let foreground = NSColorWell()
    private let background = NSColorWell()

    init(localization: L10n) {
        self.localization = localization
        columnsButton = WorkspaceButton(title: localization.text("tools.toggleColumns"), symbol: "chevron.right.2")
        let tools: [ToolKind] = [.move, .crop, .brush, .cloneStamp, .eyedropper, .type, .rectangle, .hand, .zoom]
        slots = tools.map { tool in
            let group: [ToolKind] = tool == .crop ? [.crop, .perspectiveCrop] : tool == .rectangle ? [.rectangle, .ellipse, .line] : []
            let label = localization.text(tool.key) + " (" + tool.shortcut + ")"
            let button: WorkspaceButton
            if !group.isEmpty {
                let key = tool == .crop ? "tools.cropGroup" : "tools.shapeGroup"
                let disclosure = ToolGroupButton(title: localization.text(key))
                let menu = NSMenu(title: localization.text(key)); menu.autoenablesItems = false
                for member in group {
                    let item = menu.addItem(withTitle: localization.text(member.key) + " (" + member.shortcut + ")", action: nil, keyEquivalent: "")
                    item.representedObject=member.rawValue;item.image = member.icon(); item.isEnabled = false
                    item.toolTip = localization.text("feature.noDocument")
                }
                disclosure.flyout = menu
                disclosure.toolTip = localization.text(key) + " — " + localization.text("tools.flyoutHelp")
                button = disclosure
            } else {
                button = WorkspaceButton(title: label)
                button.isEnabled = false
                button.toolTip = label + " — " + localization.text("feature.noDocument")
            }
            button.image = tool.icon(); button.imagePosition = .imageOnly
            button.identifier = .init("tool." + tool.rawValue)
            return button
        }
        super.init(color: WorkspaceStyle.toolbar)
        identifier = .init("workspace.tools")
        columnsButton.target = self; columnsButton.action = #selector(toggleColumns)
        columnsButton.toolTip = localization.text("tools.toggleColumns")
        columnsButton.identifier = .init("tools.columns")
        for child in [columnsButton] + slots { addSubview(child) }
        foreground.color = .black; background.color = .white
        for (well, key) in [(background, "color.background"), (foreground, "color.foreground")] {
            well.target=self;well.action=#selector(changeColor(_:));well.isEnabled = false; well.setAccessibilityLabel(localization.text(key))
            well.toolTip = localization.text("feature.unavailable")
            addSubview(well)
        }
    }
    required init?(coder: NSCoder) { fatalError("Use init(localization:)") }
    @objc private func toggleColumns() { changeColumns?() }

    func displayColors(_ document:PhotoDocument?){self.document=document;foreground.color=document?.foreground.nsColor ?? .black;background.color=document?.background.nsColor ?? .white;foreground.isEnabled=document != nil;background.isEnabled=document != nil;foreground.toolTip=localization.text("color.foreground");background.toolTip=localization.text("color.background")}
    @objc private func changeColor(_ sender:NSColorWell){guard let color=RGBAColor(sender.color) else{return};if sender===foreground{document?.setForeground(color)}else{document?.background=color;document?.changed?()}}
    func updateNavigationTools(_ selected: ToolKind?) {
        for button in slots {
            if let group=button as? ToolGroupButton,button.identifier?.rawValue == "tool.crop" {
                button.state=(selected == .crop || selected == .perspectiveCrop) ? .on:.off
                button.image=(selected == .perspectiveCrop ? ToolKind.perspectiveCrop:ToolKind.crop).icon()
                for item in group.flyout?.items ?? [] {item.isEnabled=selected != nil;item.target=self;item.action=#selector(activateGroup(_:));item.toolTip=localization.text(item.isEnabled ? (item.representedObject as? String == "crop" ? "crop.help":"perspective.help"):"feature.noDocument")}
                button.toolTip=localization.text(selected == nil ? "feature.noDocument":"crop.help")
            }
            if let group=button as? ToolGroupButton,button.identifier?.rawValue == "tool.rectangle" {
                let active=selected == .ellipse || selected == .line || selected == .rectangle
                button.state=active ? .on:.off;button.image=(active ? selected!:.rectangle).icon()
                for item in group.flyout?.items ?? []{item.isEnabled=selected != nil;item.target=self;item.action=#selector(activateGroup(_:));item.toolTip=localization.text(selected == nil ? "feature.noDocument":"shape.help")}
                button.toolTip=localization.text(selected == nil ? "feature.noDocument":"shape.help")
            }
            if !button.isEnabled { button.toolTip = localization.text(selected == nil ? "feature.noDocument" : "feature.unavailable") }
            guard let raw = button.identifier?.rawValue.replacingOccurrences(of: "tool.", with: ""), let tool = ToolKind(rawValue: raw), tool == .hand || tool == .zoom || tool == .move || tool == .type || tool == .eyedropper || tool == .brush || tool == .cloneStamp else { continue }
            button.isEnabled = selected != nil; button.state = selected == tool ? .on : .off
            button.target = self; button.action = #selector(activateNavigationTool(_:))
            if selected != nil { button.toolTip = button.accessibilityLabel() }
        }
    }
    @objc private func activateGroup(_ sender:NSMenuItem) {if let raw=sender.representedObject as? String,let tool=ToolKind(rawValue:raw){selectTool?(tool)}}
    @objc private func activateNavigationTool(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue.replacingOccurrences(of: "tool.", with: ""), let tool = ToolKind(rawValue: raw) else { return }
        selectTool?(tool)
    }
    override func layout() {
        super.layout()
        columnsButton.frame = NSRect(x: 4, y: 1, width: bounds.width - 8, height: 24)
        let count = columnCount == 2 ? 2 : 1
        for (index, button) in slots.enumerated() {
            let width: CGFloat = 30
            button.frame = NSRect(x: count == 1 ? (bounds.width - width) / 2 : 5 + CGFloat(index % 2) * 32,
                                  y: 31 + CGFloat(index / count) * 34, width: width, height: 30)
        }
        let y = 44 + CGFloat((slots.count + count - 1) / count) * 34
        background.frame = NSRect(x: bounds.width / 2 - 3, y: y + 11, width: 23, height: 23)
        foreground.frame = NSRect(x: bounds.width / 2 - 17, y: y, width: 23, height: 23)
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.secondaryLabelColor.setFill()
        for slot in slots where slot is ToolGroupButton {
            let p = NSBezierPath()
            p.move(to: .init(x: slot.frame.maxX - 5, y: slot.frame.maxY - 5))
            p.line(to: .init(x: slot.frame.maxX - 2, y: slot.frame.maxY - 5))
            p.line(to: .init(x: slot.frame.maxX - 2, y: slot.frame.maxY - 2))
            p.close(); p.fill()
        }
    }
}

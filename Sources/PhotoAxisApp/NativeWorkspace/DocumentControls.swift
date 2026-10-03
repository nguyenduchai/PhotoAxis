import AppKit
import PhotoAxisCore

@MainActor
final class DocumentTabsView: SurfaceView {
    var select: ((UUID) -> Void)?
    var closeTab: ((UUID) -> Void)?
    var openDroppedFiles: (([ImageInput]) -> Void)?
    private var ids: [UUID] = []
    private var buttons: [NSButton] = []
    private var closes: [NSButton] = []
    init() { super.init(color: WorkspaceStyle.panel); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError("Use init()") }
    func update(_ documents: [PhotoDocument], activeID: UUID?, localization: L10n) {
        subviews.forEach { $0.removeFromSuperview() }; buttons = []; closes = []; ids = documents.map { $0.model.id }
        for (index, document) in documents.enumerated() {
            let title = document.model.name + (document.isDocumentEdited ? " •" : "")
            let button = WorkspaceButton(title: title); button.title = title; button.imagePosition = .noImage
            button.setButtonType(.toggle); button.state = document.model.id == activeID ? .on : .off
            button.cell?.lineBreakMode = .byTruncatingMiddle; button.font = .systemFont(ofSize: 11)
            button.tag = index; button.target = self; button.action = #selector(activate(_:)); button.toolTip = title
            let close = WorkspaceButton(title: localization.text("document.closeTab"), symbol: "xmark")
            close.tag = index; close.target = self; close.action = #selector(remove(_:))
            buttons.append(button); closes.append(close); addSubview(button); addSubview(close)
        }
        needsLayout = true
    }
    @objc private func activate(_ sender: NSButton) { select?(ids[sender.tag]) }
    @objc private func remove(_ sender: NSButton) { closeTab?(ids[sender.tag]) }
    override func layout() {
        super.layout(); let width = min(220, bounds.width / CGFloat(max(1, ids.count)))
        for index in ids.indices {
            buttons[index].frame = NSRect(x: CGFloat(index) * width, y: 0, width: max(1, width - 23), height: bounds.height)
            closes[index].frame = NSRect(x: CGFloat(index + 1) * width - 23, y: 2, width: 21, height: 24)
        }
    }
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation { WelcomeCanvasView.files(sender.draggingPasteboard).isEmpty ? [] : .copy }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = WelcomeCanvasView.files(sender.draggingPasteboard); guard !urls.isEmpty else { return false }
        openDroppedFiles?(urls.map { .file($0) }); return true
    }
}

enum DocumentNumber {
    static func parse(_ text: String, language: String, signed: Bool = false) -> Double? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("%") { trimmed.removeLast(); trimmed = trimmed.trimmingCharacters(in: .whitespaces) }
        let separator = Locale(identifier: language).decimalSeparator ?? "."
        let pattern = (signed ? "^[+-]?" : "^") + "[0-9]+(?:" + NSRegularExpression.escapedPattern(for: separator) + "[0-9]+)?$"
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return Double(trimmed.replacingOccurrences(of: separator, with: ".")).flatMap { $0.isFinite ? $0 : nil }
    }
    static func format(_ number: Double, language: String) -> String {
        let formatter = NumberFormatter(); formatter.locale = Locale(identifier: language); formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
}

@MainActor
final class NewDocumentController: NSWindowController {
    let nameField = NSTextField(string: "")
    let widthField = NSTextField(string: "1080"), heightField = NSTextField(string: "1080"), ppiField = NSTextField(string: "72")
    let background = NSPopUpButton(), preset = NSPopUpButton()
    let notice = NSTextField(wrappingLabelWithString: "")
    var create: ((String, CanvasSize, Double, DocumentBackground) throws -> Void)?
    private let localization: L10n
    private let createButton: NSButton
    init(localization: L10n) {
        self.localization = localization
        createButton = NSButton(title: localization.text("action.new"), target: nil, action: nil)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 410), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = localization.text("action.new"); panel.isReleasedWhenClosed = false
        let root = SurfaceView(); panel.contentView = root
        super.init(window: panel)
        nameField.stringValue = localization.text("document.untitled")
        preset.addItems(withTitles: ["1080 × 1080", "1920 × 1080", "1080 × 1920", "A4 · 2480 × 3508 · 300 PPI", localization.text("document.custom")])
        preset.target = self; preset.action = #selector(changePreset)
        for value in DocumentBackground.allCases { background.addItem(withTitle: localization.text("document." + value.rawValue)) }
        for (index, pair) in [("document.name", nameField as NSView), ("document.preset", preset), ("document.width", widthField),
                              ("document.height", heightField), ("document.ppi", ppiField), ("document.background", background)].enumerated() {
            let label = WorkspaceStyle.label(localization.text(pair.0)); label.frame = NSRect(x: 20, y: 24 + index * 43, width: 130, height: 23)
            pair.1.frame = NSRect(x: 160, y: 20 + index * 43, width: 270, height: 26)
            pair.1.setAccessibilityLabel(localization.text(pair.0)); root.addSubview(label); root.addSubview(pair.1)
        }
        let swap = NSButton(title: "⇅", target: self, action: #selector(swapDimensions)); swap.bezelStyle = .rounded
        swap.setAccessibilityLabel(localization.text("document.swap")); swap.frame = NSRect(x: 443, y: 111, width: 38, height: 44); root.addSubview(swap)
        notice.textColor = .systemRed; notice.font = .systemFont(ofSize: 11); notice.frame = NSRect(x: 20, y: 291, width: 460, height: 55); root.addSubview(notice)
        let cancel = NSButton(title: localization.text("action.cancel"), target: self, action: #selector(cancelNew))
        cancel.keyEquivalent = "\u{1b}"; cancel.bezelStyle = .rounded; cancel.frame = NSRect(x: 250, y: 362, width: 110, height: 30); root.addSubview(cancel)
        createButton.target = self; createButton.action = #selector(confirmNew); createButton.keyEquivalent = "\r"; createButton.bezelStyle = .rounded
        createButton.frame = NSRect(x: 366, y: 362, width: 114, height: 30); root.addSubview(createButton)
        for field in [widthField, heightField, ppiField] { field.target = self; field.action = #selector(validateFields) }
        NotificationCenter.default.addObserver(self, selector: #selector(validateFields), name: NSControl.textDidChangeNotification, object: widthField)
        NotificationCenter.default.addObserver(self, selector: #selector(validateFields), name: NSControl.textDidChangeNotification, object: heightField)
        NotificationCenter.default.addObserver(self, selector: #selector(validateFields), name: NSControl.textDidChangeNotification, object: ppiField)
    }
    required init?(coder: NSCoder) { fatalError("Use init(localization:)") }
    @objc func changePreset() {
        guard preset.indexOfSelectedItem < 4 else { return }
        let values = [(1080,1080,72), (1920,1080,72), (1080,1920,72), (2480,3508,300)][preset.indexOfSelectedItem]
        widthField.stringValue = String(values.0); heightField.stringValue = String(values.1); ppiField.stringValue = String(values.2); validateFields()
    }
    @objc func swapDimensions() { let w = widthField.stringValue; widthField.stringValue = heightField.stringValue; heightField.stringValue = w; validateFields() }
    func validated() throws -> (CanvasSize, Double) {
        guard let w = Int(widthField.stringValue), let h = Int(heightField.stringValue) else { throw DimensionError.edgeOutOfRange }
        let size = try CanvasSize(width: w, height: h)
        guard let ppi = DocumentNumber.parse(ppiField.stringValue, language: Locale.current.identifier), ppi > 0 else { throw DocumentError.invalidPPI }
        return (size, ppi)
    }
    @objc func validateFields() {
        do { _ = try validated(); notice.stringValue = ""; createButton.isEnabled = true }
        catch { notice.stringValue = localization.text(error as? DocumentError == .invalidPPI ? "document.invalidPPI" : "document.invalidSize"); createButton.isEnabled = false }
    }
    @objc private func confirmNew() {
        do {
            let (size, ppi) = try validated()
            try create?(nameField.stringValue.isEmpty ? localization.text("document.untitled") : nameField.stringValue, size, ppi, DocumentBackground.allCases[background.indexOfSelectedItem])
            window?.sheetParent?.endSheet(window!)
        } catch { validateFields(); if notice.stringValue.isEmpty { notice.stringValue = localization.text("document.tabLimit") } }
    }
    @objc private func cancelNew() { window?.sheetParent?.endSheet(window!) }
}

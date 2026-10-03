import AppKit

enum WorkspaceStyle {
    static let canvas = NSColor(white: 30 / 255, alpha: 1)
    static let panel = NSColor(white: 43 / 255, alpha: 1)
    static let toolbar = NSColor(white: 50 / 255, alpha: 1)
    static let control = NSColor(white: 60 / 255, alpha: 1)
    static let divider = NSColor(white: 69 / 255, alpha: 1)
    static let text = NSColor(white: 217 / 255, alpha: 1)

    @MainActor static func label(_ text: String, size: CGFloat = 12, secondary: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size)
        label.textColor = secondary ? .secondaryLabelColor : Self.text
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
}

@MainActor
class SurfaceView: NSView {
    override var isFlipped: Bool { true }
    init(color: NSColor = WorkspaceStyle.panel) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
    }
    required init?(coder: NSCoder) { fatalError("Use init(color:)") }
}

@MainActor
class WorkspaceButton: NSButton {
    private var hover = false
    private var tracking: NSTrackingArea?

    init(title: String = "", symbol: String? = nil, target: AnyObject? = nil, action: Selector? = nil) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        bezelStyle = .regularSquare
        font = .systemFont(ofSize: 11)
        contentTintColor = WorkspaceStyle.text
        focusRingType = .exterior
        setButtonType(.momentaryPushIn)
        if let symbol {
            image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            imagePosition = .imageOnly
        }
        setAccessibilityLabel(title)
    }
    required init?(coder: NSCoder) { fatalError("Use init(title:)") }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { hover = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hover = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if state == .on || (isEnabled && (hover || isHighlighted)) {
            (state == .on ? NSColor(white: 0.20, alpha: 1) : WorkspaceStyle.control).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3).fill()
        }
        super.draw(dirtyRect)
    }
    override var focusRingMaskBounds: NSRect { bounds.insetBy(dx: 2, dy: 2) }
    override func drawFocusRingMask() { NSBezierPath(roundedRect: focusRingMaskBounds, xRadius: 3, yRadius: 3).fill() }
}

@MainActor
final class ToolGroupButton: WorkspaceButton {
    var flyout: NSMenu?
    override func mouseDown(with event: NSEvent) { showFlyout() }
    override func rightMouseDown(with event: NSEvent) { showFlyout() }
    override func performClick(_ sender: Any?) { showFlyout() }
    override func accessibilityPerformPress() -> Bool { showFlyout(); return true }
    private func showFlyout() { flyout?.popUp(positioning: nil, at: NSPoint(x: bounds.maxX, y: bounds.maxY), in: self) }
}

@MainActor
final class SidebarDivider: NSControl {
    var resize: ((CGFloat) -> Void)?
    var currentWidth: CGFloat = 300
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return true }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return true }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeLeftRight) }
    override func draw(_ dirtyRect: NSRect) {
        WorkspaceStyle.divider.setFill()
        NSRect(x: bounds.midX.rounded(), y: 0, width: 1, height: bounds.height).fill()
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
        }
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func mouseDragged(with event: NSEvent) {
        guard let parent = superview else { return }
        let position = parent.convert(event.locationInWindow, from: nil)
        resize?(parent.bounds.maxX - position.x)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 123 { resize?(currentWidth + 8) }
        else if event.keyCode == 124 { resize?(currentWidth - 8) }
        else { super.keyDown(with: event) }
    }
    override func accessibilityRole() -> NSAccessibility.Role? { .splitter }
    override func accessibilityValue() -> Any? { currentWidth }
    override func accessibilityPerformIncrement() -> Bool { resize?(currentWidth + 8); return true }
    override func accessibilityPerformDecrement() -> Bool { resize?(currentWidth - 8); return true }
}

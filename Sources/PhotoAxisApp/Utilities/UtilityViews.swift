import AppKit
import PhotoAxisCore

@MainActor
final class UtilityPanel: NSView {
    let stack = NSStackView(), status = NSTextField(wrappingLabelWithString: "")
    private let scroll = NSScrollView(), content = SurfaceView()
    init(identifier: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 600)); setAccessibilityIdentifier(identifier)
        scroll.hasVerticalScroller = true; scroll.drawsBackground = false; scroll.documentView = content
        scroll.frame = bounds; scroll.autoresizingMask = [.width, .height]; addSubview(scroll)
        content.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(stack)
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        status.setAccessibilityIdentifier(identifier + ".status")
        let bottom = stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10); bottom.priority = .defaultHigh
        bottom.isActive = true
        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.contentView.heightAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 10), stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -10)])
    }
    required init?(coder: NSCoder) { fatalError("Use identifier initializer") }
    func append(_ view: NSView) { stack.addArrangedSubview(view); view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
    func note(_ value: String, heading: Bool = false) {
        let label = NSTextField(wrappingLabelWithString: value); label.font = heading ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 11)
        if !heading { label.textColor = .secondaryLabelColor }; append(label)
    }
}

/// Fitted preview and a top-left pixel selection on the same canvas used by the editor.
@MainActor
final class UtilityCanvasView: NSView {
    override var isFlipped: Bool { true }
    var image: NSImage { didSet { needsDisplay = true } }
    let sourceSize: CanvasSize
    var regions: [EvidenceRegion] = [] { didSet { needsDisplay = true } }
    let multiple: Bool
    let selectable: Bool
    var selectionChanged: (([EvidenceRegion]) -> Void)?
    var selectionLimit: (() -> Void)?
    var cancel: (() -> Void)?
    private var start: Point2D?
    private var end: Point2D?
    init(image: CGImage, sourceSize: CanvasSize, selectable: Bool = false, multiple: Bool = false) {
        self.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        self.sourceSize = sourceSize; self.multiple = multiple; self.selectable = selectable
        super.init(frame: .zero); setAccessibilityIdentifier("utility.canvas"); setAccessibilityRole(.image)
    }
    required init?(coder: NSCoder) { fatalError("Use image initializer") }
    override var acceptsFirstResponder: Bool { selectable }
    var imageRect: CGRect {
        let scale = max(0, min((bounds.width - 24) / Double(sourceSize.width), (bounds.height - 24) / Double(sourceSize.height)))
        return CGRect(x: (bounds.width - Double(sourceSize.width) * scale) / 2, y: (bounds.height - Double(sourceSize.height) * scale) / 2,
                      width: Double(sourceSize.width) * scale, height: Double(sourceSize.height) * scale)
    }
    func sourcePoint(_ point: CGPoint, clamp: Bool = false) -> Point2D? {
        let rect = imageRect
        guard rect.width > 0, rect.height > 0, clamp || rect.contains(point) else { return nil }
        return Point2D(x: min(Double(sourceSize.width), max(0, (point.x - rect.minX) / rect.width * Double(sourceSize.width))),
                       y: min(Double(sourceSize.height), max(0, (point.y - rect.minY) / rect.height * Double(sourceSize.height))))
    }
    override func resetCursorRects() { if selectable { addCursorRect(imageRect, cursor: .crosshair) } }
    override func layout() { super.layout(); window?.invalidateCursorRects(for: self) }
    override func draw(_ dirtyRect: NSRect) {
        WorkspaceStyle.canvas.setFill(); bounds.fill()
        let rect = imageRect; guard rect.width > 0 else { return }
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        var selections = regions
        if let start, let end, let region = InvestigationCaptureView.region(from: start, to: end) { selections.append(region) }
        NSColor.systemBlue.setStroke()
        for region in selections {
            let box = NSRect(x: rect.minX + Double(region.x) / Double(sourceSize.width) * rect.width,
                y: rect.minY + Double(region.y) / Double(sourceSize.height) * rect.height,
                width: Double(region.width) / Double(sourceSize.width) * rect.width,
                height: Double(region.height) / Double(sourceSize.height) * rect.height)
            let path = NSBezierPath(rect: box); path.lineWidth = 2; path.stroke()
        }
    }
    override func mouseDown(with event: NSEvent) {
        guard selectable else { return }; window?.makeFirstResponder(self)
        start = sourcePoint(convert(event.locationInWindow, from: nil)); end = start; needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard start != nil else { return }; end = sourcePoint(convert(event.locationInWindow, from: nil), clamp: true); needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        defer { start = nil; end = nil; needsDisplay = true }
        guard let start, let point = sourcePoint(convert(event.locationInWindow, from: nil), clamp: true),
              let region = InvestigationCaptureView.region(from: start, to: point) else { return }
        if multiple { guard regions.count < 20 else { selectionLimit?(); return }; regions.append(region) }
        else { regions = [region] }
        selectionChanged?(regions)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { cancel?() }
        else if [51, 117].contains(event.keyCode) { if !regions.isEmpty { regions.removeLast(); selectionChanged?(regions) } }
        else { super.keyDown(with: event) }
    }
    func updateImage(_ image: CGImage) { self.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)) }
}

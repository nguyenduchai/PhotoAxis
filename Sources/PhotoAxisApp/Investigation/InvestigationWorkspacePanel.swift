import AppKit
import PhotoAxisCore

/// Scrollable native workspace page; editors live here rather than in dialogs.
@MainActor
final class InvestigationWorkspacePanel: NSView {
    let scroll = NSScrollView(), stack = NSStackView(), editor = NSStackView()
    let status = NSTextField(wrappingLabelWithString: "")
    private let content = SurfaceView()
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 300, height: 650))
        scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        scroll.frame = bounds; scroll.autoresizingMask = [.width, .height]
        addSubview(scroll); scroll.documentView = content
        content.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 9
        editor.orientation = .vertical; editor.alignment = .leading; editor.spacing = 6; editor.isHidden = true
        stack.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(stack)
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        status.setAccessibilityIdentifier("workspace.analysisStatus")
        append(status); append(editor)
        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.contentView.heightAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -10)
        ])
        // The bottom equality gives the scroll document its intrinsic content height.
        let bottom = stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10)
        bottom.priority = .defaultHigh; bottom.isActive = true
    }
    required init?(coder: NSCoder) { fatalError("Use init()") }
    func append(_ view: NSView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    func showEditor() {
        editor.isHidden = false; layoutSubtreeIfNeeded()
        scroll.contentView.scroll(to: .zero); scroll.reflectScrolledClipView(scroll.contentView)
    }
    func clearEditor() { for view in editor.arrangedSubviews { editor.removeArrangedSubview(view); view.removeFromSuperview() }; editor.isHidden = true }
    override func layout() { super.layout(); scroll.frame = bounds }
}

/// Coordinates always refer to the displayed source, including fitted margins.
/// Draft selections remain transient until the sidebar's Apply action.
@MainActor
final class InvestigationCaptureView: InvestigationOverlayView {
    enum Mode { case rectangle, rectangles, points }
    let mode: Mode
    var selectionChanged: (([EvidenceRegion], [Point2D]) -> Void)?
    var apply: (() -> Void)?
    var cancel: (() -> Void)?
    private var dragStart: Point2D?
    init(image: CGImage, sourceSize: CanvasSize, mode: Mode, regions: [EvidenceRegion] = []) {
        self.mode = mode
        super.init(image: image, sourceSize: sourceSize, regions: regions)
        setAccessibilityIdentifier("workspace.regionPicker")
        setAccessibilityRole(.group)
    }
    required init?(coder: NSCoder) { fatalError("Use capture initializer") }
    override var acceptsFirstResponder: Bool { true }
    var imageRect: CGRect {
        let scale = max(0, min((bounds.width - 24) / Double(sourceSize.width), (bounds.height - 24) / Double(sourceSize.height)))
        return CGRect(x: (bounds.width - Double(sourceSize.width) * scale) / 2,
                      y: (bounds.height - Double(sourceSize.height) * scale) / 2,
                      width: Double(sourceSize.width) * scale, height: Double(sourceSize.height) * scale)
    }
    func sourcePoint(_ viewPoint: CGPoint, clamp: Bool = false) -> Point2D? {
        let rect = imageRect
        guard rect.width > 0, rect.height > 0, clamp || rect.contains(viewPoint) else { return nil }
        return Point2D(x: min(Double(sourceSize.width), max(0, (viewPoint.x - rect.minX) / rect.width * Double(sourceSize.width))),
                       y: min(Double(sourceSize.height), max(0, (viewPoint.y - rect.minY) / rect.height * Double(sourceSize.height))))
    }
    static func region(from a: Point2D, to b: Point2D) -> EvidenceRegion? {
        guard [a.x, a.y, b.x, b.y].allSatisfy({ $0.isFinite && abs($0) < Double(Int.max) / 2 }) else { return nil }
        let x = Int(floor(min(a.x, b.x))), y = Int(floor(min(a.y, b.y)))
        let w = Int(ceil(max(a.x, b.x))) - x, h = Int(ceil(max(a.y, b.y))) - y
        guard w > 0, h > 0 else { return nil }; return EvidenceRegion(x: x, y: y, width: w, height: h)
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let point = sourcePoint(convert(event.locationInWindow, from: nil)) else { return }
        if mode == .points {
            guard points.count < 64 else { return }; points.append(point); publish()
        } else { dragStart = point }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let end = sourcePoint(convert(event.locationInWindow, from: nil), clamp: true) else { return }
        points = [start, end]; needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        guard mode != .points else { return }
        defer { dragStart = nil; points = []; needsDisplay = true }
        guard let start = dragStart, let end = sourcePoint(convert(event.locationInWindow, from: nil), clamp: true), let region = Self.region(from: start, to: end) else { return }
        if mode == .rectangle { regions = [region] } else { regions.append(region) }
        publish()
    }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: apply?()
        case 53: cancel?()
        case 51, 117:
            if mode == .points { if !points.isEmpty { points.removeLast() } }
            else if !regions.isEmpty { regions.removeLast() }; publish()
        default: super.keyDown(with: event)
        }
    }
    func resetSelection() { regions = []; points = []; dragStart = nil; publish() }
    private func publish() { needsDisplay = true; selectionChanged?(regions, points) }
}

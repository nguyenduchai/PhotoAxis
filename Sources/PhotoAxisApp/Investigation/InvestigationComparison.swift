import AppKit

@MainActor
final class InvestigationComparisonView: NSView {
    let original, processed: CGImage
    var zoom = 1.0
    var offset = CGPoint.zero
    var split = 0.5 { didSet { needsDisplay = true } }
    var swipe = false { didSet { needsDisplay = true } }
    var navigationChanged: (() -> Void)?
    private var dragPoint: CGPoint?
    init(original: CGImage, processed: CGImage) {
        self.original = original; self.processed = processed
        super.init(frame: CGRect(x: 0, y: 0, width: 900, height: 580))
        setAccessibilityIdentifier("investigation.comparison.canvas"); setAccessibilityLabel("Source and processed image comparison")
    }
    required init?(coder: NSCoder) { fatalError("Use init(original:processed:)") }
    override var acceptsFirstResponder: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        func draw(_ image: CGImage, area: CGRect) {
            let factor = min(area.width / Double(image.width), area.height / Double(image.height)) * zoom
            let size = CGSize(width: Double(image.width) * factor, height: Double(image.height) * factor)
            context.saveGState(); context.clip(to: area)
            context.draw(image, in: CGRect(x: area.midX - size.width / 2 + offset.x, y: area.midY - size.height / 2 + offset.y, width: size.width, height: size.height))
            context.restoreGState()
        }
        if swipe {
            draw(original, area: bounds); context.saveGState()
            context.clip(to: CGRect(x: bounds.width * split, y: 0, width: bounds.width * (1 - split), height: bounds.height))
            draw(processed, area: bounds); context.restoreGState()
        } else {
            draw(original, area: CGRect(x: 0, y: 0, width: bounds.width / 2 - 2, height: bounds.height))
            draw(processed, area: CGRect(x: bounds.width / 2 + 2, y: 0, width: bounds.width / 2 - 2, height: bounds.height))
        }
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); dragPoint = convert(event.locationInWindow, from: nil) }
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let previous = dragPoint { offset.x += point.x - previous.x; offset.y += point.y - previous.y; needsDisplay = true }
        dragPoint = point
    }
    override func mouseUp(with event: NSEvent) { dragPoint = nil }
    override func scrollWheel(with event: NSEvent) { offset.x -= event.scrollingDeltaX; offset.y += event.scrollingDeltaY; needsDisplay = true }
    override func magnify(with event: NSEvent) { setZoom(zoom * (1 + event.magnification)) }
    func setZoom(_ value: Double) { guard value.isFinite else { return }; zoom = min(16, max(0.1, value)); needsDisplay = true; navigationChanged?() }
    func reset() { zoom = 1; offset = .zero; needsDisplay = true; navigationChanged?() }
}

@MainActor
final class InvestigationComparisonPanel: NSView {
    let comparison: InvestigationComparisonView
    private let zoomLabel = NSTextField(labelWithString: "100 %")
    init(original: CGImage, processed: CGImage, localization: L10n) {
        comparison = InvestigationComparisonView(original: original, processed: processed)
        super.init(frame: CGRect(x: 0, y: 0, width: 850, height: 650))
        let label = NSTextField(wrappingLabelWithString: localization.text("investigation.compareHelp"))
        let mode = NSButton(checkboxWithTitle: localization.text("investigation.swipe"), target: self, action: #selector(toggleMode(_:)))
        let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: self, action: #selector(moveSplit(_:)))
        slider.setAccessibilityIdentifier("investigation.comparison.split")
        let reset = NSButton(title: localization.text("action.reset"), target: self, action: #selector(resetView))
        let controls = NSStackView(views: [mode, slider, reset]); controls.spacing = 12
        let less = NSButton(title: "−", target: self, action: #selector(zoomOut)), more = NSButton(title: "+", target: self, action: #selector(zoomIn))
        less.setAccessibilityLabel(localization.text("investigation.zoomOut")); more.setAccessibilityLabel(localization.text("investigation.zoomIn"))
        let zoomControls = NSStackView(views: [less, zoomLabel, more]); zoomControls.spacing = 12
        comparison.navigationChanged = { [weak self] in guard let self else { return }; zoomLabel.stringValue = String(format: "%.0f %%", comparison.zoom * 100) }
        let stack = NSStackView(views: [label, controls, zoomControls, comparison]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: self.topAnchor, constant: 20), stack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -20),
            comparison.widthAnchor.constraint(equalTo: stack.widthAnchor), comparison.heightAnchor.constraint(greaterThanOrEqualToConstant: 280), slider.widthAnchor.constraint(equalToConstant: 200)])
    }
    required init?(coder: NSCoder) { fatalError("Use init(original:processed:localization:)") }
    @objc private func toggleMode(_ sender: NSButton) { comparison.swipe = sender.state == .on }
    @objc private func moveSplit(_ sender: NSSlider) { comparison.split = sender.doubleValue }
    @objc private func resetView() { comparison.reset() }
    @objc private func zoomOut() { comparison.setZoom(comparison.zoom / 1.25) }
    @objc private func zoomIn() { comparison.setZoom(comparison.zoom * 1.25) }
}

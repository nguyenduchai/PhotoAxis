import AppKit
import PhotoAxisCore

@MainActor
final class InvestigationOverlayView: NSView {
    override var isFlipped: Bool { true }
    let image: NSImage
    let sourceSize: CanvasSize
    var regions: [EvidenceRegion]
    var reference: [Point2D]
    var points: [Point2D]
    var closed: Bool
    init(image: CGImage, sourceSize: CanvasSize, regions: [EvidenceRegion] = [], reference: [Point2D] = [], points: [Point2D] = [], closed: Bool = false) {
        self.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)); self.sourceSize = sourceSize
        self.regions = regions; self.reference = reference; self.points = points; self.closed = closed
        super.init(frame: .zero); setAccessibilityIdentifier("investigation.analysisPreview"); setAccessibilityRole(.image)
    }
    required init?(coder: NSCoder) { fatalError("Use image initializer") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        let scale = min((bounds.width - 24) / Double(sourceSize.width), (bounds.height - 24) / Double(sourceSize.height))
        guard scale > 0 else { return }
        let rect = NSRect(x: (bounds.width - Double(sourceSize.width) * scale) / 2, y: (bounds.height - Double(sourceSize.height) * scale) / 2,
                          width: Double(sourceSize.width) * scale, height: Double(sourceSize.height) * scale)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        func point(_ p: Point2D) -> NSPoint { NSPoint(x: rect.minX + p.x * scale, y: rect.minY + p.y * scale) }
        NSColor.systemOrange.setStroke()
        for region in regions { let path = NSBezierPath(rect: NSRect(x: rect.minX + Double(region.x) * scale, y: rect.minY + Double(region.y) * scale, width: Double(region.width) * scale, height: Double(region.height) * scale)); path.lineWidth = 2; path.stroke() }
        func drawLine(_ values: [Point2D], color: NSColor, close: Bool) {
            guard let first = values.first else { return }; let path = NSBezierPath(); path.move(to: point(first))
            for p in values.dropFirst() { path.line(to: point(p)) }; if close { path.close() }; color.setStroke(); path.lineWidth = 3; path.stroke()
            color.setFill()
            for (i, p) in values.enumerated() {
                let pos = point(p); NSBezierPath(ovalIn: NSRect(x: pos.x - 4, y: pos.y - 4, width: 8, height: 8)).fill()
                (String(i + 1) as NSString).draw(at: NSPoint(x: pos.x + 6, y: pos.y + 4), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: color, .backgroundColor: NSColor.black])
            }
        }
        drawLine(reference, color: .systemGreen, close: false); drawLine(points, color: .systemRed, close: closed)
    }
}

/// The source remains visible while a human reviews transcription. Engine text
/// is read-only, and confirmation never overwrites recognition or image pixels.
@MainActor
final class InvestigationReviewController: NSWindowController {
    let confirmed = NSTextView(), status = NSTextField(wrappingLabelWithString: "")
    private let localization: L10n
    private var confirm: (() throws -> Void)?
    init(localization: L10n, title: String, image: CGImage, sourceSize: CanvasSize, summary: String,
         regions: [EvidenceRegion] = [], reference: [Point2D] = [], points: [Point2D] = [], closed: Bool = false,
         recognized: String? = nil, confirmedText: String = "", onConfirm: ((String) throws -> Void)? = nil) {
        self.localization = localization
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(window: window); window.title = title; window.minSize = NSSize(width: 960, height: 700); window.center(); window.setAccessibilityIdentifier("investigation.reviewWindow")
        let preview = InvestigationOverlayView(image: image, sourceSize: sourceSize, regions: regions, reference: reference, points: points, closed: closed)
        let caption = NSTextField(wrappingLabelWithString: summary); caption.setAccessibilityIdentifier("investigation.analysisSummary")
        caption.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let right = NSStackView(); right.orientation = .vertical; right.alignment = .leading; right.spacing = 10
        right.addArrangedSubview(caption)
        if let recognized {
            let raw = NSTextView(); raw.string = recognized; raw.isEditable = false; raw.isSelectable = true; raw.font = .systemFont(ofSize: 15)
            raw.setAccessibilityIdentifier("investigation.ocrRecognized")
            let rawScroll = NSScrollView(); rawScroll.documentView = raw; rawScroll.hasVerticalScroller = true; rawScroll.borderType = .bezelBorder
            right.addArrangedSubview(NSTextField(labelWithString: localization.text("investigation.ocrRecognized"))); right.addArrangedSubview(rawScroll)
            confirmed.string = confirmedText; confirmed.font = .systemFont(ofSize: 15); confirmed.setAccessibilityIdentifier("investigation.ocrConfirmed")
            let reviewScroll = NSScrollView(); reviewScroll.documentView = confirmed; reviewScroll.hasVerticalScroller = true; reviewScroll.borderType = .bezelBorder
            right.addArrangedSubview(NSTextField(labelWithString: localization.text("investigation.ocrConfirmed"))); right.addArrangedSubview(reviewScroll)
            let button = NSButton(title: localization.text("investigation.confirmOCR"), target: self, action: #selector(confirmText)); button.setAccessibilityIdentifier("investigation.confirmOCR")
            right.addArrangedSubview(button)
            self.confirm = { [weak self] in guard let self else { return }; try onConfirm?(self.confirmed.string) }
            for scroll in [rawScroll, reviewScroll] { scroll.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true; scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true }
            status.stringValue = localization.text("investigation.ocrReviewHelp")
        }
        right.addArrangedSubview(status)
        let body = NSStackView(views: [preview, right]); body.spacing = 16; body.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(body)
        NSLayoutConstraint.activate([body.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 16), body.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -16),
                                     body.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 16), body.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -16),
                                     preview.widthAnchor.constraint(equalTo: body.widthAnchor, multiplier: 0.52), preview.heightAnchor.constraint(equalTo: body.heightAnchor), right.heightAnchor.constraint(equalTo: body.heightAnchor), caption.widthAnchor.constraint(equalTo: right.widthAnchor), status.widthAnchor.constraint(equalTo: right.widthAnchor)])
    }
    required init?(coder: NSCoder) { fatalError("Use analysis initializer") }
    @objc func confirmText() {
        do { try confirm?(); status.stringValue = localization.text("investigation.ocrConfirmationSaved") }
        catch { status.stringValue = localization.text((error as? InvestigationError)?.localizationKey ?? "investigation.error.auditUnavailable") }
    }
}

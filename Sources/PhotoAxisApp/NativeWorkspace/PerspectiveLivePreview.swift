import AppKit

@MainActor final class PerspectiveLivePreview: SurfaceView {
    let imageView = ScanImageView()
    let title: NSTextField
    init(localization: L10n) {
        title = WorkspaceStyle.label(localization.text("preview.live"),size:11)
        super.init(color:WorkspaceStyle.panel)
        identifier = .init("perspective.livePreview"); setAccessibilityLabel(title.stringValue)
        addSubview(title); addSubview(imageView); isHidden = true
    }
    required init?(coder:NSCoder) { fatalError("Use init(localization:)") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() {
        super.layout(); title.frame = NSRect(x:8,y:5,width:bounds.width-16,height:18)
        imageView.frame = NSRect(x:5,y:27,width:bounds.width-10,height:bounds.height-32)
    }
}

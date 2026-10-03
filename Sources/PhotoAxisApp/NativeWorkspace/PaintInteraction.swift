import AppKit
import PhotoAxisCore

@MainActor final class PaintCursorView: NSView {
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    var point: NSPoint?, sourcePoint: NSPoint?, radius = 20.0
    override func draw(_ dirtyRect: NSRect) {
        guard let point else { return }
        let path = NSBezierPath(ovalIn:NSRect(x:point.x-radius,y:point.y-radius,width:radius*2,height:radius*2))
        NSColor.black.setStroke(); path.lineWidth = 2; path.stroke(); NSColor.white.setStroke(); path.lineWidth = 1; path.stroke()
        if let p = sourcePoint {
            let cross = NSBezierPath(); cross.move(to:NSPoint(x:p.x-7,y:p.y)); cross.line(to:NSPoint(x:p.x+7,y:p.y))
            cross.move(to:NSPoint(x:p.x,y:p.y-7)); cross.line(to:NSPoint(x:p.x,y:p.y+7))
            NSColor.systemOrange.setStroke(); cross.lineWidth = 2; cross.stroke()
        }
    }
}

@MainActor final class PaintInteraction {
    weak var canvas: WelcomeCanvasView?
    private weak var owner: PhotoDocument?
    private var sampling: Task<Void,Never>?
    private var token = UUID()
    private(set) var cloneSource: EmbeddedImage?
    private(set) var sourceAnchor: Point2D?
    private var alignedOffset: Point2D?
    private var sourceCanvas: CanvasSize?
    init(canvas: WelcomeCanvasView) { self.canvas = canvas }
    func reset() {
        token = UUID(); sampling?.cancel(); sampling = nil
        let previous = owner; owner = nil; previous?.cancelSession()
        cloneSource = nil; sourceAnchor = nil; alignedOffset = nil; sourceCanvas = nil
        canvas?.paintCursor.point = nil; canvas?.paintCursor.sourcePoint = nil; canvas?.paintCursor.needsDisplay = true
    }
    private func point(_ view: NSPoint) -> Point2D? {
        guard let c = canvas, let d = c.document, let viewport = c.presentedViewport, c.presentedModel?.canvas == d.model.canvas,
              let p = Optional(viewport.transform.documentPoint(fromView:Point2D(x:view.x,y:view.y))),
              p.x >= 0, p.y >= 0, p.x <= Double(d.model.canvas.width), p.y <= Double(d.model.canvas.height) else { return nil }
        return p
    }
    func cursor(_ view: NSPoint) {
        guard let c = canvas, let d = c.document else { return }
        c.paintCursor.point = view; c.paintCursor.radius = d.brushSettings.diameter*d.viewport.zoom/d.viewport.backingScale/2
        c.paintCursor.sourcePoint = nil
        if d.activeTool == .cloneStamp, sourceCanvas == d.model.canvas,
           let source = alignedOffset.flatMap({ offset in point(view).map { Point2D(x:$0.x+offset.x,y:$0.y+offset.y) } }) ?? sourceAnchor {
            let p = d.viewport.transform.viewPoint(fromDocument:source); c.paintCursor.sourcePoint = NSPoint(x:p.x,y:p.y)
        }
        c.paintCursor.needsDisplay = true
    }
    func down(_ view: NSPoint, option: Bool) {
        guard let c = canvas, let d = c.document, let p = point(view), d.canPaint else { return }
        cursor(view)
        if d.activeTool == .cloneStamp && option { pickSource(p); return }
        if sourceCanvas != d.model.canvas { cloneSource = nil; sourceAnchor = nil; alignedOffset = nil }
        do {
            if d.activeTool == .cloneStamp {
                guard sampling == nil, let source = cloneSource, let anchor = sourceAnchor else { d.paintMessageKey = "paint.needSource"; d.changed?(); return }
                let offset = d.brushSettings.aligned ? (alignedOffset ?? Point2D(x:anchor.x-p.x,y:anchor.y-p.y)) : Point2D(x:anchor.x-p.x,y:anchor.y-p.y)
                try d.startPaint(at:p,source:source,offset:offset)
                if d.brushSettings.aligned { alignedOffset = offset }
            } else { try d.startPaint(at:p) }
            owner = d; d.paintMessageKey = "paint.help"
        } catch { d.paintMessageKey = "paint.limit"; d.changed?(); NSSound.beep() }
    }
    func drag(_ view: NSPoint) {
        cursor(view)
        guard let d = owner, d === canvas?.document, d.paintSession != nil, let p = point(view) else { return }
        do { try d.extendPaint(to:p) } catch { d.paintMessageKey = "paint.limit"; d.changed?() }
    }
    func up(_ view: NSPoint) {
        guard let d = owner else { return }; drag(view)
        d.finishPaint(); owner = nil
    }
    func cancel() { owner?.cancelSession(); owner = nil }
    func resetAlignment() { alignedOffset = nil }
    func chooseSourceAtCursor() { if let view = canvas?.paintCursor.point, let p = point(view) { pickSource(p) } }
    private func pickSource(_ p: Point2D) {
        guard let c = canvas, let d = c.document, !d.hasSession, let pipeline = c.imagePipeline else { return }
        sampling?.cancel(); token = UUID(); let request = token, snapshot = d.snapshot()
        // Preflight the worst-case new source before decoding/allocating a full canvas.
        guard d.importBudget.remainingPixels >= d.model.canvas.pixelCount else { d.paintMessageKey = "paint.limit"; d.changed?(); return }
        cloneSource = nil; sourceAnchor = nil; alignedOffset = nil
        d.paintMessageKey = "paint.sampling"; d.changed?()
        sampling = Task { [weak self, weak d] in
            do {
                let asset = try await pipeline.cloneSnapshot(snapshot,name:"Clone source snapshot")
                try Task.checkCancellation()
                guard let self, let d, token == request else { return }
                sampling = nil
                guard d === canvas?.document, d.model == snapshot.model else { d.paintMessageKey = "paint.needSource"; d.changed?(); return }
                cloneSource = asset; sourceAnchor = p; sourceCanvas = d.model.canvas; sampling = nil
                d.paintMessageKey = "paint.sourceReady"; d.changed?()
            } catch {
                guard let self, let d, token == request else { return }
                sampling = nil; d.paintMessageKey = "paint.pickError"; d.changed?()
            }
        }
    }
}

@MainActor final class PaintControlsView: NSStackView, NSTextFieldDelegate {
    weak var document: PhotoDocument?
    var settingsChanged: (() -> Void)?
    var alignmentChanged: (() -> Void)?
    let fields = (0..<3).map { _ in NSTextField(string:"") }
    let sliders = (0..<3).map { _ in NSSlider() }
    let aligned = NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let help = WorkspaceStyle.label("",size:10,secondary:true)
    private let localization: L10n
    init(localization: L10n) {
        self.localization = localization
        super.init(frame:NSRect(x:0,y:0,width:660,height:24)); orientation = .horizontal; spacing = 5; alignment = .centerY
        for (i,key) in ["paint.size","paint.hardness","paint.opacity"].enumerated() {
            addArrangedSubview(WorkspaceStyle.label(localization.text(key),size:10))
            let field = fields[i], slider = sliders[i]
            field.tag = i; field.delegate = self; field.widthAnchor.constraint(equalToConstant:38).isActive = true
            field.font = .systemFont(ofSize:10); field.identifier = .init(key); field.setAccessibilityLabel(localization.text(key))
            slider.tag = i; slider.minValue = i == 0 ? 1:0; slider.maxValue = i == 0 ? 1000:100
            slider.isContinuous = true; slider.target = self; slider.action = #selector(slide(_:)); slider.widthAnchor.constraint(equalToConstant:52).isActive = true
            slider.identifier = .init(key+".slider"); slider.setAccessibilityLabel(localization.text(key)); addArrangedSubview(field); addArrangedSubview(slider)
            addArrangedSubview(WorkspaceStyle.label(i == 0 ? "px":"%",size:10,secondary:true))
        }
        aligned.title = localization.text("paint.aligned"); aligned.font = .systemFont(ofSize:10); aligned.target = self; aligned.action = #selector(toggleAligned)
        aligned.identifier = .init("paint.aligned"); addArrangedSubview(aligned)
        help.lineBreakMode = .byTruncatingTail; help.widthAnchor.constraint(lessThanOrEqualToConstant:110).isActive = true; addArrangedSubview(help)
    }
    required init?(coder:NSCoder) { fatalError("Use init(localization:)") }
    func refresh(_ d: PhotoDocument?) {
        document = d; guard let d else { return }
        let values = [d.brushSettings.diameter,d.brushSettings.hardness*100,d.brushSettings.opacity*100]
        for i in fields.indices {
            if fields[i].currentEditor() == nil { fields[i].stringValue = DocumentNumber.format(values[i],language:Locale.current.identifier) }
            sliders[i].doubleValue = values[i]; fields[i].isEnabled = !d.isInteractionLocked; sliders[i].isEnabled = !d.isInteractionLocked
        }
        aligned.isHidden = d.activeTool != .cloneStamp; aligned.state = d.brushSettings.aligned ? .on:.off
        let key = d.activeTool == .cloneStamp && d.paintMessageKey == "paint.help" ? "paint.cloneHelp":d.paintMessageKey
        help.stringValue = localization.text(d.canPaint ? key:"paint.unavailable"); help.toolTip = help.stringValue
    }
    private func change(_ i: Int, value: Double) {
        guard let d = document, value.isFinite, (sliders[i].minValue...sliders[i].maxValue).contains(value) else { return }
        switch i { case 0: d.brushSettings.diameter = value; case 1: d.brushSettings.hardness = value/100; default: d.brushSettings.opacity = value/100 }
        settingsChanged?(); d.changed?()
    }
    @objc private func slide(_ sender: NSSlider) { change(sender.tag,value:sender.doubleValue) }
    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, let value = DocumentNumber.parse(field.stringValue,language:Locale.current.identifier) else { return }
        change(field.tag,value:value)
    }
    @objc private func toggleAligned() { document?.brushSettings.aligned = aligned.state == .on; alignmentChanged?(); settingsChanged?(); document?.changed?() }
}

import AppKit
import MetalKit
import CoreImage
import PhotoAxisCore

@MainActor
final class MetalPresentationView: MTKView, MTKViewDelegate {
    private let presentation: CIContext?
    private let queue: (any MTLCommandQueue)?
    var image: CGImage? { didSet { needsDisplay = true } }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    init() {
        let device = MTLCreateSystemDefaultDevice()
        presentation = device.map { CIContext(mtlDevice: $0, options: [.cacheIntermediates: false]) }
        queue = device?.makeCommandQueue()
        super.init(frame: .zero, device: device)
        framebufferOnly = false; isPaused = true; enableSetNeedsDisplay = true
        colorPixelFormat = .bgra8Unorm; colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        delegate = self
    }
    required init(coder: NSCoder) { fatalError("Use init()") }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard let image, let drawable = currentDrawable, let buffer = queue?.makeCommandBuffer(), let presentation else { return }
        // Evaluation/decoding already completed off-main. This encodes only presentation of the viewport bitmap.
        let bitmap = CIImage(cgImage:image).transformed(by:.init(scaleX:drawableSize.width/CGFloat(image.width),y:drawableSize.height/CGFloat(image.height)))
        presentation.render(bitmap, to: drawable.texture, commandBuffer: buffer,
                            bounds: CGRect(origin: .zero, size: drawableSize), colorSpace: colorspace!)
        buffer.present(drawable); buffer.commit()
    }
}

@MainActor
final class CanvasBorderOverlay: NSView {
    var rectangle: NSRect = .zero { didSet { needsDisplay = true } }
    var selectedCorners: [NSPoint] = [] { didSet { needsDisplay = true } }
    var selectionBounds: NSRect? { didSet { needsDisplay = true } }
    var showsHandles = false { didSet { needsDisplay = true } }
    var handlePoints: [NSPoint] {
        guard let r = selectionBounds, showsHandles else { return [] }
        return [.init(x:r.minX,y:r.minY),.init(x:r.midX,y:r.minY),.init(x:r.maxX,y:r.minY),.init(x:r.maxX,y:r.midY),
                .init(x:r.maxX,y:r.maxY),.init(x:r.midX,y:r.maxY),.init(x:r.minX,y:r.maxY),.init(x:r.minX,y:r.midY),.init(x:r.midX,y:r.minY-24)]
    }
    func hitHandle(_ point:NSPoint)->Int? { handlePoints.firstIndex { hypot(point.x-$0.x,point.y-$0.y) <= 7 } }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.85, alpha: 0.8).setStroke()
        let path = NSBezierPath(rect: rectangle); path.lineWidth = 1; path.stroke()
        guard selectedCorners.count >= 3 else { return }
        NSColor.controlAccentColor.setStroke()
        let selected = NSBezierPath(); selected.move(to:selectedCorners[0]); selectedCorners.dropFirst().forEach{selected.line(to:$0)}; selected.close(); selected.stroke()
        guard let box = selectionBounds, showsHandles else { return }
        let outline = NSBezierPath(rect:box); outline.setLineDash([3,3],count:2,phase:0); outline.stroke()
        let stem = NSBezierPath(); stem.move(to:.init(x:box.midX,y:box.minY)); stem.line(to:.init(x:box.midX,y:box.minY-24)); stem.stroke()
        for (index,p) in handlePoints.enumerated() {
            NSColor.white.setFill()
            let rect = NSRect(x:p.x-3.5,y:p.y-3.5,width:7,height:7)
            let handle = index == 8 ? NSBezierPath(ovalIn:rect) : NSBezierPath(rect:rect)
            handle.fill(); handle.stroke()
        }
    }
}

@MainActor
final class WelcomeCanvasView: SurfaceView {
    var toggleChrome: (() -> Void)?
    var newDocument: (() -> Void)?
    var openImages: (() -> Void)?
    var importImages: (([ImageInput]) -> Void)?
    var viewportChanged: (() -> Void)?
    var toolChanged: ((ToolKind) -> Void)?
    var renderFailed: ((String) -> Void)?
    private(set) var document: PhotoDocument?
    private var pipeline: ImagePipeline?
    var imagePipeline: ImagePipeline? { pipeline }
    lazy var editing = CanvasEditing(canvas:self)
    lazy var contentEditing=ContentInteraction(canvas:self,localization:localization)
    lazy var painting = PaintInteraction(canvas:self)
    let paintCursor = PaintCursorView()
    lazy var livePerspective = PerspectiveLivePreview(localization:localization)
    private var paintTracking: NSTrackingArea?
    private var livePerspectiveTask: Task<Void,Never>?
    private var livePerspectiveKey: PhotoDocumentModel?
    private let localization: L10n
    let metal = MetalPresentationView()
    let overlay = CanvasBorderOverlay()
    let cropOverlay = CropOverlay()
    let perspectiveOverlay = PerspectiveOverlay()
    lazy var perspectiveEditing = PerspectiveInteraction(canvas:self)
    lazy var cropping = CropInteraction(canvas:self)
    private let welcome = NSStackView(frame: NSRect(x: 0, y: 0, width: 430, height: 180))
    private var renderTask: Task<Void, Never>?
    private var settleTask: Task<Void,Never>?
    private struct RenderKey: Equatable {
        let model: PhotoDocumentModel, viewport: ViewportState
        let selectedID: UUID?
        let handles: Bool
        let samplingScale: Double
        let lightweightClip: Bool
        let appearance: CanvasAppearance
    }
    var showsBrushOutline = true { didSet { updatePaintCursorVisibility() } }
    private func updatePaintCursorVisibility() {
        paintCursor.isHidden = !showsBrushOutline || spaceHeld || (document.map { $0.activeTool != .brush && $0.activeTool != .cloneStamp } ?? true)
    }
    var canvasAppearance = CanvasAppearance() { didSet { if canvasAppearance != oldValue { surfaceColor = NSColor(white:canvasAppearance.background.gray,alpha:1); requestRender() } } }
    private var requestedKey: RenderKey?
    private var generation = UUID()
    private var panStart: NSPoint?
    private var lastPointer: NSPoint?
    private var cursorPoint: NSPoint?
    private var cursorModifiers: NSEvent.ModifierFlags = []
    private var dragCursor: CanvasCursorKind?
    private(set) var spaceHeld = false
    private(set) var presentedViewport: ViewportState?
    private(set) var presentedModel: PhotoDocumentModel?
    private(set) var presentedIsInteractive = false
    override var acceptsFirstResponder: Bool { true }
    override var undoManager: UndoManager? { document?.undoManager }

    init(localization: L10n) {
        self.localization = localization
        super.init(color: WorkspaceStyle.canvas)
        identifier = .init("workspace.canvas"); setAccessibilityLabel(localization.text("workspace.canvas"))
        let brand = WorkspaceStyle.label("PhotoAxis", size: 26); brand.font = .systemFont(ofSize: 26, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: localization.text("welcome.subtitle"))
        subtitle.font = .systemFont(ofSize: 12); subtitle.textColor = .secondaryLabelColor; subtitle.alignment = .center
        let actions = NSStackView()
        for (key, selector) in [("action.new", #selector(makeNew)), ("action.open", #selector(openFiles))] {
            let button = NSButton(title: localization.text(key), target: self, action: selector)
            button.bezelStyle = .rounded; button.font = .systemFont(ofSize: 12); actions.addArrangedSubview(button)
        }
        actions.spacing = 12
        let notice = NSTextField(wrappingLabelWithString: localization.text("document.welcome"))
        notice.font = .systemFont(ofSize: 11); notice.textColor = .secondaryLabelColor; notice.alignment = .center
        welcome.orientation = .vertical; welcome.alignment = .centerX; welcome.spacing = 18
        for child in [brand, subtitle, actions, notice] { welcome.addArrangedSubview(child) }
        for child in [welcome, metal, overlay, cropOverlay, perspectiveOverlay, livePerspective, paintCursor] { addSubview(child) }
        // A transformed layer may extend beyond the viewport; its overlay must
        // never paint over the options bar, tabs or surrounding panels.
        overlay.wantsLayer = true; overlay.layer?.masksToBounds = true
        cropOverlay.wantsLayer=true;cropOverlay.layer?.masksToBounds=true;cropOverlay.isHidden=true
        perspectiveOverlay.wantsLayer=true;perspectiveOverlay.layer?.masksToBounds=true;perspectiveOverlay.isHidden=true
        metal.isHidden = true; overlay.isHidden = true
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("Use init(localization:)") }
    @objc private func makeNew() { newDocument?() }
    @objc private func openFiles() { openImages?() }
    func display(_ document: PhotoDocument?, pipeline: ImagePipeline) {
        let switched = self.document !== document || self.pipeline !== pipeline
        self.document = document; self.pipeline = pipeline
        welcome.isHidden = document != nil
        if switched { painting.reset(); livePerspectiveTask?.cancel(); livePerspectiveKey = nil; requestedKey = nil; settleTask?.cancel(); contentEditing.reset(); perspectiveEditing.reset(); cropping.reset(); editing.resetPointer(); spaceHeld = false; panStart = nil; lastPointer = nil; dragCursor = nil; cursorPoint = nil; metal.image = nil; metal.isHidden = true; overlay.isHidden = true; presentedViewport = nil; presentedModel = nil; presentedIsInteractive = false }
        resizeViewport(); updateCropOverlay(); updatePerspectiveOverlay(); updateLivePerspective(); updatePaintCursorVisibility(); contentEditing.refresh(); requestRender(interactive:document?.hasSession == true)
        window?.invalidateCursorRects(for: self)
    }
    override func layout() {
        super.layout()
        let width = min(430, max(0, bounds.width - 48))
        welcome.frame = NSRect(x: (bounds.width - width) / 2, y: max(24, bounds.midY - 90), width: width, height: 180)
        metal.frame = bounds; paintCursor.frame = bounds; livePerspective.frame = NSRect(x:max(8,bounds.width-252),y:8,width:244,height:190); overlay.frame = bounds; cropOverlay.frame = bounds; perspectiveOverlay.frame = bounds
        resizeViewport();contentEditing.refresh()
    }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); resizeViewport() }
    private func resizeViewport() {
        guard let document else { return }
        let scale = window?.backingScaleFactor ?? 1
        if document.viewport.width != bounds.width || document.viewport.height != bounds.height || document.viewport.backingScale != scale {
            document.viewport.resize(width: bounds.width, height: bounds.height, backingScale: scale, canvas: document.presentedModel.canvas)
            viewportChanged?(); requestRender()
        }
    }
    func updateCropOverlay() {
        guard let d=document,let crop=d.cropSession else{cropOverlay.isHidden=true;return}
        cropOverlay.isHidden=false;overlay.showsHandles=false;overlay.selectedCorners=[]
        let v=d.viewport, origin=v.transform.viewPoint(fromDocument:.init(x:0,y:0)),start=v.transform.viewPoint(fromDocument:.init(x:crop.region.x,y:crop.region.y))
        let scale=v.zoom/v.backingScale
        cropOverlay.canvasRect=NSRect(x:origin.x,y:origin.y,width:Double(d.model.canvas.width)*scale,height:Double(d.model.canvas.height)*scale)
        cropOverlay.cropRect=NSRect(x:start.x,y:start.y,width:crop.region.width*scale,height:crop.region.height*scale)
        cropOverlay.grid=crop.grid;cropOverlay.needsDisplay=true
    }
    func updatePerspectiveOverlay() {
        guard let d=document,let state=d.perspectiveSession,!state.showsPreview,
              let quad=state.quad,quad.points.count==4,let v=presentedViewport,
              presentedModel?.canvas==d.model.canvas else {perspectiveOverlay.isHidden=true;return}
        perspectiveOverlay.isHidden=false;overlay.showsHandles=false;overlay.selectedCorners=[]
        func view(_ p:Point2D)->NSPoint {let q=v.transform.viewPoint(fromDocument:p);return NSPoint(x:q.x,y:q.y)}
        let origin=view(.init(x:0,y:0)),scale=v.zoom/v.backingScale
        perspectiveOverlay.canvasRect=NSRect(x:origin.x,y:origin.y,width:Double(d.model.canvas.width)*scale,height:Double(d.model.canvas.height)*scale)
        perspectiveOverlay.corners=quad.points.map(view);perspectiveOverlay.isValid=state.isValid
        if state.grid,let size=state.output,let grid=try? quad.grid(in:d.model.canvas,output:size) {
            perspectiveOverlay.gridLines=grid.map{$0.map(view)}
        } else {perspectiveOverlay.gridLines=[]}
        perspectiveOverlay.needsDisplay=true
    }
    private func liveGeometryCandidate() -> PhotoDocumentModel? {
        guard let d = document else { return nil }
        if let state = d.perspectiveSession, !state.showsPreview, state.isValid { return state.candidate }
        if let state = d.cropSession, state.isValid {
            var next = d.model
            do { try next.crop(to:state.region,output:state.output); return next } catch { return nil }
        }
        return nil
    }
    func updateLivePerspective() {
        guard let d = document, let candidate = liveGeometryCandidate(), let pipeline else {
            livePerspectiveTask?.cancel(); livePerspectiveKey = nil; livePerspective.isHidden = true; return
        }
        livePerspective.isHidden = false
        guard livePerspectiveKey != candidate else { return }
        livePerspectiveKey = candidate; livePerspectiveTask?.cancel()
        let snapshot = ProjectSnapshot(model:candidate,assets:d.assets,stateID:d.history.stateID)
        livePerspectiveTask = Task { [weak self] in
            do {
                try await Task.sleep(for:.milliseconds(45))
                let image = try await pipeline.exportImage(snapshot:snapshot,options:ExportOptions(size:candidate.canvas,ppi:candidate.ppi),previewEdge:512)
                try Task.checkCancellation()
                guard let self, livePerspectiveKey == candidate, liveGeometryCandidate() == candidate else { return }
                livePerspective.imageView.image = NSImage(cgImage:image,size:.zero)
            } catch is CancellationError {} catch { self?.livePerspective.isHidden = true }
        }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let paintTracking { removeTrackingArea(paintTracking) }
        let area = NSTrackingArea(rect:.zero,options:[.mouseMoved,.mouseEnteredAndExited,.cursorUpdate,.activeInKeyWindow,.inVisibleRect],owner:self)
        paintTracking = area; addTrackingArea(area)
    }
    override func mouseMoved(with event: NSEvent) {
        updateCursor(with: event)
        if document?.activeTool == .brush || document?.activeTool == .cloneStamp { painting.cursor(convert(event.locationInWindow,from:nil)) }
    }
    override func mouseEntered(with event: NSEvent) { updateCursor(with: event) }
    override func cursorUpdate(with event: NSEvent) { updateCursor(with: event) }
    override func mouseExited(with event: NSEvent) { cursorPoint = nil; paintCursor.point = nil; paintCursor.needsDisplay = true }
    override func flagsChanged(with event: NSEvent) { cursorModifiers = event.modifierFlags; refreshCursor(); super.flagsChanged(with: event) }
    private func updateCursor(with event: NSEvent) {
        cursorPoint = convert(event.locationInWindow, from: nil); cursorModifiers = event.modifierFlags; refreshCursor()
    }
    private func refreshCursor() {
        guard let cursorPoint, bounds.contains(cursorPoint) else { return }
        CanvasCursors.cursor(cursorKind(at: cursorPoint, modifiers: cursorModifiers)).set()
    }
    func cursorKind(at point: NSPoint?, modifiers: NSEvent.ModifierFlags = []) -> CanvasCursorKind {
        guard let document, point.map({ bounds.contains($0) }) ?? true else { return .arrow }
        if spaceHeld || document.activeTool == .hand { return panStart == nil ? .openHand : .closedHand }
        if let dragCursor { return dragCursor }
        if document.activeTool == .zoom { return modifiers.contains(.option) ? .zoomOut : .zoomIn }
        if document.activeTool == .cloneStamp, modifiers.contains(.option) { return .cloneSample }
        if document.activeTool == .type { return .text }
        if let point {
            if document.activeTool == .crop, document.cropSession != nil {
                if let handle = cropOverlay.handles.firstIndex(where: { hypot(point.x-$0.x,point.y-$0.y) <= 8 }) { return .handle(handle) }
                if cropOverlay.cropRect.contains(point) { return .openHand }
            }
            if document.activeTool == .perspectiveCrop, document.perspectiveSession?.showsPreview == false,
               let handle = perspectiveOverlay.corners.firstIndex(where: { hypot(point.x-$0.x,point.y-$0.y) <= 8 }) { return .handle(handle * 2) }
            if document.activeTool == .move, document.canEditSelection, let handle = overlay.hitHandle(point) { return .handle(handle) }
        }
        return .tool(document.activeTool)
    }
    func requestRender(interactive:Bool = false) {
        guard let document, let pipeline, bounds.width > 0, bounds.height > 0 else { renderTask?.cancel(); settleTask?.cancel(); requestedKey = nil; return }
        let id = document.model.id, revision = document.model.revision
        let model = document.presentedModel, assets = document.assets, viewport = document.viewport
        let selectedID = document.selectedLayerID
        let handles = document.canEditSelection && (document.toolSession?.command == .transform || (document.activeTool == .move && document.showTransformControls))
        // At Retina scale, continuous interaction evaluates one pixel per point.
        // Geometry/overlays stay in the original viewport; only sampling changes.
        let samplingScale = interactive ? max(0.25,min(1,1/viewport.backingScale)) : 1
        let key = RenderKey(model:model,viewport:viewport,selectedID:selectedID,handles:handles,samplingScale:samplingScale,lightweightClip:interactive,appearance:canvasAppearance)
        guard requestedKey != key else { return }
        requestedKey = key; renderTask?.cancel(); settleTask?.cancel(); generation = UUID(); let token = generation
        if interactive {
            settleTask = Task { [weak self] in
                do { try await Task.sleep(for:.milliseconds(150)) } catch { return }
                guard let self, self.document?.model.id == id else { return }; requestRender(interactive:false)
            }
        }
        let appearance = canvasAppearance
        renderTask = Task { [weak self] in
            do {
                let frame = try await pipeline.render(model: model, assets: assets, viewport: viewport, samplingScale:samplingScale, lightweightClip:interactive, appearance:appearance)
                guard let self, !Task.isCancelled, generation == token, self.document?.model.id == id,
                      self.document?.model.revision == revision else { return }
                metal.image = frame; metal.isHidden = false; overlay.isHidden = false
                presentedViewport = viewport; presentedModel = model; presentedIsInteractive = interactive
                let origin = viewport.transform.viewPoint(fromDocument: .init(x: 0, y: 0))
                overlay.rectangle = NSRect(x: origin.x, y: origin.y,
                    width: Double(model.canvas.width) * viewport.zoom / viewport.backingScale,
                    height: Double(model.canvas.height) * viewport.zoom / viewport.backingScale)
                overlay.selectedCorners = []; overlay.selectionBounds = nil; overlay.showsHandles = handles
                if let selectedID, let layer = model.layer(selectedID), (document.activeTool == .move || document.toolSession != nil) && document.cropSession == nil && document.perspectiveSession == nil,
                   let corners = try? LayerGeometry.support(size:model.localSize(of:layer),transform:layer.transform,clips:layer.clip),
                   let box = try? model.bounds(of:selectedID) {
                    overlay.selectedCorners = corners.map { let p=viewport.transform.viewPoint(fromDocument:$0); return NSPoint(x:p.x,y:p.y) }
                    let start=viewport.transform.viewPoint(fromDocument:.init(x:box.x,y:box.y))
                    overlay.selectionBounds = NSRect(x:start.x,y:start.y,width:box.width*viewport.zoom/viewport.backingScale,height:box.height*viewport.zoom/viewport.backingScale)
                }
                updateCropOverlay(); updatePerspectiveOverlay()
                window?.invalidateCursorRects(for: self)
                setAccessibilityValue(String(format: localization.text("document.canvasStatus"), model.canvas.width, model.canvas.height, viewport.zoom * 100))
            } catch is CancellationError {} catch {
                guard let self, generation == token else { return }; requestedKey = nil
                renderFailed?(localization.text("document.renderError"))
            }
        }
    }
    func zoom(to value: Double, anchor: NSPoint? = nil) {
        guard let document else { return }
        document.viewport.setZoom(value, anchor: anchor.map { .init(x: $0.x, y: $0.y) }); navigationChanged()
    }
    func fit() { guard let document else { return }; document.viewport.fit(document.presentedModel.canvas); navigationChanged() }
    func pan(x: Double, y: Double) { document?.viewport.pan(x: x, y: y); navigationChanged() }
    private func navigationChanged() { painting.cancel(); contentEditing.reset();contentEditing.refresh(); editing.cancelPendingPick(); viewportChanged?(); updateCropOverlay(); updatePerspectiveOverlay(); requestRender(interactive:true) }
    func selectTool(_ kind: ToolKind) {
        guard let document, document.activeTool == kind || document.resolveSession() else { return }
        if document.activeTool != kind { contentEditing.reset(); editing.resetPointer(); cropping.reset(); perspectiveEditing.reset() }
        if kind == .crop { do {try document.startCrop()} catch{return} }
        if kind == .perspectiveCrop {do {try document.startPerspective()} catch{return}}
        document.activeTool = kind; toolChanged?(kind); document.changed?(); requestRender(); window?.invalidateCursorRects(for: self)
    }
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: CanvasCursors.cursor(cursorKind(at: nil, modifiers: cursorModifiers)))
        // AppKit rects also handle a stationary pointer when overlays/tool state
        // change; mouseMoved/cursorUpdate refine the same resolver while hovering.
        if document?.activeTool == .crop, document?.cropSession != nil, !spaceHeld, dragCursor == nil {
            addVisibleCursorRect(cropOverlay.cropRect, cursor: .openHand)
            for (index, point) in cropOverlay.handles.enumerated() { addVisibleCursorRect(NSRect(x:point.x-8,y:point.y-8,width:16,height:16), cursor: CanvasCursors.cursor(.handle(index))) }
        } else if document?.activeTool == .move, document?.canEditSelection == true, !spaceHeld, dragCursor == nil {
            for (index, point) in overlay.handlePoints.enumerated() { addVisibleCursorRect(NSRect(x:point.x-7,y:point.y-7,width:14,height:14), cursor: CanvasCursors.cursor(.handle(index))) }
        }
    }
    private func addVisibleCursorRect(_ rectangle: NSRect, cursor: NSCursor) {
        let visible = rectangle.intersection(bounds)
        guard !visible.isEmpty, visible.origin.x.isFinite, visible.origin.y.isFinite else { return }
        addCursorRect(visible, cursor: cursor)
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let document else { return }
        let point = convert(event.locationInWindow, from: nil)
        let kind = cursorKind(at: point, modifiers: event.modifierFlags)
        dragCursor = kind == .openHand ? .closedHand : kind
        updateCursor(with: event)
        lastPointer = point
        if spaceHeld || document.activeTool == .hand { panStart = point; NSCursor.closedHand.set() }
        else if document.activeTool == .zoom { zoom(to: document.viewport.zoom * (event.modifierFlags.contains(.option) ? 0.5 : 2), anchor: point) }
        else if document.activeTool == .brush || document.activeTool == .cloneStamp { painting.down(point,option:event.modifierFlags.contains(.option)) }
        else if document.activeTool == .crop {cropping.down(point)}
        else if document.activeTool == .perspectiveCrop {perspectiveEditing.down(point)}
        else if [.type,.rectangle,.ellipse,.line,.eyedropper].contains(document.activeTool){contentEditing.down(point,shift:event.modifierFlags.contains(.shift))}
        else if event.clickCount==2,let layer=document.selectedLayer,case .text=layer.content{contentEditing.edit(layer.id)}
        else { editing.down(point,shift:event.modifierFlags.contains(.shift)) }
    }
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if spaceHeld || document?.activeTool == .hand {
            if let start = panStart ?? lastPointer { pan(x:point.x-start.x,y:point.y-start.y) }; panStart=point
        } else if document?.activeTool == .brush || document?.activeTool == .cloneStamp { painting.drag(point) } else if document?.activeTool == .crop {cropping.drag(point)} else if document?.activeTool == .perspectiveCrop {perspectiveEditing.drag(point)} else if let tool=document?.activeTool,[.rectangle,.ellipse,.line,.type,.eyedropper].contains(tool){contentEditing.drag(point,shift:event.modifierFlags.contains(.shift))} else { editing.dragged(point,shift:event.modifierFlags.contains(.shift)) }
        lastPointer=point
        updateCursor(with: event)
    }
    override func mouseUp(with event: NSEvent) {
        if document?.activeTool == .brush || document?.activeTool == .cloneStamp { if !spaceHeld { painting.up(convert(event.locationInWindow,from:nil)) } else { painting.cancel() } }
        else if document?.activeTool == .crop {if !spaceHeld {cropping.up(convert(event.locationInWindow,from:nil))}else{cropping.reset()}}
        else if document?.activeTool == .perspectiveCrop {if !spaceHeld {perspectiveEditing.up(convert(event.locationInWindow,from:nil))}else{perspectiveEditing.reset()}}
        else if let tool=document?.activeTool,[.rectangle,.ellipse,.line,.type,.eyedropper].contains(tool){if !spaceHeld{contentEditing.up(convert(event.locationInWindow,from:nil),shift:event.modifierFlags.contains(.shift))}}
        else if !spaceHeld && document?.activeTool != .hand { editing.up(convert(event.locationInWindow,from:nil),shift:event.modifierFlags.contains(.shift)) }
        else { editing.finishPointer() }
        panStart = nil; lastPointer = nil; dragCursor = nil; updateCursor(with: event); window?.invalidateCursorRects(for: self)
    }
    override func scrollWheel(with event: NSEvent) {
        guard document != nil else { super.scrollWheel(with: event); return }
        let factor = event.hasPreciseScrollingDeltas ? 1.0 : 12.0
        pan(x: event.scrollingDeltaX * factor, y: event.scrollingDeltaY * factor)
    }
    override func magnify(with event: NSEvent) {
        guard let document else { return }
        zoom(to: document.viewport.zoom * (1 + event.magnification), anchor: convert(event.locationInWindow, from: nil))
    }
    override func keyDown(with event: NSEvent) {
        if document?.activeTool == .cloneStamp, event.modifierFlags.contains(.option), [36,76].contains(event.keyCode) { painting.chooseSourceAtCursor(); return }
        if document?.paintSession != nil, event.keyCode == 53 { painting.cancel(); return }
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { super.keyDown(with: event); return }
        if let state=document?.contentSession,[36,76,53].contains(event.keyCode) {
            if event.keyCode==53{document?.cancelSession()}else if case .shape=state.draft{document?.applySession()};return
        }
        if (document?.cropSession != nil || document?.perspectiveSession != nil || document?.hasAdjustmentSession == true) && [36,76,53].contains(event.keyCode) {
            cropping.reset();perspectiveEditing.reset();if event.keyCode == 53 {document?.cancelSession()} else{document?.applySession()};return
        }
        if document?.activeTool != .crop && document?.activeTool != .perspectiveCrop && editing.keyDown(event) { return }
        switch event.keyCode {
        case 48: toggleChrome?()
        case 49: spaceHeld = true; paintCursor.isHidden = true; refreshCursor(); window?.invalidateCursorRects(for: self)
        default:
            if event.charactersIgnoringModifiers?.lowercased() == "c" {selectTool(event.modifierFlags.contains(.shift) ? .perspectiveCrop:.crop)}
            else if event.charactersIgnoringModifiers?.lowercased() == "b" { selectTool(.brush) }
            else if event.charactersIgnoringModifiers?.lowercased() == "s" { selectTool(.cloneStamp) }
            else if let key = event.charactersIgnoringModifiers, ["[","]"].contains(key), let d = document, d.activeTool == .brush || d.activeTool == .cloneStamp { d.brushSettings.diameter = min(1000,max(1,d.brushSettings.diameter * (key == "[" ? 0.8:1.25))); d.changed?() }
            else if event.charactersIgnoringModifiers?.lowercased() == "v" { selectTool(.move) }
            else if event.charactersIgnoringModifiers?.lowercased() == "t" {selectTool(.type)}
            else if event.charactersIgnoringModifiers?.lowercased() == "i" {selectTool(.eyedropper)}
            else if event.charactersIgnoringModifiers?.lowercased() == "u" {
                let shapes:[ToolKind]=[.rectangle,.ellipse,.line],index=shapes.firstIndex(of:document?.activeTool ?? .rectangle) ?? 0
                selectTool(event.modifierFlags.contains(.shift) ? shapes[(index+1)%3]:shapes[index])
            }
            else if event.charactersIgnoringModifiers?.lowercased() == "x" {document?.swapColors()}
            else if event.charactersIgnoringModifiers?.lowercased() == "d" {document?.resetColors()}
            else if event.charactersIgnoringModifiers?.lowercased() == "h" { selectTool(.hand) }
            else if event.charactersIgnoringModifiers?.lowercased() == "z" { selectTool(.zoom) }
            else { super.keyDown(with: event) }
        }
    }
    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 { spaceHeld = false; panStart = nil; dragCursor = nil; updatePaintCursorVisibility(); refreshCursor(); window?.invalidateCursorRects(for: self) }
        else { editing.keyUp(event); super.keyUp(with: event) }
    }
    override func resignFirstResponder() -> Bool { painting.cancel(); editing.finishKeyboardMove(); spaceHeld = false; panStart = nil; dragCursor = nil; window?.invalidateCursorRects(for: self); return super.resignFirstResponder() }
    @objc func paste(_ sender: Any?) {
        paste(from: .general)
    }
    func paste(from board: NSPasteboard) {
        let files = Self.files(board)
        if !files.isEmpty { importImages?(files.map { .file($0) }) }
        else if let data = board.data(forType: .png) ?? board.data(forType: .tiff) {
            importImages?([.clipboard(data, name: localization.text("document.clipboard"))])
        }
    }
    static func files(_ board: NSPasteboard) -> [URL] {
        board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation { Self.files(sender.draggingPasteboard).isEmpty ? [] : .copy }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let files = Self.files(sender.draggingPasteboard); guard !files.isEmpty else { return false }
        importImages?(files.map { .file($0) }); return true
    }
}

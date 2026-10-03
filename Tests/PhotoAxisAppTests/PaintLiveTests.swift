import AppKit
import XCTest
import CoreImage
import ImageIO
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class PaintLiveTests: XCTestCase {
    func root() throws -> URL {
        let url = URL(fileURLWithPath:ProcessInfo.processInfo.environment["PHOTOAXIS_BUILD_ROOT"] ?? NSHomeDirectory()+"/Library/Developer/PhotoAxisBuilds/83990cd22abb").appendingPathComponent("paint-live-tests/"+UUID().uuidString)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true); return url
    }
    func fixture(_ name: String = "colors-srgb.png") async throws -> (PhotoDocument,ImagePipeline) {
        try await PerspectiveEditingTests().fixture(name)
    }
    func pixel(_ image: CGImage,_ x: Int,_ y: Int) throws -> [Double] { try ExportTests().rgba(image,x,y) }
    func render(_ content: PaintContent, sources: [String:CGImage] = [:]) throws -> CGImage {
        let image = try PaintRasterizer.image(content,sources:sources)
        return try XCTUnwrap(CIContext(options:[.useSoftwareRenderer:true]).createCGImage(image,from:image.extent,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)))
    }
    func testBrushUnionOpacityInterpolationSoftEdgeAndOrientation() throws {
        let size = try CanvasSize(width:200,height:160), red = RGBAColor(red:1,green:0,blue:0)
        let line = PaintStroke(points:[.init(x:20,y:30),.init(x:180,y:30)],diameter:20,hardness:1,opacity:0.5,color:red)
        let image = try render(PaintContent(size:size,strokes:[line]))
        for x in stride(from:20,through:180,by:2) { let c = try pixel(image,x,30); XCTAssertEqual(c[0],1,accuracy:0.01); XCTAssertEqual(c[3],0.5,accuracy:1.0/255) }
        XCTAssertEqual(try pixel(image,100,130)[3],0); XCTAssertEqual(try pixel(image,100,45)[3],0)
        let dot = PaintStroke(points:[.init(x:100,y:100)],diameter:40,hardness:0,color:red)
        let soft = try render(PaintContent(size:size,strokes:[dot]))
        XCTAssertGreaterThan(try pixel(soft,100,100)[3],0.9)
        XCTAssertGreaterThan(try pixel(soft,110,100)[3],0.25); XCTAssertLessThan(try pixel(soft,110,100)[3],0.7)
        XCTAssertEqual(try pixel(soft,130,100)[3],0)
    }
    func testLiveStrokeOneUndoRedoCancelAndImmutableSource() async throws {
        let (d,p) = try await fixture(), original = d.model, bytes = d.assets.mapValues(\.data)
        d.activeTool = .brush; d.foreground = RGBAColor(red:1,green:0,blue:0); d.brushSettings.diameter = 30; d.brushSettings.hardness = 1
        try d.startPaint(at:.init(x:30,y:40)); try d.extendPaint(to:.init(x:500,y:40))
        XCTAssertEqual(d.model,original); XCTAssertTrue(d.history.entries.isEmpty)
        let preview = try await p.renderDocument(model:d.presentedModel,assets:d.assets)
        XCTAssertEqual(try pixel(preview,300,40)[0],1,accuracy:0.01)
        d.finishPaint(); XCTAssertEqual(d.history.entries.count,1)
        let painted = d.model; XCTAssertEqual(d.assets.mapValues(\.data),bytes)
        d.undoManager?.undo(); XCTAssertEqual(d.model,original); d.undoManager?.redo(); XCTAssertEqual(d.model,painted)
        d.selectLayer(painted.layers.last!.id); let selection = d.selectedLayerID; try d.startPaint(at:.init(x:300,y:300)); d.cancelSession()
        XCTAssertEqual(d.model,painted); XCTAssertEqual(d.selectedLayerID,selection); XCTAssertEqual(d.history.entries.count,1)
        try d.perform(.lock) { try $0.setLock(selection!,true) }; XCTAssertFalse(d.canPaint)
        XCTAssertThrowsError(try d.startPaint(at:.init(x:10,y:10)))
    }
    func testPaintMaskStaysTransparentOutsideStrokeAfterDeskewAndPerspective() async throws {
        let size = try CanvasSize(width:640,height:480), pipeline = ImagePipeline()
        let d = PhotoDocument(model:try PhotoDocumentModel(name:"Rotated paint",canvas:size,ppi:72),localization:L10n(choice:.english))
        d.activeTool = .brush; d.brushSettings.diameter = 30; d.brushSettings.hardness = 1
        try d.startPaint(at:.init(x:100,y:250)); try d.extendPaint(to:.init(x:500,y:250)); d.finishPaint()
        for degrees in [-3.0,3.0,14.0] {
            var model = d.model; try model.deskewScan(degrees:degrees)
            let layer = model.layers[0], inverse = try layer.transform.inverted(), image = try await pipeline.renderDocument(model:model,assets:[:])
            var outside = 0, inside = 0
            for y in stride(from:5,to:image.height-5,by:11) { for x in stride(from:5,to:image.width-5,by:13) {
                let q = try inverse.applying(to:.init(x:Double(x)+0.5,y:Double(y)+0.5))
                let distance = hypot(max(100-q.x,0,q.x-500),q.y-250), alpha = try pixel(image,x,y)[3]
                if distance > 20 { outside += 1; XCTAssertEqual(alpha,0,accuracy:1.0/255) }
                if distance < 10 { inside += 1; XCTAssertGreaterThan(alpha,0.95) }
            } }
            XCTAssertGreaterThan(outside,1000); XCTAssertGreaterThan(inside,20)
        }
        var model = d.model; try model.perspectiveCrop(.init([.init(x:20,y:10),.init(x:620,y:20),.init(x:605,y:460),.init(x:35,y:445)]),output:CanvasSize(width:600,height:440))
        let result = try await pipeline.renderDocument(model:model,assets:[:])
        for x in stride(from:10,to:590,by:10) { XCTAssertEqual(try pixel(result,x,10)[3],0); XCTAssertEqual(try pixel(result,x,420)[3],0) }
    }
    func testFrozenCompositeCloneIncludesAdjustmentsAndHasNoFeedback() async throws {
        let (d,p) = try await fixture(); let originalBytes = d.assets.mapValues(\.data), id = d.selectedLayerID!
        var settings = ImageAdjustments(); settings.brightness = 15
        try d.perform(.adjustments) { try $0.setAdjustments(id,settings) }
        let sourceRender = try await p.renderDocument(model:d.model,assets:d.assets), source = try await p.cloneSnapshot(d.snapshot(),name:"Frozen")
        d.activeTool = .cloneStamp; d.brushSettings.diameter = 30; d.brushSettings.hardness = 1
        try d.startPaint(at:.init(x:400,y:300),source:source,offset:.init(x:-350,y:-240)); d.finishPaint()
        try d.startPaint(at:.init(x:420,y:320),source:source,offset:.init(x:-370,y:-260)); d.finishPaint()
        let image = try await p.renderDocument(model:d.model,assets:d.assets)
        for (a,b) in zip(try pixel(image,400,300),try pixel(sourceRender,50,60)) { XCTAssertEqual(a,b,accuracy:2.0/255) }
        for (a,b) in zip(try pixel(image,420,320),try pixel(sourceRender,50,60)) { XCTAssertEqual(a,b,accuracy:2.0/255) }
        for (key,data) in originalBytes { XCTAssertEqual(d.assets[key]?.data,data) }
        XCTAssertEqual(d.assets[source.descriptor.id]?.data,source.data); XCTAssertEqual(d.history.entries.last?.command,.cloneStamp)
    }
    func testPaintProjectExportRecoveryRoundTripAndDraftExclusion() async throws {
        let (d,p) = try await fixture(), source = try await p.cloneSnapshot(d.snapshot(),name:"Sample")
        d.activeTool = .cloneStamp; try d.startPaint(at:.init(x:400,y:300),source:source,offset:.init(x:-350,y:-240)); d.finishPaint()
        d.activeTool = .brush; try d.startPaint(at:.init(x:100,y:100)); try d.extendPaint(to:.init(x:200,y:100)); d.finishPaint()
        let committed = d.snapshot(), folder = try root(), url = folder.appendingPathComponent("Paint có dấu.paxis"), store = ProjectStore(pipeline:p)
        try d.startPaint(at:.init(x:300,y:300))
        try await store.save(d.snapshot(),to:url); let opened = try await store.open(url)
        XCTAssertEqual(opened.model,committed.model); XCTAssertEqual(opened.assets.mapValues(\.data),committed.assets.mapValues(\.data))
        XCTAssertEqual(try ProjectSchema.decode(XCTUnwrap(BoundedZIP.read(url:url)["document.json"])).formatVersion,4)
        let recovery = RecoveryStore(root:folder.appendingPathComponent("recovery"),pipeline:p)
        _ = try await recovery.write(d.snapshot()); let entries = try await recovery.list(), recovered = try await recovery.open(XCTUnwrap(entries.first))
        XCTAssertEqual(recovered.model,committed.model)
        let before = try await p.renderDocument(model:committed.model,assets:committed.assets), after = try await p.renderDocument(model:opened.model,assets:opened.assets)
        XCTAssertEqual(before.dataProvider?.data as Data?,after.dataProvider?.data as Data?)
        let png = folder.appendingPathComponent("paint.png"); try await ExportStore(pipeline:p).write(committed,options:ExportOptions(size:d.model.canvas,ppi:72),to:png)
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(XCTUnwrap(CGImageSourceCreateWithURL(png as CFURL,nil)),0,nil))
        for (a,b) in zip(try pixel(decoded,150,100),try pixel(before,150,100)) { XCTAssertEqual(a,b,accuracy:1.0/255) }
        d.cancelSession()
    }
    func testCaseCloneUnsavedRestartAuditRollbackAndTamper() async throws {
        let builder = InvestigationWorkflowTests(), (store,c) = try builder.context(), (item,d) = try await builder.add(store,c)
        let original = d.model, bytes = try Data(contentsOf:store.originalURL(item)), sample = try await c.pipeline.cloneSnapshot(d.snapshot(),name:"Sample")
        d.activeTool = .cloneStamp
        try d.startPaint(at:.init(x:400,y:300),source:sample,offset:.init(x:-350,y:-240))
        store.beforeManifestCommit = { throw POSIXError(.ENOSPC) }; d.finishPaint()
        XCTAssertEqual(d.model,original); XCTAssertNotNil(d.paintSession)
        let derived = store.root.appendingPathComponent("derived").appendingPathComponent(sample.descriptor.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath:derived.path))
        store.beforeManifestCommit = nil; d.finishPaint(); XCTAssertNil(d.paintSession)
        XCTAssertEqual(store.value.events.last?.payload.operation,"cloneStamp")
        let copy = try root().appendingPathComponent("Restart.paxcase"); try FileManager.default.copyItem(at:store.root,to:copy)
        let restarted = try InvestigationCaseStore(root:copy), reopened = try await restarted.openSnapshot(item.id,projects:c.projectStore)
        XCTAssertEqual(reopened.model,d.model); XCTAssertEqual(reopened.assets[sample.descriptor.id]?.data,sample.data)
        d.undoManager?.undo(); XCTAssertEqual(d.model,original); d.undoManager?.redo()
        let redo = try await store.openSnapshot(item.id,projects:c.projectStore); XCTAssertEqual(redo.model,d.model)
        XCTAssertEqual(try Data(contentsOf:store.originalURL(item)),bytes); try await store.verifyOriginal(item)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:derived.path); try Data("tampered".utf8).write(to:derived)
        do { _ = try await store.openSnapshot(item.id,projects:c.projectStore); XCTFail("Tampered clone was accepted") } catch { XCTAssertEqual(error as? InvestigationError,.integrity) }
    }
    func testNativeOptionClickAlignedAndUnalignedCloneAndBrushEscape() async throws {
        let (d,p) = try await fixture(), c = DocumentCoordinator(localization:L10n(choice:.english),pipeline:p); try c.add(d)
        let host = WorkspaceWindowController(preferences:WorkspacePreferences(defaults:UserDefaults(suiteName:UUID().uuidString)!),localization:L10n(choice:.english),restoreFrame:false)
        defer { host.workspaceView.canvas.display(nil,pipeline:p); host.close(); c.remove(d.model.id) }
        c.changed = { [weak host,weak c] in if let c { host?.workspaceView.refreshDocuments(c) } }
        host.showWindow(nil); host.reloadLayout(); host.workspaceView.refreshDocuments(c)
        let canvas = host.workspaceView.canvas
        func settle() async throws { for _ in 0..<300 { if canvas.presentedModel == d.presentedModel, canvas.presentedViewport == d.viewport { return }; try await Task.sleep(for:.milliseconds(10)) }; XCTFail("Canvas did not settle") }
        func event(_ type: NSEvent.EventType,_ x: Double,_ y: Double,_ flags: NSEvent.ModifierFlags = []) -> NSEvent {
            let q = d.viewport.transform.viewPoint(fromDocument:.init(x:x,y:y))
            return NSEvent.mouseEvent(with:type,location:canvas.convert(.init(x:q.x,y:q.y),to:nil),modifierFlags:flags,timestamp:0,windowNumber:host.window!.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
        }
        func click(_ x: Double,_ y: Double,_ flags: NSEvent.ModifierFlags = []) { canvas.mouseDown(with:event(.leftMouseDown,x,y,flags)); canvas.mouseUp(with:event(.leftMouseUp,x,y,flags)) }
        d.activeTool = .cloneStamp; d.changed?(); try await settle(); click(50,60,.option)
        for _ in 0..<300 { if canvas.painting.cloneSource != nil { break }; try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertNotNil(canvas.painting.cloneSource); XCTAssertTrue(d.history.entries.isEmpty)
        click(300,200); try await settle(); click(320,220); try await settle()
        d.brushSettings.aligned = false; canvas.painting.resetAlignment(); click(400,300)
        guard case .paint(let paint) = d.model.layers.last!.content else { return XCTFail("Missing native paint") }
        XCTAssertEqual(paint.strokes.count,3); XCTAssertEqual(paint.strokes[0].sourceOffset,paint.strokes[1].sourceOffset)
        XCTAssertEqual(paint.strokes[2].sourceOffset,Point2D(x:-350,y:-240))
        d.activeTool = .brush; d.changed?(); try await settle(); let before = d.model
        canvas.mouseDown(with:event(.leftMouseDown,100,100)); canvas.mouseDragged(with:event(.leftMouseDragged,200,100))
        XCTAssertNotEqual(d.presentedModel,before); XCTAssertEqual(d.model,before)
        let escape = NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:host.window!.windowNumber,context:nil,characters:"\u{1b}",charactersIgnoringModifiers:"\u{1b}",isARepeat:false,keyCode:53)!
        canvas.keyDown(with:escape); XCTAssertEqual(d.presentedModel,before); XCTAssertEqual(d.history.entries.count,3)
    }
    func testBilingualContinuousPaintControlsAndNarrowOverflow() throws {
        for language in [InterfaceLanguage.vietnamese,.english] {
            let l = L10n(choice:language), d = PhotoDocument(model:try PhotoDocumentModel(name:"Controls",canvas:CanvasSize(width:640,height:480),ppi:72),localization:l)
            d.activeTool = .cloneStamp
            let controls = PaintControlsView(localization:l); controls.refresh(d)
            XCTAssertTrue(controls.sliders.allSatisfy(\.isContinuous)); XCTAssertFalse(controls.aligned.isHidden)
            controls.fields[0].stringValue = "85"; controls.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:controls.fields[0]))
            XCTAssertEqual(d.brushSettings.diameter,85); XCTAssertTrue(d.history.entries.isEmpty)
            let bar = OptionsBarView(localization:l); bar.frame = NSRect(x:0,y:0,width:500,height:36); bar.display(d); bar.layout()
            XCTAssertTrue(bar.usesOverflow); XCTAssertNotNil(bar.overflowButton.flyout?.items.first?.action)
            XCTAssertFalse(l.text("tool.brush").hasPrefix("tool.")); XCTAssertFalse(l.text("tool.cloneStamp").hasPrefix("tool."))
        }
    }
    func testScanAutoPreviewLatestValueInvalidInputAndCancelWithoutButton() async throws {
        let builder = ScanTests(), d = try await builder.fixture("auto-preview.png",builder.image()), before = d.model
        let panel = try ScanController(document:d,pipeline:builder.pipeline,localization:L10n(choice:.vietnamese))
        defer { panel.cancel(); panel.close() }; try await builder.waitForPreview(panel)
        XCTAssertTrue(panel.previewButton.isHidden); XCTAssertNil(panel.previewButton.superview); XCTAssertTrue(panel.sliders.allSatisfy(\.isContinuous))
        for value in [0.1,0.2,0.4,0.9] { panel.sliders[0].doubleValue = value; panel.changed() }
        XCTAssertFalse(panel.applyButton.isEnabled); try await builder.waitForPreview(panel)
        XCTAssertEqual(d.presentedModel.layers[0].scan?.paper,0.9); XCTAssertEqual(d.model,before); XCTAssertTrue(d.history.entries.isEmpty)
        panel.angle.stringValue = "nan"; panel.changed(); try await Task.sleep(for:.milliseconds(350)); XCTAssertFalse(panel.applyButton.isEnabled)
        panel.angle.stringValue = "2"; NotificationCenter.default.post(name:NSControl.textDidChangeNotification,object:panel.angle); try await builder.waitForPreview(panel)
        XCTAssertNotNil(panel.afterView.image); panel.cancel(); XCTAssertEqual(d.model,before); XCTAssertTrue(d.history.entries.isEmpty)
    }
    func testImageAndCanvasSizePreviewIsAutomaticAtomicAndCancelable() async throws {
        let (d,p) = try await fixture(), original = d.model, viewport = d.viewport
        let image = DocumentSizeController(document:d,canvas:false,localization:L10n(choice:.english))
        image.widthField.stringValue = "320"; image.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:image.widthField))
        XCTAssertEqual(d.presentedModel.canvas,try CanvasSize(width:320,height:240)); XCTAssertEqual(d.model,original); XCTAssertTrue(d.history.entries.isEmpty)
        let rendered = try await p.renderDocument(model:d.presentedModel,assets:d.assets); XCTAssertEqual(rendered.width,320)
        image.widthField.stringValue = "bad"; image.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:image.widthField))
        XCTAssertFalse(image.apply.isEnabled); XCTAssertEqual(d.presentedModel,original); image.cancel(); XCTAssertEqual(d.viewport,viewport)
        let canvas = DocumentSizeController(document:d,canvas:true,localization:L10n(choice:.vietnamese))
        canvas.widthField.stringValue = "800"; canvas.heightField.stringValue = "600"; canvas.validate()
        XCTAssertEqual(d.presentedModel.canvas,try CanvasSize(width:800,height:600)); XCTAssertEqual(d.model,original)
        canvas.confirm(); XCTAssertEqual(d.model.canvas,try CanvasSize(width:800,height:600)); XCTAssertEqual(d.history.entries.count,1)
        d.undoManager?.undo(); XCTAssertEqual(d.model,original)
    }
    func testPerspectiveInsetAutomaticallyRefreshesAndCancelsWithoutHistory() async throws {
        let (d,p) = try await fixture(), before = d.model, canvas = WelcomeCanvasView(localization:L10n(choice:.english))
        canvas.frame = NSRect(x:0,y:0,width:900,height:600); canvas.display(d,pipeline:p)
        try d.startPerspective(); d.updatePerspective { $0.quad = PerspectiveEditingTests().quad }; canvas.display(d,pipeline:p)
        for _ in 0..<300 { if canvas.livePerspective.imageView.image != nil { break }; try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertFalse(canvas.livePerspective.isHidden); let first = try XCTUnwrap(canvas.livePerspective.imageView.image)
        d.updatePerspective { $0.mode = 2; $0.widthText = "300"; $0.heightText = "200" }; canvas.display(d,pipeline:p)
        for _ in 0..<300 { if canvas.livePerspective.imageView.image !== first { break }; try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertFalse(canvas.livePerspective.imageView.image === first); XCTAssertEqual(d.model,before); XCTAssertTrue(d.history.entries.isEmpty)
        d.cancelSession(); canvas.display(d,pipeline:p); XCTAssertTrue(canvas.livePerspective.isHidden)
        try await Task.sleep(for:.milliseconds(100)); XCTAssertTrue(canvas.livePerspective.isHidden)
        try d.startCrop(); d.configureCrop(preset:0,width:"",height:""); d.cropSession?.region = CropRegion(x:30,y:30,width:300,height:200); canvas.display(d,pipeline:p)
        let prior = canvas.livePerspective.imageView.image
        for _ in 0..<300 { if canvas.livePerspective.imageView.image !== prior { break }; try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertFalse(canvas.livePerspective.isHidden); XCTAssertFalse(canvas.livePerspective.imageView.image === prior)
        XCTAssertEqual(d.model,before); d.cancelSession(); canvas.display(nil,pipeline:p)
    }
}

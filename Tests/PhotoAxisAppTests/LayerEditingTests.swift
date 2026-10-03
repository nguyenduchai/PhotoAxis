import AppKit
import XCTest
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore
@testable import PhotoAxis

@MainActor
final class LayerEditingTests:XCTestCase {
    private let l10n = L10n(choice:.english)
    private func makeDocument(_ name:String = "grid-corners.png") async throws -> (PhotoDocument,ImagePipeline) {
        let pipeline=ImagePipeline()
        let url=Bundle(for:LayerEditingTests.self).resourceURL!.appendingPathComponent("P02/"+name).absoluteURL
        let asset=try await pipeline.prepare(.file(url),budget:ImportBudget())
        let document=PhotoDocument(model:try PhotoDocumentModel(name:"P03 fixture",canvas:CanvasSize(width:800,height:600),ppi:72),localization:l10n)
        try document.place(asset,recordHistory:false); document.markSaved(stateID:document.history.stateID)
        return (document,pipeline)
    }
    private func pixels(_ image:CGImage,x:Int,y:Int) throws -> NSColor {
        let rep=NSBitmapImageRep(cgImage:image),raw=try XCTUnwrap(NSBitmapImageRep(cgImage:image).colorAt(x:x,y:y))
        var values=[raw.redComponent,raw.greenComponent,raw.blueComponent,raw.alphaComponent]
        return try XCTUnwrap(NSColor(colorSpace:rep.colorSpace,components:&values,count:4).usingColorSpace(.sRGB))
    }
    private func writePNG(_ image:CGImage,_ name:String) throws {
        let root=(0..<5).reduce(Bundle.main.bundleURL){url,_ in url.deletingLastPathComponent()}
        let folder=root.appendingPathComponent("p03-native-tests");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let destination=try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent(name) as CFURL,UTType.png.identifier as CFString,1,nil))
        CGImageDestinationAddImage(destination,image,nil);XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
    func testUndoBridgeTransactionsBranchSavedMarkerAndSourceSharing() async throws {
        let (document,_)=try await makeDocument();let original=document.model,sourceBytes=document.assets.mapValues(\.data)
        let first=document.selectedLayerID!
        try document.perform(.rename){try $0.rename(first,to:"Ảnh biển 24/9")}
        let saved=document.history.stateID;document.markSaved(stateID:saved)
        try document.duplicateSelected();let copy=document.selectedLayerID!
        try document.perform(.opacity){try $0.setOpacity(copy,0.4)}
        try document.perform(.reorder){try $0.reorder(copy,to:0)}
        try document.perform(.delete){try $0.delete(copy)}
        XCTAssertEqual(document.history.entries.count,5);XCTAssertEqual(document.assets.count,1)
        document.undoManager?.undo();XCTAssertEqual(document.model.layer(copy)?.opacity,0.4)
        document.jumpHistory(to:1);XCTAssertFalse(document.isDocumentEdited);XCTAssertTrue(document.undoManager!.canRedo)
        document.jumpHistory(to:5);XCTAssertNil(document.model.layer(copy));XCTAssertTrue(document.isDocumentEdited)
        document.jumpHistory(to:0);XCTAssertEqual(document.model,original)
        document.jumpHistory(to:1)
        try document.perform(.visibility){try $0.setVisibility(first,false)}
        XCTAssertFalse(document.undoManager!.canRedo);XCTAssertEqual(document.history.entries.count,2)
        XCTAssertEqual(document.assets.mapValues(\.data),sourceBytes)
        document.undoManager?.undo();XCTAssertFalse(document.isDocumentEdited)
        document.undoManager?.redo();XCTAssertFalse(document.model.layer(first)!.isVisible)
    }
    func testTransformPreviewRollbackNumbersFlipAndSingleCommit() async throws {
        let (document,_)=try await makeDocument();let original=document.model, id=document.selectedLayerID!
        try document.startTransform();try document.setTransformValue(.x,-25.5)
        try document.setTransformValue(.width,320);try document.setTransformValue(.angle,30);try document.flip(horizontal:true)
        XCTAssertEqual(document.model,original);XCTAssertFalse(document.isDocumentEdited);XCTAssertFalse(document.undoManager!.canUndo)
        XCTAssertNotEqual(document.presentedModel,original)
        document.cancelSession();XCTAssertEqual(document.presentedModel,original)
        try document.setTransformValue(.width,320)
        XCTAssertEqual(try document.transformValue(.height),240,accuracy:1e-7)
        document.linkedProportions=false;try document.setTransformValue(.height,200)
        try document.setTransformValue(.x,-18.25);try document.setTransformValue(.y,21.5)
        let preview=document.presentedModel;document.applySession()
        XCTAssertEqual(document.model,preview);XCTAssertEqual(document.history.entries.count,1)
        XCTAssertEqual(document.undoManager?.undoActionName,"Free Transform")
        document.undoManager?.undo();XCTAssertEqual(document.model,original);XCTAssertFalse(document.isDocumentEdited)
        document.undoManager?.redo();XCTAssertEqual(document.model,preview)
        try document.startTransform()
        XCTAssertThrowsError(try document.setTransformValue(.x,2_000_000));XCTAssertFalse(document.toolSession!.isValid)
        document.applySession();XCTAssertNotNil(document.toolSession);XCTAssertEqual(document.model,preview)
        try document.setTransformValue(.x,0);XCTAssertTrue(document.toolSession!.isValid);document.cancelSession()
        try document.perform(.lock){try $0.setLock(id,true)}
        XCTAssertThrowsError(try document.startTransform());XCTAssertThrowsError(try document.deleteSelected())
        try document.perform(.visibility){try $0.setVisibility(id,false)}
        document.undoManager?.undo();XCTAssertTrue(document.model.layer(id)!.isVisible)
    }
    func testTabSessionsAndUndoRemainIndependent() async throws {
        let (first,pipeline)=try await makeDocument(),(second,_)=try await makeDocument("alpha-edges.png")
        let coordinator=DocumentCoordinator(localization:l10n,pipeline:pipeline)
        try coordinator.add(first);try coordinator.add(second);defer{for d in coordinator.documents{coordinator.remove(d.model.id)}}
        coordinator.select(first.model.id);try first.setTransformValue(.angle,45)
        let preview=first.presentedModel;coordinator.select(second.model.id)
        try second.duplicateSelected();second.undoManager?.undo()
        coordinator.select(first.model.id)
        XCTAssertEqual(first.presentedModel,preview);XCTAssertNotNil(first.toolSession);XCTAssertFalse(first.undoManager!.canUndo)
        first.applySession();XCTAssertEqual(first.history.entries.count,1);XCTAssertEqual(second.history.cursor,0)
    }
    func testNativeOpacityActionAndTransformFieldsAcrossTabs() async throws {
        let (first,pipeline)=try await makeDocument(),(second,_)=try await makeDocument()
        first.activeTool = .move; second.activeTool = .move; second.autoSelect = false; second.showTransformControls = false
        let options=OptionsBarView(localization:l10n)
        options.display(first)
        let stack=try XCTUnwrap(options.subviews.compactMap{$0 as? NSStackView}.first)
        XCTAssertEqual((stack.arrangedSubviews[0] as? NSButton)?.state,.on)
        options.display(second)
        XCTAssertEqual((stack.arrangedSubviews[0] as? NSButton)?.state,.off)
        XCTAssertEqual((stack.arrangedSubviews[1] as? NSButton)?.state,.off)
        let sidebar=SidebarView(localization:l10n)
        first.changed = { sidebar.display(first,pipeline:pipeline) }; sidebar.display(first,pipeline:pipeline)
        sidebar.opacitySlider.doubleValue=37
        sidebar.opacitySlider.sendAction(sidebar.opacitySlider.action,to:sidebar.opacitySlider.target)
        XCTAssertEqual(first.selectedLayer?.opacity,0.37);XCTAssertEqual(first.history.entries.count,1)
        first.undoManager?.undo();XCTAssertEqual(first.selectedLayer?.opacity,1)
        try first.startTransform()
        let controls=TransformOptionsView(localization:l10n);controls.refresh(first)
        let fields=controls.arrangedSubviews.compactMap{$0 as? NSTextField}.filter{$0.identifier != nil}
        XCTAssertEqual(fields.count,5)
        XCTAssertFalse(fields[2].stringValue.isEmpty)
        fields[2].stringValue="320"
        controls.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:fields[2]))
        controls.refresh(first)
        XCTAssertEqual(DocumentNumber.parse(fields[3].stringValue,language:Locale.current.identifier),240)
        first.cancelSession()
        try first.beginSession(.move);try first.previewMove(x:10,y:0,fromOriginal:false);try first.previewMove(x:-10,y:0,fromOriginal:false)
        first.applySession();XCTAssertEqual(first.history.cursor,0);XCTAssertFalse(first.isDocumentEdited)
        XCTAssertTrue(first.undoManager!.canRedo) // A gesture returning to its origin does not cut redo.
        first.changed=nil
    }
    func testNormalLinearCompositeOpacityOrderAndAlphaHitTest() async throws {
        let (document,pipeline)=try await makeDocument("alpha-edges.png")
        let asset=try XCTUnwrap(document.assets.values.first)
        var model=try PhotoDocumentModel(name:"Composite",canvas:CanvasSize(width:800,height:600),ppi:72,background:.white)
        let background=model.layers[0].id
        let id=try model.place(asset.descriptor,name:"Alpha",above:background)
        var viewport=ViewportState();viewport.resize(width:800,height:600,backingScale:1,canvas:model.canvas);viewport.setZoom(1)
        try model.setOpacity(id,0.5)
        let rendered=try await pipeline.render(model:model,assets:document.assets,viewport:viewport)
        let color=try pixels(rendered,x:400,y:300)
        XCTAssertEqual(color.redComponent,1,accuracy:0.015)
        XCTAssertEqual(color.greenComponent,0.735356983,accuracy:0.02)
        XCTAssertEqual(color.blueComponent,0.735356983,accuracy:0.02)
        try writePNG(rendered,"normal-opacity-50.png")
        let centerHit=try await pipeline.hitTest(model:model,assets:document.assets,point:.init(x:400,y:300));XCTAssertEqual(centerHit,id)
        let transparentHit=try await pipeline.hitTest(model:model,assets:document.assets,point:.init(x:81,y:61));XCTAssertNil(transparentHit)
        try model.setLock(id,true)
        let lockedHit=try await pipeline.hitTest(model:model,assets:document.assets,point:.init(x:400,y:300));XCTAssertNil(lockedHit)
        try model.setLock(id,false);try model.reorder(id,to:0)
        let covered=try await pipeline.render(model:model,assets:document.assets,viewport:viewport)
        XCTAssertEqual(try pixels(covered,x:400,y:300).greenComponent,1,accuracy:0.01)
        try model.setVisibility(background,false)
        let visible=try await pipeline.render(model:model,assets:document.assets,viewport:viewport)
        XCTAssertLessThan(try pixels(visible,x:400,y:300).greenComponent,0.7)
    }
    func testNativeHandlesScaleModifiersKeyboardAndOverlay() async throws {
        let (document,pipeline)=try await makeDocument()
        let coordinator=DocumentCoordinator(localization:l10n,pipeline:pipeline);try coordinator.add(document)
        let preferences=WorkspacePreferences(defaults:UserDefaults(suiteName:UUID().uuidString)!)
        let controller=WorkspaceWindowController(preferences:preferences,localization:l10n,restoreFrame:false)
        defer{controller.workspaceView.canvas.display(nil,pipeline:pipeline);controller.close();coordinator.remove(document.model.id)}
        coordinator.changed = { [weak controller,weak coordinator] in if let coordinator{controller?.workspaceView.refreshDocuments(coordinator)} }
        controller.showWindow(nil);controller.reloadLayout();controller.workspaceView.refreshDocuments(coordinator)
        let canvas=controller.workspaceView.canvas;canvas.selectTool(.move);canvas.zoom(to:1)
        func waitFrame() async throws {for _ in 0..<100{if canvas.overlay.handlePoints.count==9 && canvas.presentedModel == document.presentedModel && canvas.presentedViewport == document.viewport{break};try await Task.sleep(for:.milliseconds(10))}}
        try await waitFrame();XCTAssertEqual(canvas.overlay.handlePoints.count,9)
        let original=document.model,bounds=try document.model.bounds(of:document.selectedLayerID!)
        func mouse(_ kind:NSEvent.EventType,_ point:NSPoint,_ shift:Bool=false) {
            let location=canvas.convert(point,to:nil)
            let event=NSEvent.mouseEvent(with:kind,location:location,modifierFlags:shift ? [.shift]:[],timestamp:0,windowNumber:controller.window!.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
            if kind == .leftMouseDown{canvas.mouseDown(with:event)}else if kind == .leftMouseDragged{canvas.mouseDragged(with:event)}else{canvas.mouseUp(with:event)}
        }
        func key(_ kind:NSEvent.EventType,_ code:UInt16,_ shift:Bool=false)->NSEvent {
            NSEvent.keyEvent(with:kind,location:.zero,modifierFlags:shift ? [.shift]:[],timestamp:0,windowNumber:controller.window!.windowNumber,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:false,keyCode:code)!
        }
        let start=canvas.overlay.handlePoints[4]
        let end=NSPoint(x:start.x+bounds.width*0.2/document.viewport.backingScale,y:start.y+bounds.height*0.1/document.viewport.backingScale)
        mouse(.leftMouseDown,start);mouse(.leftMouseDragged,end);mouse(.leftMouseUp,end)
        XCTAssertEqual(try document.transformValue(.width),bounds.width*1.2,accuracy:1e-6)
        XCTAssertEqual(try document.transformValue(.height),bounds.height*1.2,accuracy:1e-6)
        XCTAssertEqual(document.model,original);XCTAssertEqual(document.history.entries.count,0)
        canvas.keyDown(with:key(.keyDown,53));XCTAssertEqual(document.presentedModel,original)
        try await waitFrame()
        mouse(.leftMouseDown,start,true);mouse(.leftMouseDragged,end,true);mouse(.leftMouseUp,end,true)
        XCTAssertEqual(try document.transformValue(.width),bounds.width*1.2,accuracy:1e-6)
        XCTAssertEqual(try document.transformValue(.height),bounds.height*1.1,accuracy:1e-6)
        canvas.keyDown(with:key(.keyDown,53));try await waitFrame()
        let rotationStart=canvas.overlay.handlePoints[8], center=document.viewport.transform.viewPoint(fromDocument:bounds.center)
        let dx=rotationStart.x-center.x,dy=rotationStart.y-center.y,radians=40.0 * .pi/180
        let rotationEnd=NSPoint(x:center.x+dx*cos(radians)-dy*sin(radians),y:center.y+dx*sin(radians)+dy*cos(radians))
        mouse(.leftMouseDown,rotationStart,true);mouse(.leftMouseDragged,rotationEnd,true);mouse(.leftMouseUp,rotationEnd,true)
        XCTAssertEqual(try document.transformValue(.angle),45,accuracy:1e-6)
        canvas.keyDown(with:key(.keyDown,53));try await waitFrame()
        // Numeric unlinked scale is independent; arrow repeat is one committed gesture.
        canvas.keyDown(with:key(.keyDown,124,true));canvas.keyDown(with:key(.keyDown,124,true));canvas.keyUp(with:key(.keyUp,124,true))
        XCTAssertEqual(try document.model.bounds(of:document.selectedLayerID!).x,bounds.x+20,accuracy:1e-6)
        XCTAssertEqual(document.history.entries.count,1);document.undoManager?.undo();XCTAssertEqual(document.model,original)
        // Space-pan while the mouse is down must finish Move without adding the pan delta.
        document.autoSelect=false;try await waitFrame()
        let middle=document.viewport.transform.viewPoint(fromDocument:bounds.center)
        let moveStart=NSPoint(x:middle.x,y:middle.y), moveEnd=NSPoint(x:middle.x+10,y:middle.y)
        mouse(.leftMouseDown,moveStart);mouse(.leftMouseDragged,moveEnd)
        let moved=document.presentedModel
        canvas.keyDown(with:key(.keyDown,49))
        let panEnd=NSPoint(x:moveEnd.x+30,y:moveEnd.y+20)
        mouse(.leftMouseDragged,panEnd);mouse(.leftMouseUp,panEnd);canvas.keyUp(with:key(.keyUp,49))
        XCTAssertNil(document.toolSession);XCTAssertEqual(document.model,moved);XCTAssertEqual(document.history.entries.count,1)
        document.undoManager?.undo();XCTAssertEqual(document.model,original)
        try document.setTransformValue(.angle,30);document.applySession()
        try await Task.sleep(for:.milliseconds(200))
        let frame=try XCTUnwrap(canvas.metal.image);try writePNG(frame,"transform-preview.png")
        XCTAssertEqual(canvas.overlay.selectedCorners.count,4)
        let expected=try LayerGeometry.corners(size:document.model.localSize(of:document.selectedLayer!),transform:document.selectedLayer!.transform)
        for (index,point) in expected.enumerated(){let p=document.viewport.transform.viewPoint(fromDocument:point);XCTAssertEqual(canvas.overlay.selectedCorners[index].x,p.x,accuracy:1e-6);XCTAssertEqual(canvas.overlay.selectedCorners[index].y,p.y,accuracy:1e-6)}
    }
}

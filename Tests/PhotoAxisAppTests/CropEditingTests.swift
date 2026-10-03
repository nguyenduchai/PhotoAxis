import AppKit
import XCTest
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore
@testable import PhotoAxis

@MainActor
final class CropEditingTests:XCTestCase {
    let l10n=L10n(choice:.english)
    func fixture() async throws -> (PhotoDocument,ImagePipeline) {
        let pipeline=ImagePipeline(),url=Bundle(for:Self.self).resourceURL!.appendingPathComponent("P02/grid-corners.png").absoluteURL
        let asset=try await pipeline.prepare(.file(url),budget:ImportBudget())
        let d=PhotoDocument(model:try PhotoDocumentModel(name:"Crop fixture",canvas:asset.descriptor.size,ppi:72),localization:l10n)
        try d.place(asset,recordHistory:false);d.markSaved(stateID:d.history.stateID);return(d,pipeline)
    }
    func color(_ image:CGImage,_ x:Int,_ y:Int) throws -> NSColor {
        let rep=NSBitmapImageRep(cgImage:image),raw=try XCTUnwrap(NSBitmapImageRep(cgImage:image).colorAt(x:x,y:y))
        var values=[raw.redComponent,raw.greenComponent,raw.blueComponent,raw.alphaComponent]
        return try XCTUnwrap(NSColor(colorSpace:rep.colorSpace,components:&values,count:4).usingColorSpace(.sRGB))
    }
    func write(_ image:CGImage,_ name:String) throws {
        let root=(0..<5).reduce(Bundle.main.bundleURL){url,_ in url.deletingLastPathComponent()}.appendingPathComponent("p04-native-tests")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let dest=try XCTUnwrap(CGImageDestinationCreateWithURL(root.appendingPathComponent(name) as CFURL,UTType.png.identifier as CFString,1,nil));CGImageDestinationAddImage(dest,image,nil);XCTAssertTrue(CGImageDestinationFinalize(dest))
    }
    func testCropRenderUndoAndNoResurrectionAfterCanvasMoveRotate() async throws {
        let (d,p)=try await fixture();let original=d.model,bytes=d.assets.mapValues(\.data)
        try d.startCrop();d.moveCrop(to:.init(x:0,y:0,width:320,height:240));d.applySession()
        let crop=d.model;XCTAssertEqual(d.history.entries.count,1)
        var image=try await p.renderDocument(model:d.model,assets:d.assets)
        XCTAssertEqual(image.width,320);XCTAssertEqual(image.height,240)
        XCTAssertGreaterThan(try color(image,20,20).redComponent,0.95);XCTAssertLessThan(try color(image,20,20).greenComponent,0.05)
        try write(image,"crop-top-left.png")
        try d.perform(.canvasSize){try $0.canvasSize(CanvasSize(width:640,height:480),anchorX:0,anchorY:0)}
        image=try await p.renderDocument(model:d.model,assets:d.assets)
        XCTAssertEqual(try color(image,500,300).alphaComponent,0,accuracy:0.01)
        let id=d.selectedLayerID!;try d.perform(.move){try $0.setTransform(id,LayerGeometry.translation(x:100,y:100))}
        try d.perform(.rotateCanvas){try $0.rotateCanvas(quarterTurns:1)}
        image=try await p.renderDocument(model:d.model,assets:d.assets);try write(image,"crop-expand-move-rotate.png")
        XCTAssertEqual(try color(image,40,40).alphaComponent,0,accuracy:0.01)
        XCTAssertEqual(d.assets.mapValues(\.data),bytes)
        d.jumpHistory(to:0);XCTAssertEqual(d.model,original);XCTAssertFalse(d.isDocumentEdited)
        d.jumpHistory(to:1);XCTAssertEqual(d.model,crop)
    }
    func testRatioPixelsCancelAndIndependentTabs() async throws {
        let (d,p)=try await fixture(),(other,_)=try await fixture();let before=d.model
        let coordinator=DocumentCoordinator(localization:l10n,pipeline:p);try coordinator.add(d);try coordinator.add(other)
        try d.startCrop();d.configureCrop(preset:2,width:"",height:"")
        XCTAssertEqual(d.cropSession?.region.width,480);XCTAssertEqual(d.cropSession?.region.height,480)
        coordinator.select(other.model.id);try other.duplicateSelected();coordinator.select(d.model.id)
        XCTAssertNotNil(d.cropSession);d.cancelSession();XCTAssertEqual(d.model,before);XCTAssertEqual(d.history.entries.count,0)
        try d.startCrop();d.configureCrop(preset:8,width:"160",height:"120");d.applySession()
        XCTAssertEqual(d.model.canvas,try CanvasSize(width:160,height:120));XCTAssertEqual(d.history.entries.count,1)
        let image=try await p.renderDocument(model:d.model,assets:d.assets);try write(image,"crop-resampled-160x120.png")
        XCTAssertGreaterThan(try color(image,5,5).redComponent,0.9);XCTAssertGreaterThan(try color(image,150,5).greenComponent,0.9)
        XCTAssertGreaterThan(try color(image,150,110).blueComponent,0.9)
        try d.startCrop();d.configureCrop(preset:8,width:"8001",height:"1");d.applySession();XCTAssertFalse(d.sessionIsValid);XCTAssertNotNil(d.cropSession)
        d.configureCrop(preset:8,width:"10.5",height:"10");XCTAssertFalse(d.sessionIsValid);d.cancelSession()
        try d.startCrop()
        for width in ["1","16","160","8001","160"] {d.configureCrop(preset:8,width:width,height:"120")}
        XCTAssertTrue(d.sessionIsValid)
        XCTAssertEqual(d.cropSession?.region,.full(d.model.canvas))
        let tiny="0"+(Locale.current.decimalSeparator ?? ".")+String(repeating:"0",count:308)+"1"
        d.configureCrop(preset:7,width:String(repeating:"9",count:308),height:tiny)
        XCTAssertFalse(d.sessionIsValid)
        d.cancelSession()
        for doc in coordinator.documents{coordinator.remove(doc.model.id)}
    }
    func testSizeDialogValidationPPIAndLockedBackground() async throws {
        let (d,p)=try await fixture();let id=d.selectedLayerID!;try d.perform(.lock){try $0.setLock(id,true)}
        let sheet=DocumentSizeController(document:d,canvas:false,localization:l10n)
        sheet.widthField.stringValue="320";sheet.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:sheet.widthField))
        XCTAssertEqual(sheet.heightField.stringValue,"240");sheet.ppiField.stringValue="300";sheet.confirm()
        XCTAssertEqual(d.model.canvas,try CanvasSize(width:320,height:240));XCTAssertEqual(d.model.ppi,300);XCTAssertTrue(d.model.layer(id)!.isLocked)
        let image=try await p.renderDocument(model:d.model,assets:d.assets);XCTAssertEqual(image.width,320)
        sheet.widthField.stringValue="8000";sheet.heightField.stringValue="8000";sheet.validate();XCTAssertFalse(sheet.apply.isEnabled)
        d.undoManager?.undo();XCTAssertEqual(d.model.canvas,try CanvasSize(width:640,height:480));XCTAssertEqual(d.model.ppi,72)
    }
    func testCropHandlesPanCancelAndApplyInNativeWindow() async throws {
        let (d,p)=try await fixture(),coordinator=DocumentCoordinator(localization:l10n,pipeline:p)
        try coordinator.add(d)
        let prefs=WorkspacePreferences(defaults:UserDefaults(suiteName:UUID().uuidString)!)
        let controller=WorkspaceWindowController(preferences:prefs,localization:l10n,restoreFrame:false)
        defer{controller.workspaceView.canvas.display(nil,pipeline:p);controller.close();coordinator.remove(d.model.id)}
        coordinator.changed={ [weak controller,weak coordinator] in if let coordinator{controller?.workspaceView.refreshDocuments(coordinator)} }
        controller.showWindow(nil);controller.reloadLayout();controller.workspaceView.refreshDocuments(coordinator)
        let canvas=controller.workspaceView.canvas;canvas.selectTool(.crop);canvas.zoom(to:1)
        XCTAssertEqual(controller.workspaceView.optionsBar.toolLabel.stringValue,l10n.text("tool.crop"))
        for _ in 0..<100 {if canvas.presentedViewport==d.viewport{break};try await Task.sleep(for:.milliseconds(10))}
        XCTAssertFalse(canvas.cropOverlay.isHidden);XCTAssertEqual(canvas.cropOverlay.handles.count,8)
        let rect=canvas.cropOverlay.cropRect,start=NSPoint(x:rect.maxX,y:rect.maxY),end=NSPoint(x:rect.midX,y:rect.midY)
        func event(_ kind:NSEvent.EventType,_ point:NSPoint)->NSEvent {NSEvent.mouseEvent(with:kind,location:canvas.convert(point,to:nil),modifierFlags:[],timestamp:0,windowNumber:controller.window!.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!}
        canvas.mouseDown(with:event(.leftMouseDown,start));canvas.mouseDragged(with:event(.leftMouseDragged,end));canvas.mouseUp(with:event(.leftMouseUp,end))
        XCTAssertEqual(d.cropSession?.region.width,320);XCTAssertEqual(d.cropSession?.region.height,240)
        XCTAssertEqual(d.model.canvas,try CanvasSize(width:640,height:480));XCTAssertFalse(d.isDocumentEdited)
        let before=canvas.cropOverlay.cropRect;canvas.pan(x:25,y:17)
        XCTAssertEqual(canvas.cropOverlay.cropRect.minX,before.minX+25,accuracy:1e-6)
        XCTAssertEqual(d.cropSession?.region.width,320)
        d.cancelSession();XCTAssertTrue(canvas.cropOverlay.isHidden);XCTAssertEqual(d.history.entries.count,0)
        canvas.selectTool(.crop);d.configureCrop(preset:5,width:"",height:"");d.swapCrop()
        XCTAssertEqual(try XCTUnwrap(d.cropSession?.ratio),9.0/16,accuracy:1e-12)
        d.configureCrop(preset:8,width:"120",height:"160");d.applySession()
        XCTAssertEqual(d.model.canvas,try CanvasSize(width:120,height:160));XCTAssertEqual(d.history.entries.count,1)
        XCTAssertTrue(canvas.cropOverlay.isHidden)
    }
}

import AppKit
import XCTest
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore
@testable import PhotoAxis

@MainActor
final class PerspectiveEditingTests:XCTestCase {
    let l10n=L10n(choice:.english)
    let quad=PerspectiveQuad([.init(x:20,y:10),.init(x:620,y:35),.init(x:605,y:460),.init(x:35,y:445)])
    var outputRoot:URL {(0..<5).reduce(Bundle.main.bundleURL){url,_ in url.deletingLastPathComponent()}.appendingPathComponent("p05-native-tests")}
    func fixture(_ name:String="grid-corners.png") async throws -> (PhotoDocument,ImagePipeline) {
        let pipeline=ImagePipeline(),url=Bundle(for:Self.self).resourceURL!.appendingPathComponent("P02/"+name).absoluteURL
        let asset=try await pipeline.prepare(.file(url),budget:ImportBudget())
        let d=PhotoDocument(model:try PhotoDocumentModel(name:"Perspective fixture",canvas:asset.descriptor.size,ppi:72),localization:l10n)
        try d.place(asset,recordHistory:false);d.markSaved(stateID:d.history.stateID);return(d,pipeline)
    }
    func color(_ image:CGImage,_ x:Int,_ y:Int) throws -> NSColor {
        let rep=NSBitmapImageRep(cgImage:image),raw=try XCTUnwrap(rep.colorAt(x:x,y:y))
        // colorAt reports calibrated RGB; assign the bitmap's actual profile before conversion.
        var values=[raw.redComponent,raw.greenComponent,raw.blueComponent,raw.alphaComponent]
        return try XCTUnwrap(NSColor(colorSpace:rep.colorSpace,components:&values,count:4).usingColorSpace(.sRGB))
    }
    func write(_ image:CGImage,_ name:String) throws {
        try FileManager.default.createDirectory(at:outputRoot,withIntermediateDirectories:true)
        let dest=try XCTUnwrap(CGImageDestinationCreateWithURL(outputRoot.appendingPathComponent(name) as CFURL,UTType.png.identifier as CFString,1,nil));CGImageDestinationAddImage(dest,image,nil);XCTAssertTrue(CGImageDestinationFinalize(dest))
    }
    func testPreviewApplyCornerOrientationUndoRedoAndSourceBytes() async throws {
        let (d,p)=try await fixture(),before=d.model,bytes=d.assets.mapValues(\.data)
        try write(try await p.renderDocument(model:d.model,assets:d.assets),"grid-before.png")
        try d.startPerspective();d.updatePerspective{$0.quad=quad;$0.mode=2;$0.widthText="600";$0.heightText="420"}
        XCTAssertTrue(d.sessionIsValid);XCTAssertEqual(d.model,before);XCTAssertEqual(d.history.entries.count,0)
        d.previewPerspective(true);let candidate=d.presentedModel
        let preview=try await p.renderDocument(model:candidate,assets:d.assets)
        d.previewPerspective(false);XCTAssertEqual(d.presentedModel,before);XCTAssertEqual(d.history.entries.count,0)
        d.applySession();XCTAssertEqual(d.model,candidate);XCTAssertEqual(d.history.entries.count,1)
        let result=try await p.renderDocument(model:d.model,assets:d.assets)
        XCTAssertEqual(result.width,600);XCTAssertEqual(result.height,420)
        XCTAssertEqual(result.colorSpace?.name,CGColorSpace.sRGB)
        XCTAssertEqual(result.dataProvider?.data as Data?,preview.dataProvider?.data as Data?)
        for (x,y,expected) in [(10,10,[1.0,0,0]),(590,10,[0.0,1,0]),(590,410,[0.0,0,1]),(10,410,[1.0,1,0])] {
            let c=try color(result,x,y)
            for (actual,value) in zip([c.redComponent,c.greenComponent,c.blueComponent],expected) {XCTAssertEqual(actual,value,accuracy:0.025)}
        }
        XCTAssertEqual(d.assets.mapValues(\.data),bytes)
        try write(result,"grid-after-600x420.png")
        let record:[String:Any]=["source":"grid-corners.png","order":["TL","TR","BR","BL"],"corners":quad.points.map{[$0.x,$0.y]},"output":[600,420],"cornerRGBTolerance":0.025,"previewApply":"identical RGBA bytes"]
        try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]).write(to:outputRoot.appendingPathComponent("parameters.json"))
        d.undoManager?.undo();XCTAssertEqual(d.model,before);XCTAssertFalse(d.isDocumentEdited)
        d.undoManager?.redo();XCTAssertEqual(d.model,candidate)
        try d.startPerspective();d.updatePerspective{$0.quad=PerspectiveQuad([.init(x:40,y:25),.init(x:560,y:40),.init(x:550,y:380),.init(x:50,y:395)])};d.applySession()
        XCTAssertEqual(d.history.entries.count,2);XCTAssertEqual(d.assets.mapValues(\.data),bytes)
        try write(try await p.renderDocument(model:d.model,assets:d.assets),"grid-repeat-crop.png")
        d.undoManager?.undo();XCTAssertEqual(d.model,candidate)
    }
    func testReferenceGradientAndAlphaAgainstIndependentMapping() async throws {
        // Known output->source mapping, independent of the quad solver under test.
        let known=try ProjectiveTransform([1.2,0.08,25,0.04,1.1,30,0.0003,0.0002,1]),size=try CanvasSize(width:400,height:300)
        let sourceQuad=PerspectiveQuad(try PerspectiveQuad.full(size).points.map{try known.applying(to:$0)})
        for name in ["colors-srgb.png","alpha-edges.png"] {
            let (d,p)=try await fixture(name)
            try d.startPerspective();d.updatePerspective{$0.quad=sourceQuad;$0.mode=2;$0.widthText="400";$0.heightText="300"};XCTAssertTrue(d.sessionIsValid);d.applySession()
            let result=try await p.renderDocument(model:d.model,assets:d.assets);try write(result,"reference-"+name)
            for y in stride(from:11,to:290,by:17) {for x in stride(from:13,to:390,by:19) {
                let source=try known.applying(to:.init(x:Double(x)+0.5,y:Double(y)+0.5)),c=try color(result,x,y)
                if name=="colors-srgb.png" {
                    XCTAssertEqual(c.redComponent,(source.x-0.5)/639,accuracy:0.012)
                    XCTAssertEqual(c.greenComponent,(source.y-0.5)/479,accuracy:0.012)
                    XCTAssertEqual(c.blueComponent,64.0/255,accuracy:0.006)
                } else {
                    let expected=max(0,min(1,(180-hypot(source.x-320,source.y-240))/24))
                    XCTAssertEqual(c.alphaComponent,expected,accuracy:0.025)
                    // Premultiplied RGBA8 quantization grows after unpremultiplication at low alpha.
                    XCTAssertEqual(c.redComponent*c.alphaComponent,c.alphaComponent,accuracy:2.0/255)
                    XCTAssertEqual(c.greenComponent*c.alphaComponent,0,accuracy:1.0/255)
                }
            }}
        }
    }
    func testEXIFRotatedCornersKeepNamedOrder() async throws {
        let (d,p)=try await fixture("grid-exif-6.jpg")
        XCTAssertEqual(d.model.canvas,try CanvasSize(width:480,height:640))
        try write(try await p.renderDocument(model:d.model,assets:d.assets),"exif-before.png")
        try d.startPerspective();d.updatePerspective{$0.quad=PerspectiveQuad([.init(x:12,y:15),.init(x:460,y:25),.init(x:450,y:620),.init(x:20,y:610)]);$0.mode=2;$0.widthText="450";$0.heightText="600"};d.applySession()
        let result=try await p.renderDocument(model:d.model,assets:d.assets);try write(result,"exif-after.png")
        for (x,y,expected) in [(10,10,[1.0,1,0]),(440,10,[1.0,0,0]),(440,590,[0.0,1,0]),(10,590,[0.0,0,1])] {
            let c=try color(result,x,y)
            for (actual,value) in zip([c.redComponent,c.greenComponent,c.blueComponent],expected) {XCTAssertEqual(actual,value,accuracy:0.04)}
        }
    }
    func testOutputModesInvalidInputCancelAndIndependentTabs() async throws {
        let (d,p)=try await fixture(),(other,_)=try await fixture(),before=d.model
        let coordinator=DocumentCoordinator(localization:l10n,pipeline:p);try coordinator.add(d);try coordinator.add(other)
        defer{for doc in coordinator.documents{coordinator.remove(doc.model.id)}}
        try d.startPerspective();XCTAssertFalse(d.sessionIsValid);d.updatePerspective{$0.quad=quad}
        let auto=d.perspectiveSession!.output!;d.swapPerspective();XCTAssertEqual(d.perspectiveSession?.quad,quad)
        XCTAssertEqual(d.perspectiveSession?.output?.width,auto.height)
        d.updatePerspective{$0.mode=1;$0.widthText="4";$0.heightText="3"};XCTAssertTrue(d.sessionIsValid)
        d.resetPerspective();XCTAssertEqual(d.perspectiveSession?.quad,.full(before.canvas));XCTAssertEqual(d.perspectiveSession?.mode,1)
        d.clearPerspective();XCTAssertEqual(d.perspectiveSession?.mode,0)
        for (w,h) in [("8001","1"),("8000","8000"),("10.5","10"),("0","10"),("","10"),("nan","10")] {
            d.updatePerspective{$0.mode=2;$0.widthText=w;$0.heightText=h};XCTAssertFalse(d.sessionIsValid);d.applySession();XCTAssertEqual(d.model,before)
        }
        d.updatePerspective{$0.mode=0;$0.quad=quad};d.previewPerspective(true)
        d.updatePerspective{$0.quad=PerspectiveQuad([.init(x:0,y:0),.init(x:600,y:450),.init(x:600,y:0),.init(x:0,y:450)])}
        XCTAssertFalse(d.sessionIsValid);XCTAssertFalse(d.perspectiveSession!.showsPreview)
        coordinator.select(other.model.id);try other.duplicateSelected();coordinator.select(d.model.id)
        XCTAssertNotNil(d.perspectiveSession);d.cancelSession();XCTAssertEqual(d.model,before);XCTAssertEqual(d.history.entries.count,0)
    }
    func testNativeInitialDragAllHandlesZoomPanPreviewAndReturn() async throws {
        let (d,p)=try await fixture(),coordinator=DocumentCoordinator(localization:l10n,pipeline:p);try coordinator.add(d)
        let controller=WorkspaceWindowController(preferences:WorkspacePreferences(defaults:UserDefaults(suiteName:UUID().uuidString)!),localization:l10n,restoreFrame:false)
        defer{controller.workspaceView.canvas.display(nil,pipeline:p);controller.close();coordinator.remove(d.model.id)}
        coordinator.changed={ [weak controller,weak coordinator] in if let coordinator{controller?.workspaceView.refreshDocuments(coordinator)} }
        controller.showWindow(nil);controller.reloadLayout();controller.workspaceView.refreshDocuments(coordinator)
        let canvas=controller.workspaceView.canvas
        func key(_ code:UInt16,_ text:String,_ flags:NSEvent.ModifierFlags=[])->NSEvent {NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:flags,timestamp:0,windowNumber:controller.window!.windowNumber,context:nil,characters:text,charactersIgnoringModifiers:text,isARepeat:false,keyCode:code)!}
        func event(_ kind:NSEvent.EventType,_ point:NSPoint)->NSEvent {NSEvent.mouseEvent(with:kind,location:canvas.convert(point,to:nil),modifierFlags:[],timestamp:0,windowNumber:controller.window!.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!}
        func drag(_ start:NSPoint,_ end:NSPoint) {canvas.mouseDown(with:event(.leftMouseDown,start));canvas.mouseDragged(with:event(.leftMouseDragged,end));canvas.mouseUp(with:event(.leftMouseUp,end))}
        func settled() async throws {for _ in 0..<200 {if canvas.presentedViewport==d.viewport && canvas.presentedModel==d.presentedModel {return};try await Task.sleep(for:.milliseconds(10))};XCTFail("Frame did not settle")}
        canvas.keyDown(with:key(8,"C",.shift));XCTAssertNotNil(d.perspectiveSession)
        XCTAssertFalse(controller.workspaceView.optionsBar.applyButton.isEnabled)
        for zoom in [0.5,1.0,2.0] {
            d.updatePerspective{$0.quad=nil};canvas.zoom(to:zoom);try await settled()
            func view(_ x:Double,_ y:Double)->NSPoint {let p=d.viewport.transform.viewPoint(fromDocument:.init(x:x,y:y));return .init(x:p.x,y:p.y)}
            drag(view(20,20),view(620,460));XCTAssertEqual(d.perspectiveSession?.quad?.points[0],Point2D(x:20,y:20))
            for i in 0..<4 {
                try await settled();let before=d.perspectiveSession!.quad!.points,target=NSPoint(x:canvas.perspectiveOverlay.corners[i].x+2,y:canvas.perspectiveOverlay.corners[i].y+1)
                drag(canvas.perspectiveOverlay.corners[i],target)
                let after=d.perspectiveSession!.quad!.points
                XCTAssertEqual(after[i].x,before[i].x+2*d.viewport.backingScale/zoom,accuracy:1e-6)
                for j in 0..<4 where j != i {XCTAssertEqual(after[j],before[j])}
            }
            try await settled();let before=d.perspectiveSession!.quad!
            drag(view(300,240),view(308,246));XCTAssertEqual(d.perspectiveSession!.quad!.points[0].x,before.points[0].x+8,accuracy:1e-6)
            try await settled();let stationary=d.perspectiveSession!.quad!,origin=d.viewport.origin
            canvas.keyDown(with:key(49," "));drag(view(300,240),view(320,250))
            canvas.keyUp(with:key(49," "));XCTAssertEqual(d.perspectiveSession?.quad,stationary);XCTAssertNotEqual(d.viewport.origin,origin)
        }
        d.previewPerspective(true);try await settled();XCTAssertTrue(canvas.perspectiveOverlay.isHidden)
        d.previewPerspective(false);try await settled();XCTAssertFalse(canvas.perspectiveOverlay.isHidden)
        let count=d.history.entries.count;canvas.keyDown(with:key(36,"\r"));XCTAssertEqual(d.history.entries.count,count+1);XCTAssertNil(d.perspectiveSession)
        canvas.keyDown(with:key(8,"C",.shift));d.resetPerspective();canvas.keyDown(with:key(53,"\u{1b}"));XCTAssertNil(d.perspectiveSession);XCTAssertEqual(d.history.entries.count,count+1)
    }
    func testNativeOptionsCallbacksAndLayoutInBothLanguages() async throws {
        try FileManager.default.createDirectory(at:outputRoot,withIntermediateDirectories:true)
        var measurements:[[String:Any]]=[]
        for language in [InterfaceLanguage.vietnamese,.english] {
            let loc=L10n(choice:language),(d,p)=try await fixture()
            let coordinator=DocumentCoordinator(localization:loc,pipeline:p);try coordinator.add(d)
            let controller=WorkspaceWindowController(preferences:WorkspacePreferences(defaults:UserDefaults(suiteName:UUID().uuidString)!),localization:loc,restoreFrame:false)
            defer{controller.workspaceView.canvas.display(nil,pipeline:p);controller.close();coordinator.remove(d.model.id)}
            coordinator.changed={ [weak controller,weak coordinator] in if let coordinator{controller?.workspaceView.refreshDocuments(coordinator)} }
            controller.showWindow(nil);controller.window!.setFrame(NSRect(x:30,y:30,width:1440,height:900),display:true)
            controller.reloadLayout();controller.workspaceView.refreshDocuments(coordinator)
            let root=controller.workspaceView,options=root.optionsBar
            root.canvas.selectTool(.perspectiveCrop);d.updatePerspective{$0.quad=quad}
            func descend(_ view:NSView)->[NSView] {[view]+view.subviews.flatMap(descend)}
            let controls=try XCTUnwrap(descend(options).compactMap{$0 as? PerspectiveOptionsView}.first)
            func send(_ control:NSControl) {XCTAssertTrue(NSApp.sendAction(control.action!,to:control.target,from:control));root.layoutSubtreeIfNeeded()}
            func button(_ key:String)throws->NSButton {try XCTUnwrap(controls.arrangedSubviews.compactMap{$0 as? NSButton}.first{$0.title==loc.text(key)})}
            XCTAssertEqual(controls.widthField.stringValue,"585");XCTAssertEqual(controls.heightField.stringValue,"430")
            controls.mode.selectItem(at:1);send(controls.mode);controls.ratio.selectItem(at:6);send(controls.ratio)
            XCTAssertEqual(d.perspectiveSession?.widthText,"210");XCTAssertEqual(d.perspectiveSession?.heightText,"297")
            try button("document.swap").performClick(nil);XCTAssertEqual(d.perspectiveSession?.quad,quad)
            XCTAssertEqual(d.perspectiveSession?.widthText,"297");XCTAssertEqual(d.perspectiveSession?.heightText,"210")
            controls.mode.selectItem(at:2);send(controls.mode)
            controls.widthField.stringValue="8001";controls.heightField.stringValue="120";controls.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification))
            XCTAssertFalse(options.applyButton.isEnabled)
            controls.widthField.stringValue="320";controls.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification))
            XCTAssertTrue(options.applyButton.isEnabled);XCTAssertEqual(d.perspectiveSession?.output,try CanvasSize(width:320,height:120))
            controls.preview.performClick(nil);XCTAssertTrue(d.perspectiveSession!.showsPreview);XCTAssertEqual(d.history.entries.count,0)
            controls.preview.performClick(nil);XCTAssertFalse(d.perspectiveSession!.showsPreview)
            try button("action.reset").performClick(nil);XCTAssertEqual(d.perspectiveSession?.quad,.full(d.model.canvas));XCTAssertEqual(d.perspectiveSession?.mode,2)
            try button("perspective.clear").performClick(nil);XCTAssertEqual(d.perspectiveSession?.mode,0)
            try button("options.grid").performClick(nil);XCTAssertFalse(d.perspectiveSession!.grid)
            controls.mode.selectItem(at:1);send(controls.mode)
            for width in [1440,1100] {
                controller.window!.setFrame(NSRect(x:30,y:30,width:width,height:800),display:true);controller.reloadLayout();root.layoutSubtreeIfNeeded()
                XCTAssertTrue(options.bounds.contains(options.applyButton.frame));XCTAssertTrue(options.bounds.contains(options.cancelButton.frame))
                XCTAssertFalse(options.applyButton.frame.intersects(options.cancelButton.frame))
                if width==1100 {options.frame.size.width=900;options.layoutSubtreeIfNeeded();XCTAssertTrue(options.usesOverflow);XCTAssertFalse(options.overflowButton.isHidden)}
                measurements.append(["language":language.rawValue,"widthPt":width,"backingScale":controller.window!.backingScaleFactor,"overflow":options.usesOverflow,"optionsBarWidthPt":options.bounds.width,"optionsWidthPt":controls.bounds.width,"optionsHeightPt":controls.bounds.height])
            }
            options.cancelButton.performClick(nil);XCTAssertNil(d.perspectiveSession)
        }
        try JSONSerialization.data(withJSONObject:measurements,options:[.prettyPrinted,.sortedKeys]).write(to:outputRoot.appendingPathComponent("perspective-layout.json"))
    }

    func testPoleOutsideRetainedRegionUsesBoundedMetalRender() async throws {
        let (d,p)=try await fixture("colors-srgb.png"),original=d.model,bytes=d.assets.mapValues(\.data)
        let size=try CanvasSize(width:400,height:300)
        // Independent output->source matrix: source pole of its inverse is y=50,
        // outside the retained trapezoid (y=150...450), but inside the original bitmap.
        let known=try ProjectiveTransform([0.35,-0.8,250,0,-0.125,150,0,-0.0025,1])
        let q=PerspectiveQuad(try PerspectiveQuad.full(size).points.map{try known.applying(to:$0)})
        try d.startPerspective();d.updatePerspective{$0.quad=q;$0.mode=2;$0.widthText="400";$0.heightText="300"}
        XCTAssertTrue(d.sessionIsValid);d.previewPerspective(true)
        let preview=try await p.renderDocument(model:d.presentedModel,assets:d.assets)
        d.applySession();let cropped=d.model
        XCTAssertThrowsError(try LayerGeometry.corners(size:original.canvas,transform:d.model.layers[0].transform))
        let result=try await p.renderDocument(model:d.model,assets:d.assets)
        XCTAssertEqual(result.dataProvider?.data as Data?,preview.dataProvider?.data as Data?)
        for y in stride(from:8,to:295,by:19) {for x in stride(from:9,to:395,by:23) {
            let point=try known.applying(to:.init(x:Double(x)+0.5,y:Double(y)+0.5)),c=try color(result,x,y)
            XCTAssertEqual(c.redComponent,(point.x-0.5)/639,accuracy:0.012)
            XCTAssertEqual(c.greenComponent,(point.y-0.5)/479,accuracy:0.012)
            XCTAssertEqual(c.alphaComponent,1,accuracy:0.01)
        }}
        try write(result,"pole-outside-clip.png")
        try d.perform(.canvasSize){try $0.canvasSize(CanvasSize(width:600,height:450),anchorX:0,anchorY:0)}
        let expanded=try await p.renderDocument(model:d.model,assets:d.assets)
        XCTAssertEqual(try color(expanded,500,400).alphaComponent,0,accuracy:0.01)
        let outsideHit=try await p.hitTest(model:d.model,assets:d.assets,point:.init(x:300,y:400))
        XCTAssertNil(outsideHit)
        let id=d.selectedLayerID!;try d.perform(.move){m in let moved=try m.layer(id)!.transform.followed(by:LayerGeometry.translation(x:20,y:30));try m.setTransform(id,moved)}
        try d.perform(.rotateCanvas){try $0.rotateCanvas(quarterTurns:1)}
        let rotated=try await p.renderDocument(model:d.model,assets:d.assets);try write(rotated,"pole-expand-move-rotate.png")
        XCTAssertEqual(try color(rotated,20,20).alphaComponent,0,accuracy:0.01)
        d.jumpHistory(to:1);XCTAssertEqual(d.model,cropped)
        try d.startPerspective();d.updatePerspective{$0.quad=PerspectiveQuad([.init(x:20,y:15),.init(x:370,y:20),.init(x:380,y:275),.init(x:25,y:285)])};XCTAssertTrue(d.sessionIsValid);d.applySession()
        _=try await p.renderDocument(model:d.model,assets:d.assets)
        XCTAssertEqual(d.assets.mapValues(\.data),bytes)
        d.jumpHistory(to:0);XCTAssertEqual(d.model,original)
    }

}

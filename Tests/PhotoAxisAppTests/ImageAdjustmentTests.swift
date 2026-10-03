import AppKit
import XCTest
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class ImageAdjustmentTests:XCTestCase {
    let loc=L10n(choice:.english)
    var root:URL {(0..<5).reduce(Bundle.main.bundleURL){url,_ in url.deletingLastPathComponent()}.appendingPathComponent("p08-native-tests")}
    func fixture(_ name:String="colors-srgb.png") async throws -> (PhotoDocument,ImagePipeline) {
        let p=ImagePipeline(),url=Bundle(for:Self.self).resourceURL!.appendingPathComponent("P02/"+name)
        let asset=try await p.prepare(.file(url),budget:ImportBudget())
        let d=PhotoDocument(model:try PhotoDocumentModel(name:"P08",canvas:asset.descriptor.size,ppi:72),localization:loc)
        try d.place(asset,recordHistory:false);d.markSaved(stateID:d.history.stateID);return(d,p)
    }
    func rgba(_ image:CGImage,_ x:Int,_ y:Int) throws -> [Double] {
        let rep=NSBitmapImageRep(cgImage:image),raw=try XCTUnwrap(rep.colorAt(x:x,y:y));var c=[raw.redComponent,raw.greenComponent,raw.blueComponent,raw.alphaComponent]
        let color=try XCTUnwrap(NSColor(colorSpace:rep.colorSpace,components:&c,count:4).usingColorSpace(.sRGB))
        return[color.redComponent,color.greenComponent,color.blueComponent,color.alphaComponent]
    }
    func write(_ image:CGImage,_ name:String) throws {
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let dest=try XCTUnwrap(CGImageDestinationCreateWithURL(root.appendingPathComponent(name) as CFURL,UTType.png.identifier as CFString,1,nil))
        CGImageDestinationAddImage(dest,image,nil);XCTAssertTrue(CGImageDestinationFinalize(dest))
    }
    func testTransactionCancelUndoBranchEnableResetLockAndNoSourceMutation() async throws {
        let(d,_)=try await fixture(),original=d.model,bytes=d.assets.mapValues(\.data),id=d.selectedLayerID!
        for value in stride(from:-4.0,through:4,by:0.25) {try d.previewAdjustment(.exposure,value:value)}
        XCTAssertEqual(d.model,original);XCTAssertEqual(d.history.entries.count,0)
        d.cancelSession();XCTAssertEqual(d.presentedModel,original)
        try d.previewAdjustment(.brightness,value:30);d.applySession();let saved=d.model
        XCTAssertEqual(d.history.entries.count,1);XCTAssertEqual(d.undoManager?.undoActionName,"Image Adjustments")
        d.undoManager?.undo();XCTAssertEqual(d.model,original);XCTAssertFalse(d.isDocumentEdited)
        d.undoManager?.redo();XCTAssertEqual(d.model,saved)
        try d.setAdjustmentsEnabled(false);XCTAssertEqual(d.model.layer(id)?.adjustments.brightness,30)
        XCTAssertEqual(d.model.layer(id)?.adjustments.enabled,false)
        try d.resetAdjustments();XCTAssertEqual(d.model.layer(id)?.adjustments,ImageAdjustments())
        d.undoManager?.undo();XCTAssertEqual(d.model.layer(id)?.adjustments.enabled,false)
        d.undoManager?.undo();XCTAssertEqual(d.model,saved)
        XCTAssertThrowsError(try d.previewAdjustment(.contrast,value:101));XCTAssertFalse(d.sessionIsValid)
        d.applySession();XCTAssertEqual(d.model,saved);d.cancelSession()
        try d.perform(.lock){try $0.setLock(id,true)}
        XCTAssertThrowsError(try d.previewAdjustment(.exposure,value:1))
        XCTAssertThrowsError(try d.resetAdjustments());d.undoManager?.undo()
        try d.previewAdjustment(.brightness,value:10);d.applySession();XCTAssertFalse(d.undoManager!.canRedo)
        XCTAssertEqual(d.assets.mapValues(\.data),bytes)
        XCTAssertEqual(d.model.layer(id)?.content,original.layer(id)?.content)
    }
    func testNeutralExtremesOrderAndBypassPixelOracle() async throws {
        let(d,p)=try await fixture(),id=d.selectedLayerID!,original=try await p.renderDocument(model:d.model,assets:d.assets)
        try write(original,"neutral.png")
        func render(_ a:ImageAdjustments) async throws -> CGImage {
            try d.perform(.adjustments){try $0.setAdjustments(id,a)}
            return try await p.renderDocument(model:d.model,assets:d.assets)
        }
        var a=ImageAdjustments();a.saturation = -100
        let gray=try await render(a);try write(gray,"saturation-minus100.png")
        for (x,y) in [(30,40),(250,120),(550,420)] {let c=try rgba(gray,x,y);XCTAssertEqual(c[0],c[1],accuracy:1.0/255);XCTAssertEqual(c[1],c[2],accuracy:1.0/255)}
        a.enabled=false;let bypass=try await render(a);XCTAssertEqual(bypass.dataProvider?.data as Data?,original.dataProvider?.data as Data?)
        a=ImageAdjustments();a.contrast = -100;let flat=try await render(a)
        for v in try rgba(flat,300,200).prefix(3) {XCTAssertEqual(v,0.735357,accuracy:0.008)}
        for value in [-100.0,100] {a=ImageAdjustments();a.brightness=value;let image=try await render(a);for v in try rgba(image,300,200).prefix(3) {XCTAssertEqual(v,value<0 ? 0:1,accuracy:0.008)}}
        for value in [-4.0,4] {a=ImageAdjustments();a.exposure=value;let image=try await render(a);try write(image,value<0 ? "exposure-minus4.png":"exposure-plus4.png")}
        a=ImageAdjustments();a.contrast=100;_ = try await render(a)
        a=ImageAdjustments();a.saturation=100;_ = try await render(a)
        a=ImageAdjustments();a.exposure=0.5;a.contrast = -25;a.brightness=3
        let adjusted=try await render(a),source=try rgba(original,300,200),actual=try rgba(adjusted,300,200)
        func linear(_ v:Double)->Double {v<=0.04045 ? v/12.92:pow((v+0.055)/1.055,2.4)}
        func srgb(_ v:Double)->Double {let c=min(1,max(0,v));return c<=0.0031308 ? c*12.92:1.055*pow(c,1/2.4)-0.055}
        for i in 0..<3 {let expected=srgb((linear(source[i])*sqrt(2)-0.5)*0.75+0.5+0.03);XCTAssertEqual(actual[i],expected,accuracy:0.008)}
        try write(adjusted,"combined-order.png")
        let neutral=try await render(ImageAdjustments());XCTAssertEqual(neutral.dataProvider?.data as Data?,original.dataProvider?.data as Data?)
    }
    func testAlphaOtherLayerAndPerspectivePreserveLocalAdjustment() async throws {
        let(d,p)=try await fixture("alpha-edges.png"),id=d.selectedLayerID!,bytes=d.assets.mapValues(\.data)
        let original=try await p.renderDocument(model:d.model,assets:d.assets)
        var a=ImageAdjustments();a.exposure=2;a.brightness=15;a.contrast=45;a.saturation=100
        try d.perform(.adjustments){try $0.setAdjustments(id,a)}
        let adjusted=try await p.renderDocument(model:d.model,assets:d.assets);try write(adjusted,"alpha-adjusted.png")
        var samples=0,partial=0
        for y in stride(from:0,to:480,by:17) {for x in stride(from:0,to:640,by:17) {
            let before=try rgba(original,x,y),after=try rgba(adjusted,x,y)
            XCTAssertEqual(after[3],before[3],accuracy:1.0/255);samples+=1;if before[3]>0 && before[3]<1 {partial+=1}
        }};XCTAssertGreaterThan(partial,20)
        let other=try await p.prepare(.file(Bundle(for:Self.self).resourceURL!.appendingPathComponent("P02/grid-corners.png")),budget:d.importBudget)
        try d.perform(.canvasSize){try $0.canvasSize(CanvasSize(width:1280,height:480),anchorX:0,anchorY:0)}
        try d.place(other);let otherID=d.selectedLayerID!
        try d.perform(.transform){try $0.setTransform(otherID,LayerGeometry.translation(x:640,y:0))}
        try d.perform(.perspectiveCrop){try $0.perspectiveCrop(.init([.init(x:20,y:10),.init(x:1250,y:40),.init(x:1220,y:465),.init(x:40,y:445)]),output:CanvasSize(width:640,height:240))}
        let before=d.model,baseline=try await p.renderDocument(model:before,assets:d.assets)
        d.selectLayer(id);try d.previewAdjustment(.saturation,value:-100);d.applySession()
        let after=try await p.renderDocument(model:d.model,assets:d.assets);try write(after,"perspective-two-layers.png")
        XCTAssertEqual(d.model.layer(otherID),before.layer(otherID));XCTAssertEqual(d.model.layer(id)?.transform,before.layer(id)?.transform);XCTAssertEqual(d.model.layer(id)?.clip,before.layer(id)?.clip)
        for (x,y) in [(410,60),(520,120),(610,30)] {let c1=try rgba(baseline,x,y),c2=try rgba(after,x,y);for i in 0..<4 {XCTAssertEqual(c1[i],c2[i],accuracy:0.001)}}
        XCTAssertEqual(d.assets.filter{bytes[$0.key] != nil}.mapValues(\.data),bytes)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        try JSONSerialization.data(withJSONObject:["alphaSamples":samples,"partialAlphaSamples":partial,"alphaTolerance":1.0/255,"otherLayerUnchanged":true],options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("pixel-checks.json"))
    }
    func testNativeControlsCommitCancelInvalidLockAndLanguageLayout() async throws {
        for language in [InterfaceLanguage.vietnamese,.english] {
            let(d,p)=try await fixture(),before=d.model
            let coordinator=DocumentCoordinator(localization:L10n(choice:language),pipeline:p);try coordinator.add(d)
            let suite="P08-"+UUID().uuidString,defaults=UserDefaults(suiteName:suite)!
            let host=WorkspaceWindowController(preferences:WorkspacePreferences(defaults:defaults),localization:L10n(choice:language),restoreFrame:false)
            defer {host.workspaceView.canvas.display(nil,pipeline:p);host.close();coordinator.remove(d.model.id);defaults.removePersistentDomain(forName:suite)}
            coordinator.changed={ [weak host,weak coordinator] in if let coordinator {host?.workspaceView.refreshDocuments(coordinator)} }
            host.showWindow(nil);host.window!.setFrame(NSRect(x:20,y:20,width:1100,height:700),display:true);host.reloadLayout();host.workspaceView.refreshDocuments(coordinator)
            let controls=host.workspaceView.sidebar.adjustmentControls,options=host.workspaceView.optionsBar
            XCTAssertFalse(controls.isHidden);XCTAssertTrue(host.workspaceView.sidebar.contentControls.isHidden)
            for field in controls.fields {XCTAssertTrue(field.isEnabled);XCTAssertGreaterThan(field.frame.width,40);XCTAssertFalse(field.cell!.sendsActionOnEndEditing)}
            let slider=controls.sliders[0],window=host.window!
            host.workspaceView.layoutSubtreeIfNeeded()
            let knob=try XCTUnwrap(slider.cell as? NSSliderCell).knobRect(flipped:slider.isFlipped)
            let start=slider.convert(NSPoint(x:knob.midX,y:knob.midY),to:nil)
            let end=slider.convert(NSPoint(x:slider.bounds.maxX-25,y:knob.midY),to:nil)
            func mouse(_ kind:NSEvent.EventType,_ point:NSPoint)->NSEvent {
                NSEvent.mouseEvent(with:kind,location:point,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
            }
            slider.mouseDown(with:mouse(.leftMouseDown,start))
            for n in 1...12 {
                let point=NSPoint(x:start.x+(end.x-start.x)*Double(n)/12,y:start.y)
                slider.mouseDragged(with:mouse(.leftMouseDragged,point))
            }
            XCTAssertEqual(d.model,before);XCTAssertTrue(d.hasAdjustmentSession)
            XCTAssertEqual(d.history.entries.count,0,"Drag ticks stay in preview")
            slider.mouseUp(with:mouse(.leftMouseUp,end))
            XCTAssertGreaterThan(d.model.layers[0].adjustments.exposure,2)
            XCTAssertEqual(d.history.entries.count,1,"A native drag creates one Undo")
            XCTAssertFalse(slider.trackingGesture);XCTAssertFalse(d.hasSession)
            d.undoManager?.undo();XCTAssertEqual(d.model,before)
            slider.doubleValue=2
            XCTAssertTrue(NSApp.sendAction(slider.action!,to:slider.target,from:slider))
            XCTAssertEqual(d.model.layers[0].adjustments.exposure,2,"Keyboard/accessibility action survives begin refresh")
            XCTAssertEqual(d.history.entries.count,1);XCTAssertFalse(d.hasSession)
            d.undoManager?.undo();XCTAssertEqual(d.model,before)
            // Start number checks with a fresh Undo branch after the drag.
            let exposure=controls.fields[0];host.window?.makeFirstResponder(exposure)
            exposure.stringValue="1";controls.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:exposure))
            XCTAssertEqual(d.model,before);XCTAssertTrue(d.hasAdjustmentSession);XCTAssertTrue(options.applyButton.isEnabled)
            XCTAssertTrue(NSApp.sendAction(options.cancelButton.action!,to:options.cancelButton.target,from:options.cancelButton))
            XCTAssertFalse(d.hasSession);XCTAssertEqual(d.model,before);XCTAssertEqual(d.history.cursor,0)
            exposure.stringValue="1.25".replacingOccurrences(of:".",with:Locale.current.decimalSeparator ?? ".")
            XCTAssertTrue(NSApp.sendAction(exposure.action!,to:exposure.target,from:exposure));XCTAssertFalse(d.hasSession)
            XCTAssertEqual(d.model.layers[0].adjustments.exposure,1.25);XCTAssertEqual(d.history.entries.count,1)
            d.undoManager?.undo();XCTAssertEqual(d.model,before);d.undoManager?.redo()
            exposure.stringValue="999";controls.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:exposure))
            XCTAssertFalse(d.sessionIsValid);XCTAssertFalse(options.applyButton.isEnabled)
            XCTAssertEqual(controls.message.textColor,.systemRed)
            let editor=try XCTUnwrap(host.window?.fieldEditor(true,for:exposure) as? NSTextView)
            XCTAssertTrue(controls.control(exposure,textView:editor,doCommandBy:#selector(NSResponder.cancelOperation(_:))))
            XCTAssertFalse(d.hasSession);XCTAssertEqual(d.history.entries.count,1)
            controls.enable.state = .off;XCTAssertTrue(NSApp.sendAction(controls.enable.action!,to:controls.enable.target,from:controls.enable))
            XCTAssertFalse(d.model.layers[0].adjustments.enabled);XCTAssertEqual(d.model.layers[0].adjustments.exposure,1.25)
            XCTAssertTrue(NSApp.sendAction(controls.reset.action!,to:controls.reset.target,from:controls.reset));XCTAssertTrue(d.model.layers[0].adjustments.isNeutral)
            let beforeOpacity=d.model,opacitySlider=host.workspaceView.sidebar.opacitySlider
            let opacityKnob=try XCTUnwrap(opacitySlider.cell as? NSSliderCell).knobRect(flipped:opacitySlider.isFlipped)
            let opacityStart=opacitySlider.convert(NSPoint(x:opacityKnob.midX,y:opacityKnob.midY),to:nil)
            let opacityEnd=opacitySlider.convert(NSPoint(x:opacitySlider.bounds.midX,y:opacityKnob.midY),to:nil)
            let count=d.history.entries.count
            opacitySlider.mouseDown(with:mouse(.leftMouseDown,opacityStart))
            opacitySlider.mouseDragged(with:mouse(.leftMouseDragged,opacityEnd))
            XCTAssertEqual(d.model,beforeOpacity);XCTAssertEqual(d.history.entries.count,count)
            opacitySlider.mouseUp(with:mouse(.leftMouseUp,opacityEnd))
            XCTAssertEqual(d.history.entries.count,count+1);XCTAssertEqual(d.model.layers[0].opacity,0.5,accuracy:0.01)
            d.undoManager?.undo();XCTAssertEqual(d.model,beforeOpacity)
            try d.perform(.lock){try $0.setLock(d.selectedLayerID!,true)}
            XCTAssertTrue(controls.fields.allSatisfy{!$0.isEnabled});XCTAssertFalse(controls.enable.isEnabled)
            // Scroll to the final field in a narrow native Properties pane.
            controls.fields[3].scrollToVisible(controls.fields[3].bounds);host.workspaceView.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(controls.fields[3].visibleRect.width,40)
        }
    }
    func testRapidPreviewTabSwitchAndShortResponseMeasurement() async throws {
        let(d,p)=try await fixture(),(other,_)=try await fixture("grid-corners.png")
        let canvas=WelcomeCanvasView(localization:loc);canvas.frame=NSRect(x:0,y:0,width:640,height:480)
        canvas.display(d,pipeline:p)
        d.changed={ [weak canvas,weak d] in if let d {canvas?.display(d,pipeline:p)} }
        let start=ProcessInfo.processInfo.systemUptime
        for n in 0..<60 {try d.previewAdjustment(.exposure,value:Double(n%9)-4)}
        canvas.display(other,pipeline:p)
        for _ in 0..<200 {if canvas.presentedModel==other.model {break};try await Task.sleep(for:.milliseconds(10))}
        XCTAssertEqual(canvas.presentedModel,other.model)
        canvas.display(d,pipeline:p)
        let candidate=d.presentedModel
        for _ in 0..<200 {if canvas.presentedModel==candidate {break};try await Task.sleep(for:.milliseconds(10))}
        XCTAssertEqual(canvas.presentedModel,candidate);XCTAssertNotNil(canvas.metal.image)
        d.applySession();XCTAssertEqual(d.history.entries.count,1)
        let warmDecodes=await p.normalizedDecodeCount
        var timings:[Double]=[]
        for n in 0..<20 {
            let begin=ProcessInfo.processInfo.systemUptime
            try d.previewAdjustment(.saturation,value:Double(n*10)-100)
            _=try await p.renderDocument(model:d.presentedModel,assets:d.assets)
            timings.append(ProcessInfo.processInfo.systemUptime-begin)
        }
        d.cancelSession()
        let decodes=await p.normalizedDecodeCount,cache=await p.cacheBytes
        XCTAssertEqual(decodes,warmDecodes,"No source decode per warm slider tick")
        let thumbnailBefore=try await p.thumbnail(layer:d.selectedLayer!,assets:d.assets)
        try d.setAdjustmentsEnabled(false)
        let thumbnailAfter=try await p.thumbnail(layer:d.selectedLayer!,assets:d.assets)
        XCTAssertNotEqual(thumbnailBefore?.dataProvider?.data as Data?,thumbnailAfter?.dataProvider?.data as Data?)
        canvas.display(nil,pipeline:p);d.changed=nil
        await p.retainCache(for:[]);let released=await p.cacheBytes;XCTAssertEqual(released,0)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let sorted=timings.sorted()
        let record:[String:Any]=["queuedPreviewChanges":60,"renderSamples":20,"fixture":[640,480],"renderSeconds":timings,"medianSeconds":sorted[10],"maximumSeconds":sorted.last!,"elapsedSeconds":ProcessInfo.processInfo.systemUptime-start,"normalizedDecodeCount":decodes,"decodedCacheBytes":cache,"cacheAfterRelease":released,"scope":"small fixture worker render and stale-frame correctness; not P12 full-quota UI latency"]
        try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("response-measurements.json"))
    }
}

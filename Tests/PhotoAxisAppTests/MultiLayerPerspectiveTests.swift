import AppKit
import XCTest
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class MultiLayerPerspectiveTests:XCTestCase {
    let loc=L10n(choice:.english)
    let output=try! CanvasSize(width:400,height:300)
    let inverse=try! ProjectiveTransform([1.2,0.08,25,0.04,1.1,30,0.0003,0.0002,1])
    var outputRoot:URL {(0..<5).reduce(Bundle.main.bundleURL){url,_ in url.deletingLastPathComponent()}.appendingPathComponent("p07-native-tests")}
    struct Fixture {let d:PhotoDocument,p:ImagePipeline,image:UUID,text:UUID,shape:UUID,hidden:UUID,locked:UUID}
    func fixture() async throws -> Fixture {
        let p=ImagePipeline(),url=Bundle(for:Self.self).resourceURL!.appendingPathComponent("P02/colors-srgb.png")
        let asset=try await p.prepare(.file(url),budget:ImportBudget())
        let d=PhotoDocument(model:try PhotoDocumentModel(name:"P07 Mixed",canvas:asset.descriptor.size,ppi:144),localization:loc)
        try d.place(asset,recordHistory:false);let image=d.selectedLayerID!
        var model=d.model
        var text=TextContent(text:"PHỐI CẢNH",fontName:"Helvetica-Bold",fontSize:28,color:.white)
        text=try ContentRasterizer.measured(text)
        let t=try model.insertContent(.text(text),name:"Chữ cũ",transform:LayerGeometry.translation(x:80,y:80),above:nil)
        var ellipse=ShapeContent(kind:.ellipse,size:try CanvasSize(width:150,height:110),fill:RGBAColor(red:1,green:0.25,blue:0,alpha:0.6))
        ellipse.strokeWidth=5;ellipse.stroke = .white
        let s=try model.insertContent(.shape(ellipse),name:"Ellipse",transform:LayerGeometry.translation(x:220,y:155),above:nil)
        let hidden=try model.insertContent(.shape(.init(kind:.rectangle,size:CanvasSize(width:75,height:45),fill:.black)),name:"Hidden",transform:LayerGeometry.translation(x:320,y:220),above:nil)
        try model.setVisibility(hidden,false)
        var line=ShapeContent(kind:.line,size:try CanvasSize(width:220,height:22),fill:.clear)
        line.stroke=RGBAColor(red:0,green:1,blue:1);line.strokeWidth=6
        let locked=try model.insertContent(.shape(line),name:"Locked",transform:LayerGeometry.translation(x:90,y:290),above:nil)
        try model.setLock(locked,true)
        let copy=try model.duplicate(image,name:"Second image")
        try model.setTransform(copy,ProjectiveTransform([0.18,0,70,0,0.18,170,0,0,1]));try model.setOpacity(copy,0.7)
        d.commit(model,command:.createShape);d.markSaved(stateID:d.history.stateID)
        return Fixture(d:d,p:p,image:image,text:t,shape:s,hidden:hidden,locked:locked)
    }
    func crop(_ d:PhotoDocument) throws {
        let quad=PerspectiveQuad(try PerspectiveQuad.full(output).points.map{try inverse.applying(to:$0)})
        try d.startPerspective();d.updatePerspective{$0.quad=quad;$0.mode=2;$0.widthText="400";$0.heightText="300"}
        XCTAssertTrue(d.sessionIsValid)
    }
    func write(_ image:CGImage,_ name:String) throws {
        try FileManager.default.createDirectory(at:outputRoot,withIntermediateDirectories:true)
        let dest=try XCTUnwrap(CGImageDestinationCreateWithURL(outputRoot.appendingPathComponent(name) as CFURL,UTType.png.identifier as CFString,1,nil))
        CGImageDestinationAddImage(dest,image,nil);XCTAssertTrue(CGImageDestinationFinalize(dest))
    }
    func pixel(_ image:CGImage,_ x:Int,_ y:Int) throws -> [Double] {
        let rep=NSBitmapImageRep(cgImage:image),c=try XCTUnwrap(rep.colorAt(x:x,y:y))
        var components=[c.redComponent,c.greenComponent,c.blueComponent,c.alphaComponent]
        let actual=try XCTUnwrap(NSColor(colorSpace:rep.colorSpace,components:&components,count:4).usingColorSpace(.sRGB))
        return [actual.redComponent,actual.greenComponent,actual.blueComponent,actual.alphaComponent]
    }
    func testMixedPreviewCommonMappingPixelOracleAndHistory() async throws {
        let f=try await fixture(),d=f.d,before=d.model,bytes=d.assets.mapValues(\.data),count=d.history.entries.count
        let original=try await f.p.renderDocument(model:before,assets:d.assets);try write(original,"mixed-before.png")
        try crop(d);d.previewPerspective(true);let candidate=d.presentedModel
        XCTAssertEqual(d.model,before);XCTAssertEqual(d.history.entries.count,count)
        let preview=try await f.p.renderDocument(model:candidate,assets:d.assets)
        d.applySession();let after=d.model,result=try await f.p.renderDocument(model:after,assets:d.assets)
        XCTAssertEqual(after,candidate);XCTAssertEqual(d.history.entries.count,count+1)
        XCTAssertEqual(result.dataProvider?.data as Data?,preview.dataProvider?.data as Data?)
        XCTAssertEqual(after.layers.map(\.id),before.layers.map(\.id));XCTAssertEqual(d.assets.mapValues(\.data),bytes)
        for (old,new) in zip(before.layers,after.layers) {
            XCTAssertEqual(old.content,new.content);XCTAssertEqual(old.isLocked,new.isLocked);XCTAssertEqual(old.isVisible,new.isVisible);XCTAssertEqual(old.opacity,new.opacity)
            let local=Point2D(x:15,y:12),expected=try inverse.inverted().applying(to:old.transform.applying(to:local)),actual=try new.transform.applying(to:local)
            XCTAssertEqual(actual.x,expected.x,accuracy:1e-7);XCTAssertEqual(actual.y,expected.y,accuracy:1e-7)
        }
        // Reproject the pre-crop composite through an independently known inverse.
        // Exclude high contrast edges to avoid conflating filter kernels with geometry.
        var checked=0,foreground=0,maxError=0.0
        for y in stride(from:5,to:295,by:7) {for x in stride(from:5,to:395,by:7) {
            let p=try inverse.applying(to:.init(x:Double(x)+0.5,y:Double(y)+0.5)),sx=Int(floor(p.x)),sy=Int(floor(p.y))
            let expected=try pixel(original,sx,sy),actual=try pixel(result,x,y)
            var smooth=true
            for dy in [-2,0,2] {for dx in [-2,0,2] {
                let neighbor=try pixel(original,sx+dx,sy+dy)
                if zip(expected,neighbor).contains(where:{abs($0-$1)>0.025}) {smooth=false}
            }}
            guard smooth else{continue};checked+=1
            if abs(expected[2]-64.0/255)>0.08{foreground+=1}
            for (a,b) in zip(actual,expected){maxError=max(maxError,abs(a-b));XCTAssertEqual(a,b,accuracy:0.018)}
        }}
        XCTAssertGreaterThan(checked,1000);XCTAssertGreaterThan(foreground,20)
        try write(result,"mixed-after.png")
        d.undoManager?.undo();XCTAssertEqual(d.model,before);XCTAssertFalse(d.isDocumentEdited)
        d.undoManager?.redo();XCTAssertEqual(d.model,after)
        try d.startPerspective();d.updatePerspective{$0.quad=PerspectiveQuad([.init(x:20,y:15),.init(x:380,y:25),.init(x:365,y:280),.init(x:25,y:270)])};d.applySession()
        let twice=d.model;XCTAssertEqual(d.history.entries.count,count+2)
        try write(try await f.p.renderDocument(model:twice,assets:d.assets),"mixed-second-crop.png")
        d.undoManager?.undo();XCTAssertEqual(d.model,after);d.undoManager?.redo();XCTAssertEqual(d.model,twice)
        let record:[String:Any]=["layers":before.layers.count,"inverse":inverse.coefficients,"output":[400,300],"smoothSamples":checked,"foregroundSamples":foreground,"maximumChannelError":maxError,"tolerance":0.018,"previewApplyBytesEqual":true]
        try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]).write(to:outputRoot.appendingPathComponent("pixel-oracle.json"))
    }
    func testOldTextShapeEditsNewLayersAndProjectiveHitMoveTransform() async throws {
        let f=try await fixture(),d=f.d;try crop(d);d.applySession()
        let old=d.model.layer(f.text)!,oldShape=d.model.layer(f.shape)!,bytes=d.assets.mapValues(\.data)
        try d.startContentEdit(f.text);XCTAssertTrue(d.contentSession!.usesProperties)
        guard case .text(var t)=old.content else{return XCTFail("Typed text missing")}
        t.text="CHỮ MỚI";t.color=RGBAColor(red:1,green:1,blue:0);d.updateContent(.text(t));d.applySession()
        XCTAssertEqual(d.model.layer(f.text)?.transform,old.transform);XCTAssertEqual(d.model.layer(f.text)?.clip,old.clip)
        guard case .text(let edited)=d.model.layer(f.text)!.content else{return XCTFail("Text flattened")};XCTAssertEqual(edited.text,"CHỮ MỚI")
        try d.startContentEdit(f.shape)
        guard case .shape(var shape)=oldShape.content else{return XCTFail("Shape missing")}
        shape.fill=RGBAColor(red:0,green:1,blue:0.2,alpha:0.5);shape.strokeWidth=9;d.updateContent(.shape(shape));d.applySession()
        XCTAssertEqual(d.model.layer(f.shape)?.transform,oldShape.transform);XCTAssertEqual(d.model.layer(f.shape)?.clip,oldShape.clip)
        let hitPoint=try oldShape.transform.applying(to:.init(x:75,y:45))
        let hit=try await f.p.hitTest(model:d.model,assets:d.assets,point:hitPoint);XCTAssertEqual(hit,f.shape)
        d.selectLayer(f.shape);try d.beginSession(.move);try d.previewMove(x:12,y:8,fromOriginal:true);d.applySession()
        let moved=try d.model.layer(f.shape)!.transform.applying(to:.init(x:75,y:45))
        XCTAssertEqual(moved.x,hitPoint.x+12,accuracy:1e-7);XCTAssertEqual(moved.y,hitPoint.y+8,accuracy:1e-7)
        let b=try d.model.bounds(of:f.shape);try d.setTransformValue(.width,b.width*1.2);d.applySession()
        XCTAssertEqual(try d.model.bounds(of:f.shape).width,b.width*1.2,accuracy:1e-7);XCTAssertEqual(d.model.layer(f.shape)?.clip,oldShape.clip)
        try d.startText(at:.init(x:30,y:20));t.text="THẲNG";t.fontSize=20;d.updateContent(.text(t));d.applySession()
        let newText=d.selectedLayer!;XCTAssertTrue(newText.transform.isAffine);XCTAssertEqual(newText.transform,try LayerGeometry.translation(x:30,y:20));XCTAssertTrue(newText.clip.isEmpty)
        try d.startContentEdit(newText.id);XCTAssertFalse(d.contentSession!.usesProperties);d.cancelSession()
        try d.startShape(kind:.rectangle,at:.init(x:10,y:250));d.updateContent(.shape(.init(kind:.rectangle,size:try CanvasSize(width:100,height:20),fill:.white)));d.applySession()
        XCTAssertEqual(d.selectedLayer!.transform,try LayerGeometry.translation(x:10,y:250));XCTAssertTrue(d.selectedLayer!.clip.isEmpty)
        try write(try await f.p.renderDocument(model:d.model,assets:d.assets),"edited-and-new-layers.png")
        let asset=try XCTUnwrap(d.assets.values.first);try d.place(asset)
        XCTAssertTrue(d.selectedLayer!.transform.isAffine);XCTAssertTrue(d.selectedLayer!.clip.isEmpty)
        XCTAssertEqual(d.assets.mapValues(\.data),bytes);XCTAssertEqual(d.model.sources.count,1)
    }
    func testHiddenLockedAndDiscardedContentNeverReappears() async throws {
        let f=try await fixture(),d=f.d;try crop(d);d.applySession()
        let hidden=d.model.layer(f.hidden)!,locked=d.model.layer(f.locked)!
        XCTAssertFalse(hidden.isVisible);XCTAssertTrue(locked.isLocked)
        XCTAssertThrowsError(try d.startContentEdit(f.locked))
        try d.perform(.visibility){try $0.setVisibility(f.hidden,true)}
        try d.perform(.lock){try $0.setLock(f.locked,false)}
        XCTAssertEqual(d.model.layer(f.hidden)?.transform,hidden.transform);XCTAssertEqual(d.model.layer(f.locked)?.transform,locked.transform)
        let hiddenPoint=try hidden.transform.applying(to:.init(x:20,y:15))
        let hit=try await f.p.hitTest(model:d.model,assets:d.assets,point:hiddenPoint);XCTAssertEqual(hit,f.hidden)
        try write(try await f.p.renderDocument(model:d.model,assets:d.assets),"unhidden-unlocked.png")
        // Crop a strip through a large editable shape, then enlarge canvas and move.
        let m=try PhotoDocumentModel(name:"Clip",canvas:CanvasSize(width:200,height:160),ppi:72),clipDoc=PhotoDocument(model:m,localization:loc)
        try clipDoc.startShape(kind:.rectangle,at:.init(x:0,y:0))
        var rectangle=ShapeContent(kind:.rectangle,size:m.canvas,fill:.white)
        clipDoc.updateContent(.shape(rectangle));clipDoc.applySession();let id=clipDoc.selectedLayerID!
        try clipDoc.perform(.perspectiveCrop){try $0.perspectiveCrop(.init([.init(x:40,y:30),.init(x:160,y:40),.init(x:150,y:130),.init(x:50,y:120)]),output:CanvasSize(width:120,height:90))}
        let clipped=clipDoc.model.layer(id)!
        try clipDoc.perform(.canvasSize){try $0.canvasSize(CanvasSize(width:300,height:220),anchorX:0,anchorY:0)}
        clipDoc.selectLayer(id);try clipDoc.beginSession(.move);try clipDoc.previewMove(x:50,y:50,fromOriginal:true);clipDoc.applySession()
        try clipDoc.startContentEdit(id);rectangle.fill=RGBAColor(red:1,green:0,blue:0);rectangle.size=try CanvasSize(width:250,height:200);clipDoc.updateContent(.shape(rectangle));clipDoc.applySession()
        XCTAssertEqual(clipDoc.model.layer(id)?.clip,clipped.clip)
        let image=try await f.p.renderDocument(model:clipDoc.model,assets:[:]);try write(image,"clip-after-resize-move-edit.png")
        XCTAssertEqual(try pixel(image,100,90)[3],1,accuracy:0.01)
        for (x,y) in [(10,10),(35,90),(190,90),(100,165)] {XCTAssertEqual(try pixel(image,x,y)[3],0,accuracy:0.01)}
        let outside=try await f.p.hitTest(model:clipDoc.model,assets:[:],point:.init(x:190,y:90));XCTAssertNil(outside)
        try clipDoc.perform(.perspectiveCrop){try $0.perspectiveCrop(.full($0.canvas),output:$0.canvas)}
        let repeated=try await f.p.renderDocument(model:clipDoc.model,assets:[:]);XCTAssertEqual(try pixel(repeated,190,90)[3],0,accuracy:0.01)
    }
    func testRepeatedCropTransformKeepsResourcesAndTypedSources() async throws {
        let f=try await fixture(),d=f.d,original=d.model,bytes=d.assets.mapValues(\.data)
        let start=ProcessInfo.processInfo.systemUptime
        for n in 0..<24 {
            let before=d.model,c=d.model.canvas,w=Double(c.width),h=Double(c.height)
            try d.startPerspective();d.updatePerspective{$0.quad=PerspectiveQuad([.init(x:1,y:1),.init(x:w-2,y:2),.init(x:w-4,y:h-1),.init(x:2,y:h-2)]);$0.mode=2;$0.widthText=String(c.width);$0.heightText=String(c.height)}
            XCTAssertTrue(d.sessionIsValid,"Iteration \(n)");d.applySession();let after=d.model
            d.undoManager?.undo();XCTAssertEqual(d.model,before);d.undoManager?.redo();XCTAssertEqual(d.model,after)
            d.selectLayer(f.shape);try d.beginSession(.move);try d.previewMove(x:n%2==0 ? 1:-1,y:0,fromOriginal:true);d.applySession()
            _=try await f.p.renderDocument(model:d.model,assets:d.assets)
            XCTAssertEqual(d.model.layers.map(\.content),original.layers.map(\.content));XCTAssertEqual(d.assets.mapValues(\.data),bytes)
            XCTAssertLessThanOrEqual(d.history.entries.count,100);XCTAssertLessThanOrEqual(d.history.retainedBytes,128*1024*1024)
        }
        try d.startContentEdit(f.text);XCTAssertTrue(d.contentSession!.usesProperties);d.cancelSession()
        let cache=await f.p.cacheBytes;XCTAssertLessThanOrEqual(cache,ImagePipeline.cacheLimit)
        await f.p.retainCache(for:[]);let released=await f.p.cacheBytes;XCTAssertEqual(released,0)
        try FileManager.default.createDirectory(at:outputRoot,withIntermediateDirectories:true)
        let record:[String:Any]=["cycles":24,"seconds":ProcessInfo.processInfo.systemUptime-start,"layerCount":d.model.layers.count,"sourceCount":d.model.sources.count,"sourceBytes":bytes.values.reduce(0){$0+$1.count},"historySteps":d.history.entries.count,"historyBytes":d.history.retainedBytes,"decodedCacheBytes":cache,"cacheBytesAfterRelease":released,"scope":"small fixture stability; not P12 full quota benchmark"]
        try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]).write(to:outputRoot.appendingPathComponent("repeat-resources.json"))
    }
    func testFullyDiscardedTypedLayersStayEmptyAfterExpansionAndMove() async throws {
        let f=try await fixture(),d=f.d,contents=d.model.layers.map(\.content),bytes=d.assets.mapValues(\.data)
        try d.perform(.move){m in
            for layer in m.layers {
                try m.setLock(layer.id,false);try m.setTransform(layer.id,layer.transform.followed(by:LayerGeometry.translation(x:900,y:800)))
                try m.setLock(layer.id,layer.isLocked)
            }
        }
        try crop(d);d.applySession()
        XCTAssertTrue(d.model.layers.allSatisfy{$0.clip == [[]]})
        try d.perform(.canvasSize){try $0.canvasSize(CanvasSize(width:800,height:600),anchorX:0,anchorY:0)}
        try d.perform(.move){m in
            for layer in m.layers {
                try m.setLock(layer.id,false);try m.setVisibility(layer.id,true)
                try m.setTransform(layer.id,LayerGeometry.translation(x:20,y:20))
            }
        }
        let image=try await f.p.renderDocument(model:d.model,assets:d.assets)
        for (x,y) in [(25,25),(80,80),(300,250)] {XCTAssertEqual(try pixel(image,x,y)[3],0,accuracy:0.001)}
        let hit=try await f.p.hitTest(model:d.model,assets:d.assets,point:.init(x:80,y:80));XCTAssertNil(hit)
        XCTAssertEqual(d.model.layers.map(\.content),contents);XCTAssertEqual(d.assets.mapValues(\.data),bytes)
        try d.startText(at:.init(x:30,y:30));var text=d.textDefaults;text.text="Mới";d.updateContent(.text(text));d.applySession()
        XCTAssertTrue(d.selectedLayer!.clip.isEmpty);XCTAssertTrue(d.selectedLayer!.transform.isAffine)
        try write(try await f.p.renderDocument(model:d.model,assets:d.assets),"fully-clipped-plus-new-text.png")
    }
    func testPropertiesEditorVisibleAndFocusForBothLanguages() async throws {
        for language in [InterfaceLanguage.vietnamese,.english] {
            let f=try await fixture(),d=f.d;try crop(d);d.applySession()
            // A scale-equivalent representation must still route to Properties.
            try d.perform(.transform){let m=$0.layer(f.text)!.transform;try $0.setTransform(f.text,ProjectiveTransform(m.coefficients.map{$0*1e-18}))}
            let coordinator=DocumentCoordinator(localization:L10n(choice:language),pipeline:f.p);try coordinator.add(d)
            let controller=WorkspaceWindowController(preferences:WorkspacePreferences(defaults:UserDefaults(suiteName:UUID().uuidString)!),localization:L10n(choice:language),restoreFrame:false)
            defer{controller.workspaceView.canvas.display(nil,pipeline:f.p);controller.close();coordinator.remove(d.model.id)}
            coordinator.changed={ [weak controller,weak coordinator] in if let coordinator{controller?.workspaceView.refreshDocuments(coordinator)} }
            controller.showWindow(nil);controller.window!.setFrame(NSRect(x:30,y:30,width:1100,height:700),display:true);controller.reloadLayout();controller.workspaceView.refreshDocuments(coordinator)
            let root=controller.workspaceView;root.canvas.contentEditing.edit(f.text);root.layoutSubtreeIfNeeded()
            let controls=root.sidebar.contentControls,editor=controls.propertiesEditor
            XCTAssertTrue(d.contentSession!.usesProperties);XCTAssertTrue(root.canvas.contentEditing.inlineEditor.isHidden)
            XCTAssertTrue(controller.window?.firstResponder===editor.editor)
            XCTAssertGreaterThanOrEqual(editor.visibleRect.height,100)
            XCTAssertTrue(controls.documentVisibleRect.intersects(editor.frame))
            editor.editor.selectAll(nil);editor.editor.insertText("Chữ sau crop",replacementRange:NSRange(location:NSNotFound,length:0));editor.editor.didChangeText()
            let matrix=d.model.layer(f.text)!.transform,clip=d.model.layer(f.text)!.clip
            let apply=root.optionsBar.applyButton
            XCTAssertTrue(NSApp.sendAction(apply.action!,to:apply.target,from:apply))
            XCTAssertNil(d.contentSession);XCTAssertEqual(d.model.layer(f.text)?.transform,matrix);XCTAssertEqual(d.model.layer(f.text)?.clip,clip)
            let count=d.history.entries.count;root.canvas.contentEditing.edit(f.text)
            editor.editor.insertText(" hủy",replacementRange:NSRange(location:NSNotFound,length:0));editor.editor.didChangeText();XCTAssertTrue(NSApp.sendAction(root.optionsBar.cancelButton.action!,to:root.optionsBar.cancelButton.target,from:root.optionsBar.cancelButton))
            XCTAssertNil(d.contentSession);XCTAssertEqual(d.history.entries.count,count)
            root.sidebar.inspectorTabs.selectedSegment=1;root.sidebar.changeInspector()
            root.canvas.contentEditing.edit(f.shape);root.layoutSubtreeIfNeeded()
            XCTAssertEqual(root.sidebar.inspectorTabs.selectedSegment,0)
            XCTAssertTrue(controls.propertiesEditor.isHidden)
            XCTAssertTrue(controller.window?.firstResponder===controls.width.currentEditor())
            XCTAssertTrue(NSApp.sendAction(root.optionsBar.cancelButton.action!,to:root.optionsBar.cancelButton.target,from:root.optionsBar.cancelButton))
        }
    }
}

import AppKit
import XCTest
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class ContentEditingTests:XCTestCase {
    let loc=L10n(choice:.english)
    var outputRoot:URL{(0..<5).reduce(Bundle.main.bundleURL){url,_ in url.deletingLastPathComponent()}.appendingPathComponent("p06-native-tests")}
    func document()throws->PhotoDocument{PhotoDocument(model:try PhotoDocumentModel(name:"P06",canvas:CanvasSize(width:640,height:480),ppi:72),localization:loc)}
    func write(_ image:CGImage,_ name:String)throws {
        try FileManager.default.createDirectory(at:outputRoot,withIntermediateDirectories:true)
        let dest=try XCTUnwrap(CGImageDestinationCreateWithURL(outputRoot.appendingPathComponent(name) as CFURL,UTType.png.identifier as CFString,1,nil));CGImageDestinationAddImage(dest,image,nil);XCTAssertTrue(CGImageDestinationFinalize(dest))
    }
    func pixel(_ image:CGImage,_ x:Int,_ y:Int)throws->[Double] {
        let rep=NSBitmapImageRep(cgImage:image),raw=try XCTUnwrap(rep.colorAt(x:x,y:y));var values=[raw.redComponent,raw.greenComponent,raw.blueComponent,raw.alphaComponent]
        let c=try XCTUnwrap(NSColor(colorSpace:rep.colorSpace,components:&values,count:4).usingColorSpace(.sRGB));return [c.redComponent,c.greenComponent,c.blueComponent,c.alphaComponent]
    }
    func testTextSessionsUnicodeFontFallbackAndUndo() async throws {
        let d=try document(),original=d.model;d.markSaved(stateID:d.history.stateID)
        try d.startText(at:.init(x:20,y:30));var t=d.textDefaults;t.text="Tiếng Việt — PhotoAxis\nV T C Space ă â ê ô ơ ư đ";t.fontSize=24;t.alignment = .center;t.lineSpacing=8
        d.updateContent(.text(t));XCTAssertTrue(d.sessionIsValid);XCTAssertEqual(d.model,original);XCTAssertEqual(d.history.entries.count,0)
        d.cancelSession();XCTAssertEqual(d.model,original);XCTAssertNil(d.selectedLayerID)
        try d.startText(at:.init(x:20,y:30));d.updateContent(.text(t));d.applySession()
        XCTAssertEqual(d.history.entries.count,1);let id=try XCTUnwrap(d.selectedLayerID),saved=d.model
        guard case .text(var savedText)=d.model.layer(id)?.content else{return XCTFail("Missing typed text")}
        XCTAssertEqual(savedText.text,t.text);XCTAssertGreaterThan(savedText.layoutSize.width,100)
        let p=ImagePipeline(),image=try await p.renderDocument(model:d.model,assets:[:]);try write(image,"vietnamese-text.png")
        d.undoManager?.undo();XCTAssertEqual(d.model,original);XCTAssertFalse(d.isDocumentEdited);d.undoManager?.redo();XCTAssertEqual(d.model,saved)
        try d.startContentEdit(id);savedText.fontName="PhotoAxis-Missing-Font-123";savedText.fontFamily="Original Family";savedText.fontStyle="Original Style"
        d.updateContent(.text(savedText));d.applySession();let missing=d.model
        XCTAssertTrue(ContentRasterizer.missingFont(savedText));_ = try await p.renderDocument(model:d.model,assets:[:]);XCTAssertEqual(d.model,missing)
        try d.startContentEdit(id);savedText.fontName="Helvetica-Bold";d.updateContent(.text(savedText));d.applySession()
        d.undoManager?.undo();XCTAssertEqual(d.model,missing);XCTAssertEqual(d.model.layer(id)?.transform,saved.layer(id)?.transform)
    }
    func testShapeAlphaHitTestingAndCompositeEyedropper() async throws {
        let d=try document(),p=ImagePipeline()
        var shape=ShapeContent(kind:.ellipse,size:try CanvasSize(width:100,height:80),fill:RGBAColor(red:1,green:0,blue:0,alpha:0.5));shape.strokeWidth=4;shape.stroke = .black
        try d.perform(.createShape){try $0.insertContent(.shape(shape),name:"Ellipse",transform:LayerGeometry.translation(x:20,y:30),above:nil)}
        let id=d.model.layers[0].id,image=try await p.renderDocument(model:d.model,assets:[:]);try write(image,"ellipse-alpha.png")
        let center=try await p.sample(model:d.model,assets:[:],point:.init(x:70,y:70));XCTAssertEqual(center.red,1,accuracy:0.02);XCTAssertEqual(center.alpha,0.5,accuracy:0.01)
        let corner=try await p.hitTest(model:d.model,assets:[:],point:.init(x:20,y:30)),hit=try await p.hitTest(model:d.model,assets:[:],point:.init(x:70,y:70));XCTAssertNil(corner);XCTAssertEqual(hit,id)
        let clear=try await p.sample(model:d.model,assets:[:],point:.init(x:0,y:0));XCTAssertEqual(clear,.clear)
        var outline=shape;outline.fill = .clear;try d.perform(.editShape){try $0.setContent(id,.shape(outline))}
        let noHit=try await p.hitTest(model:d.model,assets:[:],point:.init(x:70,y:70));XCTAssertNil(noHit)
        try d.perform(.lock){try $0.setLock(id,true)};XCTAssertThrowsError(try d.startContentEdit(id))
        d.undoManager?.undo();try d.perform(.opacity){try $0.setOpacity(id,0.5)}
        try write(try await p.renderDocument(model:d.model,assets:[:]),"ellipse-outline-opacity.png")
        // Image-only sampling remains independent of viewport checkerboard and selections.
        d.showTransformControls=true;d.viewport.setZoom(2)
        let sampled=try await p.sample(model:d.model,assets:[:],point:.init(x:0,y:0));XCTAssertEqual(sampled,.clear)
    }
    func testTextRenderingAlignmentBoundsAndQuota() async throws {
        var t=TextContent(text:"AV\nÁ",fontName:"Helvetica-Oblique",fontSize:48,color:RGBAColor(red:0,green:0,blue:1,alpha:0.75))
        t=try ContentRasterizer.measured(t);let left=try ContentRasterizer.textImage(t)
        t.alignment = .right;let right=try ContentRasterizer.textImage(t)
        XCTAssertNotEqual(left.dataProvider?.data as Data?,right.dataProvider?.data as Data?)
        XCTAssertEqual(left.width,t.layoutSize.width);XCTAssertEqual(left.height,t.layoutSize.height)
        try write(right,"text-alignment-alpha.png")
        t.text=String(repeating:"W",count:1000);t.fontSize=1000;XCTAssertThrowsError(try ContentRasterizer.measured(t))
        t.text="A";t.fontSize=1001;XCTAssertThrowsError(try ContentRasterizer.measured(t))
        t.fontSize=1;t.text="";XCTAssertNoThrow(try ContentRasterizer.measured(t))
    }
    func testNativeCompositionTypingKeysCancelAndApply() async throws {
        let d=try document(),coordinator=DocumentCoordinator(localization:loc,pipeline:ImagePipeline());try coordinator.add(d)
        let controller=WorkspaceWindowController(preferences:WorkspacePreferences(defaults:UserDefaults(suiteName:UUID().uuidString)!),localization:loc,restoreFrame:false)
        defer{controller.workspaceView.canvas.display(nil,pipeline:coordinator.pipeline);controller.close();coordinator.remove(d.model.id)}
        coordinator.changed={ [weak controller,weak coordinator] in if let coordinator{controller?.workspaceView.refreshDocuments(coordinator)} }
        controller.showWindow(nil);controller.reloadLayout();controller.workspaceView.refreshDocuments(coordinator)
        let canvas=controller.workspaceView.canvas;canvas.selectTool(.type);try d.startText(at:.init(x:40,y:50));canvas.contentEditing.refresh()
        let host=canvas.contentEditing.inlineEditor,editor=host.editor;host.focus();XCTAssertTrue(controller.window?.firstResponder===editor)
        editor.setMarkedText("Tieengs",selectedRange:NSRange(location:6,length:0),replacementRange:NSRange(location:NSNotFound,length:0));editor.didChangeText()
        XCTAssertTrue(editor.hasMarkedText());XCTAssertFalse(d.sessionIsValid);d.applySession();XCTAssertEqual(d.model.layers.count,0)
        editor.insertText("Tiếng",replacementRange:editor.markedRange());editor.didChangeText();XCTAssertFalse(editor.hasMarkedText())
        editor.insertText(" Việt V T C ",replacementRange:NSRange(location:NSNotFound,length:0));editor.insertNewline(nil);editor.insertText("Đường phố",replacementRange:NSRange(location:NSNotFound,length:0));editor.didChangeText()
        XCTAssertEqual(d.activeTool,.type);XCTAssertEqual(editor.string,"Tiếng Việt V T C \nĐường phố")
        let enter=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:.command,timestamp:0,windowNumber:controller.window!.windowNumber,context:nil,characters:"\r",charactersIgnoringModifiers:"\r",isARepeat:false,keyCode:36)!
        editor.keyDown(with:enter);XCTAssertNil(d.contentSession);XCTAssertEqual(d.history.entries.count,1)
        let before=d.model;canvas.contentEditing.edit(d.selectedLayerID!);editor.insertText(" hủy",replacementRange:NSRange(location:NSNotFound,length:0));editor.didChangeText()
        let escape=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:controller.window!.windowNumber,context:nil,characters:"\u{1b}",charactersIgnoringModifiers:"\u{1b}",isARepeat:false,keyCode:53)!
        editor.keyDown(with:escape);XCTAssertEqual(d.model,before);XCTAssertEqual(d.history.entries.count,1)
        // Ending a numeric field sends its action again. Apply must end that
        // editing before committing, otherwise a new content session reopens.
        let size=controller.workspaceView.sidebar.contentControls.size
        controller.window?.makeFirstResponder(size);size.selectText(nil)
        size.currentEditor()?.string="30";size.stringValue="30"
        _ = size.sendAction(size.action!,to:size.target)
        controller.workspaceView.optionsBar.applyButton.performClick(nil)
        XCTAssertNil(d.contentSession);XCTAssertEqual(d.history.entries.count,2)
        controller.window?.makeFirstResponder(size);size.selectText(nil)
        size.currentEditor()?.string="40";size.stringValue="40"
        _ = size.sendAction(size.action!,to:size.target)
        controller.workspaceView.optionsBar.cancelButton.performClick(nil)
        XCTAssertNil(d.contentSession);XCTAssertEqual(d.history.entries.count,2)
        guard case .text(let applied)=d.selectedLayer?.content else{return XCTFail("Expected text")}
        XCTAssertEqual(applied.fontSize,30)
    }
    func testNativeShapeGesturesAndPropertiesRouting() async throws {
        let d=try document(),coordinator=DocumentCoordinator(localization:loc,pipeline:ImagePipeline());try coordinator.add(d)
        let controller=WorkspaceWindowController(preferences:WorkspacePreferences(defaults:UserDefaults(suiteName:UUID().uuidString)!),localization:loc,restoreFrame:false)
        defer{controller.workspaceView.canvas.display(nil,pipeline:coordinator.pipeline);controller.close();coordinator.remove(d.model.id)}
        coordinator.changed={ [weak controller,weak coordinator] in if let coordinator{controller?.workspaceView.refreshDocuments(coordinator)} }
        controller.showWindow(nil);controller.reloadLayout();controller.workspaceView.refreshDocuments(coordinator)
        let c=controller.workspaceView.canvas
        func view(_ x:Double,_ y:Double)->NSPoint{let p=d.viewport.transform.viewPoint(fromDocument:.init(x:x,y:y));return .init(x:p.x,y:p.y)}
        for tool in [ToolKind.rectangle,.ellipse,.line] {
            c.selectTool(tool);c.contentEditing.down(view(40,40),shift:true);c.contentEditing.drag(view(140,105),shift:true);c.contentEditing.up(view(140,105),shift:true)
            XCTAssertTrue(d.sessionIsValid)
            guard case .shape(let shape)=d.contentSession?.draft else{return XCTFail("Shape missing")}
            XCTAssertEqual(shape.size.width,shape.size.height);d.applySession()
        }
        XCTAssertEqual(d.history.entries.count,3);let before=d.model
        c.selectTool(.rectangle);c.contentEditing.down(view(40,40),shift:false);d.cancelSession();XCTAssertEqual(d.model,before)
        try d.startText(at:.init(x:10,y:10));var t=d.textDefaults;t.text="Phối cảnh";d.updateContent(.text(t));d.applySession();let id=d.selectedLayerID!
        try d.perform(.transform){try $0.setTransform(id,ProjectiveTransform([1,0,10,0,1,10,0.0003,0.0002,1]))}
        c.contentEditing.edit(id);XCTAssertTrue(d.contentSession?.usesProperties==true);XCTAssertTrue(controller.window?.firstResponder===controller.workspaceView.sidebar.contentControls.propertiesEditor.editor)
        let matrix=d.model.layer(id)?.transform;t.text="Chữ mới";d.updateContent(.text(t));d.applySession();XCTAssertEqual(d.model.layer(id)?.transform,matrix)
    }
    func testInspectorLayoutColorActionsAndMissingFontNotice() throws {
        for choice in [InterfaceLanguage.vietnamese,.english] {
            let localization=L10n(choice:choice),d=try document()
            let controls=ContentControlsView(localization:localization)
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:260,height:310),styleMask:[.titled],backing:.buffered,defer:false)
            window.isReleasedWhenClosed=false;window.contentView=controls
            defer{window.close()}
            d.activeTool = .type;controls.refresh(d);controls.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(controls.size.frame.width,110)
            XCTAssertGreaterThan(controls.message.frame.height,30)
            let source=try XCTUnwrap(controls.documentView)
            for row in source.subviews where !row.isHidden {
                XCTAssertLessThanOrEqual(row.frame.maxX,source.bounds.width)
                XCTAssertGreaterThan(row.frame.height,0)
            }
            try d.startText(at:.init(x:10,y:10));var text=d.textDefaults;text.text="Chữ Việt";text.fontName="Missing-P06-Font"
            d.updateContent(.text(text));controls.refresh(d)
            XCTAssertTrue(controls.message.stringValue.contains("Missing-P06-Font"))
            controls.size.stringValue="36";_ = controls.size.sendAction(controls.size.action!,to:controls.size.target)
            guard case .text(let draft)=d.contentSession?.draft else{return XCTFail("Text draft missing")}
            XCTAssertEqual(draft.fontSize,36);XCTAssertEqual(draft.fontName,"Missing-P06-Font")
            var invalid=draft;invalid.fontSize=1e100;d.updateContent(.text(invalid))
            XCTAssertFalse(d.sessionIsValid)
            let editor=NativeTextEditor(localization:localization);editor.refresh(d)
            XCTAssertEqual(editor.editor.font?.pointSize,36)
            d.updateContent(.text(draft))
            let colors=ColorControlsView(localization:localization);colors.refresh(d)
            colors.hex.stringValue="#1278FF";_ = colors.hex.sendAction(colors.hex.action!,to:colors.hex.target)
            XCTAssertEqual(d.foreground.hex,"#1278FF")
            colors.refresh(d);colors.alpha.stringValue="50";_ = colors.alpha.sendAction(colors.alpha.action!,to:colors.alpha.target)
            XCTAssertEqual(d.foreground.alpha,0.5)
            colors.hex.stringValue="invalid";_ = colors.hex.sendAction(colors.hex.action!,to:colors.hex.target)
            XCTAssertEqual(d.foreground.hex,"#1278FF");XCTAssertEqual(d.history.entries.count,0)
        }
    }

    func testInstalledVietnameseInputContext() async throws {
        let d=try document(),host=NativeTextEditor(localization:loc)
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:500,height:240),styleMask:[.titled],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.contentView=host
        try d.startText(at:.init(x:10,y:10));host.refresh(d);window.makeKeyAndOrderFront(nil);host.focus()
        let context=try XCTUnwrap(host.editor.inputContext),original=context.selectedKeyboardInputSource
        defer{context.selectedKeyboardInputSource=original;context.deactivate();window.close()}
        NSApp.activate(ignoringOtherApps:true);context.activate()
        try await Task.sleep(for:.milliseconds(300))
        let sources=context.keyboardInputSources ?? []
        try FileManager.default.createDirectory(at:outputRoot,withIntermediateDirectories:true)
        try ("Available sources: \(sources)\nSelected: \(context.selectedKeyboardInputSource ?? "nil")\n").write(to:outputRoot.appendingPathComponent("native-ime.txt"),atomically:true,encoding:.utf8)
        let telex=sources.first(where:{$0.contains("Vietnamese") && $0.contains("Telex")}) ?? "com.apple.inputmethod.VietnameseSimpleTelex"
        context.selectedKeyboardInputSource=telex
        try await Task.sleep(for:.milliseconds(300))
        let diagnostic="Available sources: \(sources)\nOriginal: \(original ?? "nil")\nRequested: \(telex)\nSelected: \(context.selectedKeyboardInputSource ?? "nil")\nAllowed locales: \(context.allowedInputSourceLocales ?? [])\n"
        try diagnostic.write(to:outputRoot.appendingPathComponent("native-ime.txt"),atomically:true,encoding:.utf8)
        guard context.selectedKeyboardInputSource==telex else{throw XCTSkip("The native context cannot activate Telex; manual IME acceptance remains required")}
        XCTAssertEqual(context.selectedKeyboardInputSource,telex)
        let keyCodes:[Character:UInt16]=["t":17,"i":34,"e":14,"n":45,"g":5,"s":1," ":49,"v":9,"j":38]
        for character in "tieengs vieetj " {
            let value=String(character),code=try XCTUnwrap(keyCodes[character])
            let event=try XCTUnwrap(NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,characters:value,charactersIgnoringModifiers:value,isARepeat:false,keyCode:code))
            host.editor.keyDown(with:event)
            try await Task.sleep(for:.milliseconds(30))
        }
        host.editor.unmarkText();host.editor.didChangeText()
        XCTAssertEqual(host.editor.string,"tiếng việt ")
        try FileManager.default.createDirectory(at:outputRoot,withIntermediateDirectories:true)
        let evidence="Source: \(telex)\nInput: tieengs vieetj <space>\nActual: \(host.editor.string)\nMarked after commit: \(host.editor.hasMarkedText())\n"
        try evidence.write(to:outputRoot.appendingPathComponent("native-ime.txt"),atomically:true,encoding:.utf8)
    }

}

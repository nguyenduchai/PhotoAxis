import AppKit
import XCTest
import ImageIO
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class AcceptanceWorkflowTests: XCTestCase {
    func testFullMixedWorkflowSaveCloseReopenContinueAndExportBothLanguages() async throws {
        let output = (0..<5).reduce(Bundle.main.bundleURL) { url,_ in url.deletingLastPathComponent() }.appendingPathComponent("p12-workflow")
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        var records:[[String:Any]] = []
        for language in [InterfaceLanguage.vietnamese,.english] {
            let loc = L10n(choice:language), builder = MultiLayerPerspectiveTests(), f = try await builder.fixture()
            let d = PhotoDocument(loaded:f.d.snapshot(),url:nil,localization:loc)
            let c = DocumentCoordinator(localization:loc,pipeline:f.p,recoveryRoot:output.appendingPathComponent(".qa-recovery-"+UUID().uuidString))
            try c.add(d); let bytes = d.assets.mapValues(\.data)
            try await c.exportStore.write(d.snapshot(),options:ExportOptions(size:d.model.canvas,ppi:d.model.ppi),to:output.appendingPathComponent("before-"+loc.language+".png"))
            try builder.crop(d); d.applySession()
            d.textDefaults = TextContent(text:"",fontName:"Helvetica-Bold",fontSize:24,color:.white)
            try d.startText(at:Point2D(x:25,y:240)); var typed = d.textDefaults; typed.text = "PHAN THIẾT\nChữ mới sau nắn"; d.updateContent(.text(typed)); d.applySession()
            let newText = try XCTUnwrap(d.selectedLayerID); XCTAssertTrue(d.model.layer(newText)!.transform.isAffine)
            var adjustment = ImageAdjustments(); adjustment.exposure = 0.375; adjustment.saturation = -12.5
            try d.perform(.adjustments) { try $0.setAdjustments(f.image,adjustment) }
            let savedModel = d.model, project = output.appendingPathComponent("workflow-"+loc.language+".paxis")
            let saved = await c.save(d,saveAs:true,destination:project); XCTAssertTrue(saved); XCTAssertFalse(d.isDocumentEdited)
            let closed = await c.requestCloseAll(); XCTAssertTrue(closed); XCTAssertTrue(c.documents.isEmpty)
            c.startImport([.file(project)],into:nil); await c.importTask?.value
            let reopened = try XCTUnwrap(c.active); XCTAssertEqual(reopened.model,savedModel); XCTAssertTrue(reopened.history.entries.isEmpty); XCTAssertFalse(reopened.isDocumentEdited)
            let old = try XCTUnwrap(reopened.model.layer(f.text)); guard case .text(var text) = old.content else { return XCTFail("Old text lost its type") }
            text.text += " — sửa tiếp"; try reopened.startContentEdit(f.text); XCTAssertTrue(reopened.contentSession?.usesProperties == true)
            reopened.updateContent(.text(text)); reopened.applySession()
            XCTAssertEqual(reopened.model.layer(f.text)?.transform,old.transform); XCTAssertEqual(reopened.model.layer(f.text)?.clip,old.clip)
            let state = reopened.history.stateID, expected = reopened.model
            for format in [ExportFormat.png,.jpeg] {
                var options = ExportOptions(size:reopened.model.canvas,ppi:reopened.model.ppi); options.format = format
                let target = output.appendingPathComponent("after-"+loc.language+(format == .png ? ".png" : ".jpg"))
                let exported = await c.export(reopened.snapshot(),options:options,destination:target); XCTAssertTrue(exported)
                let source = try XCTUnwrap(CGImageSourceCreateWithURL(target as CFURL,nil)), image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source,0,nil))
                XCTAssertEqual(image.width,400); XCTAssertEqual(image.height,300); XCTAssertEqual(image.bitsPerComponent,8)
            }
            XCTAssertEqual(reopened.model,expected); XCTAssertEqual(reopened.history.stateID,state); XCTAssertTrue(reopened.isDocumentEdited); XCTAssertEqual(reopened.assets.mapValues(\.data),bytes)
            await c.flushRecovery(); let recoveries = await c.recoveryEntries(); XCTAssertEqual(recoveries.count,1)
            c.confirmClose = { _ in .discard }; let finish = await c.requestCloseAll(); XCTAssertTrue(finish)
            let empty = await c.recoveryEntries(); XCTAssertTrue(empty.isEmpty)
            records.append(["interfaceLanguage":loc.language,"canvas":[400,300],"sourceSHA256":Array(bytes.keys).sorted(),"layerCount":expected.layers.count,"oldTextRemainsProjective":!old.transform.isAffine,"newTextRemainsAffine":expected.layer(newText)!.transform.isAffine,"sourceBytesUnchanged":true,"dirtyAfterExport":true,"scope":"scripted real coordinator, Image I/O, document commands, shared renderer, ZIP, Export and Recovery; Unicode strings supplied directly, no claim of physical Telex/VNI or SavePanel pointer acceptance"])
        }
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("workflow-results.json"))
    }
}

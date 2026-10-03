import AppKit
import XCTest
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class ProjectDocumentTests: XCTestCase {
    var outputRoot: URL { (0..<5).reduce(Bundle.main.bundleURL) { url,_ in url.deletingLastPathComponent() }.appendingPathComponent("p09-native-tests") }
    func output(_ name: String) throws -> URL {
        try FileManager.default.createDirectory(at:outputRoot,withIntermediateDirectories:true)
        return outputRoot.appendingPathComponent(name)
    }
    func testMixedTwiceCroppedRoundTripImmutableAssetsRenderCrossLanguageAndEditability() async throws {
        let builder = MultiLayerPerspectiveTests(), f = try await builder.fixture(), d = f.d
        try builder.crop(d); d.applySession()
        try d.perform(.perspectiveCrop) { try $0.perspectiveCrop(.init([.init(x:15,y:10),.init(x:380,y:20),.init(x:370,y:280),.init(x:20,y:275)]),output:CanvasSize(width:320,height:240)) }
        var adjustment = ImageAdjustments(); adjustment.exposure = 1.125; adjustment.brightness = -12.25; adjustment.contrast = 25.5; adjustment.saturation = -31.75
        try d.perform(.adjustments) { try $0.setAdjustments(f.image,adjustment) }
        var missing = TextContent(text:"PHỐI CẢNH\nĐường biển",fontName:"PhotoAxisMissingFont-Fixture",fontSize:24,color:.white)
        missing.layoutSize = try CanvasSize(width:240,height:100)
        try d.perform(.createText) { _ = try $0.insertContent(.text(missing),name:"Chữ mới có dấu",transform:LayerGeometry.translation(x:40.125,y:30.875),above:nil) }
        let snapshot = d.snapshot(), sourceBytes = snapshot.assets.mapValues(\.data)
        let before = try await f.p.renderDocument(model:snapshot.model,assets:snapshot.assets)
        let store = ProjectStore(pipeline:f.p), url = try output("Dự án phối cảnh.paxis")
        try await store.save(snapshot,to:url)
        let copy = try output("copied-without-original.paxis"); try? FileManager.default.removeItem(at:copy); try FileManager.default.copyItem(at:url,to:copy)
        let loaded = try await store.open(copy)
        XCTAssertEqual(loaded.model,snapshot.model); XCTAssertEqual(loaded.assets.mapValues(\.data),sourceBytes)
        let after = try await f.p.renderDocument(model:loaded.model,assets:loaded.assets)
        XCTAssertEqual(after.dataProvider?.data as Data?,before.dataProvider?.data as Data?)
        for language in [InterfaceLanguage.vietnamese,.english] {
            let reopened = PhotoDocument(loaded:loaded,url:copy,localization:L10n(choice:language))
            XCTAssertFalse(reopened.isDocumentEdited); XCTAssertTrue(reopened.history.entries.isEmpty)
            XCTAssertEqual(reopened.model,d.model); XCTAssertEqual(reopened.assets.mapValues(\.data),sourceBytes)
            var text: TextContent
            guard case .text(let original) = reopened.model.layer(f.text)!.content else { return XCTFail("Text payload missing") }
            text = original; text.text += " — sửa tiếp"; text = try ContentRasterizer.measured(text)
            let old = reopened.model.layer(f.text)!
            try reopened.perform(.editText) { try $0.setContent(f.text,.text(text)) }
            XCTAssertEqual(reopened.model.layer(f.text)?.transform,old.transform); XCTAssertEqual(reopened.model.layer(f.text)?.clip,old.clip)
            XCTAssertTrue(reopened.isDocumentEdited); reopened.undoManager?.undo(); XCTAssertFalse(reopened.isDocumentEdited)
        }
        let preview = try BoundedZIP.read(url:copy)
        XCTAssertEqual(preview.count,d.model.sources.count+2)
        try before.dataProvider?.data.map { try ($0 as Data).write(to:output("before.rgba")) }
        try after.dataProvider?.data.map { try ($0 as Data).write(to:output("after.rgba")) }
    }
    func testAtomicNoSpaceDeniedCancellationAndRenameFailurePreservePreviousGoodFile() async throws {
        let url = try output("atomic-target.paxis"), original = Data("last good save".utf8)
        try original.write(to:url)
        for code in [POSIXErrorCode.ENOSPC,.EACCES] {
            XCTAssertThrowsError(try AtomicFile.write(to:url,beforeCommit:{ throw POSIXError(code) }) { try $0.write(contentsOf:Data(repeating:7,count:1000)) })
            XCTAssertEqual(try Data(contentsOf:url),original)
        }
        let task = Task.detached {
            try AtomicFile.write(to:url,beforeCommit:{ throw CancellationError() }) { try $0.write(contentsOf:Data([8,9])) }
        }
        do { try await task.value; XCTFail("Cancellation succeeded") } catch is CancellationError {}
        XCTAssertEqual(try Data(contentsOf:url),original)
        let directory = try output("rename-refused-directory"); try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        XCTAssertThrowsError(try AtomicFile.write(to:directory) { try $0.write(contentsOf:Data([1])) })
        let remaining = try FileManager.default.contentsOfDirectory(atPath:outputRoot.path)
        XCTAssertFalse(remaining.contains { $0.hasPrefix(".photoaxis-") })
    }
    func testSavedSnapshotDoesNotClearLaterEditsAndUndoReturnsToWrittenState() async throws {
        let f = try await MultiLayerPerspectiveTests().fixture(), d = f.d
        try d.perform(.rename) { try $0.rename(f.image,to:"Tên đã ghi") }
        let snapshot = d.snapshot(); try d.perform(.rename) { try $0.rename(f.image,to:"Tên sửa khi đang lưu") }
        let store = ProjectStore(pipeline:f.p), url = try output("concurrent-edit.paxis")
        try await store.save(snapshot,to:url); d.markSaved(stateID:snapshot.stateID)
        XCTAssertTrue(d.isDocumentEdited); XCTAssertEqual(d.model.layer(f.image)?.name,"Tên sửa khi đang lưu")
        let loaded = try await store.open(url); XCTAssertEqual(loaded.model.layer(f.image)?.name,"Tên đã ghi")
        d.undoManager?.undo(); XCTAssertFalse(d.isDocumentEdited); d.undoManager?.redo(); XCTAssertTrue(d.isDocumentEdited)
    }
    func testCoordinatorSaveAndOpenRouteOwnsDirtyStateWithoutUndoOrSourceURL() async throws {
        let loc = L10n(choice:.vietnamese), coordinator = DocumentCoordinator(localization:loc)
        var reports: [String] = []; coordinator.report = { reports.append($0) }
        let external = try output("temporary-import.png"), fixture = Bundle(for:Self.self).resourceURL!.appendingPathComponent("P02/grid-exif-6.jpg")
        try Data(contentsOf:fixture).write(to:external)
        coordinator.startImport([.file(external)],into:nil); await coordinator.importTask?.value
        let d = try XCTUnwrap(coordinator.active); XCTAssertTrue(d.isDocumentEdited)
        let url = try output("standalone-source.paxis")
        let saved = await coordinator.save(d,saveAs:true,destination:url); XCTAssertTrue(saved); XCTAssertFalse(d.isDocumentEdited)
        let expected = d.model; coordinator.remove(d.model.id); try FileManager.default.removeItem(at:external)
        coordinator.startImport([.file(url)],into:nil); await coordinator.importTask?.value
        let opened = try XCTUnwrap(coordinator.active); XCTAssertEqual(opened.model,expected); XCTAssertFalse(opened.isDocumentEdited)
        XCTAssertEqual(opened.history.entries.count,0); XCTAssertTrue(reports.isEmpty)
        let closed = await coordinator.requestCloseAll(); XCTAssertTrue(closed); XCTAssertTrue(coordinator.documents.isEmpty)
    }
    func testEmbeddedHashAndDimensionsAreCheckedWithoutDecodingUnboundedPixels() async throws {
        let pipeline = ImagePipeline(), url = Bundle(for:Self.self).resourceURL!.appendingPathComponent("P02/grid-corners.png")
        let data = try Data(contentsOf:url), id = ImagePipeline.digest(data)
        do { _ = try await pipeline.validateEmbedded(data,descriptor:.init(id:String(repeating:"a",count:64),size:CanvasSize(width:640,height:480)),ppi:72); XCTFail("Hash accepted") }
        catch { XCTAssertEqual(error as? ProjectError,.assetMismatch) }
        do { _ = try await pipeline.validateEmbedded(data,descriptor:.init(id:id,size:CanvasSize(width:1,height:1)),ppi:72); XCTFail("Dimensions accepted") }
        catch { XCTAssertEqual(error as? ProjectError,.assetMismatch) }
        let decodes = await pipeline.normalizedDecodeCount; XCTAssertEqual(decodes,0)
    }
    func testIndependentDeflateZIPAndRealPermissionDeniedSave() async throws {
        let pipeline = ImagePipeline(), store = ProjectStore(pipeline:pipeline)
        let url = Bundle(for:Self.self).resourceURL!.appendingPathComponent("P09/empty-deflate.paxis")
        let loaded = try await store.open(url); XCTAssertEqual(loaded.model.name,"Deflate độc lập")
        XCTAssertEqual(loaded.model.canvas,try CanvasSize(width:1,height:1))
        let directory = try output("permission-denied"); try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let target = directory.appendingPathComponent("previous.paxis"), original = Data("good previous".utf8)
        try original.write(to:target)
        try FileManager.default.setAttributes([.posixPermissions:0o500],ofItemAtPath:directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:directory.path) }
        do { try await store.save(loaded,to:target); XCTFail("Save into nonwritable directory succeeded") }
        catch { XCTAssertEqual((error as? POSIXError)?.code,.EACCES) }
        XCTAssertEqual(try Data(contentsOf:target),original)
    }
}

import AppKit
import XCTest
import PhotoAxisCore
@testable import PhotoAxis

private actor RecoveryGate {
    var reached = false
    var continuation: CheckedContinuation<Void,Never>?
    func pause() async { reached = true; await withCheckedContinuation { continuation = $0 } }
    func release() { continuation?.resume(); continuation = nil }
}

@MainActor final class RecoveryTests: XCTestCase {
    var outputRoot: URL { (0..<5).reduce(Bundle.main.bundleURL) { url,_ in url.deletingLastPathComponent() }.appendingPathComponent("p11-native-tests") }
    func root() throws -> URL {
        try FileManager.default.createDirectory(at:outputRoot,withIntermediateDirectories:true)
        return outputRoot.appendingPathComponent(".qa-recovery-"+UUID().uuidString,isDirectory:true)
    }
    func testCommittedSnapshotExcludesDraftReopensUnsavedAndPreservesNewerRecoveryOnSave() async throws {
        let f = try await MultiLayerPerspectiveTests().fixture(), d = f.d, store = RecoveryStore(root:try root(),pipeline:f.p)
        let initialHistoryCount = d.history.entries.count, committed = d.snapshot(); try d.startPerspective()
        let saved = try await store.write(d.snapshot()); XCTAssertTrue(saved)
        let entries = try await store.list(), entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.stateID,committed.stateID); XCTAssertEqual(entry.revision,committed.model.revision)
        XCTAssertLessThan(abs(entry.date.timeIntervalSinceNow),5)
        let recovered = try await store.open(entry); XCTAssertEqual(recovered.model,committed.model); XCTAssertEqual(recovered.assets.mapValues(\.data),committed.assets.mapValues(\.data))
        let reopened = PhotoDocument(loaded:recovered,url:nil,localization:L10n(choice:.english))
        XCTAssertTrue(reopened.isDocumentEdited); XCTAssertNil(reopened.fileURL); XCTAssertTrue(reopened.history.entries.isEmpty); XCTAssertFalse(reopened.hasSession)
        d.cancelSession(); try d.perform(.rename) { try $0.rename(f.image,to:"Thay đổi sau khi Save bắt đầu") }
        let newer = d.snapshot(); _ = try await store.write(newer)
        try await store.discard(d.model.id,stateID:committed.stateID)
        let remaining = try await store.list(); XCTAssertEqual(remaining.first?.stateID,newer.stateID)
        try await store.discard(d.model.id,stateID:newer.stateID); let empty = try await store.list(); XCTAssertTrue(empty.isEmpty)
        XCTAssertTrue(d.isDocumentEdited); XCTAssertEqual(d.history.entries.count,initialHistoryCount+1)
    }
    func testDiscardDuringSuspendedWriteCannotResurrectRecoveryAndOldArchiveIsAtomic() async throws {
        let f = try await MultiLayerPerspectiveTests().fixture(), store = RecoveryStore(root:try root(),pipeline:f.p)
        let original = f.d.snapshot(); _ = try await store.write(original)
        try f.d.perform(.rename) { try $0.rename(f.image,to:"New pending state") }
        let pending = f.d.snapshot(), gate = RecoveryGate()
        let task = Task { try await store.write(pending,beforeManifest:{ await gate.pause() }) }
        while !(await gate.reached) { try await Task.sleep(for:.milliseconds(5)) }
        let entries = try await store.list(), old = try await store.open(XCTUnwrap(entries.first)); XCTAssertEqual(old.model,original.model)
        try await store.discard(f.d.model.id); await gate.release()
        let committed = try await task.value; XCTAssertFalse(committed)
        let empty = try await store.list(); XCTAssertTrue(empty.isEmpty)
        let folder = await store.root.appendingPathComponent(f.d.model.id.uuidString)
        if FileManager.default.fileExists(atPath:folder.path) { XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:folder.path).isEmpty) }
    }
    func testPeriodicRecoveryCompletesWithinThirtySecondsAndSkipsUnchangedState() async throws {
        let loc = L10n(choice:.vietnamese), c = DocumentCoordinator(localization:loc,recoveryRoot:try root())
        try c.create(name:"Tự động phục hồi có dấu",size:CanvasSize(width:64,height:64),ppi:72,background:.white)
        let d = try XCTUnwrap(c.active), state = d.history.stateID, start = Date()
        c.startRecovery(); defer { c.stopRecovery() }
        var entries: [RecoveryEntry] = []
        while entries.isEmpty, Date().timeIntervalSince(start) < 15 { try await Task.sleep(for:.milliseconds(100)); entries = await c.recoveryEntries() }
        XCTAssertEqual(entries.first?.stateID,state); XCTAssertLessThan(Date().timeIntervalSince(start),30)
        let date = try XCTUnwrap(entries.first?.date); await c.flushRecovery(); let unchanged = await c.recoveryEntries(); XCTAssertEqual(unchanged.first?.date,date)
        let result:[String:Any] = ["secondsToCompletedRecovery":Date().timeIntervalSince(start),"maximumNormalIntervalSeconds":30,"source":"real coordinator timer and atomic recovery manifest"]
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:outputRoot.appendingPathComponent("recovery-timing.json"))
        c.confirmClose = { _ in .discard }; let closed = await c.requestCloseAll(); XCTAssertTrue(closed)
    }
    func testMultiDocumentCancelKeepsEveryTabAndRecoveryUntilFinalDontSave() async throws {
        let c = DocumentCoordinator(localization:L10n(choice:.english),recoveryRoot:try root())
        for i in 0..<3 { try c.create(name:"Document \(i)",size:CanvasSize(width:32,height:32),ppi:72,background:.white) }
        await c.flushRecovery(); let snapshots = c.documents.map { $0.snapshot() }
        var decisions = 0; c.confirmClose = { _ in decisions += 1; return decisions == 2 ? .cancel : .discard }
        let cancelled = await c.requestCloseAll(); XCTAssertFalse(cancelled); XCTAssertEqual(c.documents.count,3)
        let entries = await c.recoveryEntries(); XCTAssertEqual(entries.count,3)
        for (d,s) in zip(c.documents,snapshots) { XCTAssertEqual(d.model,s.model); XCTAssertEqual(d.history.stateID,s.stateID); XCTAssertFalse(d.lifecycleLocked) }
        c.confirmClose = { _ in .discard }; let closed = await c.requestCloseAll(); XCTAssertTrue(closed); let empty = await c.recoveryEntries(); XCTAssertTrue(empty.isEmpty)
    }
    func testRecoveryPermissionFailureReportsOnceCorruptRecordIsExplicitAndNoSavedMarkerChanges() async throws {
        let folder = try root(); try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let c = DocumentCoordinator(localization:L10n(choice:.vietnamese),recoveryRoot:folder)
        try c.create(name:"Lỗi quyền",size:CanvasSize(width:32,height:32),ppi:72,background:.transparent)
        let state = c.active!.history.stateID; var notices:[String] = []; c.recoveryNotice = { notices.append($0) }
        try FileManager.default.setAttributes([.posixPermissions:0o500],ofItemAtPath:folder.path)
        await c.flushRecovery(); await c.flushRecovery(); XCTAssertEqual(notices.count,1); XCTAssertTrue(c.active!.isDocumentEdited); XCTAssertEqual(c.active!.history.stateID,state)
        try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:folder.path); await c.flushRecovery()
        let manifest = folder.appendingPathComponent(c.active!.model.id.uuidString).appendingPathComponent("record.json")
        try Data("{broken}".utf8).write(to:manifest)
        let entries = await c.recoveryEntries(); XCTAssertTrue(try XCTUnwrap(entries.first).isCorrupt)
        let discarded = await c.discardRecovery(entries[0]); XCTAssertTrue(discarded); let empty = await c.recoveryEntries(); XCTAssertTrue(empty.isEmpty); XCTAssertEqual(notices.count,1)
    }
    func testRealControlledAbnormalChildExitAndRestartReadsLastCommittedRecovery() async throws {
        #if !DEBUG
        throw XCTSkip("Controlled abnormal child is debug-only; production executable has no crash fixture entry point")
        #else
        let f = try await MultiLayerPerspectiveTests().fixture(); try MultiLayerPerspectiveTests().crop(f.d); f.d.applySession()
        let source = outputRoot.appendingPathComponent("controlled-crash-source.paxis"), folder = try root()
        try await ProjectStore(pipeline:f.p).save(f.d.snapshot(),to:source)
        let child = Process(); child.executableURL = Bundle.main.executableURL
        child.arguments = ["--photoaxis-recovery-crash-fixture",folder.path,source.path]
        child.environment = ProcessInfo.processInfo.environment.filter { !$0.key.contains("XCTest") && !$0.key.hasPrefix("XCInject") && $0.key != "DYLD_INSERT_LIBRARIES" }
        child.environment?["PHOTOAXIS_QA_MODE"] = "1"; child.environment?["LLVM_PROFILE_FILE"] = outputRoot.appendingPathComponent("child-%p.profraw").path
        let log = outputRoot.appendingPathComponent("controlled-crash.log"); FileManager.default.createFile(atPath:log.path,contents:nil)
        let handle = try FileHandle(forWritingTo:log); defer { try? handle.close() }
        child.standardOutput = handle; child.standardError = handle; child.standardInput = FileHandle.nullDevice
        try child.run(); let start = Date()
        while child.isRunning, Date().timeIntervalSince(start) < 20 { try await Task.sleep(for:.milliseconds(100)) }
        if child.isRunning { child.terminate(); XCTFail("Controlled child timed out") }; child.waitUntilExit()
        XCTAssertEqual(child.terminationStatus,86)
        let restarted = RecoveryStore(root:folder,pipeline:ImagePipeline()), entries = try await restarted.list()
        let loaded = try await restarted.open(XCTUnwrap(entries.first)); XCTAssertEqual(loaded.model,f.d.model); XCTAssertEqual(loaded.assets.mapValues(\.data),f.d.assets.mapValues(\.data))
        let document = PhotoDocument(loaded:loaded,url:nil,localization:L10n(choice:.vietnamese)); XCTAssertTrue(document.isDocumentEdited); XCTAssertNil(document.fileURL)
        let record:[String:Any] = ["terminationStatus":child.terminationStatus,"restartedRecoveredRevision":loaded.model.revision,"projectName":loaded.model.name,"source":"separate debug-only QA process; no personal app terminated"]
        try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]).write(to:outputRoot.appendingPathComponent("controlled-crash-result.json"))
        #endif
    }
    func testMissingFontControlsAndRecoveryListInBothLanguagesPreserveOriginalFont() async throws {
        for language in [InterfaceLanguage.vietnamese,.english] {
            let loc = L10n(choice:language), d = PhotoDocument(model:try PhotoDocumentModel(name:"Missing font",canvas:CanvasSize(width:320,height:240),ppi:72),localization:loc)
            let text = TextContent(text:"Chữ giữ nguyên",fontName:"PhotoAxis-QA-Missing",fontSize:24,color:.white)
            try d.perform(.createText) { _ = try $0.insertContent(.text(text),name:"Chữ",transform:.identity,above:nil) }
            d.selectedLayerID = d.model.layers.last!.id
            let controls = ContentControlsView(localization:loc); controls.refresh(d)
            XCTAssertTrue(controls.family.titleOfSelectedItem?.contains("PhotoAxis-QA-Missing") == true); XCTAssertFalse(controls.style.isEnabled)
            XCTAssertTrue(controls.message.stringValue.contains("PhotoAxis-QA-Missing")); XCTAssertEqual(d.model.layers.last?.content,.text(text))
            let entry = RecoveryEntry(id:UUID(),name:"Dự án có dấu",date:Date(),stateID:UUID(),revision:1,isCorrupt:false)
            let corrupt = RecoveryEntry(id:UUID(),name:"Broken",date:.distantPast,stateID:nil,revision:nil,isCorrupt:true)
            let sheet = RecoveryController(entries:[entry,corrupt],localization:loc)
            sheet.window?.makeKeyAndOrderFront(nil); sheet.table.reloadData(); sheet.window?.contentView?.layoutSubtreeIfNeeded(); XCTAssertGreaterThan(sheet.table.tableColumns[0].width,500)
            if let view = sheet.window?.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) {
                view.cacheDisplay(in:view.bounds,to:bitmap)
                try bitmap.representation(using:.png,properties:[:])?.write(to:outputRoot.appendingPathComponent("hosted-recovery-"+loc.language+".png"))
            }
            sheet.window?.orderOut(nil)
            XCTAssertTrue(sheet.openButton.isEnabled); sheet.table.selectRowIndexes(IndexSet(integer:1),byExtendingSelection:false); XCTAssertFalse(sheet.openButton.isEnabled); XCTAssertTrue(sheet.discardButton.isEnabled)
            sheet.completed(corrupt); XCTAssertEqual(sheet.visibleEntries.count,1)
            d.lifecycleLocked = true; XCTAssertFalse(d.canEditSelection); XCTAssertThrowsError(try d.perform(.rename) { try $0.rename(d.model.layers.last!.id,to:"Forbidden") }); d.lifecycleLocked = false
        }
    }
}

import AppKit
import XCTest
import ImageIO
import PDFKit
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class InvestigationWorkflowTests: XCTestCase {
    func root() throws -> URL {
        let root = (0..<5).reduce(Bundle.main.bundleURL) { url, _ in url.deletingLastPathComponent() }.appendingPathComponent("investigation-tests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); return root
    }
    func fixture() -> URL { Bundle(for: Self.self).resourceURL!.appendingPathComponent("P02/grid-corners.png") }
    func context() throws -> (InvestigationCaseStore, DocumentCoordinator) {
        let root = try root(), coordinator = DocumentCoordinator(localization: L10n(choice: .vietnamese), recoveryRoot: root.appendingPathComponent("recovery"))
        let store = try InvestigationCaseStore(root: root.appendingPathComponent("Hồ-sơ.paxcase"), creating: InvestigationCase(code: "HS-01", title: "Bản ảnh thử nghiệm có dấu", examiner: "Người lập thử"), appVersion: "test")
        coordinator.investigationSessionFor = { reference in guard reference.caseID == store.value.id else { return nil }; return InvestigationSession(store: store, itemID: reference.itemID) }
        return (store, coordinator)
    }
    func add(_ store: InvestigationCaseStore, _ coordinator: DocumentCoordinator) async throws -> (EvidenceItem, PhotoDocument) {
        let item = try await store.importFile(fixture(), intake: EvidenceIntake(source: "Fixture tự tạo", provider: "", receiver: "Người thử", receivedAt: "", handover: ""), pipeline: coordinator.pipeline, projects: coordinator.projectStore)
        let snapshot = try await store.openSnapshot(item.id, projects: coordinator.projectStore)
        let document = PhotoDocument(loaded: snapshot, url: store.projectURL(item.id), localization: L10n(choice: .vietnamese))
        document.investigationSession = InvestigationSession(store: store, itemID: item.id); try coordinator.add(document)
        return (item, document)
    }
    func testScanAuditSaveUndoAndReviewInvalidationPreserveOriginal() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let original = document.model, id = try XCTUnwrap(document.selectedLayerID)
        try store.setRedactions(item.id,regions:[EvidenceRegion(x:0,y:0,width:10,height:10)])
        let reviewed = try store.item(item.id).redactionModelSHA256
        var settings = ScanSettings(); settings.mode = .gray; settings.paper = 0.7
        try document.perform(.scan) { try $0.setScan(id,settings) }
        let edited = document.model
        XCTAssertEqual(store.value.events.last?.payload.operation,"scan")
        XCTAssertNotEqual(reviewed,InvestigationDigest.hash(try store.item(item.id).currentModelJSON))
        document.undoManager?.undo(); XCTAssertEqual(document.model,original)
        document.undoManager?.redo(); XCTAssertEqual(document.model,edited)
        let saved = await coordinator.save(document,saveAs:false); XCTAssertTrue(saved)
        let reopened = try await store.openSnapshot(item.id,projects:coordinator.projectStore)
        XCTAssertEqual(reopened.model,edited); XCTAssertEqual(reopened.model.layers[0].scan,settings)
        XCTAssertEqual(try InvestigationFiles.hashFile(store.originalURL(item)),item.originalSHA256)
        _ = try InvestigationCase.decode(Data(contentsOf:store.manifestURL))
    }
    func testIntakePreservesExactOriginalSeparatesWorkingAndDetectsExternalMutation() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let bytes = try Data(contentsOf: fixture())
        XCTAssertEqual(try Data(contentsOf: store.originalURL(item)), bytes)
        XCTAssertEqual(item.originalSHA256, InvestigationDigest.hash(bytes)); XCTAssertEqual(item.originalByteCount, bytes.count)
        XCTAssertTrue(item.originalMetadataJSON.contains("PixelWidth")); XCTAssertEqual(item.intake.source, "Fixture tự tạo")
        XCTAssertEqual(document.model.investigation, InvestigationReference(caseID: store.value.id, itemID: item.id))
        XCTAssertThrowsError(try InvestigationCaseStore(root: store.root)) { XCTAssertEqual($0 as? InvestigationError, .locked) }
        XCTAssertThrowsError(try store.protectDestination(store.originalURL(item)))
        let original = store.originalURL(item)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: original.path)
        try Data("changed".utf8).write(to: original)
        do { try await store.verifyOriginal(item); XCTFail("Changed original accepted") } catch { XCTAssertEqual(error as? InvestigationError, .integrity) }
    }
    func testProcessingUndoRedoSaveAndRestartRetainLogWithoutSessionHistory() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let imageID = try XCTUnwrap(document.selectedLayerID), initial = document.model
        try document.perform(.rename) { try $0.rename(imageID, to: "Dấu vết đã chú thích") }
        let edited = document.model; document.undoManager?.undo(); XCTAssertEqual(document.model, initial)
        document.undoManager?.redo(); XCTAssertEqual(document.model, edited)
        XCTAssertEqual(store.value.events.suffix(3).map(\.payload.operation), ["rename", "undo", "redo"])
        let saved = await coordinator.save(document, saveAs: false); XCTAssertTrue(saved); XCTAssertFalse(document.isDocumentEdited)
        let snapshot = try await store.openSnapshot(item.id, projects: coordinator.projectStore)
        XCTAssertEqual(snapshot.model, edited)
        let manifest = try InvestigationCase.decode(Data(contentsOf: store.manifestURL))
        XCTAssertEqual(manifest.events.filter { $0.payload.operation == "rename" }.count, 1)
        XCTAssertEqual(manifest.events.last?.payload.operation, "workingSaved")
        let restarted = PhotoDocument(loaded: snapshot, url: store.projectURL(item.id), localization: L10n(choice: .english))
        XCTAssertTrue(restarted.history.entries.isEmpty); XCTAssertFalse(restarted.isDocumentEdited)
        XCTAssertGreaterThan(manifest.events.count, restarted.history.entries.count)
        XCTAssertEqual(try InvestigationFiles.hashFile(store.originalURL(item)), item.originalSHA256)
    }
    func testFailedAuditRefusesEditAndUndoAndPreservesPreviousManifest() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let layer = try XCTUnwrap(document.selectedLayerID), originalModel = document.model, originalFile = try Data(contentsOf: store.manifestURL)
        store.beforeManifestCommit = { throw POSIXError(.ENOSPC) }
        XCTAssertThrowsError(try document.perform(.rename) { try $0.rename(layer, to: "Must not commit") })
        XCTAssertEqual(document.model, originalModel); XCTAssertEqual(document.history.entries.count, 0)
        XCTAssertEqual(try Data(contentsOf: store.manifestURL), originalFile)
        store.beforeManifestCommit = nil; try document.perform(.rename) { try $0.rename(layer, to: "Committed") }
        let changed = document.model, cursor = document.history.cursor
        store.beforeManifestCommit = { throw POSIXError(.EACCES) }; document.undoManager?.undo()
        XCTAssertEqual(document.model, changed); XCTAssertEqual(document.history.cursor, cursor)
        store.beforeManifestCommit = nil
        XCTAssertEqual(try InvestigationFiles.hashFile(store.originalURL(item)), item.originalSHA256)
    }
    func testFailedSaveReceiptKeepsPreviousArchiveAndRestartableUnsavedEdits() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let oldURL = store.projectURL(item.id), oldBytes = try Data(contentsOf: oldURL), oldCheckpoint = try store.item(item.id).savedModelJSON
        try document.perform(.rename) { try $0.rename(document.selectedLayerID!, to: "Chưa có biên nhận lưu") }
        let edited = document.model
        var commits = 0
        store.beforeManifestCommit = { commits += 1; if commits == 2 { throw POSIXError(.ENOSPC) } }
        let failed = await coordinator.save(document, saveAs: false)
        XCTAssertFalse(failed); XCTAssertTrue(document.isDocumentEdited)
        XCTAssertEqual(store.projectURL(item.id), oldURL); XCTAssertEqual(try Data(contentsOf: oldURL), oldBytes)
        XCTAssertEqual(try store.item(item.id).savedModelJSON, oldCheckpoint)
        let reopened = try await store.openSnapshot(item.id, projects: coordinator.projectStore)
        XCTAssertEqual(reopened.model, edited); XCTAssertTrue(try store.item(item.id).hasUnsavedChanges)
        let archives = try FileManager.default.contentsOfDirectory(at: oldURL.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        XCTAssertEqual(archives.count, 1)
        store.beforeManifestCommit = nil
        let saved = await coordinator.save(document, saveAs: false); XCTAssertTrue(saved); XCTAssertFalse(document.isDocumentEdited)
        XCTAssertNotEqual(store.projectURL(item.id), oldURL)
        let finalSnapshot = try await store.openSnapshot(item.id, projects: coordinator.projectStore)
        XCTAssertEqual(finalSnapshot.model, edited)
    }
    func testDeleteSaveUndoThenRestartRestoresIntakeWorkingSource() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let initial = document.model, imageID = try XCTUnwrap(document.selectedLayerID)
        try document.perform(.delete) { try $0.delete(imageID) }
        let saved = await coordinator.save(document, saveAs: false); XCTAssertTrue(saved)
        XCTAssertTrue(document.model.sources.isEmpty)
        document.undoManager?.undo(); XCTAssertEqual(document.model, initial)
        let snapshot = try await store.openSnapshot(item.id, projects: coordinator.projectStore)
        XCTAssertEqual(snapshot.model, initial); XCTAssertEqual(snapshot.assets[item.workingSourceSHA256]?.data, document.assets[item.workingSourceSHA256]?.data)
        let image = try await coordinator.pipeline.renderDocument(model: snapshot.model, assets: snapshot.assets)
        XCTAssertEqual(image.width, initial.canvas.width)
        XCTAssertTrue(try store.item(item.id).hasUnsavedChanges)
    }
    func testResizedWorkingImageAndPrivateMetadataKeepReceivedBytesUnchanged() async throws {
        let (store, coordinator) = try context(), root = try root(), input = root.appendingPathComponent("private-wide.png")
        let context = try XCTUnwrap(CGContext(data: nil, width: 8100, height: 2, bitsPerComponent: 8, bytesPerRow: 8100 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 8100, height: 2))
        let bytes = NSMutableData(), encoder = try XCTUnwrap(CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(encoder, try XCTUnwrap(context.makeImage()), [kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2001:02:03 04:05:06", kCGImagePropertyExifUserComment: "Private fixture"], kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 10.0, kCGImagePropertyGPSLatitudeRef: "N", kCGImagePropertyGPSLongitude: 108.0, kCGImagePropertyGPSLongitudeRef: "E"]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(encoder)); try (bytes as Data).write(to: input)
        let item = try await store.importFile(input, intake: .init(), pipeline: coordinator.pipeline, projects: coordinator.projectStore, allowResize: true)
        XCTAssertEqual(try Data(contentsOf: store.originalURL(item)), bytes as Data)
        XCTAssertTrue(item.originalMetadataJSON.contains("Private fixture")); XCTAssertTrue(item.originalMetadataJSON.contains("GPS"))
        XCTAssertLessThanOrEqual(try item.model.canvas.width, 8000)
        try Data("Received path changed later".utf8).write(to: input)
        try await store.verifyOriginal(item)
        let snapshot = try await store.openSnapshot(item.id, projects: coordinator.projectStore)
        let image = try await coordinator.pipeline.renderDocument(model: snapshot.model, assets: snapshot.assets)
        let shared = try InvestigationSharing.pngBytes(image, ppi: 72)
        XCTAssertNil(shared.range(of: Data("Private fixture".utf8)))
        let probe = try XCTUnwrap(CGImageSourceCreateWithData(shared as CFData, nil)), properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(probe, 0, nil) as? [CFString: Any])
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
    }
    func testTwoTabQuitCancellationPreservesCaseEditsAndFinalDiscardIsRecorded() async throws {
        let (store, coordinator) = try context(), (_, first) = try await add(store, coordinator), (_, second) = try await add(store, coordinator)
        for document in [first, second] { let id = try XCTUnwrap(document.selectedLayerID); try document.perform(.rename) { try $0.rename(id, to: "Unsaved \(document.model.id)") } }
        let manifest = try Data(contentsOf: store.manifestURL)
        coordinator.confirmClose = { $0 === first ? .discard : .cancel }
        let cancelled = await coordinator.requestCloseAll(); XCTAssertFalse(cancelled)
        XCTAssertEqual(coordinator.documents.count, 2); XCTAssertTrue(first.isDocumentEdited); XCTAssertTrue(second.isDocumentEdited)
        XCTAssertEqual(try Data(contentsOf: store.manifestURL), manifest)
        coordinator.confirmClose = { _ in .discard }
        let closed = await coordinator.requestCloseAll(); XCTAssertTrue(closed); XCTAssertTrue(coordinator.documents.isEmpty)
        XCTAssertEqual(store.value.events.filter { $0.payload.operation == "workingEditsDiscarded" }.count, 2)
        for item in store.value.items { XCTAssertFalse(item.hasUnsavedChanges) }
    }
    func testCaseBoundWorkingFileIsLockedWithoutCaseAndCannotBypassSharing() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let isolated = DocumentCoordinator(localization: L10n(choice: .english))
        isolated.startImport([.file(store.projectURL(item.id))], into: nil); await isolated.importTask?.value
        let opened = try XCTUnwrap(isolated.active)
        XCTAssertTrue(opened.investigationUnavailable); XCTAssertTrue(opened.isInteractionLocked)
        let result = await isolated.save(opened, saveAs: false); XCTAssertFalse(result)
        let external = try root().appendingPathComponent("escaped.paxis")
        let saveAs = await coordinator.save(document, saveAs: true, destination: external); XCTAssertFalse(saveAs); XCTAssertFalse(FileManager.default.fileExists(atPath: external.path))
        let export = await coordinator.export(document.snapshot(), options: ExportOptions(size: document.model.canvas, ppi: 72), destination: try root().appendingPathComponent("bypass.png"))
        XCTAssertFalse(export)
        XCTAssertThrowsError(try document.place(document.assets.values.first!))
    }
    func testFlattenedPNGRedactionsRemovePixelsAndMetadataWhileOriginalIsUnchanged() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let image = try await coordinator.pipeline.renderDocument(model: document.model, assets: document.assets)
        let region = EvidenceRegion(x: 20, y: 30, width: 55, height: 37)
        try store.setRedactions(item.id, regions: [region])
        let redacted = try InvestigationSharing.redacted(image, modelSize: document.model.canvas, regions: [region])
        let data = try InvestigationSharing.pngBytes(redacted, ppi: 144), source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil)), rep = NSBitmapImageRep(cgImage: decoded)
        for y in region.y..<(region.y + region.height) { for x in region.x..<(region.x + region.width) {
            let c = try XCTUnwrap(rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
            XCTAssertEqual(c.redComponent, 0); XCTAssertEqual(c.greenComponent, 0); XCTAssertEqual(c.blueComponent, 0); XCTAssertEqual(c.alphaComponent, 1)
        } }
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertNil(props[kCGImagePropertyGPSDictionary])
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        XCTAssertNil(exif[kCGImagePropertyExifDateTimeOriginal]); XCTAssertNil(exif[kCGImagePropertyExifUserComment])
        XCTAssertTrue(Set(exif.keys).isSubset(of: [kCGImagePropertyExifColorSpace, kCGImagePropertyExifPixelXDimension, kCGImagePropertyExifPixelYDimension]))
        XCTAssertEqual(CGImageSourceGetCount(source), 1)
        XCTAssertEqual(try InvestigationFiles.hashFile(store.originalURL(item)), item.originalSHA256)
        let reviewed = try store.item(item.id).redactionModelSHA256
        try document.perform(.rename) { try $0.rename(document.selectedLayerID!, to: "Changed after review") }
        XCTAssertNotEqual(reviewed, InvestigationDigest.hash(try store.item(item.id).currentModelJSON))
        let output = store.root.deletingLastPathComponent().appendingPathComponent("redacted-fixture.png"); try await InvestigationSharing.write(data, to: output)
        XCTAssertEqual(try Data(contentsOf: output), data)
    }
    func testA4PDFLayoutsAreRasterOnlyAndPaginateOneTwoFour() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let image = try await coordinator.pipeline.renderDocument(model: document.model, assets: document.assets)
        let redacted = try InvestigationSharing.redacted(image, modelSize: document.model.canvas, regions: [.init(x: 20, y: 30, width: 55, height: 37)])
        let plates = (1...5).map { InvestigationSharing.Plate(code: "IMG-000\($0)", caption: "Dấu vết thử nghiệm — ảnh \($0)", originalSHA256: item.originalSHA256, image: redacted) }
        for perPage in [1, 2, 4] {
            let data = try InvestigationSharing.pdf(plates, title: store.value.title, caseCode: store.value.code, examiner: store.value.examiner, perPage: perPage, language: "vi")
            let pdf = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertEqual(pdf.pageCount, (5 + perPage - 1) / perPage)
            for i in 0..<pdf.pageCount {
                let page = try XCTUnwrap(pdf.page(at: i)), bounds = page.bounds(for: .mediaBox)
                XCTAssertEqual(bounds.width, 595.276, accuracy: 0.01); XCTAssertEqual(bounds.height, 841.89, accuracy: 0.01)
                XCTAssertTrue((page.string ?? "").isEmpty); XCTAssertTrue(page.annotations.isEmpty)
            }
            XCTAssertFalse(data.range(of: Data(item.originalMetadataJSON.utf8)) != nil)
            try data.write(to: store.root.deletingLastPathComponent().appendingPathComponent("A4-\(perPage).pdf"))
        }
    }
    func testStreamedPDFEnglishAndLongCaptionRefusesSilentTruncation() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let image = try await coordinator.pipeline.renderDocument(model: document.model, assets: document.assets)
        let plate = InvestigationSharing.Plate(code: item.code, caption: "Evidence photograph — recorded source", originalSHA256: item.originalSHA256, image: image)
        let pages = try InvestigationSharing.PDFPages(title: "Investigation photographs", caseCode: "TEST-EN", examiner: "Test operator", perPage: 4, count: 5, language: "en")
        try await pages.append(Array(repeating: plate, count: 4)); try await pages.append([plate])
        let data = try await pages.finish(), pdf = try XCTUnwrap(PDFDocument(data: data)); XCTAssertEqual(pdf.pageCount, 2)
        try data.write(to: store.root.deletingLastPathComponent().appendingPathComponent("A4-English.pdf"))
        let long = InvestigationSharing.Plate(code: item.code, caption: String(repeating: "Chú thích rất dài cần được giữ đầy đủ. ", count: 100), originalSHA256: item.originalSHA256, image: image)
        XCTAssertThrowsError(try InvestigationSharing.pdf([long], title: "Test", caseCode: "TEST", examiner: "Test", perPage: 4, language: "vi")) { XCTAssertEqual($0 as? InvestigationError, .limit) }
    }
    func testInvestigationNativeControlsAndComparisonInBothLanguages() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let image = try await coordinator.pipeline.renderDocument(model: document.model, assets: document.assets)
        for language in [InterfaceLanguage.vietnamese, .english] {
            let loc = L10n(choice: language), controller = InvestigationController(coordinator: coordinator, localization: loc)
            let workspace = WorkspaceWindowController(preferences: WorkspacePreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!), localization: loc, restoreFrame: false)
            controller.attach(to: workspace.workspaceView); controller.use(store); workspace.workspaceView.refreshDocuments(coordinator)
            controller.synchronizeActiveDocument(); workspace.window?.layoutIfNeeded()
            XCTAssertTrue(controller.sourcePanel.window === workspace.window)
            XCTAssertTrue(controller.analysisPanel.window === workspace.window)
            XCTAssertTrue(controller.outputPanel.window === workspace.window)
            XCTAssertEqual(controller.selectedItem?.id, item.id)
            let compare = InvestigationComparisonPanel(original: image, processed: image, localization: loc)
            workspace.workspaceView.showPresentation(compare)
            XCTAssertTrue(compare.window === workspace.window)
            compare.comparison.zoom = 2; compare.comparison.offset = CGPoint(x: 8, y: 10); compare.comparison.swipe = true; compare.comparison.split = 0.25
            XCTAssertEqual(compare.comparison.split, 0.25); compare.comparison.reset(); XCTAssertEqual(compare.comparison.zoom, 1); XCTAssertEqual(compare.comparison.offset, .zero)
            compare.comparison.setZoom(100); XCTAssertEqual(compare.comparison.zoom, 16)
            compare.comparison.setZoom(0); XCTAssertEqual(compare.comparison.zoom, 0.1)
            compare.comparison.setZoom(.nan); XCTAssertEqual(compare.comparison.zoom, 0.1)
            let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: CGPoint(x: 100, y: 150), modifierFlags: [], timestamp: 1, windowNumber: compare.window!.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
            let drag = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDragged, location: CGPoint(x: 135, y: 170), modifierFlags: [], timestamp: 2, windowNumber: compare.window!.windowNumber, context: nil, eventNumber: 2, clickCount: 1, pressure: 1))
            compare.comparison.mouseDown(with: down); compare.comparison.mouseDragged(with: drag)
            XCTAssertEqual(compare.comparison.offset, CGPoint(x: 35, y: 20))
        }
    }
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    private func control<T: NSView>(_ key: String, in view: NSView, as type: T.Type = T.self) throws -> T {
        try XCTUnwrap(descendants(view).first { $0.accessibilityIdentifier() == key } as? T)
    }
    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<200 { if condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
        XCTFail("Workspace operation did not settle")
    }
    private func workspace(_ coordinator: DocumentCoordinator, _ controller: InvestigationController) -> WorkspaceWindowController {
        let window = WorkspaceWindowController(preferences: WorkspacePreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!), localization: L10n(choice: .vietnamese), restoreFrame: false)
        controller.attach(to: window.workspaceView)
        coordinator.changed = { [weak controller, weak window] in window?.workspaceView.refreshDocuments(coordinator); controller?.synchronizeActiveDocument() }
        window.workspaceView.refreshDocuments(coordinator); controller.synchronizeActiveDocument(); window.window?.layoutIfNeeded()
        return window
    }
    func testInlineCaseEditApplyAndCancelAreTransactionalWithoutAuxiliaryWindow() async throws {
        let (store, coordinator) = try context(); _ = try await add(store, coordinator)
        let controller = InvestigationController(coordinator: coordinator, localization: L10n(choice: .vietnamese)); controller.use(store)
        let window = workspace(coordinator, controller)
        let button: NSButton = try control("investigation.editCase", in: controller.sourcePanel)
        button.performClick(nil); try await waitFor { controller.hasPendingParameters }
        XCTAssertEqual(window.workspaceView.sidebar.selectedPage, 1); XCTAssertTrue(controller.sourcePanel.editor.window === window.window)
        let field: NSTextField = try control("investigation.caseTitle", in: controller.sourcePanel); field.stringValue = "Hồ sơ đã sửa"
        controller.applyParameters(); try await waitFor { store.value.title == "Hồ sơ đã sửa" }
        XCTAssertEqual(store.value.events.last?.payload.operation, "caseInformationAmended")
        let before = try Data(contentsOf: store.manifestURL)
        button.performClick(nil); try await waitFor { controller.hasPendingParameters }
        let next: NSTextField = try control("investigation.caseTitle", in: controller.sourcePanel); next.stringValue = "Không được lưu"
        controller.cancelParameters(); await Task.yield()
        XCTAssertEqual(try Data(contentsOf: store.manifestURL), before); XCTAssertTrue(controller.sourcePanel.editor.isHidden)
    }
    func testChangingTabOrModelCancelsDraftWithoutWritingAudit() async throws {
        let (store, coordinator) = try context(), (_, document) = try await add(store, coordinator)
        let controller = InvestigationController(coordinator: coordinator, localization: L10n(choice: .vietnamese)); controller.use(store)
        let window = workspace(coordinator, controller)
        let button: NSButton = try control("investigation.redact", in: controller.outputPanel)
        button.performClick(nil); try await waitFor { controller.hasPendingParameters }
        let before = try Data(contentsOf: store.manifestURL)
        try coordinator.create(name: "Other", size: CanvasSize(width: 100,height: 100), ppi: 72, background: .transparent)
        XCTAssertFalse(controller.hasPendingParameters); controller.applyParameters(); await Task.yield()
        XCTAssertEqual(try Data(contentsOf: store.manifestURL), before)
        coordinator.select(document.model.id); button.performClick(nil); try await waitFor { controller.hasPendingParameters }
        let id = try XCTUnwrap(document.selectedLayerID); try document.perform(.opacity) { try $0.setOpacity(id, 0.6) }
        XCTAssertFalse(controller.hasPendingParameters); XCTAssertNil(window.workspaceView.presentation)
        XCTAssertNil(try store.item(document.model.id).redactionModelSHA256)
    }
    func testOrphanUnsavedDocumentCannotBeDiscardedWhenOpeningCaseItem() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let id = try XCTUnwrap(document.selectedLayerID); try document.perform(.opacity) { try $0.setOpacity(id, 0.4) }
        document.investigationSession = nil
        let before = document.model
        let controller = InvestigationController(coordinator: coordinator, localization: L10n(choice: .vietnamese)); controller.use(store)
        do { _ = try await controller.openItem(item.id); XCTFail("Must preserve orphan tab") }
        catch { XCTAssertEqual(error as? InvestigationError, .locked) }
        XCTAssertTrue(coordinator.active === document); XCTAssertEqual(document.model, before); XCTAssertTrue(document.isDocumentEdited)
    }
    func testCaseSelectionFollowsActiveTabAcrossTwoCases() async throws {
        let (first, coordinator) = try context(), (item1, _) = try await add(first, coordinator)
        let second = try InvestigationCaseStore(root: first.root.deletingLastPathComponent().appendingPathComponent("Second.paxcase"), creating: InvestigationCase(code: "HS-02",title: "Second",examiner: "Test"))
        let (item2, _) = try await add(second, coordinator)
        let controller = InvestigationController(coordinator: coordinator, localization: L10n(choice: .vietnamese)); controller.use(first); controller.use(second)
        let window = workspace(coordinator, controller)
        coordinator.select(item1.id); XCTAssertTrue(controller.store === first); XCTAssertEqual(controller.selectedItem?.id,item1.id)
        coordinator.select(item2.id); XCTAssertTrue(controller.store === second); XCTAssertEqual(controller.selectedItem?.id,item2.id)
        XCTAssertTrue(controller.sourcePanel.window === window.window)
    }
    func testCanvasPickingUsesSourcePixelsWithMarginsReverseDragAndClamping() async throws {
        let (store, coordinator) = try context(), (_, document) = try await add(store, coordinator)
        let image = try await coordinator.pipeline.renderDocument(model: document.model, assets: document.assets)
        let size = try CanvasSize(width: 400,height: 200), capture = InvestigationCaptureView(image:image,sourceSize:size,mode:.rectangles)
        capture.frame = CGRect(x:0,y:0,width:500,height:500)
        XCTAssertNil(capture.sourcePoint(CGPoint(x:10,y:10)))
        let rect = capture.imageRect
        XCTAssertEqual(try XCTUnwrap(capture.sourcePoint(CGPoint(x:rect.midX,y:rect.midY))).x,200,accuracy:0.001)
        let clamped = try XCTUnwrap(capture.sourcePoint(CGPoint(x:1000,y:1000),clamp:true)); XCTAssertEqual(clamped,Point2D(x:400,y:200))
        XCTAssertEqual(InvestigationCaptureView.region(from:Point2D(x:90.7,y:50.9),to:Point2D(x:10.2,y:20.1)),EvidenceRegion(x:10,y:20,width:81,height:31))
        XCTAssertNil(InvestigationCaptureView.region(from:Point2D(x:10,y:20),to:Point2D(x:10,y:20)))
        XCTAssertNil(InvestigationCaptureView.region(from:Point2D(x:.nan,y:20),to:Point2D(x:10,y:20)))
    }
    func testCanvasPointsPersistAcrossMouseUpAndEscapeDiscardsPresentation() async throws {
        let (store, coordinator) = try context(), (_, document) = try await add(store, coordinator)
        let controller = InvestigationController(coordinator: coordinator, localization: L10n(choice: .vietnamese)); controller.use(store)
        let window = workspace(coordinator, controller), image = try await coordinator.pipeline.renderDocument(model: document.model, assets: document.assets)
        let capture = InvestigationCaptureView(image:image,sourceSize:document.model.canvas,mode:.points)
        window.workspaceView.showPresentation(capture); window.window?.layoutIfNeeded()
        let rect = capture.imageRect
        for point in [CGPoint(x:rect.minX + rect.width * 0.2,y:rect.midY),CGPoint(x:rect.minX + rect.width * 0.8,y:rect.midY)] {
            let location = capture.convert(point,to:nil)
            for type in [NSEvent.EventType.leftMouseDown,.leftMouseUp] {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with:type,location:location,modifierFlags:[],timestamp:1,windowNumber:window.window!.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1))
                if type == .leftMouseDown { capture.mouseDown(with:event) } else { capture.mouseUp(with:event) }
            }
        }
        XCTAssertEqual(capture.points.count,2)
        capture.resetSelection(); XCTAssertTrue(capture.points.isEmpty)
        capture.cancel = { window.workspaceView.dismissPresentation() }
        let escape = try XCTUnwrap(NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:2,windowNumber:window.window!.windowNumber,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:false,keyCode:53))
        capture.keyDown(with:escape); XCTAssertNil(window.workspaceView.presentation); XCTAssertFalse(window.workspaceView.canvas.isHidden)
    }
    func testInlineAnnotationMakesOneUndoAndNeverChangesOriginalBytes() async throws {
        let (store, coordinator) = try context(), (item, document) = try await add(store, coordinator)
        let controller = InvestigationController(coordinator:coordinator,localization:L10n(choice:.vietnamese)); controller.use(store)
        let window = workspace(coordinator,controller), before = document.model, bytes = try Data(contentsOf:store.originalURL(item))
        let button: NSButton = try control("investigation.annotate",in:controller.analysisPanel)
        button.performClick(nil); try await waitFor { controller.hasPendingParameters }
        XCTAssertEqual(window.workspaceView.sidebar.selectedPage,2)
        controller.applyParameters(); try await waitFor { document.model.layers.count > before.layers.count }
        XCTAssertEqual(store.value.events.last?.payload.operation,"annotation")
        document.undoManager?.undo(); XCTAssertEqual(document.model,before)
        XCTAssertEqual(try Data(contentsOf:store.originalURL(item)),bytes)
    }

}

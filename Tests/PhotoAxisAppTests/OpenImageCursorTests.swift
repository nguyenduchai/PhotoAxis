import AppKit
import XCTest
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class OpenImageCursorTests: XCTestCase {
    private let loc = L10n(choice: .vietnamese)
    private func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoAxis-UI8-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false); return root
    }
    private func document(_ coordinator: DocumentCoordinator) async throws -> PhotoDocument {
        let url = Bundle(for: Self.self).resourceURL!.appendingPathComponent("P02/grid-corners.png")
        let asset = try await coordinator.pipeline.prepare(.file(url), budget: ImportBudget())
        let document = PhotoDocument(model: try PhotoDocumentModel(name: "Ảnh đang mở", canvas: asset.descriptor.size, ppi: 72), localization: loc)
        try document.place(asset, recordHistory: false); try coordinator.add(document); return document
    }
    private func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
    private func control<T: NSView>(_ key: String, _ view: NSView) throws -> T {
        try XCTUnwrap(views(view).first { $0.accessibilityIdentifier() == key } as? T)
    }
    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<600 { if condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
        XCTFail("Operation did not settle")
    }
    func testDirectCaptureUsesCommittedEditedCanvasAndPreservesTabHistoryAssetsAndCheckpoint() async throws {
        let coordinator = DocumentCoordinator(localization: loc), document = try await document(coordinator)
        let baseline = try XCTUnwrap(document.analysisBaseline), layer = try XCTUnwrap(document.selectedLayerID)
        try document.perform(.opacity) { try $0.setOpacity(layer, 0.5) }
        let before = document.snapshot(), model = document.model, cursor = document.history.cursor
        let context = try await OpenImageAnalysis.capture(document, coordinator: coordinator, localization: loc)
        let item = try context.store.item(context.itemID)
        let current = try await coordinator.pipeline.renderDocument(model: model, assets: document.assets)
        let frozen = try await context.store.intakeSnapshot(item.id, projects: coordinator.projectStore)
        let image = try await coordinator.pipeline.renderDocument(model: frozen.model, assets: frozen.assets)
        XCTAssertEqual(image.width, current.width); XCTAssertEqual(image.height, current.height)
        XCTAssertEqual(image.dataProvider!.data! as Data, current.dataProvider!.data! as Data)
        XCTAssertEqual(document.model, model); XCTAssertEqual(document.history.cursor, cursor)
        XCTAssertEqual(document.history.stateID, before.stateID); XCTAssertEqual(document.assets.mapValues(\.data), before.assets.mapValues(\.data))
        XCTAssertNil(document.model.investigation); XCTAssertNil(document.fileURL); XCTAssertTrue(document.isDocumentEdited)
        XCTAssertEqual(context.baseline.model, baseline.model); XCTAssertNotEqual(baseline.model, model)
        XCTAssertEqual(context.store.value.events.last?.payload.details["documentModelSHA256"], InvestigationDigest.hash(try ProjectSchema(model).encoded()))
        XCTAssertEqual(context.store.value.events.last?.payload.details["origin"], "rendered-current-canvas-not-received-original")
        XCTAssertTrue(item.intake.source.contains("không phải file gốc"))
        _ = try InvestigationCase.decode(Data(contentsOf: context.store.manifestURL))
    }
    func testAnalysisTracksActiveTabAndNeverFallsBackToSelectedCaseOrClosedTab() async throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = DocumentCoordinator(localization: loc), ordinary = try await document(coordinator)
        let store = try InvestigationCaseStore(root: root.appendingPathComponent("Other.paxcase"), creating: InvestigationCase(code: "OTHER", title: "Other case", examiner: "Tester"))
        let input = Bundle(for: Self.self).resourceURL!.appendingPathComponent("P02/grid-corners.png")
        let item = try await store.importFile(input, intake: .init(), pipeline: coordinator.pipeline, projects: coordinator.projectStore)
        let controller = InvestigationController(coordinator: coordinator, localization: loc); controller.use(store)
        XCTAssertEqual(controller.selectedItem?.id, item.id); XCTAssertNil(controller.analysisItem)
        let (direct, captured) = try await controller.prepareActiveImage()
        XCTAssertFalse(direct === store); XCTAssertEqual(controller.analysisItem?.id, captured.id)
        let working = try await controller.openItem(item.id); controller.synchronizeActiveDocument()
        XCTAssertTrue(controller.analysisStore === store); XCTAssertEqual(controller.analysisItem?.id, item.id)
        coordinator.select(ordinary.model.id); controller.synchronizeActiveDocument()
        XCTAssertTrue(controller.analysisStore === direct)
        coordinator.remove(ordinary.model.id); coordinator.remove(working.model.id); controller.synchronizeActiveDocument()
        XCTAssertNil(controller.analysisStore); XCTAssertNil(controller.analysisItem)
        let button: NSButton = try control("investigation.compare", controller.analysisPanel); XCTAssertFalse(button.isEnabled)
    }
    func testEditingInvalidatesDirectCalibrationAndRedactionsAndCapturesNewCanvas() async throws {
        let coordinator = DocumentCoordinator(localization: loc), document = try await document(coordinator)
        let controller = InvestigationController(coordinator: coordinator, localization: loc)
        let (store, item) = try await controller.prepareActiveImage()
        try store.setRedactions(item.id, regions: [.init(x:0,y:0,width:20,height:20)])
        let calibration = try EvidenceCalibration(itemID: item.id, originalSHA256: item.originalSHA256,
            modelSHA256: InvestigationDigest.hash(item.currentModelJSON), canvas: item.model.canvas,
            reference: [.init(x:0,y:0),.init(x:100,y:0)], knownLength:100, unit:.mm, assumption:"Synthetic", operatorName:"")
        try store.addCalibration(calibration)
        try document.perform(.opacity) { try $0.setOpacity(document.selectedLayerID!, 0.3) }; controller.synchronizeActiveDocument()
        XCTAssertNil(controller.analysisStore)
        let measure: NSButton = try control("investigation.measure", controller.analysisPanel); XCTAssertFalse(measure.isEnabled)
        let (next, entry) = try await controller.prepareActiveImage()
        XCTAssertFalse(next === store); XCTAssertTrue(entry.redactions.isEmpty); XCTAssertNil(entry.redactionModelSHA256)
        XCTAssertNil(next.value.analysis); XCTAssertNotEqual(entry.originalSHA256, item.originalSHA256)
        XCTAssertEqual(store.value.analysis?.calibrations.count,1)
    }
    func testSavingDerivedAnalysisRetainsLedgerAndSnapshotWithoutAttachingOriginalTab() async throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at:root) }
        let coordinator = DocumentCoordinator(localization: loc), document = try await document(coordinator), model = document.model, dirty = document.isDocumentEdited
        let context = try await OpenImageAnalysis.capture(document, coordinator:coordinator, localization:loc, parent:root)
        try context.store.setRedactions(context.itemID,regions:[.init(x:10,y:10,width:30,height:30)])
        let destination = root.appendingPathComponent("Saved.paxcase")
        let controller = InvestigationController(coordinator:coordinator,localization:loc)
        XCTAssertNoThrow(try controller.protectNewCaseDestination(destination))
        XCTAssertThrowsError(try controller.protectNewCaseDestination(context.store.root.appendingPathComponent("Nested.paxcase")))
        var saved: OpenImageAnalysis? = try await context.save(to:destination,code:"CANVAS-01",title:"Bản dựng đã lưu",examiner:"Tester")
        XCTAssertThrowsError(try controller.protectNewCaseDestination(destination))
        XCTAssertFalse(saved!.isTemporary); XCTAssertEqual(saved!.store.value.items[0].redactions.count,1)
        XCTAssertEqual(saved!.store.value.events.prefix(context.store.value.events.count).map(\.sha256),context.store.value.events.map(\.sha256))
        XCTAssertEqual(saved!.store.value.events.last?.payload.operation,"openImageAnalysisSaved")
        do { _ = try await context.save(to:destination,code:"",title:"Overwrite",examiner:""); XCTFail("Existing destination overwritten") } catch { XCTAssertEqual(error as? InvestigationError,.protectedDestination) }
        saved = nil
        let reopened = try InvestigationCaseStore(root:destination)
        try await reopened.verifyOriginal(reopened.value.items[0]); _ = try await reopened.openSnapshot(context.itemID,projects:coordinator.projectStore)
        XCTAssertTrue(reopened.value.items[0].caption.contains("không phải file gốc"))
        XCTAssertEqual(document.model,model); XCTAssertNil(document.investigationSession); XCTAssertNil(document.fileURL)
        XCTAssertEqual(document.isDocumentEdited,dirty)
    }
    func testEditingSavedSnapshotCannotReplaceAnalysisOfTheOriginalEditableTab() async throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at:root) }
        let coordinator = DocumentCoordinator(localization:loc), document = try await document(coordinator), original = document.model
        let context = try await OpenImageAnalysis.capture(document,coordinator:coordinator,localization:loc,parent:root)
        let saved = try await context.save(to:root.appendingPathComponent("Saved.paxcase"),code:"C",title:"Snapshot",examiner:"")
        XCTAssertTrue(saved.matches(document))
        let before = try saved.store.item(saved.itemID).model
        var edited = before; try edited.setOpacity(before.layers[0].id,0.25)
        try saved.store.commitModel(saved.itemID,operation:"opacity",before:before,after:edited)
        XCTAssertFalse(saved.matches(document),"A case working tab can edit a saved raster; it must not override the original canvas context")
        XCTAssertTrue(context.matches(document)); XCTAssertEqual(document.model,original)
        XCTAssertNotEqual(try saved.store.item(saved.itemID).model,before)
    }
    func testTemporaryCaptureCleanupAndFailedSaveLeaveNoPartialCase() async throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = DocumentCoordinator(localization: loc), document = try await document(coordinator)
        var context: OpenImageAnalysis? = try await OpenImageAnalysis.capture(document,coordinator:coordinator,localization:loc,parent:root)
        let temporary = context!.store.root, destination = root.appendingPathComponent("Invalid.paxcase")
        do { _ = try await context!.save(to:destination,code:"",title:"",examiner:""); XCTFail("Invalid title accepted") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath:destination.path))
        let original = context!.store.originalURL(try context!.store.item(context!.itemID))
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:original.path)
        try Data("External mutation".utf8).write(to:original)
        do { _ = try await context!.save(to:destination,code:"",title:"Corrupt",examiner:""); XCTFail("Corrupt raster accepted") }
        catch { XCTAssertEqual(error as? InvestigationError,.integrity) }
        XCTAssertFalse(FileManager.default.fileExists(atPath:destination.path))
        context = nil; XCTAssertFalse(FileManager.default.fileExists(atPath:temporary.path))
        XCTAssertEqual(document.history.entries.count,0)
    }
    func testDirectInlineAnnotationMakesOneUndoAndChangingTabCancelsRedactionDraft() async throws {
        let coordinator = DocumentCoordinator(localization:loc), document = try await document(coordinator), before = document.model
        let controller = InvestigationController(coordinator:coordinator,localization:loc)
        coordinator.changed = { [weak controller] in controller?.synchronizeActiveDocument() }
        controller.synchronizeActiveDocument()
        let annotate: NSButton = try control("investigation.annotate",controller.analysisPanel)
        annotate.performClick(nil); try await waitFor { controller.hasPendingParameters }
        controller.applyParameters(); try await waitFor { document.model.layers.count > before.layers.count }
        XCTAssertEqual(document.history.entries.count,1); XCTAssertNil(document.model.investigation)
        document.undoManager?.undo(); XCTAssertEqual(document.model,before)
        let redact: NSButton = try control("investigation.redact",controller.outputPanel)
        try await waitFor { redact.isEnabled }; redact.performClick(nil); try await waitFor { controller.hasPendingParameters }
        let store = try XCTUnwrap(controller.analysisStore), bytes = try Data(contentsOf:store.manifestURL)
        try coordinator.create(name:"Other tab",size:CanvasSize(width:100,height:100),ppi:72,background:.white)
        XCTAssertFalse(controller.hasPendingParameters); controller.applyParameters(); await Task.yield()
        XCTAssertEqual(try Data(contentsOf:store.manifestURL),bytes); XCTAssertNil(controller.analysisItem)
    }
    func testAsyncCaptureCannotSelectAnOlderTabAfterSwitch() async throws {
        let coordinator = DocumentCoordinator(localization:loc), first = try await document(coordinator)
        let controller = InvestigationController(coordinator:coordinator,localization:loc)
        let capture = Task { try await controller.prepareActiveImage() }
        await Task.yield()
        try coordinator.create(name:"Latest tab",size:CanvasSize(width:80,height:60),ppi:72,background:.white)
        do { _ = try await capture.value } catch { XCTAssertTrue(error is CancellationError) }
        controller.synchronizeActiveDocument(); XCTAssertNotEqual(coordinator.active?.model.id,first.model.id)
        XCTAssertNil(controller.analysisItem)
    }
    private func canvas() throws -> (WelcomeCanvasView,PhotoDocument) {
        let canvas = WelcomeCanvasView(localization:loc); canvas.frame = .init(x:0,y:0,width:500,height:400)
        let document = PhotoDocument(model:try PhotoDocumentModel(name:"Cursor",canvas:CanvasSize(width:300,height:200),ppi:72),localization:loc)
        canvas.display(document,pipeline:ImagePipeline()); return (canvas,document)
    }
    private func event(_ type: NSEvent.EventType, at point:NSPoint, flags:NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(with:type,location:point,modifierFlags:flags,timestamp:1,windowNumber:0,context:nil,eventNumber:1,clickCount:1,pressure:1)!
    }
    func testToolCursorImagesAreDistinctCachedAndSetActualAppKitHotspots() throws {
        let (canvas,document) = try canvas(), point = NSPoint(x:250,y:200)
        var hashes = Set<String>()
        let output = (0..<5).reduce(Bundle.main.bundleURL) { url, _ in url.deletingLastPathComponent() }.appendingPathComponent("ui8-cursors")
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        for tool in ToolKind.allCases {
            document.activeTool = tool
            canvas.cursorUpdate(with:event(.mouseMoved,at:point))
            let kind = canvas.cursorKind(at:point), cursor = CanvasCursors.cursor(kind)
            XCTAssertTrue(NSCursor.current === cursor); XCTAssertTrue(CanvasCursors.cursor(kind) === cursor)
            if case .tool = kind {
                XCTAssertEqual(cursor.hotSpot,NSPoint(x:5,y:5))
                let data = try XCTUnwrap(cursor.image.tiffRepresentation); hashes.insert(InvestigationDigest.hash(data))
                let bitmap = try XCTUnwrap(NSBitmapImageRep(data:data))
                try XCTUnwrap(bitmap.representation(using:.png,properties:[:])).write(to:output.appendingPathComponent(tool.rawValue+".png"))
            }
        }
        XCTAssertEqual(hashes.count,9)
        document.activeTool = .zoom
        canvas.mouseMoved(with:event(.mouseMoved,at:point,flags:.option)); XCTAssertTrue(NSCursor.current === CanvasCursors.cursor(.zoomOut))
        document.activeTool = .cloneStamp
        canvas.mouseMoved(with:event(.mouseMoved,at:point,flags:.option)); XCTAssertTrue(NSCursor.current === CanvasCursors.cursor(.cloneSample))
        XCTAssertEqual(canvas.cursorKind(at:.init(x:-10,y:0)),.arrow)
        canvas.display(nil,pipeline:ImagePipeline()); XCTAssertEqual(canvas.cursorKind(at:point),.arrow)
    }
    func testCropTransformResizeHandDragAndSpaceReleaseRestoreCorrectCursor() throws {
        let (canvas,document) = try canvas()
        document.activeTool = .crop; try document.startCrop()
        canvas.cropOverlay.cropRect = .init(x:100,y:80,width:300,height:200)
        for (index,point) in canvas.cropOverlay.handles.enumerated() { XCTAssertEqual(canvas.cursorKind(at:point),.handle(index)) }
        XCTAssertEqual(canvas.cursorKind(at:.init(x:250,y:180)),.openHand)
        canvas.cropOverlay.cropRect = .init(x:2000,y:2000,width:300,height:200); canvas.resetCursorRects()
        document.cancelSession(); document.activeTool = .move
        canvas.overlay.showsHandles = true; canvas.overlay.selectionBounds = .init(x:50,y:40,width:100,height:80)
        // No editable layer means no transform handles take over the Move cursor.
        XCTAssertEqual(canvas.cursorKind(at:.init(x:50,y:40)),.tool(.move))
        document.activeTool = .hand
        let point = NSPoint(x:200,y:150)
        canvas.mouseDown(with:event(.leftMouseDown,at:point)); XCTAssertEqual(canvas.cursorKind(at:point),.closedHand)
        canvas.mouseUp(with:event(.leftMouseUp,at:point)); XCTAssertEqual(canvas.cursorKind(at:point),.openHand)
        document.activeTool = .brush
        let space = NSEvent.keyEvent(with:.keyDown,location:point,modifierFlags:[],timestamp:2,windowNumber:0,context:nil,characters:" ",charactersIgnoringModifiers:" ",isARepeat:false,keyCode:49)!
        canvas.keyDown(with:space); XCTAssertEqual(canvas.cursorKind(at:point),.openHand); XCTAssertTrue(canvas.paintCursor.isHidden)
        canvas.mouseDown(with:event(.leftMouseDown,at:point)); XCTAssertEqual(canvas.cursorKind(at:point),.closedHand)
        canvas.display(document,pipeline:canvas.imagePipeline!); XCTAssertTrue(canvas.paintCursor.isHidden)
        canvas.keyUp(with:space); XCTAssertEqual(canvas.cursorKind(at:point),.tool(.brush)); XCTAssertFalse(canvas.paintCursor.isHidden)
        canvas.mouseUp(with:event(.leftMouseUp,at:point))
    }
}

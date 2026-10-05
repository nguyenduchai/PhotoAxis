import AppKit
import CoreGraphics
import ImageIO
import PDFKit
import XCTest
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class UtilityPrivacyTests: XCTestCase {
    private let loc = L10n(choice: .vietnamese)
    private func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoAxis-Utility10-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    private func picture(_ size: CanvasSize, transparent: Bool = false) throws -> CGImage {
        let c = try ContentRasterizer.context(size)
        if !transparent {
            for y in 0..<size.height { for x in 0..<size.width {
                c.setFillColor(ContentRasterizer.color((x + y) % 2 == 0 ? .white : .black)); c.fill(CGRect(x: x, y: y, width: 1, height: 1))
            } }
        }
        return try XCTUnwrap(c.makeImage())
    }
    private func rgba(_ image: CGImage) throws -> [UInt8] {
        let c = try ContentRasterizer.context(CanvasSize(width: image.width, height: image.height))
        c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Array(UnsafeBufferPointer(start: c.data!.assumingMemoryBound(to: UInt8.self), count: c.bytesPerRow * image.height))
    }
    private func fixture(_ coordinator: DocumentCoordinator) async throws -> PhotoDocument {
        let size = try CanvasSize(width: 100, height: 80), image = try picture(size)
        let data = try InvestigationSharing.pngBytes(image, ppi: 72)
        let asset = try await coordinator.pipeline.prepare(.clipboard(data, name: "Synthetic.png"), budget: ImportBudget())
        let document = PhotoDocument(model: try PhotoDocumentModel(name: "Ảnh tổng hợp", canvas: size, ppi: 72), localization: loc)
        try document.place(asset, recordHistory: false); try coordinator.add(document); return document
    }
    private func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
    private func waitFor(_ predicate: () -> Bool) async throws {
        for _ in 0..<500 { if predicate() { return }; try await Task.sleep(for: .milliseconds(10)) }
        XCTFail("Utility operation did not settle")
    }
    private func entry(_ name: String = "Private.jpg", caption: String = "", color: RGBAColor = .white) throws -> PhotoSheetEntry {
        let size = try CanvasSize(width: 80, height: 40), c = try ContentRasterizer.context(size)
        c.setFillColor(ContentRasterizer.color(color)); c.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        return PhotoSheetEntry(name: name, pixels: size, data: try InvestigationSharing.pngBytes(XCTUnwrap(c.makeImage()), ppi: 72), caption: caption)
    }
    func testProductionSidebarOnlyContainsEditOCRSheetAndPrivacyAndScrollControlsFit() throws {
        for language in [InterfaceLanguage.vietnamese, .english] {
            let coordinator = DocumentCoordinator(localization: L10n(choice: language), opensLegacyProjectsAsCopies: true)
            let preferences = WorkspacePreferences(defaults: UserDefaults(suiteName: "PhotoAxis.UtilityLayout." + UUID().uuidString)!)
            let window = WorkspaceWindowController(preferences: preferences, localization: L10n(choice: language), restoreFrame: false)
            defer { window.close() }
            let utilities = DocumentUtilitiesController(coordinator: coordinator, localization: L10n(choice: language)); utilities.attach(to: window.workspaceView)
            window.showWindow(nil); window.workspaceView.sidebar.frame.size = CGSize(width: 260, height: 620)
            window.workspaceView.sidebar.layoutSubtreeIfNeeded()
            XCTAssertEqual(window.workspaceView.sidebar.pageButtons.map { $0.identifier!.rawValue }, ["workspace.page.edit", "workspace.page.ocr", "workspace.page.sheet", "workspace.page.privacy"])
            XCTAssertFalse(views(window.workspaceView.sidebar).contains { ($0.accessibilityIdentifier() ?? "").hasPrefix("investigation.") })
            for page in 1...3 {
                window.workspaceView.sidebar.pageButtons[page].performClick(nil); window.workspaceView.sidebar.layoutSubtreeIfNeeded()
                for view in views(window.workspaceView.sidebar) where !view.isHidden && view is NSControl && view.superview is NSStackView {
                    let rect = view.alignmentRect(forFrame: view.frame)
                    XCTAssertGreaterThan(view.frame.width, 0)
                    XCTAssertLessThanOrEqual(rect.maxX, view.superview!.bounds.maxX + 1, "\(view.accessibilityIdentifier() ?? view.description)")
                }
            }
        }
    }
    func testBlackCoverUsesTopLeftRegionAndDoesNotChangeAnyOutsidePixel() async throws {
        let size = try CanvasSize(width: 100, height: 80), source = try picture(size), engine = PrivacyEngine()
        let region = EvidenceRegion(x: 7, y: 11, width: 31, height: 17)
        let before = try rgba(source), after = try rgba(await engine.preview(image: source, modelSize: size, regions: [region], style: .cover, strength: 50))
        for y in 0..<size.height { for x in 0..<size.width {
            let offset = (y * size.width + x) * 4
            if x >= 7 && x < 38 && y >= 11 && y < 28 { XCTAssertEqual(Array(after[offset..<offset+4]), [0, 0, 0, 255]) }
            else { XCTAssertEqual(Array(after[offset..<offset+4]), Array(before[offset..<offset+4])) }
        } }
    }
    func testBlurAndPixelationAreOpaqueAndChangeHighFrequencyContent() async throws {
        let size = try CanvasSize(width: 64, height: 48), source = try picture(size), engine = PrivacyEngine()
        let region = EvidenceRegion(x: 0, y: 0, width: 64, height: 48), original = try rgba(source)
        for style in [PrivacyStyle.blur, .pixelate] {
            let output = try rgba(await engine.patch(image: source, region: region, style: style, strength: 80))
            XCTAssertNotEqual(output, original)
            XCTAssertTrue(stride(from: 3, to: output.count, by: 4).allSatisfy { output[$0] == 255 })
            let transparent = try rgba(await engine.patch(image: picture(size, transparent: true), region: region, style: style, strength: 80))
            XCTAssertTrue(transparent.allSatisfy { $0 == 255 }, "Transparent ROI must be matted with opaque white")
        }
    }
    func testPrivacyInvalidCoordinatesStrengthAndTooManyRegionsReject() async throws {
        let size = try CanvasSize(width: 40, height: 40), source = try picture(size), engine = PrivacyEngine()
        for region in [EvidenceRegion(x: -1, y: 0, width: 10, height: 10), .init(x: 39, y: 0, width: 2, height: 4), .init(x: 0, y: 0, width: 0, height: 4)] {
            do { _ = try await engine.patch(image: source, region: region, style: .blur, strength: 50); XCTFail("Invalid region accepted") } catch {}
        }
        for value in [Double.nan, .infinity, 0, 101] {
            do { _ = try await engine.patch(image: source, region: .init(x: 0, y: 0, width: 10, height: 10), style: .blur, strength: value); XCTFail("Invalid strength accepted") } catch {}
        }
        do { _ = try await engine.preview(image: source, modelSize: size, regions: Array(repeating: .init(x: 0, y: 0, width: 2, height: 2), count: 21), style: .cover, strength: 50); XCTFail("21 regions accepted") } catch {}
    }
    func testMultipleCoversCommitOneUndoAndPreserveSourceBytes() async throws {
        let coordinator = DocumentCoordinator(localization: loc), document = try await fixture(coordinator), before = document.snapshot()
        try document.applyPrivacy([.init(region: .init(x: 7, y: 11, width: 31, height: 17), asset: nil), .init(region: .init(x: 50, y: 20, width: 20, height: 30), asset: nil)], style: .cover)
        XCTAssertEqual(document.history.entries.count, 1); XCTAssertEqual(document.model.layers.count, before.model.layers.count + 2)
        XCTAssertTrue(document.model.layers.suffix(2).allSatisfy(\.isLocked))
        XCTAssertEqual(document.assets.mapValues(\.data), before.assets.mapValues(\.data))
        document.undoManager?.undo(); XCTAssertEqual(document.model, before.model)
        document.undoManager?.redo(); XCTAssertEqual(document.model.layers.count, before.model.layers.count + 2)
        let image = try await coordinator.pipeline.renderDocument(model: document.model, assets: document.assets), pixels = try rgba(image)
        XCTAssertEqual(Array(pixels[((12 * 100 + 8) * 4)..<((12 * 100 + 8) * 4 + 4)]), [0, 0, 0, 255])
    }
    func testLayerQuotaFailureIsAtomicAndDoesNotRetainPartialAssets() async throws {
        let coordinator = DocumentCoordinator(localization: loc), document = try await fixture(coordinator)
        for _ in 0..<48 { try document.perform(.createShape) { _ = try $0.insertContent(.shape(.init(kind: .rectangle, size: CanvasSize(width: 2, height: 2), fill: .white)), name: "Quota", transform: .identity, above: nil) } }
        let before = document.snapshot(), selection = document.selectedLayerID
        XCTAssertThrowsError(try document.applyPrivacy(Array(repeating: .init(region: .init(x: 0, y: 0, width: 4, height: 4), asset: nil), count: 2), style: .cover))
        XCTAssertEqual(document.model, before.model); XCTAssertEqual(document.history.stateID, before.stateID); XCTAssertEqual(document.assets.mapValues(\.data), before.assets.mapValues(\.data)); XCTAssertEqual(document.selectedLayerID, selection)
    }
    func testBlurProjectRoundTripAndCropRetainImmutableOriginalAndOpaqueExport() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = DocumentCoordinator(localization: loc), document = try await fixture(coordinator), originals = document.assets.mapValues(\.data)
        let source = try await coordinator.pipeline.renderDocument(model: document.model, assets: document.assets), engine = PrivacyEngine()
        let patches = try await engine.patches(image: source, regions: [.init(x: 10, y: 10, width: 30, height: 20)], style: .blur, strength: 90, ppi: 72)
        try document.applyPrivacy(patches, style: .blur)
        let snapshot = document.snapshot(), url = root.appendingPathComponent("privacy.paxis")
        try await coordinator.projectStore.save(snapshot, to: url); let loaded = try await coordinator.projectStore.open(url)
        XCTAssertEqual(loaded.model, snapshot.model); XCTAssertEqual(loaded.assets.mapValues(\.data), snapshot.assets.mapValues(\.data))
        for (id, data) in originals { XCTAssertEqual(loaded.assets[id]?.data, data) }
        let before = try await coordinator.pipeline.renderDocument(model: snapshot.model, assets: snapshot.assets), after = try await coordinator.pipeline.renderDocument(model: loaded.model, assets: loaded.assets)
        XCTAssertEqual(try rgba(after), try rgba(before))
        var cropped = loaded.model; try cropped.crop(to: .init(x: 5, y: 5, width: 90, height: 70))
        XCTAssertTrue(cropped.layers.last!.isLocked); XCTAssertEqual(cropped.sources, loaded.model.sources)
    }
    func testFaceRectanglesConvertOriginExpandAndClampWithoutIdentification() throws {
        let size = try CanvasSize(width: 1000, height: 800)
        let region = try XCTUnwrap(PrivacyEngine.faceRegions(boxes: [CGRect(x: 0.2, y: 0.4, width: 0.2, height: 0.3)], size: size).first)
        XCTAssertLessThanOrEqual(region.x, 176); XCTAssertGreaterThanOrEqual(region.x + region.width, 424)
        XCTAssertLessThan(region.y, 240); XCTAssertGreaterThan(region.y + region.height, 480)
        let edge = try XCTUnwrap(PrivacyEngine.faceRegions(boxes: [CGRect(x: 0, y: 0.8, width: 0.2, height: 0.2)], size: size).first)
        XCTAssertEqual(edge.x, 0); XCTAssertEqual(edge.y, 0); try edge.validate(in: size)
        XCTAssertThrowsError(try PrivacyEngine.faceRegions(boxes: [CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1)], size: size))
        XCTAssertThrowsError(try PrivacyEngine.faceRegions(boxes: Array(repeating: CGRect(x: 0, y: 0, width: 1, height: 1), count: 21), size: size))
    }
    func testNoFaceSyntheticImageHasNoSuggestedRegion() async throws {
        let engine = PrivacyEngine(), size = try CanvasSize(width: 100, height: 80)
        let regions = try await engine.faces(image: picture(size), modelSize: size); XCTAssertTrue(regions.isEmpty)
    }
    func testPhotoSheetAspectRatioAndPaginationForEveryLayout() throws {
        let entries = try (0..<7).map { try entry("\($0).jpg", caption: "Ảnh tổng hợp số \($0)") }
        for perPage in [1, 2, 4, 6] { for landscape in [false, true] {
            let settings = PhotoSheetSettings(title: "BẢNG ẢNH", note: "Tiếng Việt có dấu", perPage: perPage, landscape: landscape)
            XCTAssertEqual(PhotoSheetEngine.pageCount(7, perPage: perPage), Int(ceil(7.0 / Double(perPage))))
            let page = try PhotoSheetEngine.page(entries: entries, settings: settings, index: 0, dpi: 90, language: "vi")
            XCTAssertEqual(page.width > page.height, landscape)
        } }
        let fit = PhotoSheetEngine.imageRect(source: try CanvasSize(width: 800, height: 200), cell: CGRect(x: 10, y: 20, width: 100, height: 200))
        XCTAssertEqual(fit.width / fit.height, 4, accuracy: 0.0001); XCTAssertEqual(fit.midX, 60); XCTAssertEqual(fit.midY, 120)
    }
    func testPhotoSheetPDFHasA4PagesAndNoSelectableTextOrHiddenOriginal() throws {
        let entries = try [entry("SECRET-SOURCE-NAME.jpg", caption: "HỌ TÊN ĐÃ CHE", color: .black), entry("Original.jpg"), entry("Third.jpg")]
        let settings = PhotoSheetSettings(title: "BẢNG ẢNH", perPage: 2)
        let bytes = try PhotoSheetEngine.pdf(entries: entries, settings: settings, language: "vi")
        let pdf = try XCTUnwrap(PDFDocument(data: bytes)); XCTAssertEqual(pdf.pageCount, 2)
        for i in 0..<pdf.pageCount {
            let page = try XCTUnwrap(pdf.page(at: i)); XCTAssertEqual(page.bounds(for: .mediaBox).width, 595.276, accuracy: 0.01)
            XCTAssertTrue((page.string ?? "").isEmpty)
        }
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("SECRET-SOURCE-NAME")); XCTAssertFalse(bytes.range(of: entries[0].data) != nil)
        XCTAssertNil(pdf.documentAttributes?[PDFDocumentAttribute.authorAttribute])
    }
    func testPhotoSheetRejectsLongCaptionHeaderMismatchAndOversizedDecodeBeforeRendering() throws {
        let e = try entry(caption: String(repeating: "Chú thích quá dài ", count: 100))
        XCTAssertThrowsError(try PhotoSheetEngine.page(entries: [e], settings: .init(perPage: 6), index: 0, dpi: 90, language: "vi"))
        let bad = PhotoSheetEntry(name: "Mismatch", pixels: try CanvasSize(width: 2000, height: 2000), data: e.data)
        XCTAssertThrowsError(try PhotoSheetEngine.page(entries: [bad], settings: .init(), index: 0, dpi: 90, language: "en"))
        XCTAssertThrowsError(try PhotoSheetEngine.validate(Array(repeating: e, count: 101), settings: .init()))
        XCTAssertThrowsError(try PhotoSheetSettings(perPage: 3).validate())
    }
    func testPhotoSheetReorderingAndCaptionRemainAttachedToTheirPhoto() throws {
        let coordinator = DocumentCoordinator(localization: loc), controller = DocumentUtilitiesController(coordinator: coordinator, localization: loc)
        let a = try entry("A.png", caption: "A"), b = try entry("B.png", caption: "B")
        try controller.appendPhoto(a); try controller.appendPhoto(b); controller.reorderPhoto(delta: -1)
        XCTAssertEqual(controller.entries.map(\.id), [b.id, a.id]); XCTAssertEqual(controller.entries.map(\.caption), ["B", "A"])
        controller.caption.stringValue = "Chú thích B mới"; controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: controller.caption))
        XCTAssertEqual(controller.entries[0].caption, "Chú thích B mới"); XCTAssertEqual(controller.entries[1].caption, "A")
    }
    func testOCRReadsCurrentCanvasAndPublishesEditableVietnameseWithoutChangingDocument() async throws {
        let coordinator = DocumentCoordinator(localization: loc), document = try await fixture(coordinator), controller = DocumentUtilitiesController(coordinator: coordinator, localization: loc)
        let before = document.snapshot()
        controller.recognition = { image, region, _ in
            XCTAssertEqual(image.width, 100); XCTAssertEqual(image.height, 80); XCTAssertEqual(region.width, 100)
            return .init(language: "vi-VN", revision: 3, sourceSize: try CanvasSize(width: 100, height: 80), region: region, lines: [EvidenceOCRLine(text: "CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM", confidence: 1, region: .init(x: 0, y: 0, width: 1, height: 1))])
        }
        controller.runOCR(); try await waitFor { !controller.ocrText.string.isEmpty }
        XCTAssertTrue(controller.ocrText.isEditable); XCTAssertTrue(controller.ocrText.string.contains("VIỆT NAM"))
        XCTAssertEqual(document.model, before.model); XCTAssertEqual(document.history.stateID, before.stateID); XCTAssertEqual(document.assets.mapValues(\.data), before.assets.mapValues(\.data))
    }
    func testCancellingOCRAndChangingTabDiscardsLateResults() async throws {
        let coordinator = DocumentCoordinator(localization: loc), document = try await fixture(coordinator), controller = DocumentUtilitiesController(coordinator: coordinator, localization: loc)
        let entered = expectation(description: "OCR started"), ended = expectation(description: "OCR released"), release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        controller.recognition = { _, region, _ in
            entered.fulfill(); release.wait(); ended.fulfill()
            return .init(language: "vi-VN", revision: 3, sourceSize: try CanvasSize(width: 100, height: 80), region: region, lines: [])
        }
        controller.runOCR(); await fulfillment(of: [entered], timeout: 5)
        controller.cancelOCR(); XCTAssertTrue(controller.ocrText.isEditable)
        try coordinator.create(name: "Other", size: CanvasSize(width: 20, height: 20), ppi: 72, background: .white); controller.synchronizeActiveDocument()
        release.signal(); await fulfillment(of: [ended], timeout: 5); try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(controller.ocrText.string.isEmpty); XCTAssertNil(document.model.investigation)
    }
    func testLegacyProjectOpensAsDetachedEditableCopyAndCannotOverwriteArchive() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = DocumentCoordinator(localization: loc, opensLegacyProjectsAsCopies: true), document = try await fixture(coordinator)
        var legacy = document.model; legacy.investigation = .init(caseID: UUID(), itemID: document.model.id)
        let url = root.appendingPathComponent("Legacy.paxis"), snapshot = ProjectSnapshot(model: legacy, assets: document.assets, stateID: UUID())
        try await coordinator.projectStore.save(snapshot, to: url); let original = try Data(contentsOf: url)
        coordinator.remove(document.model.id); coordinator.startImport([.file(url)], into: nil); await coordinator.importTask?.value
        let copy = try XCTUnwrap(coordinator.active); XCTAssertNil(copy.model.investigation); XCTAssertNil(copy.fileURL); XCTAssertFalse(copy.isInteractionLocked); XCTAssertTrue(copy.isDocumentEdited)
        XCTAssertEqual(copy.assets.mapValues(\.data), snapshot.assets.mapValues(\.data)); XCTAssertEqual(try Data(contentsOf: url), original)
        let archive = root.appendingPathComponent("Old.paxcase"); try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        let alias = root.appendingPathComponent("Alias"); try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: archive)
        for destination in [archive.appendingPathComponent("overwrite.paxis"), alias.appendingPathComponent("overwrite.png")] { XCTAssertThrowsError(try DocumentCoordinator.protectLegacyDestination(destination)) }
        let blocked = await coordinator.save(copy, saveAs: true, destination: archive.appendingPathComponent("overwrite.paxis")); XCTAssertFalse(blocked)
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.appendingPathComponent("overwrite.paxis").path))
        let saved = await coordinator.save(copy, saveAs: true, destination: root.appendingPathComponent("Copy.paxis")); XCTAssertTrue(saved)
    }
    func testCommittedPrivacyExportAndPhotoSheetExcludeOriginalsAndMetadata() async throws {
        let coordinator = DocumentCoordinator(localization: loc), document = try await fixture(coordinator)
        try document.applyPrivacy([.init(region: .init(x: 7, y: 11, width: 31, height: 17), asset: nil)], style: .cover)
        var snapshot = document.snapshot()
        if let path = ProcessInfo.processInfo.environment["PHOTOAXIS_NATIVE_PRIVACY_PROJECT"] {
            snapshot = try await coordinator.projectStore.open(URL(fileURLWithPath: path))
        }
        let image = try await coordinator.pipeline.renderDocument(model: snapshot.model, assets: snapshot.assets)
        let png = try InvestigationSharing.pngBytes(image, ppi: snapshot.model.ppi)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        // Image I/O creates technical ColorSpace/PixelDimension EXIF fields for a
        // new bitmap. Source metadata such as dates, IDs or comments must be absent.
        XCTAssertNil(exif[kCGImagePropertyExifDateTimeOriginal]); XCTAssertNil(exif[kCGImagePropertyExifUserComment])
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        XCTAssertNil(tiff[kCGImagePropertyTIFFMake]); XCTAssertNil(tiff[kCGImagePropertyTIFFModel])
        let covered = snapshot.model.layers.filter { $0.name == loc.text("privacy.layer.cover") }
        XCTAssertFalse(covered.isEmpty)
        let pixels = try rgba(image), width = image.width
        var black = 0
        for layer in covered {
            guard case .shape(let shape) = layer.content else { return XCTFail("Expected a cover shape") }
            let x = Int(layer.transform.coefficients[2]), y = Int(layer.transform.coefficients[5])
            for row in y..<y+shape.size.height { for column in x..<x+shape.size.width {
                let i = (row * width + column) * 4
                if pixels[i] == 0 && pixels[i+1] == 0 && pixels[i+2] == 0 && pixels[i+3] == 255 { black += 1 }
                else { return XCTFail("Exported privacy region leaked a pixel") }
            } }
        }
        XCTAssertGreaterThan(black, 0)
        let entry = PhotoSheetEntry(name: "PRIVATE-ORIGINAL.png", pixels: snapshot.model.canvas, data: png, caption: "Ảnh đã che")
        let settings = PhotoSheetSettings(title: "BẢNG ẢNH KIỂM THỬ", perPage: 1)
        let sheet = try PhotoSheetEngine.page(entries: [entry], settings: settings, index: 0, dpi: 300, language: "vi")
        let sheetPNG = try InvestigationSharing.pngBytes(sheet, ppi: 300)
        let pdf = try PhotoSheetEngine.pdf(entries: [entry], settings: settings, language: "vi")
        let parsed = try XCTUnwrap(PDFDocument(data: pdf)); XCTAssertEqual(parsed.pageCount, 1); XCTAssertTrue((parsed.page(at: 0)?.string ?? "").isEmpty)
        for original in snapshot.assets.values { XCTAssertNil(pdf.range(of: original.data)); XCTAssertNil(sheetPNG.range(of: original.data)) }
        if let path = ProcessInfo.processInfo.environment["PHOTOAXIS_UTILITY_EVIDENCE"] {
            let root = URL(fileURLWithPath: path); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try png.write(to: root.appendingPathComponent("committed-privacy.png")); try sheetPNG.write(to: root.appendingPathComponent("sheet-current.png")); try pdf.write(to: root.appendingPathComponent("sheet-all.pdf"))
        }
    }

}

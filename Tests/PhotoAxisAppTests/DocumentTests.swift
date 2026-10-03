import AppKit
import XCTest
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore
@testable import PhotoAxis

@MainActor
final class DocumentAppTests: XCTestCase {
    private let root = (0..<5).reduce(Bundle.main.bundleURL) { url, _ in url.deletingLastPathComponent() }
    private func fixture(_ name: String) -> URL { Bundle(for: DocumentAppTests.self).resourceURL!.appendingPathComponent("P02/" + name).absoluteURL }
    private func output(_ name: String) throws -> URL {
        let directory = root.appendingPathComponent("p02-native-tests")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }
    private func png(_ image: CGImage, name: String) throws {
        let url = try output(name)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil); XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
    private func color(_ image: CGImage, x: Int, y: Int) throws -> NSColor {
        let rep = NSBitmapImageRep(cgImage: image)
        let raw = try XCTUnwrap(rep.colorAt(x: x, y: y))
        var components = [raw.redComponent, raw.greenComponent, raw.blueComponent, raw.alphaComponent]
        let tagged = NSColor(colorSpace: rep.colorSpace, components: &components, count: 4)
        return try XCTUnwrap(tagged.usingColorSpace(.sRGB))
    }
    private func assertColor(_ image: CGImage, x: Int, y: Int, red: Double, green: Double, blue: Double, file: StaticString = #filePath, line: UInt = #line) throws {
        let c = try color(image, x: x, y: y)
        XCTAssertEqual(c.redComponent, red, accuracy: 0.03, file: file, line: line)
        XCTAssertEqual(c.greenComponent, green, accuracy: 0.03, file: file, line: line)
        XCTAssertEqual(c.blueComponent, blue, accuracy: 0.03, file: file, line: line)
    }

    func testImportUnicodeEXIFAlphaAndImmutableSources() async throws {
        let pipeline = ImagePipeline()
        let unicode = try output("Ảnh phố biển có dấu.png")
        try Data(contentsOf: fixture("grid-corners.png")).write(to: unicode)
        let data = try Data(contentsOf: unicode)
        let source = try await pipeline.prepare(.file(unicode), budget: ImportBudget())
        XCTAssertEqual(source.name, unicode.lastPathComponent); XCTAssertEqual(source.data, data)
        try Data(repeating: 0, count: data.count).write(to: unicode)
        XCTAssertEqual(source.data, data, "Embedded bytes must not track edits to the external file")
        try data.write(to: unicode)
        let image = try await pipeline.normalizedImage(source)
        try assertColor(image, x: 30, y: 30, red: 1, green: 0, blue: 0)
        let exifURL = fixture("grid-exif-6.jpg"), before = try Data(contentsOf: exifURL)
        let rotated = try await pipeline.prepare(.file(exifURL), budget: ImportBudget())
        XCTAssertEqual(rotated.descriptor.size, try CanvasSize(width: 480, height: 640))
        let normalized = try await pipeline.normalizedImage(rotated)
        try assertColor(normalized, x: 30, y: 30, red: 1, green: 1, blue: 0)
        try assertColor(normalized, x: 450, y: 30, red: 1, green: 0, blue: 0)
        try assertColor(normalized, x: 450, y: 610, red: 0, green: 1, blue: 0)
        try assertColor(normalized, x: 30, y: 610, red: 0, green: 0, blue: 1)
        XCTAssertEqual(try Data(contentsOf: exifURL), before)
        let alpha = try await pipeline.prepare(.file(fixture("alpha-edges.png")), budget: ImportBudget())
        let alphaImage = try await pipeline.normalizedImage(alpha)
        XCTAssertEqual(try color(alphaImage, x: 0, y: 0).alphaComponent, 0)
        XCTAssertEqual(try color(alphaImage, x: 320, y: 240).alphaComponent, 1)
        XCTAssertGreaterThan(try color(alphaImage, x: 485, y: 240).alphaComponent, 0)
        XCTAssertLessThan(try color(alphaImage, x: 485, y: 240).alphaComponent, 1)
        try png(normalized, name: "exif-normalized.png"); try png(alphaImage, name: "alpha-normalized.png")
    }

    func testP3AndHEICConversion() async throws {
        let pipeline = ImagePipeline()
        let asset = try await pipeline.prepare(.file(fixture("colors-display-p3.png")), budget: ImportBudget())
        let normalized = try await pipeline.normalizedImage(asset)
        XCTAssertEqual(normalized.colorSpace?.name, CGColorSpace.sRGB)
        let original = try XCTUnwrap(CGImageSourceCreateWithURL(fixture("colors-display-p3.png") as CFURL, nil))
        let originalImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(original, 0, nil))
        // Independent ColorSync conversion through NSColor, not the CI implementation under test.
        let expected = try color(originalImage, x: 400, y: 300), actual = try color(normalized, x: 400, y: 300)
        XCTAssertEqual(actual.redComponent, expected.redComponent, accuracy: 0.015)
        XCTAssertEqual(actual.greenComponent, expected.greenComponent, accuracy: 0.015)
        let heic = try output("Ảnh tĩnh.heic")
        // HEVC encoder setup can synchronously contact system services. Fixture
        // generation, like the import pipeline under test, must stay off-main.
        let encoded = await Task.detached {
            guard let destination = CGImageDestinationCreateWithURL(heic as CFURL, UTType.heic.identifier as CFString, 1, nil) else { return false }
            CGImageDestinationAddImage(destination, normalized, nil)
            return CGImageDestinationFinalize(destination)
        }.value
        XCTAssertTrue(encoded)
        let imported = try await pipeline.prepare(.file(heic), budget: ImportBudget())
        XCTAssertEqual(imported.descriptor.size, asset.descriptor.size)
        let importedImage = try await pipeline.normalizedImage(imported)
        XCTAssertEqual(importedImage.colorSpace?.name, CGColorSpace.sRGB)
        try png(normalized, name: "p3-to-srgb.png")
    }

    func testRejectsCorruptUnsupportedAndMultipleImages() async throws {
        let pipeline = ImagePipeline()
        for name in ["invalid-truncated.png", "chữ-tiếng-Việt.txt"] {
            do { _ = try await pipeline.prepare(.file(fixture(name)), budget: ImportBudget()); XCTFail("Accepted \(name)") } catch {}
        }
        let asset = try await pipeline.prepare(.file(fixture("grid-corners.png")), budget: ImportBudget())
        let image = try await pipeline.normalizedImage(asset)
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.tiff.identifier as CFString, 2, nil))
        CGImageDestinationAddImage(destination, image, nil); CGImageDestinationAddImage(destination, image, nil); XCTAssertTrue(CGImageDestinationFinalize(destination))
        do { _ = try await pipeline.prepare(.clipboard(data as Data, name: "multi.tiff"), budget: ImportBudget()); XCTFail("Accepted multiple pages") }
        catch { XCTAssertEqual(error as? ImageImportError, .multipleImages) }
        let tiff = try output("unsupported.tiff"); try (data as Data).write(to: tiff)
        do { _ = try await pipeline.prepare(.file(tiff), budget: ImportBudget()); XCTFail("Accepted file TIFF") }
        catch { XCTAssertEqual(error as? ImageImportError, .unsupported) }
        let animation = NSMutableData()
        let apng = try XCTUnwrap(CGImageDestinationCreateWithData(animation, UTType.png.identifier as CFString, 2, nil))
        CGImageDestinationSetProperties(apng, [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 0]] as CFDictionary)
        let frameProperties = [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: 0.1]] as CFDictionary
        CGImageDestinationAddImage(apng, image, frameProperties); CGImageDestinationAddImage(apng, image, frameProperties)
        XCTAssertTrue(CGImageDestinationFinalize(apng))
        do { _ = try await pipeline.prepare(.clipboard(animation as Data, name: "animation.png"), budget: ImportBudget()); XCTFail("Accepted animation") }
        catch { XCTAssertEqual(error as? ImageImportError, .multipleImages) }
    }

    func testQuotaPreflightResizeConsentAndCacheReclamation() async throws {
        let pipeline = ImagePipeline()
        let budget = ImportBudget(remainingPixels: 10_000)
        do { _ = try await pipeline.prepare(.file(fixture("grid-corners.png")), budget: budget); XCTFail("Resized silently") }
        catch { XCTAssertEqual(error as? ImageImportError, .resizeRequired(width: 640, height: 480, proposedWidth: 115, proposedHeight: 86)) }
        let beforeDecode = await pipeline.cacheBytes; XCTAssertEqual(beforeDecode, 0)
        let reduced = try await pipeline.prepare(.file(fixture("grid-corners.png")), budget: budget, allowResize: true)
        XCTAssertLessThanOrEqual(reduced.descriptor.size.pixelCount, 10_000)
        XCTAssertNotEqual(reduced.data, try Data(contentsOf: fixture("grid-corners.png")))
        do { _ = try await pipeline.prepare(.file(fixture("grid-corners.png")), budget: ImportBudget(layerCount: 50)); XCTFail("Exceeded layers") }
        catch { XCTAssertEqual(error as? ImageImportError, .layerLimit) }
        let large = try ImagePipeline.reducedSize(width: Int.max, height: Int.max, pixelBudget: 40_000_000)
        XCTAssertLessThanOrEqual(large.pixelCount, 40_000_000)
        let cacheBytes = await pipeline.cacheBytes; XCTAssertGreaterThan(cacheBytes, 0); XCTAssertLessThanOrEqual(cacheBytes, ImagePipeline.cacheLimit)
        await pipeline.retainCache(for: [])
        let empty = await pipeline.cacheBytes; XCTAssertEqual(empty, 0)
    }

    func testRendererCornersAndOverlayCoordinatesAtBothBackingScales() async throws {
        let pipeline = ImagePipeline()
        let asset = try await pipeline.prepare(.file(fixture("grid-corners.png")), budget: ImportBudget())
        var model = try PhotoDocumentModel(name: "Grid", canvas: asset.descriptor.size, ppi: 72)
        _ = try model.place(asset.descriptor, name: "Grid", above: nil)
        for scale in [1.0, 2.0] {
            var viewport = ViewportState(); viewport.resize(width: 800, height: 600, backingScale: scale, canvas: model.canvas)
            viewport.setZoom(1); viewport.pan(x: 23, y: -17)
            let image = try await pipeline.render(model: model, assets: [asset.descriptor.id: asset], viewport: viewport)
            for (x, y, r, g, b) in [(30.0,30.0,1.0,0.0,0.0),(610,30,0,1,0),(610,450,0,0,1),(30,450,1,1,0)] {
                let point = viewport.transform.viewPoint(fromDocument: .init(x: x, y: y))
                try assertColor(image, x: Int(point.x * scale), y: Int(point.y * scale), red: r, green: g, blue: b)
            }
            try png(image, name: "render-grid-\(Int(scale))x.png")
        }
    }

    func testTabsKeepNavigationSelectionUndoAndRejectSixth() throws {
        let coordinator = DocumentCoordinator(localization: L10n(choice: .english))
        defer { for document in coordinator.documents { coordinator.remove(document.model.id) } }
        for index in 0..<5 { try coordinator.create(name: "Tab \(index)", size: CanvasSize(width: 1080, height: 1080), ppi: 72, background: .white) }
        let first = coordinator.documents[0], last = coordinator.documents[4]
        first.viewport.resize(width: 800, height: 600, backingScale: 2, canvas: first.model.canvas)
        first.viewport.setZoom(2.5); first.viewport.pan(x: 22, y: 44); first.activeTool = .zoom
        let state = first.viewport, model = first.model
        let id = first.selectedLayerID
        XCTAssertFalse(NSDocumentController.shared.documents.contains { $0 === first }, "Only the coordinator may review unsaved tabs")
        XCTAssertFalse(first.undoManager === last.undoManager)
        XCTAssertFalse(first.undoManager!.canUndo)
        coordinator.select(last.model.id); coordinator.select(first.model.id)
        XCTAssertEqual(first.viewport, state); XCTAssertEqual(first.selectedLayerID, id); XCTAssertEqual(first.activeTool, .zoom)
        XCTAssertEqual(first.model, model); XCTAssertTrue(first.isDocumentEdited); XCTAssertNil(first.fileURL)
        XCTAssertThrowsError(try coordinator.create(name: "six", size: CanvasSize(width: 1, height: 1), ppi: 72, background: .transparent))
        XCTAssertEqual(coordinator.documents.count, 5)
    }

    func testBatchPartialFailureAndClosedTargetDiscard() async throws {
        let coordinator = DocumentCoordinator(localization: L10n(choice: .english))
        var report = ""; coordinator.report = { report = $0 }
        defer { for document in coordinator.documents { coordinator.remove(document.model.id) } }
        coordinator.startImport([.file(fixture("grid-corners.png")), .file(fixture("invalid-truncated.png")), .file(fixture("alpha-edges.png"))], into: nil)
        await coordinator.importTask?.value
        XCTAssertEqual(coordinator.documents.count, 2); XCTAssertTrue(report.contains("invalid-truncated.png"))
        let target = coordinator.documents[0]
        coordinator.startImport([.file(fixture("alpha-edges.png"))], into: target.model.id)
        let task = coordinator.importTask; coordinator.remove(target.model.id); await task?.value
        XCTAssertEqual(coordinator.documents.count, 1); XCTAssertEqual(coordinator.documents[0].model.layers.count, 1)
        coordinator.startImport([.file(fixture("grid-corners.png"))], into: nil); let cancelled = coordinator.importTask
        coordinator.cancelImport(); await cancelled?.value; XCTAssertEqual(coordinator.documents.count, 1)
    }

    func testNewPresetsValidationAndRegionalNumbers() throws {
        for language in [InterfaceLanguage.vietnamese, .english] {
            let controller = NewDocumentController(localization: L10n(choice: language)); defer { controller.close() }
            for (index, expected) in [(1080,1080,72), (1920,1080,72), (1080,1920,72), (2480,3508,300)].enumerated() {
                controller.preset.selectItem(at: index); controller.changePreset()
                let (size, ppi) = try controller.validated()
                XCTAssertEqual(size.width, expected.0); XCTAssertEqual(size.height, expected.1); XCTAssertEqual(ppi, Double(expected.2))
                controller.swapDimensions(); XCTAssertEqual(try controller.validated().0.width, expected.1)
            }
            for input in ["8001", "0", "1.5", "bad", "9223372036854775808"] {
                controller.widthField.stringValue = input; XCTAssertThrowsError(try controller.validated())
            }
            controller.widthField.stringValue = "8000"; controller.heightField.stringValue = "8000"; XCTAssertThrowsError(try controller.validated())
        }
        XCTAssertEqual(DocumentNumber.parse("125,5 %", language: "vi_VN"), 125.5)
        XCTAssertEqual(DocumentNumber.parse("125.5 %", language: "en_US"), 125.5)
        for bad in ["12abc", "NaN", "-1", "1e5", "1%2"] { XCTAssertNil(DocumentNumber.parse(bad, language: "en_US")) }
    }

    func testHighDepthGrayscaleUnprofiledAndOversizedMetadata() async throws {
        let pipeline = ImagePipeline()
        func encode(width: Int, height: Int, depth: Int, space: CGColorSpace, name: String) throws -> URL {
            let channels = space.numberOfComponents, row = width * channels * depth / 8
            let provider = try XCTUnwrap(CGDataProvider(data: Data(repeating: 128, count: row * height) as CFData))
            let image = try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: depth, bitsPerPixel: channels * depth,
                bytesPerRow: row, space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
            try png(image, name: name); return try output(name)
        }
        let deep = try encode(width: 16, height: 12, depth: 16, space: CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!, name: "gray-16bit.png")
        let asset = try await pipeline.prepare(.file(deep), budget: ImportBudget())
        XCTAssertTrue(asset.convertedToSDR)
        let normalized = try await pipeline.normalizedImage(asset)
        XCTAssertEqual(normalized.bitsPerComponent, 8); XCTAssertEqual(normalized.colorSpace?.name, CGColorSpace.sRGB)
        let gray = try color(normalized, x: 5, y: 5)
        XCTAssertEqual(gray.redComponent, gray.greenComponent, accuracy: 0.01); XCTAssertEqual(gray.greenComponent, gray.blueComponent, accuracy: 0.01)
        let tooWide = try encode(width: 8001, height: 1, depth: 8, space: CGColorSpace(name: CGColorSpace.sRGB)!, name: "8001x1.png")
        let original = try Data(contentsOf: tooWide)
        do { _ = try await pipeline.prepare(.file(tooWide), budget: ImportBudget()); XCTFail("Allowed 8001 pixels") }
        catch { XCTAssertEqual(error as? ImageImportError, .resizeRequired(width: 8001, height: 1, proposedWidth: 8000, proposedHeight: 1)) }
        let reduced = try await pipeline.prepare(.file(tooWide), budget: ImportBudget(), allowResize: true)
        XCTAssertEqual(reduced.descriptor.size.width, 8000); XCTAssertEqual(try Data(contentsOf: tooWide), original)
        // Retain only critical PNG chunks: remove ICC/gamma without touching pixel data or CRCs.
        let originalPNG = try Data(contentsOf: fixture("grid-corners.png"))
        var untagged = Data(originalPNG.prefix(8)), offset = 8
        while offset + 12 <= originalPNG.count {
            let length = originalPNG[offset..<offset+4].reduce(0) { ($0 << 8) | Int($1) }
            let name = String(data: originalPNG[offset+4..<offset+8], encoding: .ascii)!
            if ["IHDR", "IDAT", "IEND"].contains(name) { untagged.append(originalPNG[offset..<offset+length+12]) }
            offset += length + 12
        }
        let noProfileURL = try output("without-profile.png"); try untagged.write(to: noProfileURL)
        let noProfile = try await pipeline.prepare(.file(noProfileURL), budget: ImportBudget())
        let unprofiledImage = try await pipeline.normalizedImage(noProfile)
        try assertColor(unprofiledImage, x: 30, y: 30, red: 1, green: 0, blue: 0)
    }

    func testClipboardRoutingAndNativeNavigationWithoutDirtyOrUndo() async throws {
        let pipeline = ImagePipeline(), l10n = L10n(choice: .english)
        let asset = try await pipeline.prepare(.file(fixture("grid-corners.png")), budget: ImportBudget())
        let document = PhotoDocument(model: try PhotoDocumentModel(name: "Grid", canvas: asset.descriptor.size, ppi: 72))
        try document.place(asset, recordHistory: false); document.markSaved(stateID: document.history.stateID)
        let preferences = WorkspacePreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let controller = WorkspaceWindowController(preferences: preferences, localization: l10n, restoreFrame: false)
        defer { controller.workspaceView.canvas.display(nil, pipeline: pipeline); controller.close() }
        controller.showWindow(nil); controller.reloadLayout()
        let canvas = controller.workspaceView.canvas
        canvas.display(document, pipeline: pipeline)
        let model = document.model, selected = document.selectedLayerID
        canvas.zoom(to: 1); canvas.selectTool(.zoom)
        func key(_ kind: NSEvent.EventType, code: UInt16, text: String) -> NSEvent {
            NSEvent.keyEvent(with: kind, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: controller.window!.windowNumber, context: nil, characters: text,
                charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
        }
        canvas.keyDown(with: key(.keyDown, code: 49, text: " ")); XCTAssertTrue(canvas.spaceHeld)
        let start = canvas.convert(NSPoint(x: 120, y: 150), to: nil), end = canvas.convert(NSPoint(x: 170, y: 180), to: nil)
        let beforePan = document.viewport
        for (kind, point) in [(NSEvent.EventType.leftMouseDown, start), (.leftMouseDragged, end)] {
            let event = NSEvent.mouseEvent(with: kind, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: controller.window!.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            if kind == .leftMouseDown { canvas.mouseDown(with: event) } else { canvas.mouseDragged(with: event) }
        }
        XCTAssertEqual(document.viewport.origin.x - beforePan.origin.x, 50, accuracy: 1e-8)
        XCTAssertEqual(document.viewport.origin.y - beforePan.origin.y, 30, accuracy: 1e-8)
        canvas.keyUp(with: key(.keyUp, code: 49, text: " ")); XCTAssertFalse(canvas.spaceHeld); XCTAssertEqual(document.activeTool, .zoom)
        canvas.zoom(to: 0.05); canvas.zoom(to: 16); canvas.zoom(to: 1)
        XCTAssertEqual(document.model, model); XCTAssertEqual(document.selectedLayerID, selected)
        XCTAssertFalse(document.isDocumentEdited); XCTAssertFalse(document.undoManager!.canUndo)
        let board = NSPasteboard(name: .init(UUID().uuidString)); defer { board.releaseGlobally() }
        var inputs: [ImageInput] = []; canvas.importImages = { inputs = $0 }
        board.setData(asset.data, forType: .png); canvas.paste(from: board)
        XCTAssertEqual(inputs.count, 1)
        guard case .clipboard(let data, _) = inputs[0] else { XCTFail("Did not route clipboard image"); return }
        XCTAssertEqual(data, asset.data)
        board.clearContents(); board.writeObjects([fixture("grid-corners.png") as NSURL]); canvas.paste(from: board)
        guard case .file(let url) = inputs[0] else { XCTFail("Did not route file URL"); return }
        XCTAssertEqual(url, fixture("grid-corners.png"))
        // Changing tabs during a render must never present the old document's bitmap.
        let white = PhotoDocument(model: try PhotoDocumentModel(name: "White", canvas: CanvasSize(width: 80, height: 80), ppi: 72, background: .white))
        canvas.display(white, pipeline: pipeline); canvas.zoom(to: 1)
        let deadline = Date().addingTimeInterval(5)
        while canvas.presentedViewport != white.viewport && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(canvas.presentedViewport, white.viewport)
        let image = try XCTUnwrap(canvas.metal.image)
        try assertColor(image, x: image.width / 2, y: image.height / 2, red: 1, green: 1, blue: 1)
        let expectedOrigin = white.viewport.transform.viewPoint(fromDocument: .init(x: 0, y: 0))
        XCTAssertEqual(canvas.overlay.rectangle.minX, expectedOrigin.x, accuracy: 1e-8)
        XCTAssertEqual(canvas.overlay.rectangle.minY, expectedOrigin.y, accuracy: 1e-8)
        try png(image, name: "latest-tab-render.png")
    }
}

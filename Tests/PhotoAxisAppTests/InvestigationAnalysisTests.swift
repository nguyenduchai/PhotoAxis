import XCTest
import AppKit
import ImageIO
import Vision
import CoreML
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class InvestigationAnalysisTests: XCTestCase {
    func fixture(_ name: String) -> URL { Bundle(for: Self.self).resourceURL!.appendingPathComponent("P17/" + name) }
    func context() throws -> (InvestigationCaseStore, DocumentCoordinator) {
        let root = (0..<5).reduce(Bundle.main.bundleURL) { url, _ in url.deletingLastPathComponent() }.appendingPathComponent("investigation2-tests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let coordinator = DocumentCoordinator(localization: L10n(choice: .vietnamese), recoveryRoot: root.appendingPathComponent("recovery"))
        let store = try InvestigationCaseStore(root: root.appendingPathComponent("Test.paxcase"), creating: InvestigationCase(code: "INV2", title: "Synthetic investigation 2", examiner: "Tester"), appVersion: "test")
        return (store, coordinator)
    }
    func image(_ store: InvestigationCaseStore, _ coordinator: DocumentCoordinator) async throws -> EvidenceItem {
        try await store.importFile(fixture("ocr-tieng-viet.png"), intake: EvidenceIntake(source: "Synthetic fixture", receiver: "Test"), pipeline: coordinator.pipeline, projects: coordinator.projectStore)
    }
    func testOCRComputeUsesOnlyRequestSupportedCPUDevices() throws {
        let request = VNRecognizeTextRequest(); request.revision = VNRecognizeTextRequestRevision3; request.recognitionLevel = .accurate
        let supported = try request.supportedComputeStageDevices
        let count = try InvestigationAnalysisEngine.configureTextCompute(request)
        XCTAssertGreaterThan(count,0)
        for (stage, devices) in supported where devices.contains(where: { if case .cpu = $0 { return true }; return false }) {
            guard case .cpu? = request.computeDevice(for:stage) else { XCTFail("Expected supported CPU compute device"); continue }
        }
    }
    func testVietnameseOCRSourceROIRecognitionConfirmationAndPersistentRevisions() async throws {
        let (store, coordinator) = try context(), item = try await image(store, coordinator)
        let record = try await store.recognize(item.id, region: .init(x: 40, y: 20, width: 1520, height: 450), pipeline: coordinator.pipeline, projects: coordinator.projectStore)
        XCTAssertTrue(record.language.hasPrefix("vi-")); XCTAssertTrue(record.recognizedText.contains("ĐIỀU TRA"), record.recognizedText)
        XCTAssertTrue(record.recognizedText.contains("tiếng Việt"), record.recognizedText)
        XCTAssertFalse(record.recognizedText.contains("NGOÀI VÙNG")); XCTAssertTrue(record.confirmations.isEmpty)
        let originalModel = try store.item(item.id).currentModelJSON, original = try Data(contentsOf: store.originalURL(item))
        try store.confirmOCR(record.id, text: "Bản người thử xác nhận — phần không đọc được để trống")
        try store.confirmOCR(record.id, text: "Bản xác nhận lần hai")
        let value = try InvestigationCase.decode(Data(contentsOf: store.manifestURL)), saved = try XCTUnwrap(value.analysis?.ocr.first)
        XCTAssertEqual(value.formatVersion, 2); XCTAssertEqual(saved.recognizedText, record.recognizedText)
        XCTAssertEqual(saved.confirmations.count, 2); XCTAssertEqual(saved.confirmations.last?.text, "Bản xác nhận lần hai")
        XCTAssertEqual(try store.item(item.id).currentModelJSON, originalModel); XCTAssertEqual(try Data(contentsOf: store.originalURL(item)), original)
        XCTAssertEqual(value.events.suffix(3).map(\.payload.operation), ["ocrRecognized", "ocrConfirmed", "ocrConfirmed"])
        try record.validate()
    }
    func testUnsupportedVietnameseOCRHasExplicitFailureAndNeverSubstitutesEnglish() throws {
        XCTAssertThrowsError(try InvestigationAnalysisEngine.vietnameseLanguage(supported: ["en-US", "fr-FR"])) { XCTAssertEqual($0 as? InvestigationError, .ocrUnavailable) }
        XCTAssertEqual(try InvestigationAnalysisEngine.vietnameseLanguage(supported: ["en-US", "vi-VT"]), "vi-VT")
    }
    func testOCRReceiptFailureKeepsPreviousConfirmationAndManifest() async throws {
        let (store, coordinator) = try context(), item = try await image(store, coordinator)
        let record = try await store.recognize(item.id, region: .init(x: 40, y: 20, width: 1520, height: 180), pipeline: coordinator.pipeline, projects: coordinator.projectStore)
        let before = try Data(contentsOf: store.manifestURL)
        store.beforeManifestCommit = { throw POSIXError(.ENOSPC) }
        XCTAssertThrowsError(try store.confirmOCR(record.id, text: "Must not persist"))
        XCTAssertEqual(try Data(contentsOf: store.manifestURL), before); XCTAssertTrue(store.value.analysis!.ocr[0].confirmations.isEmpty)
    }
    func testOriginalVideoBytesAndVariableRateFrameOrdinalExactPTSAndTrackRotation() async throws {
        let (store, coordinator) = try context(), source = fixture("video-vfr-rotated.mov")
        let video = try await store.importVideo(source, intake: EvidenceIntake(source: "Synthetic VFR"))
        XCTAssertEqual(try Data(contentsOf: store.videoURL(video)), try Data(contentsOf: source))
        XCTAssertEqual(video.sha256, InvestigationDigest.hash(try Data(contentsOf: source)))
        XCTAssertEqual(video.encodedSize, try CanvasSize(width: 320, height: 200))
        let item = try await store.extractFrame(video.id, index: 2, offset: 5, reason: "Thử lệch đồng hồ", pipeline: coordinator.pipeline, projects: coordinator.projectStore)
        let frame = try XCTUnwrap(store.value.analysis?.frames.first)
        XCTAssertEqual(frame.frameIndex, 2); XCTAssertEqual(frame.presentationTime.seconds, 0.350, accuracy: 0.000001)
        XCTAssertEqual(frame.correctedRelativeSeconds, 5.350, accuracy: 0.000001)
        XCTAssertEqual(frame.videoSHA256, video.sha256); XCTAssertEqual(frame.frameSHA256, item.originalSHA256)
        XCTAssertEqual(try item.model.canvas, try CanvasSize(width: 200, height: 320))
        let snapshot = try await store.intakeSnapshot(item.id, projects: coordinator.projectStore)
        let cg = try await coordinator.pipeline.normalizedImage(snapshot.assets[item.workingSourceSHA256]!)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!, pixel = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        pixel.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let rgba = pixel.data!.assumingMemoryBound(to: UInt8.self)
        // Lossy H.264 and video-to-sRGB conversion need not preserve literal RGB bytes.
        // Dominant blue identifies sample2; a red/green/yellow frame fails this oracle.
        XCTAssertGreaterThan(rgba[2], 200); XCTAssertGreaterThan(Int(rgba[2]) - Int(rgba[0]), 170); XCTAssertGreaterThan(Int(rgba[2]) - Int(rgba[1]), 170)
        let persisted = try InvestigationCase.decode(Data(contentsOf: store.manifestURL)); XCTAssertEqual(persisted.analysis?.frames[0].presentationTime, frame.presentationTime)
        XCTAssertTrue(String(decoding: try store.analysisBytes(), as: UTF8.self).contains("timeOffsetSeconds"))
    }
    func testVideoOutOfRangeMissingOffsetReasonAndOriginalMutationRefuseExtraction() async throws {
        let (store, coordinator) = try context(), video = try await store.importVideo(fixture("video-vfr-rotated.mov"), intake: EvidenceIntake())
        let before = try Data(contentsOf: store.manifestURL)
        for (index, offset, reason) in [(99, 0.0, ""), (0, 10.0, "")] {
            do { _ = try await store.extractFrame(video.id, index: index, offset: offset, reason: reason, pipeline: coordinator.pipeline, projects: coordinator.projectStore); XCTFail("Invalid frame accepted") } catch {}
        }
        XCTAssertEqual(try Data(contentsOf: store.manifestURL), before); XCTAssertTrue(store.value.items.isEmpty)
        let url = store.videoURL(video); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path); try Data("tampered".utf8).write(to: url)
        do { _ = try await store.extractFrame(video.id, index: 0, offset: 0, reason: "", pipeline: coordinator.pipeline, projects: coordinator.projectStore); XCTFail("Tampered video accepted") } catch { XCTAssertEqual(error as? InvestigationError, .integrity) }
    }
    func testVideoFailedIntakeCommitRollsBackNewOriginalAndAnalysis() async throws {
        let (store, _) = try context(), before = try Data(contentsOf: store.manifestURL)
        store.beforeManifestCommit = { throw POSIXError(.ENOSPC) }
        do { _ = try await store.importVideo(fixture("video-vfr-rotated.mov"), intake: EvidenceIntake()); XCTFail("Failed receipt accepted") } catch {}
        XCTAssertEqual(try Data(contentsOf: store.manifestURL), before); XCTAssertNil(store.value.analysis)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: store.root.appendingPathComponent("originals").path).isEmpty)
    }
    func testCalibrationMeasureStalenessAndReceiptRollbackWithoutChangingPixels() async throws {
        let (store, coordinator) = try context(), item = try await image(store, coordinator), initial = item.currentModelJSON
        let c = try EvidenceCalibration(itemID: item.id, originalSHA256: item.originalSHA256, modelSHA256: InvestigationDigest.hash(initial), canvas: item.model.canvas, reference: [.init(x: 10, y: 10), .init(x: 110, y: 10)], knownLength: 10, unit: .cm, assumption: "Thước phẳng, chụp thẳng", operatorName: "Test")
        try store.addCalibration(c)
        XCTAssertEqual(try store.measure(calibrationID: c.id, kind: .distance, points: [.init(x: 10, y: 10), .init(x: 310, y: 410)]).result, 50)
        XCTAssertEqual(try store.item(item.id).currentModelJSON, initial)
        let before = try Data(contentsOf: store.manifestURL); store.beforeManifestCommit = { throw POSIXError(.ENOSPC) }
        XCTAssertThrowsError(try store.measure(calibrationID: c.id, kind: .area, points: [.init(x: 10,y: 10), .init(x: 110,y: 10), .init(x: 110,y: 110), .init(x: 10,y: 110)]))
        XCTAssertEqual(try Data(contentsOf: store.manifestURL), before); XCTAssertEqual(store.value.analysis?.measurements.count, 1)
        store.beforeManifestCommit = nil
        var edited = try item.model; try edited.rename(edited.layers[0].id, to: "Changed")
        try store.commitModel(item.id, operation: "rename", before: item.model, after: edited)
        XCTAssertThrowsError(try store.measure(calibrationID: c.id, kind: .distance, points: [.init(x: 10,y: 10), .init(x: 110,y: 10)])) { XCTAssertEqual($0 as? InvestigationError, .staleCalibration) }
        let value = try InvestigationCase.decode(Data(contentsOf: store.manifestURL)); XCTAssertEqual(value.analysis?.measurements[0].result, 50)
    }
    func testAnalysisTamperingIsRejectedAndExportContainsSeparateRawAndConfirmedText() async throws {
        let (store, coordinator) = try context(), item = try await image(store, coordinator)
        let record = try await store.recognize(item.id, region: .init(x: 40,y: 20,width: 1520,height: 180), pipeline: coordinator.pipeline, projects: coordinator.projectStore)
        try store.confirmOCR(record.id, text: "Confirmed")
        var value = store.value; value.analysis!.ocr[0].confirmations.append(.init(text: "Forged", operatorName: "Test"))
        XCTAssertThrowsError(try value.validate()) { XCTAssertEqual($0 as? InvestigationError, .integrity) }
        let data = try store.analysisBytes(), json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("Confirmed")); XCTAssertTrue(json.contains("HỒ SƠ")); XCTAssertTrue(json.contains("region")); XCTAssertTrue(json.contains("ledgerSHA256"))
        let output = store.root.deletingLastPathComponent().appendingPathComponent("analysis.json"); try await InvestigationSharing.write(data, to: output)
        XCTAssertEqual(try Data(contentsOf: output), data)
        XCTAssertThrowsError(try store.protectDestination(store.manifestURL))
    }
    func testNativeOCRReviewKeepsRawReadOnlyAndSavesExplicitUserEdit() async throws {
        let (store, coordinator) = try context(), item = try await image(store, coordinator)
        let record = try await store.recognize(item.id, region: .init(x: 40,y: 20,width: 1520,height: 180), pipeline: coordinator.pipeline, projects: coordinator.projectStore)
        let snapshot = try await store.intakeSnapshot(item.id, projects: coordinator.projectStore), cg = try await coordinator.pipeline.normalizedImage(snapshot.assets[item.workingSourceSHA256]!)
        for choice in [InterfaceLanguage.vietnamese, .english] {
            let review = InvestigationReviewPanel(localization: L10n(choice: choice), title: "Review", image: cg, sourceSize: record.sourceSize, summary: "ROI", regions: [record.region], recognized: record.recognizedText, confirmedText: record.recognizedText, onConfirm: { try store.confirmOCR(record.id, text: $0) })
            review.confirmed.string = "Human review \(choice)"; review.confirmText()
            XCTAssertEqual(store.value.analysis?.ocr[0].confirmations.last?.text, review.confirmed.string)
            XCTAssertEqual(store.value.analysis?.ocr[0].recognizedText, record.recognizedText)
            XCTAssertTrue(review.status.stringValue.contains(choice == .vietnamese ? "Đã lưu" : "saved"))
            XCTAssertNil(review.window)
        }
    }
}

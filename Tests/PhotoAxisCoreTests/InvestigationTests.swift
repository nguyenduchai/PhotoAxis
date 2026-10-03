import XCTest
@testable import PhotoAxisCore

final class InvestigationTests: XCTestCase {
    func testLegacySchemaAndCaseBoundSchemaAreDistinctAndRoundTrip() throws {
        var model = try PhotoDocumentModel(name: "Ảnh điều tra", canvas: CanvasSize(width: 100, height: 80), ppi: 72)
        let legacy = try ProjectSchema(model).encoded()
        XCTAssertEqual(try ProjectSchema.decode(legacy).formatVersion, 1)
        XCTAssertFalse(String(decoding: legacy, as: UTF8.self).contains("investigation"))
        let reference = InvestigationReference(caseID: UUID(), itemID: model.id); model.investigation = reference
        let caseSchema = ProjectSchema(model), bytes = try caseSchema.encoded()
        XCTAssertEqual(caseSchema.formatVersion, 2)
        XCTAssertEqual(try ProjectSchema.decode(bytes).model(), model)
        var invalid = caseSchema; invalid.formatVersion = 1
        XCTAssertThrowsError(try invalid.model())
        invalid.investigation = nil; invalid.formatVersion = 2; XCTAssertThrowsError(try invalid.model())
        invalid.investigation = .init(caseID: reference.caseID, itemID: UUID()); XCTAssertThrowsError(try invalid.model())
    }
    func testCaseLedgerChecksMetadataSequenceAndHashLinks() throws {
        var value = InvestigationCase(code: "HS-01", title: "Hồ sơ thử", examiner: "Người lập thử")
        try value.record(operation: "caseCreated", details: ["source": "fixture"], appVersion: "test")
        let bytes = try value.encoded()
        XCTAssertEqual(try InvestigationCase.decode(bytes).events.count, 1)
        value.title = "Tên đã bị thay bên ngoài"
        XCTAssertThrowsError(try value.validate()) { XCTAssertEqual($0 as? InvestigationError, .integrity) }
        var data = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        var events = try XCTUnwrap(data["events"] as? [[String: Any]])
        var payload = try XCTUnwrap(events[0]["payload"] as? [String: Any]); payload["operation"] = "forged"
        events[0]["payload"] = payload; data["events"] = events
        XCTAssertThrowsError(try InvestigationCase.decode(JSONSerialization.data(withJSONObject: data)))
    }
    func testAnnotationPiecesRemainTypedSourcesAndClipsArePreserved() throws {
        var model = try PhotoDocumentModel(name: "Typed", canvas: CanvasSize(width: 320, height: 240), ppi: 72)
        let source = SourceDescriptor(id: String(repeating: "a", count: 64), size: try CanvasSize(width: 320, height: 240))
        let image = try model.place(source, name: "Nguồn", above: nil)
        try model.crop(to: .init(x: 20, y: 20, width: 240, height: 180), output: CanvasSize(width: 240, height: 180))
        let clipped = try XCTUnwrap(model.layer(image)), text = TextContent(text: "1", fontName: "Helvetica", fontSize: 20, color: .black)
        for kind in [InvestigationAnnotation.arrow, .ellipse, .number, .label] {
            _ = try model.addInvestigationAnnotation(kind, region: .init(x: 30, y: 30, width: 50, height: 40), text: text, name: "Dấu vết 1")
        }
        let ids = try model.addInvestigationAnnotation(.magnifier, region: .init(x: 30, y: 30, width: 50, height: 40), text: text, name: "Chi tiết nguồn", sourceLayerID: image)
        let inset = try XCTUnwrap(model.layer(ids[0]))
        XCTAssertEqual(inset.content, clipped.content); XCTAssertEqual(Array(inset.clip.dropLast()), clipped.clip)
        XCTAssertEqual(model.sources.count, 1); XCTAssertEqual(model.layer(image), clipped)
        XCTAssertTrue(model.layers.contains { if case .text = $0.content { return true }; return false })
        _ = try ProjectSchema.decode(ProjectSchema(model).encoded()).model()
    }
    func testRegionBoundsRejectOverflowAndOffCanvas() throws {
        let canvas = try CanvasSize(width: 100, height: 80)
        for r in [EvidenceRegion(x: Int.max, y: 0, width: 1, height: 1), .init(x: 90, y: 0, width: 11, height: 1), .init(x: 0, y: -1, width: 1, height: 1), .init(x: 0, y: 0, width: 0, height: 1)] {
            XCTAssertThrowsError(try r.validate(in: canvas))
        }
        XCTAssertNoThrow(try EvidenceRegion(x: 99, y: 79, width: 1, height: 1).validate(in: canvas))
    }
    func testCaseJSONRejectsDeepNestingAndDuplicateKeysBeforeDecode() throws {
        let deep = Data((String(repeating: "[", count: 25) + "0" + String(repeating: "]", count: 25)).utf8)
        XCTAssertThrowsError(try InvestigationCase.decode(deep))
        let duplicate = Data("{\"formatVersion\":1,\"formatVersion\":1}".utf8)
        XCTAssertThrowsError(try InvestigationCase.decode(duplicate))
    }
}

extension InvestigationTests {
    func calibration() throws -> EvidenceCalibration {
        try EvidenceCalibration(itemID: UUID(), originalSHA256: String(repeating: "a", count: 64), modelSHA256: String(repeating: "b", count: 64), canvas: CanvasSize(width: 100, height: 80), reference: [.init(x: 0, y: 0), .init(x: 10, y: 0)], knownLength: 20, unit: .cm, assumption: "Thước cùng mặt phẳng, ảnh chụp thẳng", operatorName: "Kiểm thử")
    }
    func testCalibratedDistanceAndConcaveAreaWithReversedWinding() throws {
        let c = try calibration()
        let d = try EvidenceMeasurement(calibration: c, kind: .distance, points: [.init(x: 0, y: 0), .init(x: 3, y: 4)], operatorName: "Test")
        XCTAssertEqual(d.result, 10)
        let points = [Point2D(x: 0, y: 0), .init(x: 10, y: 0), .init(x: 10, y: 10), .init(x: 5, y: 5), .init(x: 0, y: 10)]
        XCTAssertEqual(try EvidenceMeasurement(calibration: c, kind: .area, points: points, operatorName: "Test").result, 300)
        XCTAssertEqual(try EvidenceMeasurement(calibration: c, kind: .area, points: points.reversed(), operatorName: "Test").result, 300)
    }
    func testMeasurementRejectsSelfIntersectionDegenerateAndNonfinitePoints() throws {
        let c = try calibration()
        for points in [[Point2D(x: 0, y: 0), .init(x: 10, y: 10), .init(x: 0, y: 10), .init(x: 10, y: 0)], [.init(x: 0, y: 0), .init(x: 10, y: 0), .init(x: 20, y: 0)], [.init(x: 0, y: 0), .init(x: .nan, y: 5), .init(x: 20, y: 0)], [.init(x: 0, y: 0), .init(x: 101, y: 0), .init(x: 0, y: 10)]] {
            XCTAssertThrowsError(try EvidenceMeasurement(calibration: c, kind: .area, points: points, operatorName: "Test"))
        }
        XCTAssertThrowsError(try EvidenceMeasurement(calibration: c, kind: .distance, points: [.init(x: 0, y: 0), .init(x: 0, y: 0)], operatorName: "Test"))
    }
    func testCalibrationRequiresKnownScaleAndExplicitGeometryBasis() throws {
        let c = try calibration()
        for (points, length, assumption) in [([Point2D(x: 0,y: 0), .init(x: 0,y: 0)], 10.0, "ok"), (c.reference, 0.0, "ok"), (c.reference, Double.infinity, "ok"), (c.reference, 10.0, " ")] {
            XCTAssertThrowsError(try EvidenceCalibration(itemID: c.itemID, originalSHA256: c.originalSHA256, modelSHA256: c.modelSHA256, canvas: c.canvas, reference: points, knownLength: length, unit: .mm, assumption: assumption, operatorName: "Test"))
        }
    }
    func testExactMediaTimeAndOffsetNeverReplaceOriginalPTS() throws {
        let pts = try EvidenceMediaTime(value: 1001, timescale: 30000)
        let f = EvidenceVideoFrame(videoID: UUID(), itemID: UUID(), videoSHA256: String(repeating: "a", count: 64), frameSHA256: String(repeating: "b", count: 64), trackID: 1, frameIndex: 42, presentationTime: pts, timeOffsetSeconds: -3, offsetReason: "Đồng hồ camera lệch")
        try f.validate(); XCTAssertEqual(f.presentationTime.value, 1001); XCTAssertEqual(f.correctedRelativeSeconds, 1001.0 / 30000 - 3)
        XCTAssertThrowsError(try EvidenceMediaTime(value: 1, timescale: 0))
        let invalid = EvidenceVideoFrame(videoID: f.videoID, itemID: f.itemID, videoSHA256: f.videoSHA256, frameSHA256: f.frameSHA256, trackID: 1, frameIndex: 42, presentationTime: pts, timeOffsetSeconds: 5, offsetReason: "")
        XCTAssertThrowsError(try invalid.validate())
    }
    func testVersionOneDigestSurvivesAndVersionTwoAnalysisIsIntegrityBound() throws {
        var value = InvestigationCase(code: "Old", title: "Legacy", examiner: "Test")
        try value.record(operation: "caseCreated", appVersion: "Investigation 1")
        let old = try value.encoded(), decoded = try InvestigationCase.decode(old)
        XCTAssertEqual(try decoded.encoded(), old); XCTAssertNil(decoded.analysis)
        XCTAssertFalse(String(decoding: old, as: UTF8.self).contains("analysis"))
        value.analysis = InvestigationAnalysis(); XCTAssertThrowsError(try value.validate())
        value.formatVersion = 2; try value.record(operation: "extensionActivated", appVersion: "Investigation 2")
        let upgraded = try value.encoded(); XCTAssertEqual(try InvestigationCase.decode(upgraded).formatVersion, 2)
        value.analysis = nil; XCTAssertThrowsError(try value.validate())
    }
}

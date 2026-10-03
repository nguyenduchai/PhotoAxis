import Foundation

/// Analysis is an optional v2 extension. Nil is omitted when encoding v1 cases,
/// preserving the byte-canonical state digest of existing Investigation 1 cases.
public struct InvestigationAnalysis: Codable, Sendable {
    public var ocr: [EvidenceOCR] = []
    public var videos: [EvidenceVideo] = []
    public var frames: [EvidenceVideoFrame] = []
    public var calibrations: [EvidenceCalibration] = []
    public var measurements: [EvidenceMeasurement] = []
    public init() {}
    public func validate(items: [EvidenceItem]) throws {
        guard ocr.count <= 100, videos.count <= 20, frames.count <= 100, calibrations.count <= 100, measurements.count <= 500 else { throw InvestigationError.limit }
        let itemMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for record in ocr {
            guard let item = itemMap[record.itemID], record.originalSHA256 == item.originalSHA256, record.sourceSHA256 == item.workingSourceSHA256 else { throw InvestigationError.integrity }
            try record.validate()
        }
        for video in videos { try video.validate() }
        guard Set(videos.map(\.id)).count == videos.count, Set(ocr.map(\.id)).count == ocr.count,
              Set(frames.map(\.itemID)).count == frames.count, Set(calibrations.map(\.id)).count == calibrations.count,
              Set(measurements.map(\.id)).count == measurements.count else { throw InvestigationError.invalidCase }
        for frame in frames {
            guard let item = itemMap[frame.itemID], let video = videos.first(where: { $0.id == frame.videoID }),
                  frame.videoSHA256 == video.sha256, frame.frameSHA256 == item.originalSHA256,
                  frame.trackID == video.trackID else { throw InvestigationError.integrity }
            try frame.validate()
        }
        for calibration in calibrations {
            guard let item = itemMap[calibration.itemID], calibration.originalSHA256 == item.originalSHA256 else { throw InvestigationError.integrity }
            try calibration.validate()
        }
        for measurement in measurements {
            guard let calibration = calibrations.first(where: { $0.id == measurement.calibrationID }), itemMap[calibration.itemID] != nil else { throw InvestigationError.invalidCase }
            try measurement.validate(calibration: calibration)
        }
    }
}

public struct EvidenceOCRLine: Codable, Equatable, Sendable {
    public let text: String
    public let confidence: Double
    public let region: EvidenceRegion
    public init(text: String, confidence: Double, region: EvidenceRegion) { self.text = text; self.confidence = confidence; self.region = region }
}
public struct EvidenceOCRConfirmation: Codable, Sendable {
    public let text, operatorName, recordedAt: String
    public init(text: String, operatorName: String) { self.text = text; self.operatorName = operatorName; recordedAt = InvestigationDigest.timestamp() }
}
public struct EvidenceOCR: Codable, Sendable {
    public let id, itemID: UUID
    public let originalSHA256, sourceSHA256, language, engine, operatingSystem, recordedAt: String
    public let revision: Int
    public let sourceSize: CanvasSize
    public let region: EvidenceRegion
    public let lines: [EvidenceOCRLine]
    public var confirmations: [EvidenceOCRConfirmation] = []
    public init(itemID: UUID, originalSHA256: String, sourceSHA256: String, language: String, revision: Int,
                sourceSize: CanvasSize, region: EvidenceRegion, lines: [EvidenceOCRLine], operatingSystem: String) {
        id = UUID(); self.itemID = itemID; self.originalSHA256 = originalSHA256; self.sourceSHA256 = sourceSHA256
        self.language = language; self.revision = revision; self.sourceSize = sourceSize; self.region = region; self.lines = lines
        engine = "Apple Vision / accurate / languageCorrection=false"; self.operatingSystem = operatingSystem; recordedAt = InvestigationDigest.timestamp()
    }
    public var recognizedText: String { lines.map(\.text).joined(separator: "\n") }
    public func validate() throws {
        guard [originalSHA256, sourceSHA256].allSatisfy(ProjectSchema.isSourceID), language.hasPrefix("vi-"), language.utf8.count <= 128,
              revision > 0, revision <= 100, engine.utf8.count <= 256, operatingSystem.utf8.count <= 256, recordedAt.utf8.count <= 128,
              lines.count <= 500, recognizedText.utf8.count <= 65_536, confirmations.count <= 100 else { throw InvestigationError.invalidCase }
        try region.validate(in: sourceSize)
        for line in lines {
            try line.region.validate(in: sourceSize)
            guard line.confidence.isFinite, (0...1).contains(line.confidence), !line.text.isEmpty,
                  line.region.x >= region.x, line.region.y >= region.y,
                  line.region.x + line.region.width <= region.x + region.width,
                  line.region.y + line.region.height <= region.y + region.height else { throw InvestigationError.invalidCase }
        }
        for confirmation in confirmations {
            guard confirmation.text.utf8.count <= 65_536, confirmation.operatorName.utf8.count <= 4096, confirmation.recordedAt.utf8.count <= 128 else { throw InvestigationError.limit }
        }
    }
}

/// Exact media time; no nominal-FPS calculation or wall-clock claim.
public struct EvidenceMediaTime: Codable, Equatable, Sendable {
    public let value: Int64
    public let timescale: Int32
    public init(value: Int64, timescale: Int32) throws {
        self.value = value; self.timescale = timescale; try validate()
    }
    public var seconds: Double { Double(value) / Double(timescale) }
    public func validate() throws { guard timescale > 0, seconds.isFinite, abs(seconds) <= 315_576_000 else { throw InvestigationError.invalidCase } }
}
public struct EvidenceVideo: Codable, Sendable {
    public let id: UUID
    public let originalName, sha256, importedAt, metadataJSON: String
    public let byteCount: Int
    public let intake: EvidenceIntake
    public let trackID: Int32
    public let duration: EvidenceMediaTime
    public let encodedSize: CanvasSize
    public let preferredTransform: [Double]
    public init(originalName: String, sha256: String, byteCount: Int, intake: EvidenceIntake, trackID: Int32,
                duration: EvidenceMediaTime, encodedSize: CanvasSize, preferredTransform: [Double], metadataJSON: String) {
        id = UUID(); self.originalName = originalName; self.sha256 = sha256; self.byteCount = byteCount; self.intake = intake
        self.trackID = trackID; self.duration = duration; self.encodedSize = encodedSize; self.preferredTransform = preferredTransform; self.metadataJSON = metadataJSON
        importedAt = InvestigationDigest.timestamp()
    }
    public var containerExtension: String { URL(fileURLWithPath: originalName).pathExtension.lowercased() }
    public func validate() throws {
        try intake.validate(); try duration.validate()
        guard ["mov", "mp4", "m4v"].contains(containerExtension), originalName.utf8.count <= 4096, ProjectSchema.isSourceID(sha256), (1...InvestigationCase.maximumOriginalBytes).contains(byteCount),
              duration.seconds > 0, importedAt.utf8.count <= 128, metadataJSON.utf8.count <= 262_144,
              preferredTransform.count == 6, preferredTransform.allSatisfy(\.isFinite),
              abs(preferredTransform[0] * preferredTransform[3] - preferredTransform[1] * preferredTransform[2]) > 1e-12 else { throw InvestigationError.invalidCase }
    }
}
public struct EvidenceVideoFrame: Codable, Sendable {
    public let videoID, itemID: UUID
    public let videoSHA256, frameSHA256: String
    public let trackID: Int32
    /// Zero-based ordinal of decoded presentation samples in the selected track.
    public let frameIndex: Int
    public let presentationTime: EvidenceMediaTime
    public let timeOffsetSeconds: Double
    public let offsetReason: String
    public let extractedAt: String
    public init(videoID: UUID, itemID: UUID, videoSHA256: String, frameSHA256: String, trackID: Int32, frameIndex: Int,
                presentationTime: EvidenceMediaTime, timeOffsetSeconds: Double, offsetReason: String) {
        self.videoID = videoID; self.itemID = itemID; self.videoSHA256 = videoSHA256; self.frameSHA256 = frameSHA256
        self.trackID = trackID; self.frameIndex = frameIndex; self.presentationTime = presentationTime
        self.timeOffsetSeconds = timeOffsetSeconds; self.offsetReason = offsetReason; extractedAt = InvestigationDigest.timestamp()
    }
    public var correctedRelativeSeconds: Double { presentationTime.seconds + timeOffsetSeconds }
    public func validate() throws {
        try presentationTime.validate()
        guard [videoSHA256, frameSHA256].allSatisfy(ProjectSchema.isSourceID), (0..<100_000).contains(frameIndex),
              timeOffsetSeconds.isFinite, abs(timeOffsetSeconds) <= 315_576_000, correctedRelativeSeconds.isFinite,
              offsetReason.utf8.count <= 4096, extractedAt.utf8.count <= 128,
              timeOffsetSeconds == 0 || !offsetReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw InvestigationError.invalidCase }
    }
}

public enum EvidenceUnit: String, Codable, CaseIterable, Sendable { case mm, cm, m }
public struct EvidenceCalibration: Codable, Sendable {
    public let id, itemID: UUID
    public let originalSHA256, modelSHA256, assumption, operatorName, recordedAt: String
    public let canvas: CanvasSize
    public let reference: [Point2D]
    public let knownLength: Double
    public let unit: EvidenceUnit
    public init(itemID: UUID, originalSHA256: String, modelSHA256: String, canvas: CanvasSize, reference: [Point2D],
                knownLength: Double, unit: EvidenceUnit, assumption: String, operatorName: String) throws {
        id = UUID(); self.itemID = itemID; self.originalSHA256 = originalSHA256; self.modelSHA256 = modelSHA256; self.canvas = canvas
        self.reference = reference; self.knownLength = knownLength; self.unit = unit; self.assumption = assumption
        self.operatorName = operatorName; recordedAt = InvestigationDigest.timestamp(); try validate()
    }
    public var unitsPerPixel: Double { knownLength / hypot(reference[1].x - reference[0].x, reference[1].y - reference[0].y) }
    public func validate() throws {
        guard [originalSHA256, modelSHA256].allSatisfy(ProjectSchema.isSourceID), reference.count == 2,
              knownLength.isFinite, knownLength > 0, knownLength <= 1e9,
              !assumption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, assumption.utf8.count <= 4096,
              operatorName.utf8.count <= 4096, recordedAt.utf8.count <= 128 else { throw InvestigationError.invalidCase }
        try EvidenceMeasurement.validatePoints(reference, canvas: canvas)
        guard hypot(reference[1].x - reference[0].x, reference[1].y - reference[0].y) >= 1, unitsPerPixel.isFinite else { throw InvestigationError.invalidCase }
    }
}
public enum EvidenceMeasurementKind: String, Codable, CaseIterable, Sendable { case distance, area }
public struct EvidenceMeasurement: Codable, Sendable {
    public let id, calibrationID: UUID
    public let kind: EvidenceMeasurementKind
    public let points: [Point2D]
    public let result: Double
    public let operatorName, recordedAt: String
    public init(calibration: EvidenceCalibration, kind: EvidenceMeasurementKind, points: [Point2D], operatorName: String) throws {
        id = UUID(); calibrationID = calibration.id; self.kind = kind; self.points = points; self.operatorName = operatorName; recordedAt = InvestigationDigest.timestamp()
        result = try Self.calculate(calibration: calibration, kind: kind, points: points); try validate(calibration: calibration)
    }
    public static func validatePoints(_ points: [Point2D], canvas: CanvasSize) throws {
        guard (2...64).contains(points.count), points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.x >= 0 && $0.y >= 0 && $0.x <= Double(canvas.width) && $0.y <= Double(canvas.height) }),
              Set(points.map { "\($0.x),\($0.y)" }).count == points.count else { throw InvestigationError.invalidCase }
    }
    public static func calculate(calibration: EvidenceCalibration, kind: EvidenceMeasurementKind, points: [Point2D]) throws -> Double {
        try calibration.validate(); try validatePoints(points, canvas: calibration.canvas)
        let scale = calibration.unitsPerPixel
        if kind == .distance {
            guard points.count == 2 else { throw InvestigationError.invalidCase }
            return hypot(points[1].x - points[0].x, points[1].y - points[0].y) * scale
        }
        guard points.count >= 3 else { throw InvestigationError.invalidCase }
        func cross(_ a: Point2D, _ b: Point2D, _ c: Point2D) -> Double { (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) }
        func intersects(_ a: Point2D, _ b: Point2D, _ c: Point2D, _ d: Point2D) -> Bool {
            let abC = cross(a,b,c), abD = cross(a,b,d), cdA = cross(c,d,a), cdB = cross(c,d,b)
            if abC * abD < 0 && cdA * cdB < 0 { return true }
            func on(_ p: Point2D, _ q: Point2D, _ r: Point2D, _ v: Double) -> Bool { abs(v) < 1e-8 && r.x >= min(p.x,q.x) && r.x <= max(p.x,q.x) && r.y >= min(p.y,q.y) && r.y <= max(p.y,q.y) }
            return on(a,b,c,abC) || on(a,b,d,abD) || on(c,d,a,cdA) || on(c,d,b,cdB)
        }
        for i in points.indices {
            let a = points[i], b = points[(i + 1) % points.count]
            for j in points.indices where j > i && j != (i + 1) % points.count && (j + 1) % points.count != i {
                if intersects(a,b,points[j],points[(j + 1) % points.count]) { throw InvestigationError.invalidCase }
            }
        }
        var twiceArea = 0.0
        for i in points.indices { let a = points[i], b = points[(i + 1) % points.count]; twiceArea += a.x * b.y - b.x * a.y }
        let area = abs(twiceArea) * 0.5 * scale * scale
        guard area.isFinite, area > 1e-12 else { throw InvestigationError.invalidCase }; return area
    }
    public func validate(calibration: EvidenceCalibration) throws {
        guard calibrationID == calibration.id, result.isFinite, result == (try Self.calculate(calibration: calibration, kind: kind, points: points)),
              operatorName.utf8.count <= 4096, recordedAt.utf8.count <= 128 else { throw InvestigationError.integrity }
    }
}

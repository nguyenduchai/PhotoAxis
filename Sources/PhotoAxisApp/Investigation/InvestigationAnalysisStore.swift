import Foundation
import CryptoKit
import Darwin
import PhotoAxisCore

extension InvestigationFiles {
    /// Stream from a single stable descriptor; do not load a whole movie in RAM.
    static func captureVideo(_ source: URL, stage: URL) throws -> (String, Int) {
        let fd = open(source.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw InvestigationError.videoUnavailable }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true); defer { try? handle.close() }
        var before = stat(), hash = SHA256(), count = 0
        guard fstat(fd, &before) == 0, before.st_mode & S_IFMT == S_IFREG, before.st_size > 0, before.st_size <= InvestigationCase.maximumOriginalBytes else { throw InvestigationError.limit }
        try AtomicFile.write(to: stage) { destination in
            while let block = try handle.read(upToCount: 1_048_576), !block.isEmpty {
                try Task.checkCancellation(); count += block.count; guard count <= InvestigationCase.maximumOriginalBytes else { throw InvestigationError.limit }
                hash.update(data: block); try destination.write(contentsOf: block)
            }
            var after = stat()
            guard count == before.st_size, fstat(fd, &after) == 0, before.st_size == after.st_size,
                  before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec, before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
                  before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec, before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else { throw InvestigationError.integrity }
        }
        return (hash.finalize().map { String(format: "%02x", $0) }.joined(), count)
    }
}

extension InvestigationCaseStore {
    func mutateAnalysis(_ operation: String, itemID: UUID? = nil, details: [String: String] = [:], change: (inout InvestigationAnalysis) throws -> Void) throws {
        try mutate(operation, itemID: itemID, details: details) { value in
            value.formatVersion = 2
            if value.analysis == nil { value.analysis = InvestigationAnalysis() }
            try change(&value.analysis!)
        }
    }
    func intakeSnapshot(_ id: UUID, projects: ProjectStore) async throws -> ProjectSnapshot {
        let item = try item(id); try await verifyOriginal(item)
        let hash = item.intakeWorkingFileSHA256 ?? item.workingFileSHA256, url = archiveURL(id, hash: hash)
        guard try await Task.detached(operation: { try InvestigationFiles.hashFile(url) }).value == hash else { throw InvestigationError.integrity }
        let snapshot = try await projects.open(url)
        guard snapshot.assets[item.workingSourceSHA256] != nil else { throw InvestigationError.integrity }; return snapshot
    }
    func recognize(_ id: UUID, region: EvidenceRegion, pipeline: ImagePipeline, projects: ProjectStore) async throws -> EvidenceOCR {
        let item = try item(id), snapshot = try await intakeSnapshot(id, projects: projects)
        guard let source = snapshot.assets[item.workingSourceSHA256] else { throw InvestigationError.integrity }
        let image = try await pipeline.normalizedImage(source)
        let record = try await OCRExecution.run { cancellation in
            try InvestigationAnalysisEngine.recognize(image:image,item:item,region:region,cancellation:cancellation)
        }
        try Task.checkCancellation()
        try mutateAnalysis("ocrRecognized", itemID: id, details: ["ocrID": record.id.uuidString, "sourceSHA256": record.sourceSHA256,
                                                                  "language": record.language, "computePolicy": "CPU where supported", "region": String(decoding: try InvestigationDigest.encode(region), as: UTF8.self)]) { $0.ocr.append(record) }
        return record
    }
    func confirmOCR(_ recordID: UUID, text: String) throws {
        guard let record = value.analysis?.ocr.first(where: { $0.id == recordID }) else { throw InvestigationError.invalidCase }
        let confirmation = EvidenceOCRConfirmation(text: text, operatorName: value.examiner)
        try mutateAnalysis("ocrConfirmed", itemID: record.itemID, details: ["ocrID": recordID.uuidString, "recognizedSHA256": InvestigationDigest.hash(Data(record.recognizedText.utf8)),
                                                                           "confirmedSHA256": InvestigationDigest.hash(Data(text.utf8))]) { analysis in
            let i = analysis.ocr.firstIndex { $0.id == recordID }!; analysis.ocr[i].confirmations.append(confirmation)
        }
    }
    func videoURL(_ video: EvidenceVideo) -> URL { root.appendingPathComponent("originals/" + video.sha256 + "." + video.containerExtension) }
    func verifyVideo(_ video: EvidenceVideo) async throws {
        try verifyManifest(); let url = videoURL(video)
        guard try await Task.detached(operation: { try InvestigationFiles.hashFile(url, limit: InvestigationCase.maximumOriginalBytes) }).value == video.sha256 else { throw InvestigationError.integrity }
    }
    func importVideo(_ url: URL, intake: EvidenceIntake) async throws -> EvidenceVideo {
        try verifyManifest(); try intake.validate()
        guard ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased()), (value.analysis?.videos.count ?? 0) < 20 else { throw InvestigationError.videoUnavailable }
        let stage = root.appendingPathComponent("originals/.video-" + UUID().uuidString + "." + url.pathExtension.lowercased())
        defer { _ = unlink(stage.path) }
        let capture = try await Task.detached { try InvestigationFiles.captureVideo(url, stage: stage) }.value
        let video = try await Task.detached { try await InvestigationAnalysisEngine.inspectVideo(stage, name: url.lastPathComponent, sha256: capture.0, byteCount: capture.1, intake: intake) }.value
        let total = value.items.reduce(Int64(0), { $0 + Int64($1.originalByteCount) }) + (value.analysis?.videos.reduce(Int64(0), { $0 + Int64($1.byteCount) }) ?? 0)
        guard total <= 10_737_418_240 - Int64(video.byteCount) else { throw InvestigationError.limit }
        let destination = videoURL(video); try InvestigationFiles.directory(destination.deletingLastPathComponent())
        var created = false, committed = false
        defer { if created && !committed { try? FileManager.default.removeItem(at: destination) } }
        if FileManager.default.fileExists(atPath: destination.path) {
            guard try InvestigationFiles.hashFile(destination, limit: InvestigationCase.maximumOriginalBytes) == video.sha256 else { throw InvestigationError.integrity }
        } else {
            guard rename(stage.path, destination.path) == 0 else { throw POSIXError(.EIO) }; created = true
            guard chmod(destination.path, 0o444) == 0 else { throw POSIXError(.EIO) }
        }
        try mutateAnalysis("videoIntake", details: ["videoID": video.id.uuidString, "sha256": video.sha256, "originalName": video.originalName]) { $0.videos.append(video) }
        committed = true; return video
    }
    func extractFrame(_ videoID: UUID, index: Int, offset: Double, reason: String, pipeline: ImagePipeline, projects: ProjectStore) async throws -> EvidenceItem {
        guard let video = value.analysis?.videos.first(where: { $0.id == videoID }), offset.isFinite, abs(offset) <= 315_576_000,
              reason.utf8.count <= 4096, offset == 0 || !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw InvestigationError.invalidCase }
        try await verifyVideo(video)
        let url = videoURL(video)
        let frame = try await Task.detached { try await InvestigationAnalysisEngine.frame(url, video: video, index: index) }.value
        try await verifyVideo(video)
        let stage = root.appendingPathComponent("projects/frame-\(index)-" + UUID().uuidString + ".png")
        defer { _ = unlink(stage.path) }
        try await InvestigationSharing.write(frame.png, to: stage)
        return try await importFile(stage, intake: video.intake, pipeline: pipeline, projects: projects, frame: (video, index, frame.presentationTime, offset, reason))
    }
    func addCalibration(_ calibration: EvidenceCalibration) throws {
        let item = try item(calibration.itemID)
        guard calibration.modelSHA256 == InvestigationDigest.hash(item.currentModelJSON), calibration.canvas == (try item.model.canvas) else { throw InvestigationError.staleCalibration }
        try mutateAnalysis("measurementCalibrated", itemID: item.id, details: ["calibrationID": calibration.id.uuidString]) { $0.calibrations.append(calibration) }
    }
    func measure(calibrationID: UUID, kind: EvidenceMeasurementKind, points: [Point2D]) throws -> EvidenceMeasurement {
        guard let calibration = value.analysis?.calibrations.first(where: { $0.id == calibrationID }) else { throw InvestigationError.invalidCase }
        let item = try item(calibration.itemID)
        guard calibration.modelSHA256 == InvestigationDigest.hash(item.currentModelJSON) else { throw InvestigationError.staleCalibration }
        let result = try EvidenceMeasurement(calibration: calibration, kind: kind, points: points, operatorName: value.examiner)
        try mutateAnalysis("measurementRecorded", itemID: item.id, details: ["measurementID": result.id.uuidString, "calibrationID": calibrationID.uuidString]) { $0.measurements.append(result) }
        return result
    }
    /// Sensitive trace data: never describe this JSON as a redacted sharing image.
    func analysisBytes() throws -> Data {
        try verifyManifest(); try value.validate()
        struct Export: Encodable {
            let formatIdentifier = "photoaxis.investigation-analysis"
            let formatVersion = 1
            struct ItemState: Encodable { let itemID: UUID; let originalSHA256, currentModelSHA256: String }
            let caseID: UUID; let code, title, ledgerSHA256: String
            let currentItems: [ItemState]
            let analysis: InvestigationAnalysis
        }
        return try InvestigationDigest.encode(Export(caseID: value.id, code: value.code, title: value.title, ledgerSHA256: value.events.last!.sha256, currentItems: value.items.map { Export.ItemState(itemID: $0.id, originalSHA256: $0.originalSHA256, currentModelSHA256: InvestigationDigest.hash($0.currentModelJSON)) }, analysis: value.analysis ?? InvestigationAnalysis()))
    }
}

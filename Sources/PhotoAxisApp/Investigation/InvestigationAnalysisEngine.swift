import Foundation
import Vision
import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore

/// All recognition and decoding runs on a worker. No network or generative model.
enum InvestigationAnalysisEngine {
    static func vietnameseLanguage(supported: [String]) throws -> String {
        guard let language = supported.first(where: { $0.hasPrefix("vi-") }) else { throw InvestigationError.ocrUnavailable }
        return language
    }
    static func ocrLanguage() throws -> String {
        let request = VNRecognizeTextRequest(); request.revision = VNRecognizeTextRequestRevision3; request.recognitionLevel = .accurate
        return try vietnameseLanguage(supported: request.supportedRecognitionLanguages())
    }
    static func recognize(image: CGImage, item: EvidenceItem, region: EvidenceRegion) throws -> EvidenceOCR {
        let size = try CanvasSize(width: image.width, height: image.height); try region.validate(in: size)
        guard let crop = image.cropping(to: CGRect(x: region.x, y: region.y, width: region.width, height: region.height)) else { throw InvestigationError.invalidCase }
        let request = VNRecognizeTextRequest(); request.revision = VNRecognizeTextRequestRevision3; request.recognitionLevel = .accurate
        let language = try vietnameseLanguage(supported: request.supportedRecognitionLanguages())
        request.recognitionLanguages = [language]; request.usesLanguageCorrection = false; request.automaticallyDetectsLanguage = false
        try Task.checkCancellation(); try VNImageRequestHandler(cgImage: crop, options: [:]).perform([request]); try Task.checkCancellation()
        let lines = (request.results ?? []).compactMap { observation -> EvidenceOCRLine? in
            guard let candidate = observation.topCandidates(1).first, !candidate.string.isEmpty else { return nil }
            let box = observation.boundingBox
            let x = max(0, min(region.width - 1, Int(floor(box.minX * Double(region.width)))))
            let y = max(0, min(region.height - 1, Int(floor((1 - box.maxY) * Double(region.height)))))
            let right = max(x + 1, min(region.width, Int(ceil(box.maxX * Double(region.width)))))
            let bottom = max(y + 1, min(region.height, Int(ceil((1 - box.minY) * Double(region.height)))))
            return EvidenceOCRLine(text: candidate.string, confidence: Double(candidate.confidence), region: EvidenceRegion(x: region.x + x, y: region.y + y, width: right - x, height: bottom - y))
        }.sorted { $0.region.y == $1.region.y ? $0.region.x < $1.region.x : $0.region.y < $1.region.y }
        let record = EvidenceOCR(itemID: item.id, originalSHA256: item.originalSHA256, sourceSHA256: item.workingSourceSHA256,
                                 language: language, revision: request.revision, sourceSize: size, region: region, lines: lines,
                                 operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString)
        try record.validate(); return record
    }
    static func asset(_ url: URL) throws -> AVURLAsset {
        guard url.isFileURL else { throw InvestigationError.videoUnavailable }
        return AVURLAsset(url: url, options: [AVURLAssetReferenceRestrictionsKey: AVAssetReferenceRestrictions.forbidAll.rawValue,
                                             AVURLAssetPreferPreciseDurationAndTimingKey: true])
    }
    static func time(_ value: CMTime) throws -> EvidenceMediaTime {
        guard value.isNumeric, value.epoch == 0 else { throw InvestigationError.videoUnavailable }
        return try EvidenceMediaTime(value: value.value, timescale: value.timescale)
    }
    static func inspectVideo(_ url: URL, name: String, sha256: String, byteCount: Int, intake: EvidenceIntake) async throws -> EvidenceVideo {
        let asset = try asset(url), tracks = try await asset.loadTracks(withMediaType: .video)
        // A single video track removes ambiguity over which stream/frame is used.
        guard tracks.count == 1, let track = tracks.first else { throw InvestigationError.videoUnavailable }
        let (duration, naturalSize, transform, rate) = try await (asset.load(.duration), track.load(.naturalSize), track.load(.preferredTransform), track.load(.nominalFrameRate))
        guard naturalSize.width.isFinite, naturalSize.height.isFinite, naturalSize.width > 0, naturalSize.height > 0,
              naturalSize.width <= 8000, naturalSize.height <= 8000 else { throw InvestigationError.limit }
        let size = try CanvasSize(width: Int(naturalSize.width.rounded(.up)), height: Int(naturalSize.height.rounded(.up)))
        let matrix = [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty].map { Double($0) }
        struct Metadata: Encodable { let nominalFrameRate: Float; let trackID: Int32; let duration: EvidenceMediaTime; let encodedSize: CanvasSize; let preferredTransform: [Double] }
        let mediaTime = try time(duration)
        let metadata = Metadata(nominalFrameRate: rate, trackID: track.trackID, duration: mediaTime, encodedSize: size, preferredTransform: matrix)
        let result = EvidenceVideo(originalName: name, sha256: sha256, byteCount: byteCount, intake: intake, trackID: track.trackID,
                                   duration: mediaTime, encodedSize: size, preferredTransform: matrix, metadataJSON: String(decoding: try InvestigationDigest.encode(metadata), as: UTF8.self))
        try result.validate(); return result
    }
    struct DecodedFrame: Sendable { let png: Data; let presentationTime: EvidenceMediaTime; let size: CanvasSize }
    static func frame(_ url: URL, video: EvidenceVideo, index: Int) async throws -> DecodedFrame {
        guard (0..<100_000).contains(index) else { throw InvestigationError.limit }
        let asset = try asset(url), tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first(where: { $0.trackID == video.trackID }) else { throw InvestigationError.videoUnavailable }
        let transform = try await track.load(.preferredTransform)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw InvestigationError.videoUnavailable }; reader.add(output)
        guard reader.startReading() else { throw InvestigationError.videoUnavailable }; defer { reader.cancelReading() }
        let started = ContinuousClock.now
        var ordinal = 0, lastPTS: CMTime?
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard started.duration(to: .now) < .seconds(120) else { throw InvestigationError.limit }
            guard CMSampleBufferGetNumSamples(sample) > 0 else { continue }
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)
            _ = try time(pts)
            if let lastPTS, CMTimeCompare(pts, lastPTS) < 0 { throw InvestigationError.videoUnavailable }; lastPTS = pts
            guard let pixels = CMSampleBufferGetImageBuffer(sample) else { throw InvestigationError.videoUnavailable }
            let width = CVPixelBufferGetWidth(pixels), height = CVPixelBufferGetHeight(pixels)
            _ = try CanvasSize(width: width, height: height)
            guard width == video.encodedSize.width, height == video.encodedSize.height else { throw InvestigationError.videoUnavailable }
            if ordinal == index {
                // AV track matrices use top-left coordinates. Convert from CI's
                // bottom-left, apply the track matrix, then return to bottom-left.
                var image = CIImage(cvPixelBuffer: pixels).transformed(by: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: Double(height))).transformed(by: transform)
                var extent = image.extent.integral
                guard !extent.isInfinite, !extent.isNull, extent.width.isFinite, extent.height.isFinite,
                      extent.width > 0, extent.height > 0, extent.width <= 8000, extent.height <= 8000 else { throw InvestigationError.limit }
                let size = try CanvasSize(width: Int(extent.width), height: Int(extent.height))
                image = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
                image = image.transformed(by: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: extent.height))
                extent = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                let context = CIContext(options: [.cacheIntermediates: false])
                guard let srgb = CGColorSpace(name: CGColorSpace.sRGB), let cg = context.createCGImage(image, from: extent, format: .RGBA8, colorSpace: srgb) else { throw InvestigationError.videoUnavailable }
                let bytes = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil) else { throw InvestigationError.videoUnavailable }
                CGImageDestinationAddImage(destination, cg, nil)
                guard CGImageDestinationFinalize(destination), bytes.length <= InvestigationCase.maximumOriginalBytes else { throw InvestigationError.limit }
                return DecodedFrame(png: bytes as Data, presentationTime: try time(pts), size: size)
            }
            ordinal += 1
        }
        throw InvestigationError.videoUnavailable
    }
}

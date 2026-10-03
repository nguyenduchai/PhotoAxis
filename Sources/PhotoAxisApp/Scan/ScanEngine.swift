import Foundation
import Vision
import CoreGraphics
import PhotoAxisCore

enum ScanError: Error, Equatable { case noPage, noTextAngle, invalidOptions, tooManyFiles }

struct ScanRecipe: Sendable {
    var settings = ScanSettings()
    var quad: PerspectiveQuad?
    var degrees = 0.0
    var size: CanvasSize?
    var ppi = 300.0
    func candidate(_ original: PhotoDocumentModel, layerID: UUID) throws -> PhotoDocumentModel {
        guard ppi.isFinite, (36...1200).contains(ppi) else { throw ScanError.invalidOptions }
        var result = original
        try result.setScan(layerID, settings)
        if let quad { try quad.validate(in: result.canvas); try result.perspectiveCrop(quad, output: quad.outputSize(.auto(swapped: false))) }
        try result.deskewScan(degrees: degrees)
        if let size { try result.normalizeScan(to: size, ppi: ppi) }
        else { try result.imageSize(result.canvas, ppi: ppi) }
        return result
    }
}

actor ScanDetector {
    struct Page: Sendable { let quad: PerspectiveQuad; let confidence: Float }
    struct Analysis: Sendable {
        let recipe: ScanRecipe
        let pageConfidence: Float?
        let warnings: [String]
    }
    func analyze(_ recipe: ScanRecipe, image: CGImage, canvas: CanvasSize, autoPage: Bool, autoDeskew: Bool) throws -> Analysis {
        var result = recipe; result.quad = nil
        var confidence: Float?, warnings: [String] = []
        if autoPage {
            do { let page = try page(in:image,canvas:canvas); result.quad = page.quad; confidence = page.confidence }
            catch ScanError.noPage { warnings.append("page-not-detected") }
        }
        if autoDeskew, result.quad == nil, abs(result.degrees) < 0.001 {
            do { result.degrees = try deskew(in:image) }
            catch ScanError.noTextAngle { warnings.append("text-angle-not-detected") }
        }
        return Analysis(recipe:result,pageConfidence:confidence,warnings:warnings)
    }
    func page(in image: CGImage, canvas: CanvasSize) throws -> Page {
        let request = VNDetectRectanglesRequest()
        request.revision = VNDetectRectanglesRequestRevision1
        request.maximumObservations = 8; request.minimumConfidence = 0.6
        request.minimumSize = 0.3; request.minimumAspectRatio = 0.3; request.maximumAspectRatio = 1
        request.quadratureTolerance = 35
        try Task.checkCancellation()
        try VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([request])
        try Task.checkCancellation()
        let candidates = (request.results ?? []).filter { $0.boundingBox.width*$0.boundingBox.height >= 0.2 }
        func score(_ item: VNRectangleObservation) -> Double { Double(item.boundingBox.width*item.boundingBox.height) * Double(item.confidence) }
        guard let observation = candidates.max(by: { score($0) < score($1) }) else { throw ScanError.noPage }
        let corners: [CGPoint] = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
        let points: [Point2D] = corners.map { corner in
            let x = Double(corner.x)*Double(canvas.width), y = (1-Double(corner.y))*Double(canvas.height)
            return Point2D(x: min(Double(canvas.width), max(0,x)), y: min(Double(canvas.height), max(0,y)))
        }
        let quad = PerspectiveQuad(points)
        try quad.validate(in: canvas)
        return Page(quad: quad, confidence: observation.confidence)
    }
    /// Text baselines, not OCR transcription. Refuse too few/disagreeing lines.
    func deskew(in image: CGImage) throws -> Double {
        let request = VNDetectTextRectanglesRequest(); request.reportCharacterBoxes = false
        try Task.checkCancellation()
        try VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([request])
        try Task.checkCancellation()
        let angles = (request.results ?? []).compactMap { observation -> Double? in
            let dx = (observation.topRight.x-observation.topLeft.x)*Double(image.width)
            let dy = (observation.topRight.y-observation.topLeft.y)*Double(image.height)
            guard dx > Double(image.width)*0.1 else { return nil }
            let angle = atan2(dy, dx)*180 / .pi
            return abs(angle) <= 15 ? angle : nil
        }.sorted()
        guard angles.count >= 3 else { throw ScanError.noTextAngle }
        let median = angles[angles.count/2]
        let agreed = angles.filter { abs($0-median) <= 2 }
        guard agreed.count >= 3, agreed.count*2 >= angles.count else { throw ScanError.noTextAngle }
        return agreed.reduce(0,+)/Double(agreed.count)
    }
}

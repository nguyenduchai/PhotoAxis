import Foundation
import CoreImage
import CoreGraphics
import Vision
import PhotoAxisCore

/// Serial, bounded raster work. Output patches are opaque, preventing the original
/// lower layer from showing through a blurred alpha channel.
actor PrivacyEngine {
    private let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!,
                                              .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, .cacheIntermediates: false])
    private let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    func patch(image: CGImage, region: EvidenceRegion, style: PrivacyStyle, strength: Double) throws -> CGImage {
        try region.validate(in: CanvasSize(width: image.width, height: image.height))
        guard strength.isFinite, (1...100).contains(strength) else { throw DocumentError.invalidValue }
        try Task.checkCancellation()
        let rect = CGRect(x: region.x, y: image.height - region.y - region.height, width: region.width, height: region.height)
        let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: rect)
        var local = CIImage(cgImage: image).cropped(to: rect).composited(over: white)
        switch style {
        case .cover: local = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: rect)
        case .blur:
            let radius = max(2, Double(min(region.width, region.height)) * strength / 500)
            local = local.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius]).cropped(to: rect)
        case .pixelate:
            let scale = max(4, Double(min(region.width, region.height)) * strength / 250)
            local = local.clampedToExtent().applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: scale,
                kCIInputCenterKey: CIVector(x: rect.midX, y: rect.midY)]).cropped(to: rect)
        }
        guard let result = context.createCGImage(local, from: rect, format: .RGBA8, colorSpace: srgb) else { throw ImageImportError.unreadable }
        try Task.checkCancellation(); return result
    }
    func preview(image: CGImage, modelSize: CanvasSize, regions: [EvidenceRegion], style: PrivacyStyle, strength: Double) throws -> CGImage {
        guard regions.count <= 20 else { throw DocumentError.resourceLimit }
        let canvas = try ContentRasterizer.context(CanvasSize(width: image.width, height: image.height))
        canvas.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        canvas.setBlendMode(.copy); canvas.interpolationQuality = .none
        for region in regions {
            try region.validate(in: modelSize)
            let sx = Double(image.width) / Double(modelSize.width), sy = Double(image.height) / Double(modelSize.height)
            let left = Int(floor(Double(region.x) * sx)), top = Int(floor(Double(region.y) * sy))
            let right = min(image.width, Int(ceil(Double(region.x + region.width) * sx)))
            let bottom = min(image.height, Int(ceil(Double(region.y + region.height) * sy)))
            let scaled = EvidenceRegion(x: left, y: top, width: right - left, height: bottom - top)
            let masked = try patch(image: image, region: scaled, style: style, strength: strength)
            canvas.draw(masked, in: CGRect(x: left, y: image.height - bottom, width: scaled.width, height: scaled.height))
        }
        guard let result = canvas.makeImage() else { throw ImageImportError.unreadable }; return result
    }
    func patches(image: CGImage, regions: [EvidenceRegion], style: PrivacyStyle, strength: Double, ppi: Double) throws -> [PrivacyPatch] {
        guard !regions.isEmpty, regions.count <= 20 else { throw DocumentError.invalidValue }
        return try regions.map { region in
            try Task.checkCancellation(); try region.validate(in: CanvasSize(width: image.width, height: image.height))
            if style == .cover { return PrivacyPatch(region: region, asset: nil) }
            let output = try patch(image: image, region: region, style: style, strength: strength)
            let bytes = try InvestigationSharing.pngBytes(output, ppi: ppi)
            let source = SourceDescriptor(id: ImagePipeline.digest(bytes), size: try CanvasSize(width: region.width, height: region.height))
            return PrivacyPatch(region: region, asset: EmbeddedImage(descriptor: source, data: bytes, name: style.rawValue, ppi: ppi, convertedToSDR: false))
        }
    }
    static func faceRegions(boxes: [CGRect], size: CanvasSize) throws -> [EvidenceRegion] {
        guard boxes.count <= 20 else { throw DocumentError.resourceLimit }
        return try boxes.map { box in
            guard [box.minX, box.minY, box.width, box.height].allSatisfy(\.isFinite), box.width > 0, box.height > 0 else { throw DocumentError.invalidValue }
            let padded = box.insetBy(dx: -box.width * 0.12, dy: -box.height * 0.18).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard !padded.isNull, !padded.isEmpty else { throw DocumentError.invalidValue }
            let x = max(0, Int(floor(padded.minX * Double(size.width))))
            let y = max(0, Int(floor((1 - padded.maxY) * Double(size.height))))
            let right = min(size.width, Int(ceil(padded.maxX * Double(size.width))))
            let bottom = min(size.height, Int(ceil((1 - padded.minY) * Double(size.height))))
            let region = EvidenceRegion(x: x, y: y, width: right - x, height: bottom - y)
            try region.validate(in: size); return region
        }
    }
    func faces(image: CGImage, modelSize: CanvasSize) throws -> [EvidenceRegion] {
        try Task.checkCancellation()
        let request = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        try Task.checkCancellation()
        return try Self.faceRegions(boxes: (request.results ?? []).map(\.boundingBox), size: modelSize)
    }
}

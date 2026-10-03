import Foundation
import CoreImage
import PhotoAxisCore

/// Kernels are loaded once per image worker; no full-size CPU pixel copy.
final class ScanFilters {
    private let clean: CIColorKernel
    private let curve: CIWarpKernel
    init() throws {
        guard let url = Bundle.main.url(forResource: "Perspective", withExtension: "metallib") else { throw ImageImportError.unreadable }
        let library = try Data(contentsOf: url)
        clean = try CIColorKernel(functionName: "photoAxisScan", fromMetalLibraryData: library)
        curve = try CIWarpKernel(functionName: "photoAxisScanCurve", fromMetalLibraryData: library)
    }
    func apply(_ settings: ScanSettings, to image: CIImage) throws -> CIImage {
        try settings.validate()
        guard settings.enabled else { return image }
        let extent = image.extent
        var smooth = image
        if settings.denoise > 0 {
            smooth = smooth.clampedToExtent().applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": settings.denoise*0.1, "inputSharpness": 0.0]).cropped(to: extent)
        }
        let background = smooth.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: ["inputRadius": max(3, min(160, min(extent.width, extent.height)*settings.radius))]).cropped(to: extent)
        let mode = settings.mode == .color ? 0.0 : settings.mode == .gray ? 1.0 : 2.0
        guard var output = clean.apply(extent: extent, arguments: [image, smooth, background, settings.paper, settings.threshold, mode]) else { throw ImageImportError.unreadable }
        if settings.sharpness > 0, settings.mode != .blackWhite {
            output = output.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: ["inputRadius": 1.0, "inputIntensity": settings.sharpness]).cropped(to: extent)
        }
        if settings.curveX != 0 || settings.curveY != 0 {
            guard let warped = curve.apply(extent: extent, roiCallback: { _, _ in extent }, image: output,
                                           arguments: [extent.width, extent.height, settings.curveX, settings.curveY]) else { throw ImageImportError.unreadable }
            output = warped
        }
        return output.cropped(to: extent)
    }
}

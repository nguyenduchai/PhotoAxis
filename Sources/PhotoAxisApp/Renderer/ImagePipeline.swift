import Foundation
import ImageIO
import CoreImage
import Metal
import CryptoKit
import UniformTypeIdentifiers
import PhotoAxisCore

enum ImageImportError: Error, Equatable {
    case unreadable, unsupported, multipleImages, layerLimit, sourceLimit
    case resizeRequired(width: Int, height: Int, proposedWidth: Int, proposedHeight: Int)
    var key: String {
        switch self {
        case .unreadable: "import.unreadable"
        case .unsupported: "import.unsupported"
        case .multipleImages: "import.multipleImages"
        case .layerLimit: "import.layerLimit"
        case .sourceLimit: "import.sourceLimit"
        case .resizeRequired: "import.resizeRequired"
        }
    }
}

struct EmbeddedImage: Sendable {
    let descriptor: SourceDescriptor
    let data: Data
    let name: String
    let ppi: Double
    let convertedToSDR: Bool
}

enum ImageInput: Sendable {
    case file(URL)
    case clipboard(Data, name: String)
    var name: String {
        switch self { case .file(let url): url.lastPathComponent; case .clipboard(_, let name): name }
    }
}

struct ImportBudget: Sendable {
    var remainingPixels = DocumentLimits.maximumUniqueSourcePixels
    var knownSources: Set<String> = []
    var layerCount = 0
}

/// Image I/O, color conversion, decoded cache and preview evaluation share one worker.
/// No NSView or mutable document crosses this boundary. Cache is at most 256 MiB;
/// temporary decode/output buffers live only for one serial operation.
actor ImagePipeline {
    private let context: CIContext
    private var perspectiveKernel:CIWarpKernel?
    private var scanFilters: ScanFilters?
    private let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    private var cache: [String: CGImage] = [:]
    private var lru: [String] = []
    private(set) var cacheBytes = 0
    private(set) var normalizedDecodeCount = 0
    static let cacheLimit = 256 * 1024 * 1024

    init() {
        let options: [CIContextOption: Any] = [.workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!,
            .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, .cacheIntermediates: false]
        if let device = MTLCreateSystemDefaultDevice() { context = CIContext(mtlDevice: device, options: options) }
        else { context = CIContext(options: options) }
    }

    static func reducedSize(width: Int, height: Int, pixelBudget: Int) throws -> CanvasSize {
        guard width > 0, height > 0, pixelBudget > 0 else { throw ImageImportError.sourceLimit }
        let pixels = Double(width) * Double(height)
        let ratio = min(1, min(8000 / Double(max(width, height)), sqrt(Double(min(40_000_000, pixelBudget)) / pixels)))
        return try CanvasSize(width: max(1, Int(floor(Double(width) * ratio))), height: max(1, Int(floor(Double(height) * ratio))))
    }

    func prepare(_ input: ImageInput, budget: ImportBudget, allowResize: Bool = false) throws -> EmbeddedImage {
        try Task.checkCancellation()
        guard budget.layerCount < DocumentLimits.maximumLayers else { throw ImageImportError.layerLimit }
        let source: CGImageSource
        let originalData: Data
        let isClipboard: Bool
        switch input {
        case .file(let url):
            let unsupportedExtensions: Set<String> = ["pdf", "svg", "psd", "psb", "raw", "dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2", "gif", "tif", "tiff", "paxis"]
            if unsupportedExtensions.contains(url.pathExtension.lowercased()) { throw ImageImportError.unsupported }
            // Probe dimensions/type from the file before reading bytes or decoding pixels.
            guard let probe = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw ImageImportError.unreadable }
            try validateType(probe, clipboard: false)
            let header = try metadata(probe)
            let bounded = try Self.reducedSize(width: header.width, height: header.height, pixelBudget: DocumentLimits.maximumPixels)
            if bounded.width != header.width || bounded.height != header.height {
                guard allowResize else {
                    throw ImageImportError.resizeRequired(width: header.width, height: header.height,
                        proposedWidth: bounded.width, proposedHeight: bounded.height)
                }
                // A consented oversized source is downsampled from the URL; never copy
                // its full encoded payload into the document just to discard it later.
                originalData = Data(); source = probe
            } else {
                // An owned byte copy is essential: a mapped file could change underneath
                // an embedded layer if another application rewrites the original file.
                originalData = try Data(contentsOf: url)
                source = try imageSource(originalData)
            }
            isClipboard = false
        case .clipboard(let data, _): originalData = data; source = try imageSource(data); isClipboard = true
        }
        try validateType(source, clipboard: isClipboard)
        let info = try metadata(source)
        let originalID = Self.digest(originalData)
        let available = budget.knownSources.contains(originalID) ? DocumentLimits.maximumPixels : budget.remainingPixels
        let proposed = try Self.reducedSize(width: info.width, height: info.height, pixelBudget: available)
        let reduced = proposed.width != info.width || proposed.height != info.height
        if reduced && !allowResize {
            throw ImageImportError.resizeRequired(width: info.width, height: info.height, proposedWidth: proposed.width, proposedHeight: proposed.height)
        }
        try Task.checkCancellation()
        let hasGainMap = hasHDRGainMap(source)
        let decodeOptions: [CFString: Any] = [kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: false, kCGImageSourceDecodeRequest: kCGImageSourceDecodeToSDR]
        let decoded: CGImage?
        if reduced {
            var options = decodeOptions
            options[kCGImageSourceCreateThumbnailFromImageAlways] = true
            options[kCGImageSourceCreateThumbnailWithTransform] = true
            options[kCGImageSourceThumbnailMaxPixelSize] = max(proposed.width, proposed.height)
            decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        } else { decoded = CGImageSourceCreateImageAtIndex(source, 0, decodeOptions as CFDictionary) }
        guard let decoded, CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else { throw ImageImportError.unreadable }
        try Task.checkCancellation()
        var ci = CIImage(cgImage: decoded, options: [.colorSpace: sourceColorSpace(source, decoded: decoded)])
        if !reduced { ci = ci.oriented(forExifOrientation: Int32(info.orientation)) }
        ci = ci.transformed(by: .init(translationX: -ci.extent.minX, y: -ci.extent.minY))
        // Thumbnail rounding is validated again before any full-size RGBA allocation.
        let size = try CanvasSize(width: Int(ci.extent.width), height: Int(ci.extent.height))
        guard size.pixelCount <= available else { throw ImageImportError.sourceLimit }
        guard let normalized = context.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: srgb) else { throw ImageImportError.unreadable }
        let data: Data
        if reduced || isClipboard {
            let buffer = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(buffer, UTType.png.identifier as CFString, 1, nil) else { throw ImageImportError.unreadable }
            CGImageDestinationAddImage(destination, normalized, nil)
            guard CGImageDestinationFinalize(destination) else { throw ImageImportError.unreadable }
            data = buffer as Data
        } else { data = originalData }
        let id = Self.digest(data)
        insert(normalized, id: id)
        return EmbeddedImage(descriptor: SourceDescriptor(id: id, size: size), data: data,
            name: input.name, ppi: info.ppi, convertedToSDR: info.highDepth || hasGainMap)
    }

    private func sourceColorSpace(_ source: CGImageSource, decoded: CGImage) -> CGColorSpace {
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        if decoded.colorSpace?.model == .rgb, props?[kCGImagePropertyProfileName] == nil { return srgb }
        return decoded.colorSpace ?? srgb
    }
    private func imageSource(_ data: Data) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw ImageImportError.unreadable }
        return source
    }
    private func validateType(_ source: CGImageSource, clipboard: Bool) throws {
        guard let type = CGImageSourceGetType(source) as String?,
              [UTType.png.identifier, UTType.jpeg.identifier, UTType.heic.identifier, UTType.heif.identifier].contains(type)
                || (clipboard && type == UTType.tiff.identifier) else { throw ImageImportError.unsupported }
        guard CGImageSourceGetCount(source) == 1 else { throw ImageImportError.multipleImages }
        let properties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        let png = properties?[kCGImagePropertyPNGDictionary] as? [CFString: Any]
        guard png?[kCGImagePropertyAPNGLoopCount] == nil else { throw ImageImportError.multipleImages }
    }
    private func metadata(_ source: CGImageSource) throws -> (width: Int, height: Int, orientation: Int, ppi: Double, highDepth: Bool) {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = properties[kCGImagePropertyPixelWidth] as? Int, let h = properties[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0 else { throw ImageImportError.unreadable }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        guard (1...8).contains(orientation) else { throw ImageImportError.unreadable }
        let rotated = (5...8).contains(orientation)
        let ppi = properties[kCGImagePropertyDPIWidth] as? Double ?? 72
        let highDepth = (properties[kCGImagePropertyDepth] as? Int ?? 8) > 8
            || (properties[kCGImagePropertyProfileName] as? String ?? "").localizedCaseInsensitiveContains("HLG")
            || (properties[kCGImagePropertyProfileName] as? String ?? "").localizedCaseInsensitiveContains("PQ")
        return (rotated ? h : w, rotated ? w : h, orientation, ppi.isFinite && ppi > 0 ? ppi : 72, highDepth)
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func hasHDRGainMap(_ source: CGImageSource) -> Bool {
        var result = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source,0,kCGImageAuxiliaryDataTypeHDRGainMap) != nil
        if #available(macOS 15, *) { result = result || CGImageSourceCopyAuxiliaryDataInfoAtIndex(source,0,kCGImageAuxiliaryDataTypeISOGainMap) != nil }
        return result
    }
    func validateEmbedded(_ data: Data, descriptor: SourceDescriptor, ppi: Double) throws -> EmbeddedImage {
        guard Self.digest(data) == descriptor.id else { throw ProjectError.assetMismatch }
        let source = try imageSource(data); try validateType(source, clipboard: false)
        let info = try metadata(source)
        guard try CanvasSize(width: info.width, height: info.height) == descriptor.size else { throw ProjectError.assetMismatch }
        return EmbeddedImage(descriptor: descriptor, data: data, name: descriptor.id, ppi: ppi, convertedToSDR: info.highDepth || hasHDRGainMap(source))
    }
    func projectPreview(model: PhotoDocumentModel, assets: [String:EmbeddedImage]) throws -> CGImage {
        let bounds = CGRect(x:0,y:0,width:model.canvas.width,height:model.canvas.height)
        let factor = min(1,512 / Double(max(model.canvas.width,model.canvas.height)))
        let image = try composite(model:model,assets:assets).cropped(to:bounds).transformed(by:.init(scaleX:factor,y:factor))
        let rect = CGRect(x:0,y:0,width:max(1,Int((Double(model.canvas.width)*factor).rounded(.down))),height:max(1,Int((Double(model.canvas.height)*factor).rounded(.down))))
        guard let result = context.createCGImage(image,from:rect,format:.RGBA8,colorSpace:srgb) else { throw ProjectError.invalidDocument }
        return result
    }
    private func insert(_ image: CGImage, id: String) {
        if let old = cache.removeValue(forKey: id) { cacheBytes -= old.bytesPerRow * old.height }
        lru.removeAll { $0 == id }
        let cost = image.bytesPerRow * image.height
        while cacheBytes + cost > Self.cacheLimit, let first = lru.first { remove(first) }
        guard cost <= Self.cacheLimit else { return }
        cache[id] = image; lru.append(id); cacheBytes += cost
    }
    private func remove(_ id: String) {
        if let image = cache.removeValue(forKey: id) { cacheBytes -= image.bytesPerRow * image.height }
        lru.removeAll { $0 == id }
    }
    func retainCache(for ids: Set<String>) { for id in Array(cache.keys) where !ids.contains(id) { remove(id) }; context.clearCaches() }
    func normalizedImage(_ asset: EmbeddedImage) throws -> CGImage {
        if let image = cache[asset.descriptor.id] { lru.removeAll { $0 == asset.descriptor.id }; lru.append(asset.descriptor.id); return image }
        let source = try imageSource(asset.data)
        let info = try metadata(source)
        normalizedDecodeCount += 1
        guard let decoded = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: false, kCGImageSourceDecodeRequest: kCGImageSourceDecodeToSDR] as CFDictionary) else { throw ImageImportError.unreadable }
        var ci = CIImage(cgImage: decoded, options: [.colorSpace: sourceColorSpace(source, decoded: decoded)]).oriented(forExifOrientation: Int32(info.orientation))
        ci = ci.transformed(by: .init(translationX: -ci.extent.minX, y: -ci.extent.minY))
        guard let image = context.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: srgb) else { throw ImageImportError.unreadable }
        insert(image, id: asset.descriptor.id); return image
    }

    func render(model: PhotoDocumentModel, assets: [String: EmbeddedImage], viewport: ViewportState, samplingScale: Double = 1, lightweightClip: Bool = false) throws -> CGImage {
        try Task.checkCancellation()
        guard samplingScale.isFinite, (0.25...1).contains(samplingScale) else { throw ImageImportError.unreadable }
        let w = Int((viewport.width * viewport.backingScale * samplingScale).rounded()), h = Int((viewport.height * viewport.backingScale * samplingScale).rounded())
        _ = try CanvasSize(width: w, height: h)
        let viewportRect = CGRect(x: 0, y: 0, width: w, height: h)
        let canvasRect = CGRect(x: 0, y: 0, width: model.canvas.width, height: model.canvas.height)
        let clipScale = lightweightClip ? min(1,max(1.0/64,viewport.zoom*samplingScale)) : 1
        let composite = try composite(model:model,assets:assets,clipSamplingScale:clipScale)
        let mapping = CGAffineTransform(a: viewport.zoom * samplingScale, b: 0, c: 0, d: viewport.zoom * samplingScale,
            tx: viewport.origin.x * viewport.backingScale * samplingScale,
            ty: ((viewport.height - viewport.origin.y) * viewport.backingScale - Double(model.canvas.height) * viewport.zoom) * samplingScale)
        let visibleCanvas = canvasRect.applying(mapping).intersection(viewportRect)
        let background = CIImage(color: CIColor(red: 30.0/255, green: 30.0/255, blue: 30.0/255)).cropped(to: viewportRect)
        let checker = CIFilter(name: "CICheckerboardGenerator", parameters: ["inputCenter": CIVector(x: 0, y: 0),
            "inputColor0": CIColor(red: 0.65, green: 0.65, blue: 0.65), "inputColor1": CIColor(red: 0.45, green: 0.45, blue: 0.45),
            "inputWidth": 8 * viewport.backingScale * samplingScale, "inputSharpness": 1])!.outputImage!.cropped(to: visibleCanvas)
        let output = composite.cropped(to: canvasRect).transformed(by: mapping)
            .composited(over: checker.composited(over: background)).cropped(to: viewportRect)
        guard let frame = context.createCGImage(output, from: viewportRect, format: .RGBA8, colorSpace: srgb) else { throw ImageImportError.unreadable }
        try Task.checkCancellation()
        return frame
    }

    /// Shared image-only output for pixel validation and the future export path. No checkerboard or overlay.
    func renderDocument(model:PhotoDocumentModel, assets:[String:EmbeddedImage]) throws -> CGImage {
        let rect=CGRect(x:0,y:0,width:model.canvas.width,height:model.canvas.height)
        let image=try composite(model:model,assets:assets).cropped(to:rect)
        guard let result=context.createCGImage(image,from:rect,format:.RGBA8,colorSpace:srgb) else{throw ImageImportError.unreadable}
        return result
    }
    func cloneSnapshot(_ snapshot: ProjectSnapshot, name: String) throws -> EmbeddedImage {
        try Task.checkCancellation()
        let image = try renderDocument(model:snapshot.model,assets:snapshot.assets), buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(buffer,UTType.png.identifier as CFString,1,nil) else { throw ImageImportError.unreadable }
        CGImageDestinationAddImage(destination,image,nil)
        guard CGImageDestinationFinalize(destination) else { throw ImageImportError.unreadable }
        try Task.checkCancellation()
        let data = buffer as Data
        return EmbeddedImage(descriptor:SourceDescriptor(id:Self.digest(data),size:snapshot.model.canvas),data:data,name:name,ppi:snapshot.model.ppi,convertedToSDR:false)
    }
    private func paintImage(_ paint: PaintContent, assets: [String: EmbeddedImage], scale: Double = 1) throws -> CIImage {
        var images: [String: CGImage] = [:]
        for id in paint.sourceIDs {
            guard let asset = assets[id] else { throw DocumentError.missingSource }
            images[id] = try normalizedImage(asset)
        }
        return try PaintRasterizer.image(paint,sources:images,samplingScale:scale)
    }
    /// Shares the full layer graph; preview only changes the evaluation extent.
    func exportImage(snapshot: ProjectSnapshot, options: ExportOptions, previewEdge: Int? = nil) throws -> CGImage {
        try options.validate(); try Task.checkCancellation()
        let model = snapshot.model
        var width = options.size.width, height = options.size.height
        if let previewEdge {
            let factor = min(1,Double(previewEdge)/Double(max(width,height)))
            width = max(1,Int((Double(width)*factor).rounded())); height = max(1,Int((Double(height)*factor).rounded()))
        }
        let rect = CGRect(x:0,y:0,width:width,height:height)
        var image = try composite(model:model,assets:snapshot.assets)
            .cropped(to:CGRect(x:0,y:0,width:model.canvas.width,height:model.canvas.height))
            .transformed(by:.init(scaleX:Double(width)/Double(model.canvas.width),y:Double(height)/Double(model.canvas.height)))
        if options.format == .jpeg || !options.transparency {
            let matte = CIImage(color:CIColor(cgColor:ContentRasterizer.color(options.matte))).cropped(to:rect)
            image = image.composited(over:matte)
        }
        guard let result = context.createCGImage(image,from:rect,format:.RGBA8,colorSpace:srgb) else { throw ImageImportError.unreadable }
        try Task.checkCancellation(); return result
    }
    private func composite(model:PhotoDocumentModel,assets:[String:EmbeddedImage],clipSamplingScale:Double = 1) throws -> CIImage {
        // A document with no visible retained pixels is still a finite, fully
        // transparent canvas. CIImage.empty() cannot create an output CGImage.
        var composite = CIImage(color:CIColor(red:0,green:0,blue:0,alpha:0))
            .cropped(to:CGRect(x:0,y:0,width:model.canvas.width,height:model.canvas.height))
        for layer in model.layers where layer.isVisible {
            try Task.checkCancellation()
            // Fully discarded layers keep their typed source for Undo/editing,
            // but need no text/shape bitmap allocation on subsequent renders.
            guard layer.opacity > 0, layer.clip.allSatisfy({ $0.count >= 3 }) else { continue }
            var local: CIImage
            switch layer.content {
            case .image(let id):
                guard let asset = assets[id] else { throw DocumentError.missingSource }
                local = try AdjustmentFilters.apply(layer.adjustments,to:CIImage(cgImage:try normalizedImage(asset)))
            case .shape(let shape):
                if shape.kind == .rectangle && shape.strokeWidth==0 {
                    local=CIImage(color:CIColor(red:shape.fill.red,green:shape.fill.green,blue:shape.fill.blue,alpha:shape.fill.alpha)).cropped(to:CGRect(x:0,y:0,width:shape.size.width,height:shape.size.height))
                }else{local=CIImage(cgImage:try ContentRasterizer.shapeImage(shape))}
            case .text(let text): local=CIImage(cgImage:try ContentRasterizer.textImage(text))
            case .paint(let paint): local = try paintImage(paint,assets:assets,scale:clipSamplingScale)
            }
            var retainedMask: CIImage?
            if !layer.clip.isEmpty {
                let width=Int(local.extent.width),height=Int(local.extent.height)
                _=try CanvasSize(width:width,height:height)
                let maskWidth = max(1,Int(ceil(Double(width)*clipSamplingScale))), maskHeight = max(1,Int(ceil(Double(height)*clipSamplingScale)))
                guard let mask=CGContext(data:nil,width:maskWidth,height:maskHeight,bitsPerComponent:8,bytesPerRow:maskWidth,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:0) else {throw ImageImportError.unreadable}
                mask.scaleBy(x:Double(maskWidth)/Double(width),y:Double(maskHeight)/Double(height))
                for polygon in layer.clip {
                    mask.beginPath();mask.move(to:CGPoint(x:polygon[0].x,y:Double(height)-polygon[0].y))
                    for p in polygon.dropFirst(){mask.addLine(to:CGPoint(x:p.x,y:Double(height)-p.y))}
                    mask.closePath();mask.clip()
                }
                mask.setFillColor(gray:1,alpha:1);mask.fill(CGRect(x:0,y:0,width:width,height:height))
                guard let image=mask.makeImage() else{throw ImageImportError.unreadable}
                let clipMask = CIImage(cgImage:image).transformed(by:.init(scaleX:Double(width)/Double(maskWidth),y:Double(height)/Double(maskHeight)))
                retainedMask = clipMask
                local=local.applyingFilter("CIBlendWithMask",parameters:["inputBackgroundImage":CIImage.empty(),"inputMaskImage":clipMask])
            }
            if let settings = layer.scan, settings.enabled {
                if scanFilters == nil { scanFilters = try ScanFilters() }
                local = try scanFilters!.apply(settings, to: local)
                // Mask before sampling and afterwards: bow correction cannot
                // resurrect source pixels excluded by a previous crop.
                if let mask = retainedMask { local = local.applyingFilter("CIBlendWithMask", parameters: ["inputBackgroundImage": CIImage.empty(), "inputMaskImage": mask]) }
            }
            let size=try model.localSize(of:layer)
            let mapped:CIImage
            if (try? LayerGeometry.bounds(size:size,transform:layer.transform)) != nil {
                func corner(_ x:Double,_ y:Double)throws->CIVector {
                    let point=try layer.transform.applying(to:.init(x:x,y:y))
                    return CIVector(x:point.x,y:Double(model.canvas.height)-point.y)
                }
                mapped=local.applyingFilter("CIPerspectiveTransform",parameters:[
                    "inputTopLeft":try corner(0,0),"inputTopRight":try corner(Double(size.width),0),
                    "inputBottomRight":try corner(Double(size.width),Double(size.height)),"inputBottomLeft":try corner(0,Double(size.height))])
            } else {
                // A valid crop may leave a pole only in discarded source pixels.
                // Sample backward into the immutable clipped source, bounded by the canvas.
                if perspectiveKernel==nil {
                    guard let url=Bundle.main.url(forResource:"Perspective",withExtension:"metallib") else {throw ImageImportError.unreadable}
                    perspectiveKernel=try CIWarpKernel(functionName:"photoAxisPerspective",fromMetalLibraryData:Data(contentsOf:url))
                }
                let matrix=try layer.transform.inverted().coefficients,scale=matrix.map{abs($0)}.max()!,m=matrix.map{$0/scale}
                let extent=CGRect(x:0,y:0,width:model.canvas.width,height:model.canvas.height),sourceExtent=local.extent
                let args:[Any]=[CIVector(x:m[0],y:m[1],z:m[2]),CIVector(x:m[3],y:m[4],z:m[5]),CIVector(x:m[6],y:m[7],z:m[8]),Double(model.canvas.height),Double(size.height)]
                guard let image=perspectiveKernel?.apply(extent:extent,roiCallback:{_,_ in sourceExtent},image:local,arguments:args) else {throw ImageImportError.unreadable}
                mapped=image
            }
            let visible=mapped.applyingFilter("CIColorMatrix",parameters:["inputAVector":CIVector(x:0,y:0,z:0,w:layer.opacity)])
            composite = visible.composited(over: composite)
        }
        return composite
    }

    func thumbnail(layer: PhotoLayer, assets: [String: EmbeddedImage]) throws -> CGImage? {
        var ci: CIImage
        switch layer.content {
        case .image(let id):
            guard let asset = assets[id] else { return nil }; ci = try AdjustmentFilters.apply(layer.adjustments,to:CIImage(cgImage:try normalizedImage(asset)))
        case .shape(let shape): ci=CIImage(cgImage:try ContentRasterizer.shapeImage(shape))
        case .text(let text): ci=CIImage(cgImage:try ContentRasterizer.textImage(text))
        case .paint(let paint): ci = try paintImage(paint,assets:assets,scale:min(1,64/Double(max(paint.size.width,paint.size.height))))
        }
        if let settings = layer.scan, settings.enabled {
            if scanFilters == nil { scanFilters = try ScanFilters() }
            ci = try scanFilters!.apply(settings, to: ci)
        }
        let factor = min(1, 64 / max(ci.extent.width, ci.extent.height))
        let small = ci.transformed(by: .init(scaleX: factor, y: factor))
        return context.createCGImage(small, from: small.extent, format: .RGBA8, colorSpace: srgb)
    }

    /// Exact normalized source alpha, evaluated on the image worker, not the UI thread.
    func hitTest(model: PhotoDocumentModel, assets: [String: EmbeddedImage], point: Point2D) throws -> UUID? {
        for layer in model.layers.reversed() where layer.isVisible && !layer.isLocked && layer.opacity > 0 {
            try Task.checkCancellation()
            guard let local = try? layer.transform.inverted().applying(to: point) else { continue }
            guard LayerGeometry.contains(local: local, size: try model.localSize(of: layer), clips: layer.clip) else { continue }
            let image:CGImage
            var samplePoint = local
            switch layer.content {
            case .image(let id):
                guard let asset=assets[id] else{continue};image=try normalizedImage(asset)
                if let scan = layer.scan, scan.enabled, scan.curveX != 0 || scan.curveY != 0 {
                    let w = Double(image.width), h = Double(image.height), u = local.x/w, v = (h-local.y)/h
                    samplePoint = Point2D(x: local.x+scan.curveX*w*0.12*4*v*(1-v)*sin(.pi*u),
                                          y: local.y-scan.curveY*h*0.12*4*u*(1-u)*sin(.pi*v))
                    guard LayerGeometry.contains(local:samplePoint,size:try model.localSize(of:layer),clips:layer.clip) else { continue }
                }
            case .shape(let shape):image=try ContentRasterizer.shapeImage(shape)
            case .text(let text):image=try ContentRasterizer.textImage(text)
            case .paint(let paint):
                let rect = CGRect(x:floor(local.x),y:Double(paint.size.height)-floor(local.y)-1,width:1,height:1)
                guard let pixel = context.createCGImage(try paintImage(paint,assets:assets),from:rect,format:.RGBA8,colorSpace:srgb) else { continue }
                image = pixel; samplePoint = Point2D(x:0,y:0)
            }
            do {
                guard let pixel = image.cropping(to: CGRect(x: floor(samplePoint.x),y: floor(samplePoint.y),width: 1,height: 1)) else { continue }
                var rgba = [UInt8](repeating: 0, count: 4)
                rgba.withUnsafeMutableBytes { bytes in
                    let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                        space: srgb, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
                    context?.draw(pixel, in: CGRect(x: 0,y: 0,width: 1,height: 1))
                }
                if rgba[3] > 0 { return layer.id }
            }
        }
        return nil
    }
    /// Sample the committed/presented composite in encoded sRGB; no canvas chrome.
    func sample(model:PhotoDocumentModel,assets:[String:EmbeddedImage],point:Point2D)throws->RGBAColor {
        guard point.x.isFinite,point.y.isFinite,point.x>=0,point.y>=0,point.x<Double(model.canvas.width),point.y<Double(model.canvas.height) else{throw DocumentError.invalidValue}
        let rect=CGRect(x:floor(point.x),y:Double(model.canvas.height)-floor(point.y)-1,width:1,height:1)
        var rgba=[UInt8](repeating:0,count:4)
        let image=try composite(model:model,assets:assets)
        rgba.withUnsafeMutableBytes{context.render(image,toBitmap:$0.baseAddress!,rowBytes:4,bounds:rect,format:.RGBA8,colorSpace:srgb)}
        let alpha=Double(rgba[3])/255
        guard alpha>0 else{return .clear}
        return RGBAColor(red:min(1,Double(rgba[0])/255/alpha),green:min(1,Double(rgba[1])/255/alpha),blue:min(1,Double(rgba[2])/255/alpha),alpha:alpha)
    }

}

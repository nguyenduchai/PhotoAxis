import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore

enum InvestigationSharing {
    static func write(_ bytes: Data, to url: URL) async throws {
        let task = Task.detached(priority: .utility) { try AtomicFile.write(to: url) { try $0.write(contentsOf: bytes) } }
        try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
    }
    static func redacted(_ image: CGImage, modelSize: CanvasSize, regions: [EvidenceRegion]) throws -> CGImage {
        for region in regions { try region.validate(in: modelSize) }
        let context = try ContentRasterizer.context(try CanvasSize(width: image.width, height: image.height))
        context.setFillColor(ContentRasterizer.color(.white)); context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.setShouldAntialias(false); context.setBlendMode(.copy); context.setFillColor(ContentRasterizer.color(.black))
        let sx = Double(image.width) / Double(modelSize.width), sy = Double(image.height) / Double(modelSize.height)
        for region in regions {
            let x = floor(Double(region.x) * sx), y = floor(Double(region.y) * sy)
            let right = ceil(Double(region.x + region.width) * sx), bottom = ceil(Double(region.y + region.height) * sy)
            context.fill(CGRect(x: x, y: Double(image.height) - bottom, width: right - x, height: bottom - y))
        }
        guard let result = context.makeImage() else { throw ImageImportError.unreadable }; return result
    }
    static func pngBytes(_ image: CGImage, ppi: Double) throws -> Data {
        let data = NSMutableData()
        guard let encoder = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw ImageImportError.unreadable }
        CGImageDestinationAddImage(encoder, image, [kCGImagePropertyDPIWidth: ppi, kCGImagePropertyDPIHeight: ppi, kCGImagePropertyOrientation: 1] as CFDictionary)
        guard CGImageDestinationFinalize(encoder) else { throw ImageImportError.unreadable }
        let bytes = try ICCEmbedding.attachSRGB(to: data as Data, format: .png)
        guard let probe = CGImageSourceCreateWithData(bytes as CFData, nil), CGImageSourceGetCount(probe) == 1,
              let props = CGImageSourceCopyPropertiesAtIndex(probe, 0, nil) as? [CFString: Any],
              props[kCGImagePropertyGPSDictionary] == nil else { throw InvestigationError.integrity }
        // Image I/O synthesizes an EXIF color-space/dimension dictionary even
        // from fresh pixels. Accept only those generated, non-source fields.
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let allowed: Set<CFString> = [kCGImagePropertyExifColorSpace, kCGImagePropertyExifPixelXDimension, kCGImagePropertyExifPixelYDimension]
        guard Set(exif.keys).isSubset(of: allowed), (exif[kCGImagePropertyExifPixelXDimension] as? Int ?? image.width) == image.width,
              (exif[kCGImagePropertyExifPixelYDimension] as? Int ?? image.height) == image.height else { throw InvestigationError.integrity }
        return bytes
    }
    struct Plate: Sendable { let code, caption, originalSHA256: String; let image: CGImage }
    private static func drawText(_ text: String, in rect: CGRect, size: Double, context: CGContext) throws {
        if text.isEmpty { return }
        let minimum = min(size, 8), path = CGPath(rect: rect, transform: nil)
        for pointSize in stride(from: size, through: minimum, by: -0.5) {
            let font = CTFontCreateWithName("Helvetica" as CFString, pointSize, nil)
            let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): ContentRasterizer.color(.black)]
            let string = NSAttributedString(string: text, attributes: attributes)
            let framesetter = CTFramesetterCreateWithAttributedString(string)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
            if CTFrameGetVisibleStringRange(frame).length == string.length { CTFrameDraw(frame, context); return }
        }
        // Never silently clip a case title, caption or source hash.
        throw InvestigationError.limit
    }
    /// Raster-only A4 pages. No original bytes, EXIF, hidden source, selectable
    /// pre-redaction text or optional PDF layer is embedded in the output.
    static func pdf(_ plates: [Plate], title: String, caseCode: String, examiner: String, perPage: Int, language: String) throws -> Data {
        let writer = try PDFWriter(title: title, caseCode: caseCode, examiner: examiner, perPage: perPage, count: plates.count, language: language)
        for start in stride(from: 0, to: plates.count, by: perPage) { try writer.append(Array(plates[start..<min(start + perPage, plates.count)])) }
        return try writer.finish()
    }
    /// The app renders and releases at most one page's photographs at a time.
    actor PDFPages {
        private let writer: PDFWriter
        init(title: String, caseCode: String, examiner: String, perPage: Int, count: Int, language: String) throws {
            writer = try PDFWriter(title: title, caseCode: caseCode, examiner: examiner, perPage: perPage, count: count, language: language)
        }
        func append(_ plates: [Plate]) throws { try writer.append(plates) }
        func finish() throws -> Data { try writer.finish() }
    }
    private final class PDFWriter {
        let buffer = NSMutableData(), pageSize = CGSize(width: 595.276, height: 841.89)
        let title, caseCode, examiner, language: String
        let perPage, count, pageCount: Int
        let pdf: CGContext
        var page = 0, finished = false
        var box: CGRect { CGRect(origin: .zero, size: pageSize) }
        init(title: String, caseCode: String, examiner: String, perPage: Int, count: Int, language: String) throws {
            guard [1, 2, 4].contains(perPage), (1...100).contains(count) else { throw InvestigationError.limit }
            self.title = title; self.caseCode = caseCode; self.examiner = examiner; self.language = language
            self.perPage = perPage; self.count = count; pageCount = (count + perPage - 1) / perPage
            var bounds = CGRect(origin: .zero, size: pageSize)
            guard let consumer = CGDataConsumer(data: buffer), let context = CGContext(consumer: consumer, mediaBox: &bounds,
                [kCGPDFContextCreator: "PhotoAxis", kCGPDFContextTitle: title] as CFDictionary) else { throw ImageImportError.unreadable }
            pdf = context
        }
        func append(_ plates: [Plate]) throws {
            guard !finished, page < pageCount, plates.count == min(perPage, count - page * perPage) else { throw InvestigationError.invalidCase }
            guard buffer.length <= InvestigationCase.maximumOriginalBytes - 16_777_216 else { throw InvestigationError.limit }
            try Task.checkCancellation()
            // 150 PPI A4; labels and the already-redacted photos are flattened together.
            guard let raster = CGContext(data: nil, width: 1240, height: 1754, bitsPerComponent: 8, bytesPerRow: 1240 * 4,
                space: ContentRasterizer.srgb, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ImageImportError.unreadable }
            raster.scaleBy(x: 1240 / pageSize.width, y: 1754 / pageSize.height)
            raster.setFillColor(ContentRasterizer.color(.white)); raster.fill(box)
            try drawText(title, in: CGRect(x: 36, y: 789, width: 523, height: 27), size: 16, context: raster)
            let heading = language == "vi" ? "Hồ sơ: \(caseCode) • Người lập: \(examiner)" : "Case: \(caseCode) • Prepared by: \(examiner)"
            try drawText(heading, in: CGRect(x: 36, y: 757, width: 523, height: 29), size: 10, context: raster)
            let columns = perPage == 4 ? 2 : 1, rows = perPage == 1 ? 1 : 2
            let cellW = 523 / Double(columns), cellH = 690 / Double(rows)
            for slot in 0..<perPage {
                guard slot < plates.count else { break }
                let plate = plates[slot], col = slot % columns, row = slot / columns
                let x = 36 + Double(col) * cellW, y = 58 + Double(rows - 1 - row) * cellH
                let area = CGRect(x: x + 6, y: y + 90, width: cellW - 12, height: cellH - 105)
                let scale = min(area.width / Double(plate.image.width), area.height / Double(plate.image.height))
                let size = CGSize(width: Double(plate.image.width) * scale, height: Double(plate.image.height) * scale)
                raster.draw(plate.image, in: CGRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2, width: size.width, height: size.height))
                try drawText(plate.code + " — " + plate.caption, in: CGRect(x: x + 6, y: y + 36, width: cellW - 12, height: 49), size: 11, context: raster)
                try drawText("SHA-256: " + plate.originalSHA256, in: CGRect(x: x + 6, y: y + 4, width: cellW - 12, height: 30), size: 7, context: raster)
            }
            let footer = language == "vi" ? "Bản ảnh đã xử lý • Trang \(page + 1)/\(pageCount)" : "Processed photographs • Page \(page + 1)/\(pageCount)"
            try drawText(footer, in: CGRect(x: 36, y: 22, width: 523, height: 19), size: 10, context: raster)
            guard let image = raster.makeImage() else { throw ImageImportError.unreadable }
            pdf.beginPDFPage(nil); pdf.draw(image, in: box); pdf.endPDFPage()
            page += 1
        }
        func finish() throws -> Data {
            guard !finished, page == pageCount else { throw InvestigationError.invalidCase }
            pdf.closePDF(); finished = true; return buffer as Data
        }
    }
}

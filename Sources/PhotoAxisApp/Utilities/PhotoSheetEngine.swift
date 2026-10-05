import Foundation
import CoreGraphics
import CoreText
import ImageIO
import PhotoAxisCore

struct PhotoSheetEntry: Identifiable, Sendable {
    let id: UUID
    let name: String
    let pixels: CanvasSize
    let data: Data
    var caption: String
    init(name: String, pixels: CanvasSize, data: Data, caption: String = "") {
        id = UUID(); self.name = name; self.pixels = pixels; self.data = data; self.caption = caption
    }
}
struct PhotoSheetSettings: Equatable, Sendable {
    var title = ""
    var note = ""
    var perPage = 2
    var landscape = false
    var showsFileNames = false
    func validate() throws {
        guard [1, 2, 4, 6].contains(perPage), title.utf8.count <= 512, note.utf8.count <= 1024 else { throw DocumentError.invalidValue }
    }
}

enum PhotoSheetEngine {
    static let maximumBytes = 128 * 1024 * 1024
    static let maximumPhotos = 100
    static func validate(_ entries: [PhotoSheetEntry], settings: PhotoSheetSettings) throws {
        try settings.validate()
        guard !entries.isEmpty, entries.count <= maximumPhotos else { throw DocumentError.resourceLimit }
        var bytes = 0
        for entry in entries {
            guard !entry.data.isEmpty, entry.data.count <= 16 * 1024 * 1024, entry.caption.utf8.count <= 4096 else { throw DocumentError.resourceLimit }
            bytes += entry.data.count; guard bytes <= maximumBytes else { throw DocumentError.resourceLimit }
        }
    }
    static func pageSize(_ settings: PhotoSheetSettings) -> CGSize {
        settings.landscape ? CGSize(width: 841.89, height: 595.276) : CGSize(width: 595.276, height: 841.89)
    }
    static func pageCount(_ count: Int, perPage: Int) -> Int { (count + perPage - 1) / perPage }
    static func imageRect(source: CanvasSize, cell: CGRect) -> CGRect {
        let scale = min(cell.width / Double(source.width), cell.height / Double(source.height))
        let w = Double(source.width) * scale, h = Double(source.height) * scale
        return CGRect(x: cell.midX - w / 2, y: cell.midY - h / 2, width: w, height: h)
    }
    private static func text(_ value: String, rect: CGRect, size: Double, bold: Bool = false, context: CGContext) throws {
        if value.isEmpty { return }
        for pointSize in stride(from: size, through: min(9, size), by: -0.5) {
            let font = CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, pointSize, nil)
            let string = NSAttributedString(string: value, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): ContentRasterizer.color(.black)])
            let setter = CTFramesetterCreateWithAttributedString(string)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: rect, transform: nil), nil)
            if CTFrameGetVisibleStringRange(frame).length == string.length { CTFrameDraw(frame, context); return }
        }
        throw PhotoSheetError.captionTooLong
    }
    /// One page is rasterized at a time, including its text. PDF cannot retain
    /// hidden originals, EXIF, OCR text or source photographs behind a cover.
    static func page(entries: [PhotoSheetEntry], settings: PhotoSheetSettings, index: Int, dpi: Double, language: String) throws -> CGImage {
        try validate(entries, settings: settings); try Task.checkCancellation()
        let count = pageCount(entries.count, perPage: settings.perPage)
        guard (0..<count).contains(index), [90.0, 150.0, 300.0].contains(dpi) else { throw DocumentError.invalidValue }
        let size = pageSize(settings), scale = dpi / 72
        let canvas = try CanvasSize(width: Int((size.width * scale).rounded()), height: Int((size.height * scale).rounded()))
        let context = try ContentRasterizer.context(canvas)
        context.setFillColor(ContentRasterizer.color(.white)); context.fill(CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height))
        context.scaleBy(x: Double(canvas.width) / size.width, y: Double(canvas.height) / size.height)
        context.textMatrix = .identity
        let margin = 30.0, header = 72.0, footer = 25.0
        try text(settings.title, rect: CGRect(x: margin, y: size.height - margin - 28, width: size.width - margin * 2, height: 28), size: 20, bold: true, context: context)
        try text(settings.note, rect: CGRect(x: margin, y: size.height - margin - 64, width: size.width - margin * 2, height: 32), size: 11, context: context)
        let columns = settings.perPage == 1 ? 1 : settings.perPage == 2 ? (settings.landscape ? 2 : 1) : 2
        let rows = settings.perPage / columns
        let gap = 16.0
        let width = (size.width - margin * 2 - gap * Double(columns - 1)) / Double(columns)
        let height = (size.height - margin * 2 - header - footer - gap * Double(rows - 1)) / Double(rows)
        let start = index * settings.perPage
        for offset in 0..<min(settings.perPage, entries.count - start) {
            try Task.checkCancellation()
            let entry = entries[start + offset]
            let x = margin + Double(offset % columns) * (width + gap)
            let y = size.height - margin - header - Double(offset / columns + 1) * height - Double(offset / columns) * gap
            let captionHeight = entry.caption.isEmpty && !settings.showsFileNames ? 28.0 : min(76, height * 0.34)
            let photoCell = CGRect(x: x, y: y + captionHeight, width: width, height: height - captionHeight)
            guard let source = CGImageSourceCreateWithData(entry.data as CFData, nil), CGImageSourceGetCount(source) == 1,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  properties[kCGImagePropertyPixelWidth] as? Int == entry.pixels.width,
                  properties[kCGImagePropertyPixelHeight] as? Int == entry.pixels.height,
                  entry.pixels.pixelCount <= 4_000_000,
                  let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { throw ImageImportError.unreadable }
            let imageRect = imageRect(source: entry.pixels, cell: photoCell)
            context.interpolationQuality = .high; context.draw(image, in: imageRect)
            let number = (language == "vi" ? "Ảnh " : "Photo ") + String(start + offset + 1)
            let name = settings.showsFileNames ? " — " + entry.name : ""
            let caption = number + name + (entry.caption.isEmpty ? "" : "\n" + entry.caption)
            try text(caption, rect: CGRect(x: x, y: y, width: width, height: captionHeight - 4), size: 12, context: context)
        }
        try text("\(index + 1) / \(count)", rect: CGRect(x: margin, y: margin - 14, width: size.width - margin * 2, height: 18), size: 10, context: context)
        guard let result = context.makeImage() else { throw ImageImportError.unreadable }; return result
    }
    static func pdf(entries: [PhotoSheetEntry], settings: PhotoSheetSettings, language: String) throws -> Data {
        try validate(entries, settings: settings)
        let buffer = NSMutableData(); var box = CGRect(origin: .zero, size: pageSize(settings))
        guard let consumer = CGDataConsumer(data: buffer), let pdf = CGContext(consumer: consumer, mediaBox: &box, [kCGPDFContextTitle: settings.title] as CFDictionary) else { throw ImageImportError.unreadable }
        var closed = false
        defer { if !closed { pdf.closePDF() } }
        for index in 0..<pageCount(entries.count, perPage: settings.perPage) {
            try Task.checkCancellation()
            let image = try page(entries: entries, settings: settings, index: index, dpi: 300, language: language)
            pdf.beginPDFPage(nil); pdf.draw(image, in: box); pdf.endPDFPage()
            guard buffer.length <= 256 * 1024 * 1024 else { throw DocumentError.resourceLimit }
        }
        pdf.closePDF(); closed = true
        guard buffer.length <= 256 * 1024 * 1024 else { throw DocumentError.resourceLimit }
        return buffer as Data
    }
}
enum PhotoSheetError: Error { case captionTooLong }

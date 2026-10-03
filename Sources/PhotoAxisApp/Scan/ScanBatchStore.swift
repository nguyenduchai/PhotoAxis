import Foundation
import CoreGraphics
import PhotoAxisCore

actor ScanBatchStore {
    let pipeline: ImagePipeline
    let detector = ScanDetector()
    init(pipeline: ImagePipeline = ImagePipeline()) { self.pipeline = pipeline }
    struct PageReceipt: Codable, Sendable {
        let index: Int
        let originalName, sourceSHA256, pngSHA256, projectSHA256: String
        let sourceBytes: Int
        let canvas: CanvasSize
        let quad: [Point2D]?
        let pageConfidence: Float?
        let warnings: [String]
        let deskewDegrees: Double
        let requiresReview: Bool
    }
    struct Receipt: Encodable, Sendable {
        let schema = 1
        let engine = "PhotoAxis Scan 1 / Vision rectangles1 / Metal linear-sRGB"
        let createdAt: Date
        let operatingSystem, applicationVersion, applicationBuild: String
        let recipe: ScanSettings
        let ppi: Double
        let targetCanvas: CanvasSize?
        let manualDeskewDegrees: Double
        let autoPage, autoDeskew: Bool
        let pages: [PageReceipt]
        let pdfSHA256: String
    }
    /// Writes a new batch directory only. An error/cancellation removes staging;
    /// publication is one same-volume rename after every output has succeeded.
    func run(_ urls: [URL], recipe: ScanRecipe, autoPage: Bool, autoDeskew: Bool, parent: URL,
             progress: @Sendable (Int, Int, String) async -> Void = { _,_,_ in }) async throws -> URL {
        guard !urls.isEmpty, urls.count <= 50 else { throw ScanError.tooManyFiles }
        try recipe.settings.validate()
        let fm = FileManager.default, id = UUID().uuidString
        let staging = parent.appendingPathComponent(".PhotoAxis-Scan-"+id, isDirectory: true)
        let destination = parent.appendingPathComponent("PhotoAxis-Scan-"+id, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }
        try fm.createDirectory(at: staging.appendingPathComponent("pages"), withIntermediateDirectories: false)
        try fm.createDirectory(at: staging.appendingPathComponent("projects"), withIntermediateDirectories: false)
        let pdfURL = staging.appendingPathComponent("pages.pdf")
        guard let consumer = CGDataConsumer(url: pdfURL as CFURL), let pdf = CGContext(consumer: consumer, mediaBox: nil, nil) else { throw ScanError.invalidOptions }
        var pdfClosed = false
        defer { if !pdfClosed { pdf.closePDF() } }
        let exports = ExportStore(pipeline: pipeline), projects = ProjectStore(pipeline: pipeline)
        var pages: [PageReceipt] = []
        for (offset, url) in urls.enumerated() {
            try Task.checkCancellation(); await progress(offset+1, urls.count, url.lastPathComponent)
            let asset = try await pipeline.prepare(.file(url), budget: ImportBudget()) // no silent downsampling
            var original = try PhotoDocumentModel(name: url.lastPathComponent, canvas: asset.descriptor.size, ppi: asset.ppi)
            let layerID = try original.place(asset.descriptor, name: asset.name, above: nil)
            let assets = [asset.descriptor.id: asset]
            let snapshot = ProjectSnapshot(model: original, assets: assets, stateID: UUID())
            let preview = try await pipeline.exportImage(snapshot: snapshot, options: ExportOptions(size: original.canvas, ppi: recipe.ppi), previewEdge: 1600)
            let analysis = try await detector.analyze(recipe,image:preview,canvas:original.canvas,autoPage:autoPage,autoDeskew:autoDeskew)
            let itemRecipe = analysis.recipe
            let model = try itemRecipe.candidate(original, layerID: layerID)
            let result = ProjectSnapshot(model: model, assets: assets, stateID: UUID())
            let number = String(format: "%04d", offset+1)
            let png = staging.appendingPathComponent("pages/"+number+".png")
            let project = staging.appendingPathComponent("projects/"+number+".paxis")
            var options = ExportOptions(size: model.canvas, ppi: recipe.ppi); options.transparency = false
            try await exports.write(result, options: options, to: png)
            try await projects.save(result, to: project)
            let image = try await pipeline.exportImage(snapshot: result, options: options)
            var box = CGRect(x: 0, y: 0, width: Double(model.canvas.width)/recipe.ppi*72, height: Double(model.canvas.height)/recipe.ppi*72)
            guard box.width <= 14400, box.height <= 14400 else { throw ScanError.invalidOptions }
            pdf.beginPDFPage([kCGPDFContextMediaBox: NSData(bytes: &box, length: MemoryLayout<CGRect>.size)] as CFDictionary)
            pdf.draw(image, in: box); pdf.endPDFPage()
            pages.append(PageReceipt(index: offset+1, originalName: asset.name, sourceSHA256: asset.descriptor.id,
                pngSHA256: ImagePipeline.digest(try Data(contentsOf: png)), projectSHA256: ImagePipeline.digest(try Data(contentsOf: project)),
                sourceBytes: asset.data.count, canvas: model.canvas, quad: itemRecipe.quad?.points,
                pageConfidence: analysis.pageConfidence, warnings: analysis.warnings,
                deskewDegrees: itemRecipe.degrees, requiresReview: true))
            await pipeline.retainCache(for: [])
        }
        pdf.closePDF(); pdfClosed = true
        try Task.checkCancellation()
        let receipt = Receipt(createdAt: Date(), operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                              applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                              applicationBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
                              recipe: recipe.settings, ppi: recipe.ppi, targetCanvas: recipe.size, manualDeskewDegrees: recipe.degrees,
                              autoPage: autoPage, autoDeskew: autoDeskew,
                              pages: pages, pdfSHA256: ImagePipeline.digest(try Data(contentsOf: pdfURL)))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(receipt).write(to: staging.appendingPathComponent("manifest.json"))
        try Task.checkCancellation(); try fm.moveItem(at: staging, to: destination)
        return destination
    }
}

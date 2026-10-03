import Foundation
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore

actor ExportStore {
    let pipeline: ImagePipeline
    init(pipeline: ImagePipeline) { self.pipeline = pipeline }
    func write(_ snapshot: ProjectSnapshot, options: ExportOptions, to url: URL,
               beforeCommit: @Sendable () throws -> Void = {}) async throws {
        try options.validate(); try Task.checkCancellation()
        let image = try await pipeline.exportImage(snapshot:snapshot,options:options)
        try Task.checkCancellation()
        let buffer = NSMutableData(), type = options.format == .png ? UTType.png : .jpeg
        guard let destination = CGImageDestinationCreateWithData(buffer,type.identifier as CFString,1,nil) else { throw CocoaError(.fileWriteUnknown) }
        // Fresh CGImage + an explicit property whitelist: source EXIF/GPS is never copied.
        var properties: [CFString:Any] = [kCGImagePropertyDPIWidth:options.ppi,kCGImagePropertyDPIHeight:options.ppi,
            kCGImagePropertyOrientation:1]
        if options.format == .jpeg { properties[kCGImageDestinationLossyCompressionQuality] = Double(options.quality)/100 }
        CGImageDestinationAddImage(destination,image,properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        try Task.checkCancellation()
        let bytes = try ICCEmbedding.attachSRGB(to:buffer as Data,format:options.format)
        try AtomicFile.write(to:url,beforeCommit:beforeCommit) { handle in
            for start in stride(from:0,to:bytes.count,by:1_048_576) {
                try Task.checkCancellation(); try handle.write(contentsOf:bytes.subdata(in:start..<min(bytes.count,start+1_048_576)))
            }
        }
    }
}

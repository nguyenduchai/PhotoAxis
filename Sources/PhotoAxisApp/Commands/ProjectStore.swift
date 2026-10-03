import Foundation
import ImageIO
import UniformTypeIdentifiers
import Darwin
import PhotoAxisCore

struct ProjectSnapshot: Sendable {
    let model: PhotoDocumentModel
    let assets: [String: EmbeddedImage]
    let stateID: UUID
}

enum AtomicFile {
    /// Commit point is a same-directory POSIX rename. Cancellation before it leaves
    /// the destination untouched; after it the write has succeeded.
    static func write(to url: URL, beforeCommit: () throws -> Void = {}, body: (FileHandle) throws -> Void) throws {
        let directory = url.deletingLastPathComponent()
        let temporary = directory.appendingPathComponent(".photoaxis-" + UUID().uuidString + ".tmp")
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close(); _ = unlink(temporary.path) }
        try body(handle); try handle.synchronize(); try beforeCommit(); try Task.checkCancellation()
        guard rename(temporary.path, url.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        // Flush directory metadata where the filesystem supports it.
        let parent = open(directory.path, O_RDONLY)
        if parent >= 0 { _ = fsync(parent); close(parent) }
    }
}

actor ProjectStore {
    let pipeline: ImagePipeline
    init(pipeline: ImagePipeline) { self.pipeline = pipeline }
    func save(_ snapshot: ProjectSnapshot, to url: URL) async throws {
        try Task.checkCancellation()
        let schema = ProjectSchema(snapshot.model), json = try schema.encoded()
        guard Set(snapshot.model.sources.keys).isSubset(of: Set(snapshot.assets.keys)) else { throw ProjectError.assetMismatch }
        var entries: [(String,Data)] = [("document.json",json)]
        for source in schema.sources {
            guard let asset = snapshot.assets[source.id], asset.descriptor == source,
                  ImagePipeline.digest(asset.data) == source.id else { throw ProjectError.assetMismatch }
            entries.append(("assets/"+source.id,asset.data))
        }
        let preview = try await pipeline.projectPreview(model: snapshot.model, assets: snapshot.assets)
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(buffer, UTType.png.identifier as CFString,1,nil) else { throw ProjectError.invalidDocument }
        CGImageDestinationAddImage(destination,preview,nil)
        guard CGImageDestinationFinalize(destination) else { throw ProjectError.invalidDocument }
        entries.append(("preview.png",buffer as Data))
        try AtomicFile.write(to: url) { handle in try BoundedZIP.write(entries) { try handle.write(contentsOf: $0) } }
    }
    func open(_ url: URL) async throws -> ProjectSnapshot {
        try Task.checkCancellation()
        let entries = try BoundedZIP.read(url: url)
        guard let json = entries["document.json"] else { throw ProjectError.invalidDocument }
        let schema = try ProjectSchema.decode(json), model = try schema.model()
        var assets: [String:EmbeddedImage] = [:]
        for source in schema.sources {
            try Task.checkCancellation()
            guard let data = entries["assets/"+source.id] else { throw ProjectError.assetMismatch }
            assets[source.id] = try await pipeline.validateEmbedded(data, descriptor: source, ppi: model.ppi)
        }
        guard let preview = entries["preview.png"],
              let probe = CGImageSourceCreateWithData(preview as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
              CGImageSourceGetType(probe) as String? == UTType.png.identifier,
              let props = CGImageSourceCopyPropertiesAtIndex(probe,0,nil) as? [CFString:Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int, let height = props[kCGImagePropertyPixelHeight] as? Int,
              (1...512).contains(width), (1...512).contains(height), CGImageSourceGetCount(probe) == 1,
              CGImageSourceCreateImageAtIndex(probe,0,nil) != nil,
              CGImageSourceGetStatusAtIndex(probe,0) == .statusComplete else { throw ProjectError.invalidDocument }
        return ProjectSnapshot(model: model, assets: assets, stateID: UUID())
    }
}

import Foundation

public enum PrivacyStyle: String, CaseIterable, Sendable { case cover, blur, pixelate }

public extension PhotoDocumentModel {
    /// Existing image/shape layers keep privacy edits compatible with project readers 1–4.
    /// Pixel coordinates are on the committed canvas; the new layer is above all content.
    @discardableResult mutating func insertPrivacy(region: EvidenceRegion, source: SourceDescriptor? = nil, name: String) throws -> UUID {
        try region.validate(in: canvas)
        let translation = try LayerGeometry.translation(x: Double(region.x), y: Double(region.y))
        let id: UUID
        if let source {
            guard source.size.width == region.width, source.size.height == region.height else { throw DocumentError.invalidValue }
            id = try place(source, name: name, above: nil)
            try setTransform(id, translation)
        } else {
            id = try insertContent(.shape(.init(kind: .rectangle, size: CanvasSize(width: region.width, height: region.height), fill: .black)), name: name, transform: translation, above: nil)
        }
        try setLock(id, true)
        return id
    }
}

import Foundation

public enum ProjectError: Error, Equatable {
    case invalidArchive, resourceLimit, invalidDocument, newerVersion(Int), unsupportedVersion(Int), assetMismatch
    public var localizationKey: String {
        switch self {
        case .newerVersion: "project.newerVersion"
        case .unsupportedVersion: "project.unsupportedVersion"
        case .resourceLimit: "project.resourceLimit"
        case .assetMismatch: "project.assetMismatch"
        default: "project.invalid"
        }
    }
}

extension CanvasSize: Codable {
    private enum CodingKeys: String, CodingKey { case width, height }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(width: c.decode(Int.self, forKey: .width), height: c.decode(Int.self, forKey: .height))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(width, forKey: .width); try c.encode(height, forKey: .height)
    }
}

/// Explicit schema keeps enum payloads stable and excludes UI state and Undo.
public struct ProjectSchema: Codable, Sendable {
    public var formatIdentifier = "photoaxis.document"
    public var formatVersion = 1
    public var id: UUID
    public var name: String
    public var canvas: CanvasSize
    public var ppi: Double
    public var revision: UInt64
    public var sources: [SourceDescriptor]
    public var layers: [Layer]
    public var investigation: InvestigationReference?

    public struct Layer: Codable, Sendable {
        public var id: UUID
        public var name: String
        public var type: String
        public var sourceID: String?
        public var text: TextContent?
        public var shape: ShapeContent?
        public var imageAdjustments: ImageAdjustments?
        public var transform: [Double]
        public var clip: [[Point2D]]
        public var isVisible: Bool
        public var isLocked: Bool
        public var opacity: Double
        init(_ layer: PhotoLayer) {
            id = layer.id; name = layer.name; transform = layer.transform.coefficients; clip = layer.clip
            isVisible = layer.isVisible; isLocked = layer.isLocked; opacity = layer.opacity
            switch layer.content {
            case .image(let source): type = "image"; sourceID = source; imageAdjustments = layer.adjustments
            case .text(let content): type = "text"; text = content
            case .shape(let content): type = "shape"; shape = content
            }
        }
        func model() throws -> PhotoLayer {
            guard name.utf8.count <= 4096, opacity.isFinite, (0...1).contains(opacity),
                  clip.count <= 100, clip.allSatisfy({ $0.count <= 512 }) else { throw ProjectError.invalidDocument }
            for polygon in clip where !polygon.isEmpty {
                guard polygon.count >= 3, polygon.allSatisfy({ $0.x.isFinite && $0.y.isFinite && abs($0.x) <= 1_000_000 && abs($0.y) <= 1_000_000 }) else { throw ProjectError.invalidDocument }
                var sign = 0.0
                for i in polygon.indices {
                    let a = polygon[i], b = polygon[(i+1)%polygon.count], c = polygon[(i+2)%polygon.count]
                    let cross = (b.x-a.x)*(c.y-b.y)-(b.y-a.y)*(c.x-b.x)
                    if abs(cross) > 1e-8 { if sign * cross < 0 { throw ProjectError.invalidDocument }; sign = cross }
                }
                guard sign != 0 else { throw ProjectError.invalidDocument }
                for i in polygon.indices {
                    let a = polygon[i], b = polygon[(i+1)%polygon.count]
                    guard polygon.allSatisfy({ sign * ((b.x-a.x)*($0.y-a.y)-(b.y-a.y)*($0.x-a.x)) >= -1e-7 }) else { throw ProjectError.invalidDocument }
                }
            }
            let content: LayerContent
            switch type {
            case "image":
                guard let sourceID, let imageAdjustments, text == nil, shape == nil else { throw ProjectError.invalidDocument }
                try imageAdjustments.validate(); content = .image(sourceID: sourceID)
            case "text":
                guard let text, sourceID == nil, shape == nil, imageAdjustments == nil else { throw ProjectError.invalidDocument }
                try text.validate(); content = .text(text)
            case "shape":
                guard let shape, sourceID == nil, text == nil, imageAdjustments == nil else { throw ProjectError.invalidDocument }
                try shape.validate(); content = .shape(shape)
            default: throw ProjectError.invalidDocument
            }
            var result = PhotoLayer(id: id, name: name, content: content, transform: try ProjectiveTransform(transform))
            result.clip = clip; result.isVisible = isVisible; result.isLocked = isLocked; result.opacity = opacity
            result.adjustments = imageAdjustments ?? ImageAdjustments(); return result
        }
    }

    public init(_ model: PhotoDocumentModel) {
        id = model.id; name = model.name; canvas = model.canvas; ppi = model.ppi; revision = model.revision
        formatVersion = model.investigation == nil ? 1 : 2
        sources = model.sources.values.sorted { $0.id < $1.id }; layers = model.layers.map(Layer.init); investigation = model.investigation
    }
    public func model() throws -> PhotoDocumentModel {
        guard formatIdentifier == "photoaxis.document" else { throw ProjectError.invalidDocument }
        guard formatVersion <= 2 else { throw ProjectError.newerVersion(formatVersion) }
        guard formatVersion == 1 || formatVersion == 2 else { throw ProjectError.unsupportedVersion(formatVersion) }
        guard (formatVersion == 2) == (investigation != nil) else { throw ProjectError.invalidDocument }
        if let investigation { guard investigation.itemID == id else { throw ProjectError.invalidDocument } }
        guard name.utf8.count <= 4096, layers.count <= DocumentLimits.maximumLayers,
              sources.count <= DocumentLimits.maximumLayers, Set(layers.map(\.id)).count == layers.count,
              Set(sources.map(\.id)).count == sources.count,
              sources.allSatisfy({ Self.isSourceID($0.id) }),
              layers.reduce(0, { $0 + $1.clip.reduce(0, { $0 + $1.count }) }) <= 16_384,
              sources.reduce(0, { $0 + $1.size.pixelCount }) <= DocumentLimits.maximumUniqueSourcePixels else { throw ProjectError.resourceLimit }
        var result = try PhotoDocumentModel(id: id, name: name, canvas: canvas, ppi: ppi)
        result.investigation = investigation
        result.sources = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        result.layers = try layers.map { try $0.model() }; result.revision = revision
        var used = Set<String>()
        for layer in result.layers {
            if case .image(let id) = layer.content {
                guard result.sources[id] != nil else { throw ProjectError.assetMismatch }; used.insert(id)
            }
            _ = try LayerGeometry.support(size: result.localSize(of: layer), transform: layer.transform, clips: layer.clip)
            _ = try LayerGeometry.bounds(size: result.localSize(of: layer), transform: layer.transform, clips: layer.clip)
        }
        guard used == Set(result.sources.keys) else { throw ProjectError.assetMismatch }
        return result
    }
    public static func isSourceID(_ id: String) -> Bool {
        id.utf8.count == 64 && id.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    public func encoded() throws -> Data {
        _ = try model()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
    public static func decode(_ data: Data) throws -> ProjectSchema {
        guard data.count <= BoundedZIP.jsonLimit else { throw ProjectError.resourceLimit }
        // Bound parser nesting before Foundation allocates a recursive object graph.
        var depth = 0, string = false, escape = false, start = 0
        var quoted: Range<Int>?, keys: [Set<String>?] = []
        for (index,byte) in data.enumerated() {
            if string {
                if escape { escape = false } else if byte == 92 { escape = true }
                else if byte == 34 { string = false; quoted = start..<index+1 }
            }
            else if byte == 34 { string = true; start = index; quoted = nil }
            else if byte == 91 || byte == 123 {
                depth += 1; guard depth <= 24 else { throw ProjectError.resourceLimit }
                keys.append(byte == 123 ? Set<String>() : nil); quoted = nil
            }
            else if byte == 93 || byte == 125 {
                depth -= 1; guard depth >= 0, (byte == 125) == (keys.last! != nil) else { throw ProjectError.invalidDocument }
                keys.removeLast(); quoted = nil
            }
            else if byte == 58 {
                guard let range = quoted, range.count <= 4096, !keys.isEmpty, var names = keys[keys.count-1] else { throw ProjectError.invalidDocument }
                let key = try JSONDecoder().decode(String.self,from:data.subdata(in:range))
                guard names.insert(key).inserted else { throw ProjectError.invalidDocument }
                guard names.count <= 32 else { throw ProjectError.resourceLimit }
                keys[keys.count-1] = names; quoted = nil
            }
            else if ![9,10,13,32].contains(byte) { quoted = nil }
        }
        guard depth == 0, !string else { throw ProjectError.invalidDocument }
        struct Header: Decodable { let formatIdentifier: String; let formatVersion: Int }
        let header = try JSONDecoder().decode(Header.self,from:data)
        guard header.formatIdentifier == "photoaxis.document" else { throw ProjectError.invalidDocument }
        guard header.formatVersion <= 2 else { throw ProjectError.newerVersion(header.formatVersion) }
        guard header.formatVersion == 1 || header.formatVersion == 2 else { throw ProjectError.unsupportedVersion(header.formatVersion) }
        let result = try JSONDecoder().decode(Self.self, from: data); _ = try result.model(); return result
    }
}

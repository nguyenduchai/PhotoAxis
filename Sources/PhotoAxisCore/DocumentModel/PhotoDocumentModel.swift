import Foundation

public enum DocumentError: Error, Equatable {
    case invalidPPI, layerLimit, sourceLimit, missingSource, missingLayer, lockedLayer, invalidValue, activeSession
}

public struct SourceDescriptor: Codable, Equatable, Sendable {
    /// SHA-256 of the embedded bytes. A duplicate references the same immutable source.
    public let id: String
    public let size: CanvasSize
    public init(id: String, size: CanvasSize) { self.id = id; self.size = size }
}

public struct RGBAColor: Codable, Equatable, Sendable {
    public let red, green, blue, alpha: Double
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
    public static let white = RGBAColor(red: 1, green: 1, blue: 1)
    public static let black = RGBAColor(red: 0, green: 0, blue: 0)
}

public enum TextAlignment: String, Codable, CaseIterable, Sendable { case left, center, right }

public struct TextContent: Codable, Equatable, Sendable {
    public var text: String
    public var fontName: String
    public var fontSize: Double
    public var fontFamily = ""
    public var fontStyle = ""
    public var alignment: TextAlignment = .left
    public var lineSpacing: Double = 0
    /// Validated pixel extent measured by the native text layout adapter.
    public var layoutSize: CanvasSize = try! CanvasSize(width: 1, height: 1)
    public var color: RGBAColor
    public init(text: String, fontName: String, fontSize: Double, color: RGBAColor) {
        self.text = text; self.fontName = fontName; self.fontSize = fontSize; self.color = color
    }
}

public struct ShapeContent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case rectangle, ellipse, line }
    public var kind: Kind
    public var size: CanvasSize
    public var fill: RGBAColor
    public var stroke: RGBAColor = .black
    public var strokeWidth: Double = 0
    public var lineStart = Point2D(x: 0, y: 0)
    public var lineEnd = Point2D(x: 1, y: 1)
    public init(kind: Kind, size: CanvasSize, fill: RGBAColor) {
        self.kind = kind; self.size = size; self.fill = fill
    }
}

public enum LayerContent: Equatable, Sendable {
    case image(sourceID: String)
    case text(TextContent)
    case shape(ShapeContent)
}

public struct PhotoLayer: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var content: LayerContent
    public var transform: ProjectiveTransform
    /// Intersection of convex polygons in layer-local pixels; empty means no extra clip.
    public var clip: [[Point2D]] = []
    public var isVisible = true
    public var isLocked = false
    public var opacity = 1.0
    public var adjustments = ImageAdjustments()
    public init(id: UUID = UUID(), name: String, content: LayerContent, transform: ProjectiveTransform = .identity) {
        self.id = id; self.name = name; self.content = content; self.transform = transform
    }
}

public enum DocumentBackground: String, CaseIterable, Sendable { case transparent, white, black }

public struct PhotoDocumentModel: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var canvas: CanvasSize
    public var investigation: InvestigationReference?
    public internal(set) var ppi: Double
    /// Bottom to top. Geometry operates on every layer, including hidden/locked ones.
    public internal(set) var layers: [PhotoLayer]
    public internal(set) var sources: [String: SourceDescriptor] = [:]
    public internal(set) var revision: UInt64 = 0
    public var uniqueSourcePixels: Int { sources.values.reduce(0) { $0 + $1.size.pixelCount } }

    public init(id: UUID = UUID(), name: String, canvas: CanvasSize, ppi: Double,
                background: DocumentBackground = .transparent, backgroundName: String = "Background") throws {
        guard ppi.isFinite, ppi > 0 else { throw DocumentError.invalidPPI }
        self.id = id; self.name = name; self.canvas = canvas; self.ppi = ppi; layers = []
        if background != .transparent {
            var layer = PhotoLayer(name: backgroundName, content: .shape(.init(kind: .rectangle, size: canvas,
                fill: background == .white ? .white : .black)))
            layer.isLocked = true; layers = [layer]
        }
    }

    public mutating func place(_ source: SourceDescriptor, name: String, above selectedID: UUID?) throws -> UUID {
        guard layers.count < DocumentLimits.maximumLayers else { throw DocumentError.layerLimit }
        let additional = sources[source.id] == nil ? source.size.pixelCount : 0
        guard uniqueSourcePixels + additional <= DocumentLimits.maximumUniqueSourcePixels else { throw DocumentError.sourceLimit }
        let scale = min(1, min(Double(canvas.width) / Double(source.size.width), Double(canvas.height) / Double(source.size.height)))
        let x = (Double(canvas.width) - Double(source.size.width) * scale) / 2
        let y = (Double(canvas.height) - Double(source.size.height) * scale) / 2
        let layer = PhotoLayer(name: name, content: .image(sourceID: source.id),
            transform: try ProjectiveTransform([scale, 0, x, 0, scale, y, 0, 0, 1]))
        let insertion = selectedID.flatMap { id in layers.firstIndex { $0.id == id }.map { $0 + 1 } } ?? layers.count
        sources[source.id] = source; layers.insert(layer, at: insertion); revision &+= 1
        return layer.id
    }
}

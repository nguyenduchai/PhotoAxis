import Foundation

/// Editable strokes retain immutable source references, never rewrite an intake image.
public struct PaintStroke: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case brush, clone }
    public var kind: Kind
    public var points: [Point2D]
    public var diameter: Double
    public var hardness: Double
    public var opacity: Double
    public var color: RGBAColor
    public var sourceID: String?
    /// Sample source at destination + offset, in top-left layer pixels.
    public var sourceOffset: Point2D?
    public init(kind: Kind = .brush, points: [Point2D], diameter: Double, hardness: Double = 1,
                opacity: Double = 1, color: RGBAColor = .black, sourceID: String? = nil, sourceOffset: Point2D? = nil) {
        self.kind = kind; self.points = points; self.diameter = diameter; self.hardness = hardness
        self.opacity = opacity; self.color = color; self.sourceID = sourceID; self.sourceOffset = sourceOffset
    }
    public var spacing: Double { max(1, diameter * 0.15) }
    public func validate(in size: CanvasSize) throws {
        guard (1...4096).contains(points.count), diameter.isFinite, (1...1000).contains(diameter),
              hardness.isFinite, (0...1).contains(hardness), opacity.isFinite, (0...1).contains(opacity), color.isValid,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...Double(size.width)).contains($0.x) && (0...Double(size.height)).contains($0.y) }) else { throw DocumentError.invalidValue }
        switch kind {
        case .brush: guard sourceID == nil, sourceOffset == nil else { throw DocumentError.invalidValue }
        case .clone:
            guard let sourceID, ProjectSchema.isSourceID(sourceID), let sourceOffset,
                  [sourceOffset.x,sourceOffset.y].allSatisfy({ $0.isFinite && abs($0) <= 16_000 }) else { throw DocumentError.invalidValue }
        }
        guard sampleCount <= 65_536 else { throw DocumentError.resourceLimit }
    }
    public var sampleCount: Int {
        zip(points, points.dropFirst()).reduce(1) { count,pair in
            let distance = hypot(pair.1.x-pair.0.x,pair.1.y-pair.0.y)
            guard distance.isFinite, spacing.isFinite, spacing > 0, distance < 1_000_000 else { return 65_537 }
            return min(65_537,count + max(1,Int(ceil(distance/spacing))))
        }
    }
    public func bounds(in size: CanvasSize) -> LayerBounds {
        let r = diameter/2 + 1
        let left = max(0,floor((points.map(\.x).min() ?? 0)-r)), top = max(0,floor((points.map(\.y).min() ?? 0)-r))
        let right = min(Double(size.width),ceil((points.map(\.x).max() ?? 0)+r)), bottom = min(Double(size.height),ceil((points.map(\.y).max() ?? 0)+r))
        return LayerBounds(x:left,y:top,width:max(1,right-left),height:max(1,bottom-top))
    }
    public func samples() -> [Point2D] {
        guard let first = points.first, sampleCount <= 65_536 else { return [] }
        var output = [first]
        for (a,b) in zip(points,points.dropFirst()) {
            let count = max(1,Int(ceil(hypot(b.x-a.x,b.y-a.y)/spacing)))
            for i in 1...count { let t = Double(i)/Double(count); output.append(Point2D(x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t)) }
        }
        return output
    }
}

public struct PaintContent: Codable, Equatable, Sendable {
    public var size: CanvasSize
    public var strokes: [PaintStroke]
    public init(size: CanvasSize, strokes: [PaintStroke] = []) { self.size = size; self.strokes = strokes }
    public var sourceIDs: Set<String> { Set(strokes.compactMap(\.sourceID)) }
    public var workPixels: Int { strokes.reduce(0) { result,stroke in let b = stroke.bounds(in:size); return result + Int(b.width)*Int(b.height) } }
    public var metadataBytes: Int { 128 + strokes.reduce(0) { $0 + 256 + $1.points.count * 16 } }
    public func validate() throws {
        guard strokes.count <= 512, strokes.reduce(0,{ $0+$1.points.count }) <= 32_768 else { throw DocumentError.resourceLimit }
        for stroke in strokes { try stroke.validate(in:size) }
        guard workPixels <= DocumentLimits.maximumUniqueSourcePixels else { throw DocumentError.resourceLimit }
    }
}

public extension LayerContent {
    var sourceIDs: Set<String> {
        switch self { case .image(let id): [id]; case .paint(let paint): paint.sourceIDs; case .text,.shape: [] }
    }
}

public extension PhotoDocumentModel {
    @discardableResult mutating func appendPaint(_ stroke: PaintStroke, selectedID: UUID?, source: SourceDescriptor?, name: String) throws -> UUID {
        var next = self
        if let source {
            guard stroke.sourceID == source.id else { throw DocumentError.invalidValue }
            if let old = next.sources[source.id], old != source { throw DocumentError.invalidValue }
            let additional = next.sources[source.id] == nil ? source.size.pixelCount : 0
            guard next.sources.count + (next.sources[source.id] == nil ? 1:0) <= DocumentLimits.maximumLayers, next.uniqueSourcePixels + additional <= DocumentLimits.maximumUniqueSourcePixels else { throw DocumentError.sourceLimit }
            next.sources[source.id] = source
        }
        guard stroke.sourceID.map({ next.sources[$0] != nil }) ?? true else { throw DocumentError.missingSource }
        try stroke.validate(in:canvas)
        let target: UUID
        if let id = selectedID, let layer = next.layer(id), case .paint(var paint) = layer.content,
           paint.size == canvas, layer.transform == .identity {
            guard !layer.isLocked else { throw DocumentError.lockedLayer }
            guard layer.isVisible else { throw DocumentError.invalidValue }
            paint.strokes.append(stroke); try next.setContent(id,.paint(paint)); target = id
        } else {
            let paint = PaintContent(size:canvas,strokes:[stroke])
            target = try next.insertContent(.paint(paint),name:name,transform:.identity,above:selectedID)
        }
        let paints = next.layers.compactMap { layer -> PaintContent? in if case .paint(let value) = layer.content { return value }; return nil }
        guard paints.reduce(0,{ $0+$1.workPixels }) <= DocumentLimits.maximumUniqueSourcePixels,
              paints.reduce(0,{ $0+$1.strokes.reduce(0,{ $0+$1.points.count }) }) <= 262_144 else { throw DocumentError.resourceLimit }
        self = next; return target
    }
}

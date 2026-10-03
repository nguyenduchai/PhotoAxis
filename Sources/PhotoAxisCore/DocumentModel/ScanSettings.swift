import Foundation

/// Reproducible, non-generative processing of an immutable image layer.
public struct ScanSettings: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable { case color, gray, blackWhite }
    public var enabled = true
    public var mode: Mode = .color
    public var paper = 0.8
    public var denoise = 0.1
    public var sharpness = 0.3
    public var threshold = 0.08
    public var radius = 0.025
    public var curveX = 0.0
    public var curveY = 0.0
    public init() {}
    public func validate() throws {
        guard [paper, denoise, sharpness].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              threshold.isFinite, (0...0.4).contains(threshold), radius.isFinite, (0.005...0.1).contains(radius),
              [curveX, curveY].allSatisfy({ $0.isFinite && (-1...1).contains($0) }) else { throw DocumentError.invalidValue }
    }
}

public extension PhotoDocumentModel {
    mutating func setScan(_ id: UUID, _ settings: ScanSettings?) throws {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { throw DocumentError.missingLayer }
        guard !layers[index].isLocked else { throw DocumentError.lockedLayer }
        guard case .image = layers[index].content else { throw DocumentError.invalidValue }
        try settings?.validate()
        if layers[index].scan != settings { layers[index].scan = settings; revision &+= 1 }
    }

    /// Positive degrees are clockwise in document coordinates. Expanded output
    /// preserves the original canvas clip and never exposes discarded pixels.
    mutating func deskewScan(degrees: Double) throws {
        guard degrees.isFinite, (-15...15).contains(degrees) else { throw DocumentError.invalidValue }
        guard abs(degrees) > 0.001 else { return }
        var next = self
        try next.crop(to: .full(canvas))
        let a = degrees * .pi / 180, c = cos(a), s = sin(a)
        let w = Double(canvas.width), h = Double(canvas.height)
        let nw = ceil(abs(w*c) + abs(h*s)), nh = ceil(abs(w*s) + abs(h*c))
        guard nw <= 8000, nh <= 8000 else { throw DocumentError.invalidValue }
        let size = try CanvasSize(width: Int(nw), height: Int(nh))
        let operation = try ProjectiveTransform([c,-s,nw/2-c*w/2+s*h/2,s,c,nh/2-s*w/2-c*h/2,0,0,1])
        for index in next.layers.indices {
            next.layers[index].transform = try next.layers[index].transform.followed(by: operation)
            _ = try LayerGeometry.support(size: next.localSize(of: next.layers[index]), transform: next.layers[index].transform, clips: next.layers[index].clip)
        }
        next.canvas = size; next.revision &+= 1; self = next
    }

    /// Fits the content without stretching, with centered transparent margins.
    /// Scan exports explicitly flatten those margins on white paper.
    mutating func normalizeScan(to size: CanvasSize, ppi: Double) throws {
        let scale = min(Double(size.width)/Double(canvas.width), Double(size.height)/Double(canvas.height))
        let fitted = try CanvasSize(width: max(1, min(size.width, Int((Double(canvas.width)*scale).rounded()))),
                                    height: max(1, min(size.height, Int((Double(canvas.height)*scale).rounded()))))
        var next = self
        try next.imageSize(fitted, ppi: ppi)
        try next.canvasSize(size, anchorX: 1, anchorY: 1)
        self = next
    }
}

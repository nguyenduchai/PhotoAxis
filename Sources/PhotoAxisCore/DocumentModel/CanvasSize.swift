/// Validated dimensions in document pixels, before allocating any pixel buffer.
public struct CanvasSize: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public var pixelCount: Int { width * height }

    public init(width: Int, height: Int, minimumEdge: Int = 1) throws {
        guard (1...2).contains(minimumEdge),
              (minimumEdge...DocumentLimits.maximumEdge).contains(width),
              (minimumEdge...DocumentLimits.maximumEdge).contains(height) else {
            throw DimensionError.edgeOutOfRange
        }
        // Multiplication is safe only after bounding both inputs.
        guard width * height <= DocumentLimits.maximumPixels else {
            throw DimensionError.pixelBudgetExceeded
        }
        self.width = width
        self.height = height
    }
}

public enum DimensionError: Error, Equatable {
    case edgeOutOfRange
    case pixelBudgetExceeded
}

public enum DocumentLimits {
    public static let maximumEdge = 8_000
    public static let maximumPixels = 40_000_000
    public static let maximumUniqueSourcePixels = 120_000_000
    public static let maximumLayers = 50
    public static let maximumDocuments = 5
    public static let maximumHistorySteps = 100
    public static let maximumHistoryBytes = 128 * 1_024 * 1_024
}

import Foundation

/// Top-left origin, x right, y down. Coordinates denote pixel boundaries.
public struct Point2D: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public enum GeometryError: Error, Equatable {
    case invalidMatrix
    case pointAtInfinity
    case invalidViewport
}

/// Row-major storage, column vectors: p' ~ M * [x, y, 1].
/// Does not solve a homography or establish that an entire polygon is safe.
public struct ProjectiveTransform: Equatable, Sendable {
    public let coefficients: [Double]
    private static let epsilon = 1e-12

    public static let identity = ProjectiveTransform(unchecked: [1, 0, 0, 0, 1, 0, 0, 0, 1])

    /// The denominator decides whether straight text can use the inline editor.
    /// Homogeneous scale must not change editor routing after repeated crops.
    public var isAffine: Bool {
        let d = coefficients.suffix(3).map { abs($0) }
        let scale = d.max()!
        return (d[0] / scale + d[1] / scale) <= Self.epsilon
    }

    public init(_ coefficients: [Double]) throws {
        guard coefficients.count == 9, coefficients.allSatisfy(\.isFinite),
              let scale = coefficients.map({ abs($0) }).max(), scale > 0 else {
            throw GeometryError.invalidMatrix
        }
        // Homogeneous matrices are scale-equivalent. Normalize for determinant tests.
        let normalized = coefficients.map { $0 / scale }
        let terms = Self.determinantTerms(normalized)
        guard abs(terms.reduce(0, +)) > Self.epsilon * terms.map({ abs($0) }).reduce(0, +) else {
            throw GeometryError.invalidMatrix
        }
        self.coefficients = coefficients
    }

    private init(unchecked coefficients: [Double]) { self.coefficients = coefficients }

    public func applying(to point: Point2D) throws -> Point2D {
        let m = coefficients
        let w = m[6] * point.x + m[7] * point.y + m[8]
        let wScale = abs(m[6] * point.x) + abs(m[7] * point.y) + abs(m[8])
        guard point.x.isFinite, point.y.isFinite, w.isFinite,
              abs(w) > Self.epsilon * wScale else { throw GeometryError.pointAtInfinity }
        let x = (m[0] * point.x + m[1] * point.y + m[2]) / w
        let y = (m[3] * point.x + m[4] * point.y + m[5]) / w
        guard x.isFinite, y.isFinite else { throw GeometryError.pointAtInfinity }
        return Point2D(x: x, y: y)
    }

    /// Returns next * self: existing layer mapping is applied before the document operation.
    public func followed(by next: Self) throws -> Self {
        var result = Array(repeating: 0.0, count: 9)
        for row in 0..<3 {
            for column in 0..<3 {
                for k in 0..<3 {
                    result[row * 3 + column] += next.coefficients[row * 3 + k] * coefficients[k * 3 + column]
                }
            }
        }
        return try Self(result)
    }

    public func inverted() throws -> Self {
        let scale = coefficients.map { abs($0) }.max()!
        let m = coefficients.map { $0 / scale }
        // Adjugate suffices because the result is homogeneous.
        return try Self([
            m[4]*m[8]-m[5]*m[7], m[2]*m[7]-m[1]*m[8], m[1]*m[5]-m[2]*m[4],
            m[5]*m[6]-m[3]*m[8], m[0]*m[8]-m[2]*m[6], m[2]*m[3]-m[0]*m[5],
            m[3]*m[7]-m[4]*m[6], m[1]*m[6]-m[0]*m[7], m[0]*m[4]-m[1]*m[3]
        ])
    }

    private static func determinantTerms(_ m: [Double]) -> [Double] {
        [m[0]*m[4]*m[8], -m[0]*m[5]*m[7], -m[1]*m[3]*m[8],
         m[1]*m[5]*m[6], m[2]*m[3]*m[7], -m[2]*m[4]*m[6]]
    }
}

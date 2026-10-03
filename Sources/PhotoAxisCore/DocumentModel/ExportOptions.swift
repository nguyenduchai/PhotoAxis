import Foundation

public enum ExportFormat: String, CaseIterable, Sendable { case png, jpeg }

public struct ExportOptions: Equatable, Sendable {
    public var format: ExportFormat = .png
    public var size: CanvasSize
    public var ppi: Double
    public var transparency = true
    public var quality = 90
    public var matte = RGBAColor.white
    public init(size: CanvasSize, ppi: Double) { self.size = size; self.ppi = ppi }
    public func validate() throws {
        guard ppi.isFinite, ppi > 0, (1...100).contains(quality), matte.isValid, matte.alpha == 1 else { throw DocumentError.invalidValue }
    }
}

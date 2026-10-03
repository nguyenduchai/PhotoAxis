import Foundation

/// Stored UI units, independent of Core Image and UI language.
public struct ImageAdjustments: Codable, Equatable, Sendable {
    public var enabled = true
    public var exposure = 0.0
    public var brightness = 0.0
    public var contrast = 0.0
    public var saturation = 0.0
    public init() {}
    public var isNeutral: Bool { exposure == 0 && brightness == 0 && contrast == 0 && saturation == 0 }
    public func validate() throws {
        guard exposure.isFinite, (-4...4).contains(exposure),
              [brightness,contrast,saturation].allSatisfy({ $0.isFinite && (-100...100).contains($0) }) else {
            throw DocumentError.invalidValue
        }
    }
    public subscript(field: ImageAdjustmentField) -> Double {
        get { switch field { case .exposure:exposure; case .brightness:brightness; case .contrast:contrast; case .saturation:saturation } }
        set { switch field { case .exposure:exposure=newValue; case .brightness:brightness=newValue; case .contrast:contrast=newValue; case .saturation:saturation=newValue } }
    }
}

public enum ImageAdjustmentField: String, CaseIterable, Sendable {
    case exposure, brightness, contrast, saturation
    public var range: ClosedRange<Double> { self == .exposure ? -4...4 : -100...100 }
    public var localizationKey: String { "adjustment." + rawValue }
}

public extension PhotoDocumentModel {
    mutating func setAdjustments(_ id: UUID, _ adjustments: ImageAdjustments) throws {
        guard let index=layers.firstIndex(where:{$0.id==id}) else {throw DocumentError.missingLayer}
        guard !layers[index].isLocked else {throw DocumentError.lockedLayer}
        guard case .image=layers[index].content else {throw DocumentError.invalidValue}
        try adjustments.validate()
        if layers[index].adjustments != adjustments {layers[index].adjustments=adjustments;revision &+= 1}
    }
}

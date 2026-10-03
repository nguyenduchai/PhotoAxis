import Foundation

public extension RGBAColor {
    var isValid: Bool { [red,green,blue,alpha].allSatisfy { $0.isFinite && (0...1).contains($0) } }
    static let clear = RGBAColor(red:0,green:0,blue:0,alpha:0)
    var hex: String { String(format:"#%02X%02X%02X",Int((red*255).rounded()),Int((green*255).rounded()),Int((blue*255).rounded())) }
    init?(hex: String, alpha: Double = 1) {
        let trimmed=hex.trimmingCharacters(in:.whitespacesAndNewlines)
        let value=trimmed.hasPrefix("#") ? String(trimmed.dropFirst()):trimmed
        guard value.count==6,value.allSatisfy({$0.isHexDigit}),let n=UInt32(value,radix:16),alpha.isFinite,(0...1).contains(alpha) else{return nil}
        self.init(red:Double((n>>16)&255)/255,green:Double((n>>8)&255)/255,blue:Double(n&255)/255,alpha:alpha)
    }
}
public extension TextContent {
    func validate() throws {
        guard fontSize.isFinite,(1...1000).contains(fontSize),lineSpacing.isFinite,(0...1000).contains(lineSpacing),
              !fontName.isEmpty,fontName.utf8.count<=4096,fontFamily.utf8.count<=4096,fontStyle.utf8.count<=4096,
              text.utf8.count<=1_048_576,color.isValid else {throw DocumentError.invalidValue}
    }
}
public extension ShapeContent {
    func validate() throws {
        guard fill.isValid,stroke.isValid,strokeWidth.isFinite,(0...1000).contains(strokeWidth),
              [lineStart.x,lineStart.y,lineEnd.x,lineEnd.y].allSatisfy({$0.isFinite && (0...1).contains($0)}) else{throw DocumentError.invalidValue}
    }
}
public extension PhotoDocumentModel {
    @discardableResult mutating func insertContent(_ content: LayerContent, name:String, transform:ProjectiveTransform, above id:UUID?) throws -> UUID {
        guard layers.count<DocumentLimits.maximumLayers else{throw DocumentError.layerLimit}
        try validateContent(content)
        let layer=PhotoLayer(name:name,content:content,transform:transform)
        _=try LayerGeometry.bounds(size:localSize(of:layer),transform:transform)
        let index=id.flatMap { id in layers.firstIndex{$0.id==id}.map{$0+1} } ?? layers.count
        layers.insert(layer,at:index);revision &+= 1;return layer.id
    }
    mutating func setContent(_ id:UUID,_ content:LayerContent) throws {
        guard let index=layers.firstIndex(where:{$0.id==id}) else{throw DocumentError.missingLayer}
        guard !layers[index].isLocked else{throw DocumentError.lockedLayer}
        try validateContent(content)
        var next=layers[index];next.content=content
        _=try LayerGeometry.bounds(size:localSize(of:next),transform:next.transform,clips:next.clip)
        if next != layers[index] {layers[index]=next;revision &+= 1}
    }
    private func validateContent(_ content:LayerContent) throws {
        switch content {
        case .text(let text):try text.validate()
        case .shape(let shape):try shape.validate()
        case .image(let id):guard sources[id] != nil else{throw DocumentError.missingSource}
        case .paint(let paint): try paint.validate(); guard paint.sourceIDs.isSubset(of:Set(sources.keys)) else { throw DocumentError.missingSource }
        }
    }
}

public extension LayerContent { var isText:Bool {if case .text=self{return true};return false} }

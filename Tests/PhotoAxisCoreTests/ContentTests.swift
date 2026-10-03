import Foundation
import Testing
@testable import PhotoAxisCore

struct ContentTests {
    @Test func typedContentValidationAndAtomicLock() throws {
        var model=try PhotoDocumentModel(name:"Content",canvas:CanvasSize(width:640,height:480),ppi:72)
        var text=TextContent(text:"Tiếng Việt\nPhối cảnh",fontName:"Missing-Font",fontSize:48,color:.black)
        text.layoutSize=try CanvasSize(width:350,height:150);text.alignment = .center;text.lineSpacing=8
        let id=try model.insertContent(.text(text),name:"Chữ",transform:.identity,above:nil)
        #expect(try model.localSize(of:model.layer(id)!)==text.layoutSize)
        var bad=text;bad.fontSize = .nan
        let before=model
        #expect(throws:DocumentError.invalidValue){try model.setContent(id,.text(bad))};#expect(model==before)
        for value in [0.0,1001,.infinity] {bad.fontSize=value;#expect(throws:DocumentError.invalidValue){try bad.validate()}}
        try model.setLock(id,true);let locked=model
        #expect(throws:DocumentError.lockedLayer){try model.setContent(id,.text(text))};#expect(model==locked)
        let copy=try model.duplicate(id,name:"Copy");#expect(model.layer(copy)?.content == .text(text));#expect(model.layer(copy)?.isLocked==true)
    }
    @Test func shapeColorAndContentKeepTransformsAndClip() throws {
        #expect(RGBAColor(hex:"#12aBef")?.hex=="#12ABEF")
        for hex in ["#GGFFFF","12","12345678","#12#3456"] {#expect(RGBAColor(hex:hex)==nil)}
        #expect(!RGBAColor(red:.nan,green:0,blue:0).isValid)
        var shape=ShapeContent(kind:.ellipse,size:try CanvasSize(width:120,height:80),fill:.clear)
        shape.stroke=RGBAColor(red:0.2,green:0.4,blue:0.6,alpha:0.5);shape.strokeWidth=5
        var model=try PhotoDocumentModel(name:"Shape",canvas:CanvasSize(width:400,height:300),ppi:72)
        let id=try model.insertContent(.shape(shape),name:"Hình",transform:LayerGeometry.translation(x:20,y:30),above:nil)
        try model.crop(to:CropRegion(x:30,y:40,width:60,height:50))
        let old=model.layer(id)!;shape.fill = .white;try model.setContent(id,.shape(shape))
        #expect(model.layer(id)?.transform==old.transform);#expect(model.layer(id)?.clip==old.clip)
        shape.strokeWidth = -1;#expect(throws:DocumentError.invalidValue){try shape.validate()}
    }
    @Test func contentLayerQuotaAndHistoryRestoration() throws {
        var model=try PhotoDocumentModel(name:"Quota",canvas:CanvasSize(width:100,height:100),ppi:72)
        let shape=ShapeContent(kind:.line,size:try CanvasSize(width:10,height:10),fill:.clear)
        for n in 0..<50{try model.insertContent(.shape(shape),name:String(n),transform:.identity,above:nil)}
        let before=model
        #expect(throws:DocumentError.layerLimit){try model.insertContent(.shape(shape),name:"51",transform:.identity,above:nil)}
        #expect(model==before)
        var history=DocumentHistory(model:model);let id=model.layers[0].id
        try model.setTransform(id,LayerGeometry.translation(x:20,y:10));history.record(model,command:.transform,sourceBytes:[:]);history.select(0)
        #expect(history.current==before);history.select(1);#expect(history.current==model)
    }
}

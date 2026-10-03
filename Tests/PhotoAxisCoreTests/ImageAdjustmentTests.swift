import Foundation
import Testing
@testable import PhotoAxisCore

struct ImageAdjustmentTests {
    @Test func boundsAndInvalidChangesAreAtomic() throws {
        var m=try PhotoDocumentModel(name:"Adjust",canvas:CanvasSize(width:100,height:80),ppi:72)
        let image=try m.place(.init(id:"asset",size:m.canvas),name:"Image",above:nil)
        let shape=try m.insertContent(.shape(.init(kind:.rectangle,size:m.canvas,fill:.white)),name:"Shape",transform:.identity,above:nil)
        for field in ImageAdjustmentField.allCases {
            for value in [field.range.lowerBound,0,field.range.upperBound] {
                var a=ImageAdjustments();a[field]=value;try m.setAdjustments(image,a);#expect(m.layer(image)?.adjustments==a)
            }
            for value in [field.range.lowerBound-0.01,field.range.upperBound+0.01,Double.nan,Double.infinity] {
                var a=ImageAdjustments();a[field]=value;let before=m
                #expect(throws:DocumentError.invalidValue) {try m.setAdjustments(image,a)};#expect(m==before)
            }
        }
        let original=m
        #expect(throws:DocumentError.invalidValue) {try m.setAdjustments(shape,ImageAdjustments())};#expect(m==original)
        try m.setLock(image,true);let locked=m
        #expect(throws:DocumentError.lockedLayer) {try m.setAdjustments(image,ImageAdjustments())};#expect(m==locked)
    }
    @Test func duplicateAndGeometryPreserveStoredParametersAndSharedSource() throws {
        var m=try PhotoDocumentModel(name:"Projective",canvas:CanvasSize(width:300,height:200),ppi:144)
        let image=try m.place(.init(id:"source",size:m.canvas),name:"Image",above:nil)
        var a=ImageAdjustments();a.exposure=0.75;a.brightness = -24.5;a.contrast=80;a.saturation = -100;a.enabled=false
        try m.setAdjustments(image,a);let copy=try m.duplicate(image,name:"Copy")
        #expect(m.layer(copy)?.adjustments==a && m.sources.count==1)
        try m.setLock(copy,true);try m.setVisibility(copy,false)
        try m.perspectiveCrop(.init([.init(x:20,y:10),.init(x:280,y:30),.init(x:260,y:190),.init(x:30,y:175)]),output:CanvasSize(width:260,height:160))
        #expect(m.layers.allSatisfy{$0.adjustments==a})
        #expect(m.layer(copy)?.isLocked==true && m.layer(copy)?.isVisible==false)
        let matrix=m.layer(image)!.transform,clip=m.layer(image)!.clip
        try m.setAdjustments(image,ImageAdjustments())
        #expect(m.layer(image)?.transform==matrix && m.layer(image)?.clip==clip)
        #expect(m.layer(copy)?.adjustments==a && m.sources.count==1)
    }
}

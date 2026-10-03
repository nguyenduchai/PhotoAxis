import Testing
@testable import PhotoAxisCore

struct CropGeometryTests {
    func document() throws -> PhotoDocumentModel {
        var model=try PhotoDocumentModel(name:"Crop grid",canvas:CanvasSize(width:640,height:480),ppi:72)
        _=try model.place(SourceDescriptor(id:"grid",size:model.canvas),name:"Visible",above:nil)
        let id=try model.duplicate(model.layers[0].id,name:"Hidden locked")
        try model.setVisibility(id,false);try model.setLock(id,true)
        return model
    }
    @Test func cropMapsEveryLayerAndKeepsSourceClip() throws {
        var m=try document();let source=m.sources,ids=m.layers.map(\.id),before=m
        try m.crop(to:.init(x:80,y:60,width:320,height:240))
        #expect(m.canvas == (try CanvasSize(width:320,height:240)));#expect(m.sources == source);#expect(m.layers.map(\.id)==ids)
        #expect(m.layers[1].isLocked && !m.layers[1].isVisible)
        for layer in m.layers {
            #expect(try layer.transform.applying(to:.init(x:80,y:60)) == Point2D(x:0,y:0))
            #expect(LayerGeometry.contains(local:.init(x:100,y:100),size:before.canvas,clips:layer.clip))
            #expect(!LayerGeometry.contains(local:.init(x:20,y:20),size:before.canvas,clips:layer.clip))
        }
        try m.canvasSize(CanvasSize(width:800,height:600),anchorX:1,anchorY:1)
        try m.rotateCanvas(quarterTurns:1);try m.flipCanvas(horizontal:true)
        #expect(!LayerGeometry.contains(local:.init(x:20,y:20),size:before.canvas,clips:m.layers[0].clip))
        #expect(m.layers[0].content == before.layers[0].content)
    }
    @Test func repeatedCropIntersectsAndEmptyLayersAreRetained() throws {
        var m=try document();let id=m.layers[0].id
        try m.crop(to:.init(x:100,y:100,width:200,height:200))
        try m.setTransform(id,LayerGeometry.translation(x:500,y:500))
        try m.crop(to:.init(x:20,y:20,width:80,height:80))
        #expect(m.layers.count==2 && m.sources.count==1)
        #expect(m.layers[0].clip == [[]]);#expect(m.layers[1].clip.count==1)
        #expect(!LayerGeometry.contains(local:.init(x:110,y:110),size:try CanvasSize(width:640,height:480),clips:m.layers[1].clip))
        #expect(LayerGeometry.contains(local:.init(x:140,y:140),size:try CanvasSize(width:640,height:480),clips:m.layers[1].clip))
    }
    @Test func allNineAnchorsAndPPIOnly() throws {
        for y in 0...2 {for x in 0...2 {
            var m=try document();try m.canvasSize(CanvasSize(width:800,height:600),anchorX:x,anchorY:y)
            #expect(try m.layers[0].transform.applying(to:.init(x:0,y:0)) == Point2D(x:Double(x*80),y:Double(y*60)))
            #expect(m.layers[0].transform == m.layers[1].transform)
        }}
        var m=try document();let layers=m.layers
        try m.imageSize(m.canvas,ppi:300);#expect(m.layers==layers && m.ppi==300)
        try m.imageSize(CanvasSize(width:320,height:240),ppi:300)
        #expect(try m.layers[0].transform.applying(to:.init(x:640,y:480)) == Point2D(x:320,y:240))
    }
    @Test func rotationsFlipsAndPixelOutput() throws {
        var m=try document();let original=m
        try m.rotateCanvas(quarterTurns:1)
        #expect(m.canvas == (try CanvasSize(width:480,height:640)))
        #expect(try m.layers[0].transform.applying(to:.init(x:0,y:0)) == Point2D(x:480,y:0))
        try m.rotateCanvas(quarterTurns:3);#expect(m.layers==original.layers && m.canvas==original.canvas)
        try m.flipCanvas(horizontal:true);try m.flipCanvas(horizontal:true);#expect(m.layers==original.layers)
        try m.crop(to:.init(x:80,y:60,width:320,height:240),output:CanvasSize(width:160,height:120))
        #expect(try m.layers[0].transform.applying(to:.init(x:400,y:300)) == Point2D(x:160,y:120))
    }
    @Test func invalidCropAtomicAndProjectiveClip() throws {
        var m=try document();let original=m
        #expect(throws:DocumentError.self){try m.crop(to:.init(x:-1,y:0,width:100,height:100))}
        #expect(m==original)
        #expect(throws:DocumentError.self){try CropRegion(x:0,y:0,width:.nan,height:10).outputSize()}
        #expect(throws:DocumentError.self){try m.imageSize(m.canvas,ppi:.infinity)}
        let id=m.layers[0].id,matrix=try ProjectiveTransform([1,0,10,0,1,20,0.0003,0.0001,1])
        try m.setTransform(id,matrix);try m.crop(to:.init(x:50,y:50,width:200,height:200))
        #expect(m.layers[0].transform.coefficients[6]==matrix.coefficients[6])
        for p in m.layers[0].clip[0] {let out=try m.layers[0].transform.applying(to:p);#expect(out.x >= -1e-7 && out.y >= -1e-7 && out.x<=200+1e-7 && out.y<=200+1e-7)}
    }
}

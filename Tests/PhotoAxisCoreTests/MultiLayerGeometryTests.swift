import Foundation
import Testing
@testable import PhotoAxisCore

struct MultiLayerGeometryTests {
    @Test func homogeneousScaleDoesNotChangeTextRouting() throws {
        for factor in [1e-100, 1e-18, 1.0, -2.0, 1e100] {
            let projective = try ProjectiveTransform([1,0,20,0,1,30,0.0003,0.0002,1].map { $0 * factor })
            let affine = try ProjectiveTransform([1,0,20,0,1,30,0,0,1].map { $0 * factor })
            #expect(!projective.isAffine)
            #expect(affine.isAffine)
        }
    }

    @Test func mixedLayerCropUsesCommonMappingAndIsAtomic() throws {
        let canvas = try CanvasSize(width:640,height:480), output = try CanvasSize(width:400,height:300)
        var model = try PhotoDocumentModel(name:"Mixed geometry",canvas:canvas,ppi:144)
        let source = SourceDescriptor(id:"source",size:canvas)
        let image = try model.place(source,name:"Image",above:nil)
        var text = TextContent(text:"Chữ Việt",fontName:"Helvetica",fontSize:24,color:.black)
        text.layoutSize = try CanvasSize(width:150,height:60)
        let textID = try model.insertContent(.text(text),name:"Text",transform:LayerGeometry.translation(x:100,y:90),above:image)
        let shape = ShapeContent(kind:.ellipse,size:try CanvasSize(width:200,height:100),fill:.white)
        let shapeID = try model.insertContent(.shape(shape),name:"Hidden locked",transform:LayerGeometry.rotation(degrees:15,around:.init(x:0,y:0)).followed(by:LayerGeometry.translation(x:230,y:170)),above:textID)
        try model.setLock(shapeID,true);try model.setVisibility(shapeID,false)
        let before = model
        // Known output -> old document mapping; independent of the solver.
        let inverse = try ProjectiveTransform([1.2,0.08,25,0.04,1.1,30,0.0003,0.0002,1])
        let quad = PerspectiveQuad(try PerspectiveQuad.full(output).points.map { try inverse.applying(to:$0) })
        try model.perspectiveCrop(quad,output:output)
        #expect(model.canvas==output && model.ppi==144 && model.revision==before.revision+1)
        #expect(model.sources==before.sources && model.layers.map(\.id)==before.layers.map(\.id))
        for (old,new) in zip(before.layers,model.layers) {
            #expect(old.content==new.content && old.name==new.name && old.isVisible==new.isVisible && old.isLocked==new.isLocked && old.opacity==new.opacity)
            for local in [Point2D(x:15,y:10),.init(x:50,y:40)] {
                let expected = try inverse.inverted().applying(to:old.transform.applying(to:local)), actual = try new.transform.applying(to:local)
                #expect(hypot(expected.x-actual.x,expected.y-actual.y)<1e-7)
            }
        }
        // A failing last layer must not commit earlier layers or canvas changes.
        var broken = before
        broken.layers[2].content = .image(sourceID:"missing")
        let invalid = broken
        #expect(throws:DocumentError.missingSource) { try broken.perspectiveCrop(quad,output:output) }
        #expect(broken==invalid)
    }
}

import Foundation
import Testing
@testable import PhotoAxisCore

struct PerspectiveGeometryTests {
    let canvas=try! CanvasSize(width:640,height:480)
    let quad=PerspectiveQuad([.init(x:20,y:10),.init(x:620,y:35),.init(x:605,y:460),.init(x:35,y:445)])
    @Test func cornerMappingInverseAndProjectedGrid() throws {
        let output=try CanvasSize(width:600,height:420),mapping=try quad.mapping(in:canvas,output:output),inverse=try mapping.inverted()
        for (i,p) in quad.points.enumerated() {
            let actual=try mapping.applying(to:p),expected=PerspectiveQuad.full(output).points[i]
            #expect(hypot(actual.x-expected.x,actual.y-expected.y)<1e-7)
        }
        for p in [Point2D(x:100,y:80),.init(x:500,y:300),.init(x:320,y:240)] {
            let actual=try inverse.applying(to:mapping.applying(to:p));#expect(hypot(actual.x-p.x,actual.y-p.y)<1e-7)
        }
        let lines=try quad.grid(in:canvas,output:output)
        for n in 0..<2 {
            for p in lines[n*2] {#expect(abs(try mapping.applying(to:p).x-Double(n+1)*200)<1e-7)}
            for p in lines[n*2+1] {#expect(abs(try mapping.applying(to:p).y-Double(n+1)*140)<1e-7)}
        }
        // Perspective thirds differ from linear interpolation along the source edge.
        #expect(abs(lines[0][0].x-(20+600.0/3))>0.5)
    }
    @Test func recoversKnownIndependentAnalyticHomography() throws {
        let output=try CanvasSize(width:400,height:300)
        let known=try ProjectiveTransform([1.2,0.08,25,0.04,1.1,30,0.0003,0.0002,1])
        let source=PerspectiveQuad(try PerspectiveQuad.full(output).points.map{try known.applying(to:$0)})
        let mapping=try source.mapping(in:canvas,output:output)
        for y in stride(from:0.0,through:300,by:30) {for x in stride(from:0.0,through:400,by:40) {
            let p=try mapping.applying(to:known.applying(to:.init(x:x,y:y)))
            #expect(abs(p.x-x)<1e-7 && abs(p.y-y)<1e-7)
        }}
    }
    @Test func rejectsInvalidPolygonsAndSingularDomains() throws {
        let invalid:[PerspectiveQuad]=[
            .init([]),.init([.init(x:0,y:0),.init(x:0,y:0),.init(x:100,y:100),.init(x:0,y:100)]),
            .init([.init(x:0,y:0),.init(x:100,y:100),.init(x:100,y:0),.init(x:0,y:100)]),
            .init([.init(x:0,y:0),.init(x:100,y:0),.init(x:40,y:40),.init(x:100,y:100)]),
            .init([.init(x:0,y:0),.init(x:100,y:0),.init(x:200,y:0.00001),.init(x:0,y:100)]),
            .init([.init(x:0,y:0),.init(x:1,y:0),.init(x:1,y:1),.init(x:0,y:1)]),
            .init([.init(x:-1,y:0),.init(x:100,y:0),.init(x:100,y:100),.init(x:0,y:100)]),
            .init([.init(x:.nan,y:0),.init(x:100,y:0),.init(x:100,y:100),.init(x:0,y:100)])]
        for q in invalid {#expect(throws:PerspectiveError.self){try q.mapping(in:canvas,output:canvas)}}
        let pole=try ProjectiveTransform([1,0,0,0,1,0,-0.01,0,1])
        #expect(throws:PerspectiveError.self){try PerspectiveQuad.validateDomain(PerspectiveQuad.full(canvas).points,mapping:pole)}
    }
    @Test func outputModesLimitsAndSwap() throws {
        let auto=try quad.outputSize(.auto()),swapped=try quad.outputSize(.auto(swapped:true))
        #expect(auto.width==585 && auto.height==430);#expect(swapped.width==430 && swapped.height==585)
        let ratio=try quad.outputSize(.ratio(4.0/3));#expect(abs(Double(ratio.width)/Double(ratio.height)-4.0/3)<0.003)
        #expect(abs(Double(ratio.pixelCount-auto.pixelCount))/Double(auto.pixelCount)<0.005)
        #expect(try quad.outputSize(.pixels(CanvasSize(width:123,height:456))) == CanvasSize(width:123,height:456))
        for value in [0.0,-1,.nan,.infinity,1e300,1e-300] {#expect(throws:PerspectiveError.self){try quad.outputSize(.ratio(value))}}
        let huge=PerspectiveQuad.full(try CanvasSize(width:8000,height:5000))
        #expect(throws:PerspectiveError.self){try huge.outputSize(.ratio(1))}
    }
    @Test func layerIdentityClipsHiddenLockedAndRepeatedCrop() throws {
        var model=try CropGeometryTests().document();let before=model
        try model.perspectiveCrop(quad,output:CanvasSize(width:600,height:420))
        #expect(model.sources==before.sources && model.layers.map(\.id)==before.layers.map(\.id))
        #expect(model.layers[1].isLocked && !model.layers[1].isVisible)
        #expect(model.layers[0].transform==model.layers[1].transform)
        #expect(model.layers[0].content==before.layers[0].content)
        #expect(!LayerGeometry.contains(local:.init(x:5,y:5),size:canvas,clips:model.layers[0].clip))
        let second=PerspectiveQuad([.init(x:40,y:25),.init(x:560,y:40),.init(x:550,y:380),.init(x:50,y:395)])
        try model.perspectiveCrop(second,output:CanvasSize(width:400,height:300))
        for layer in model.layers {for point in layer.clip[0] {
            let p=try layer.transform.applying(to:point);#expect(p.x>=(-1e-6) && p.y>=(-1e-6) && p.x<=400+1e-6 && p.y<=300+1e-6)
        }}
        #expect(model.sources==before.sources)
    }
    @Test func invalidOperationIsAtomicAndViewportIndependent() throws {
        var model=try CropGeometryTests().document();let before=model
        #expect(throws:PerspectiveError.self){try model.perspectiveCrop(.init([]),output:canvas)};#expect(model==before)
        for backing in [1.0,2.0] {for zoom in [0.5,1.0,2.0] {
            let view=try ViewportTransform(zoom:zoom,backingScale:backing,originInView:.init(x:120,y:70))
            for p in quad.points {let round=view.documentPoint(fromView:view.viewPoint(fromDocument:p));#expect(hypot(round.x-p.x,round.y-p.y)<1e-8)}
        }}
    }
}

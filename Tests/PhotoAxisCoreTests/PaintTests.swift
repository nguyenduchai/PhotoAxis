import Foundation
import XCTest
@testable import PhotoAxisCore

final class PaintTests: XCTestCase {
    let size = try! CanvasSize(width:640,height:480)
    func stroke(_ points: [Point2D] = [.init(x:20,y:30),.init(x:400,y:30)]) -> PaintStroke {
        PaintStroke(points:points,diameter:20,hardness:0.75,opacity:0.5,color:.black)
    }
    func testInterpolatedSpacingDotAndInvalidNumbers() throws {
        let line = stroke(), samples = line.samples(); try line.validate(in:size)
        XCTAssertEqual(samples.first,line.points.first); XCTAssertEqual(samples.last,line.points.last)
        for (a,b) in zip(samples,samples.dropFirst()) { XCTAssertLessThanOrEqual(hypot(b.x-a.x,b.y-a.y),line.spacing+1e-9) }
        XCTAssertEqual(stroke([.init(x:0,y:0)]).samples().count,1)
        for value in [Double.nan,.infinity,-1] {
            var bad = line; bad.points[0] = .init(x:value,y:30)
            XCTAssertThrowsError(try PaintContent(size:size,strokes:[bad]).validate())
        }
        var bad = line; bad.hardness = 1.01; XCTAssertThrowsError(try bad.validate(in:size))
        bad = line; bad.sourceID = String(repeating:"a",count:64); XCTAssertThrowsError(try bad.validate(in:size))
    }
    func testQuotaFailureIsAtomicAndLockedPaintCannotBeChanged() throws {
        var model = try PhotoDocumentModel(name:"Paint quotas",canvas:size,ppi:72)
        let id = try model.appendPaint(stroke(),selectedID:nil,source:nil,name:"Paint")
        try model.setLock(id,true); let locked = model
        XCTAssertThrowsError(try model.appendPaint(stroke(),selectedID:id,source:nil,name:"Paint")); XCTAssertEqual(model,locked)
        var huge = stroke(); huge.points = Array(repeating:.init(x:20,y:20),count:4097)
        XCTAssertThrowsError(try model.appendPaint(huge,selectedID:nil,source:nil,name:"Paint")); XCTAssertEqual(model,locked)
        let large = try CanvasSize(width:8000,height:5000)
        let giant = PaintStroke(points:[.init(x:0,y:0),.init(x:8000,y:5000)],diameter:1000)
        XCTAssertThrowsError(try PaintContent(size:large,strokes:Array(repeating:giant,count:4)).validate())
        var dense = stroke(); dense.diameter = 1; dense.points = (0..<110).map { .init(x:$0 % 2 == 0 ? 0:640,y:0) }
        XCTAssertThrowsError(try dense.validate(in:size))
    }
    func testSchemaFourRoundTripAndOldVersionsRejectPaint() throws {
        var model = try PhotoDocumentModel(name:"Nét vẽ có dấu",canvas:size,ppi:144)
        let source = SourceDescriptor(id:String(repeating:"a",count:64),size:size)
        let clone = PaintStroke(kind:.clone,points:[.init(x:100,y:120)],diameter:50,sourceID:source.id,sourceOffset:.init(x:-80,y:-90))
        let id = try model.appendPaint(clone,selectedID:nil,source:source,name:"Clone")
        _ = try model.appendPaint(stroke(),selectedID:id,source:nil,name:"Brush")
        let schema = ProjectSchema(model); XCTAssertEqual(schema.formatVersion,4)
        XCTAssertEqual(try ProjectSchema.decode(schema.encoded()).model(),model)
        for version in 1...3 { var old = schema; old.formatVersion = version; XCTAssertThrowsError(try old.model()) }
        var wrong = schema; wrong.layers[0].type = "image"; XCTAssertThrowsError(try wrong.model())
        wrong = schema; wrong.sources = []; XCTAssertThrowsError(try wrong.model())
    }
    func testCloneReferenceSurvivesSharedSourceAndPaintFollowsGeometry() throws {
        var model = try PhotoDocumentModel(name:"Geometry",canvas:size,ppi:72)
        let source = SourceDescriptor(id:String(repeating:"a",count:64),size:size)
        let image = try model.place(source,name:"Original",above:nil)
        let clone = PaintStroke(kind:.clone,points:[.init(x:100,y:120)],diameter:50,sourceID:source.id,sourceOffset:.init(x:-80,y:-90))
        let paint = try model.appendPaint(clone,selectedID:image,source:source,name:"Clone")
        try model.delete(image); XCTAssertNotNil(model.sources[source.id])
        try model.crop(to:CropRegion(x:10,y:10,width:500,height:400))
        XCTAssertNotEqual(model.layer(paint)?.transform,.identity)
        let new = try model.appendPaint(stroke(),selectedID:paint,source:nil,name:"New canvas paint")
        XCTAssertNotEqual(paint,new); try model.delete(paint); XCTAssertTrue(model.sources.isEmpty)
        XCTAssertEqual(ProjectSchema(model).formatVersion,4)
    }
    func testHistoryAccountsForStrokeMetadataAndSourceRetention() throws {
        let empty = try PhotoDocumentModel(name:"History",canvas:size,ppi:72)
        var model = empty, history = DocumentHistory(model:empty)
        let source = SourceDescriptor(id:String(repeating:"a",count:64),size:size)
        let clone = PaintStroke(kind:.clone,points:[.init(x:100,y:120)],diameter:50,sourceID:source.id,sourceOffset:.init(x:0,y:0))
        let id = try model.appendPaint(clone,selectedID:nil,source:source,name:"Clone")
        XCTAssertTrue(history.record(model,command:.cloneStamp,sourceBytes:[source.id:1000])); XCTAssertTrue(history.retainedSourceIDs.contains(source.id))
        try model.delete(id); history.record(model,command:.delete,sourceBytes:[source.id:1000])
        XCTAssertTrue(history.retainedSourceIDs.contains(source.id))
        _ = try model.appendPaint(stroke(),selectedID:nil,source:nil,name:"Brush")
        history.record(model,command:.brush,sourceBytes:[:],maximumBytes:100)
        XCTAssertTrue(history.entries.isEmpty); XCTAssertEqual(history.current,model); XCTAssertLessThanOrEqual(history.retainedBytes,100)
    }
}

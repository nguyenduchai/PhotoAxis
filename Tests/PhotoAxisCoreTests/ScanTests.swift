import XCTest
import PhotoAxisCore

final class ScanModelTests: XCTestCase {
    func fixture() throws -> (PhotoDocumentModel, UUID) {
        var model = try PhotoDocumentModel(name: "Scan", canvas: CanvasSize(width: 600,height: 800), ppi: 72)
        let id = try model.place(SourceDescriptor(id: String(repeating: "a",count: 64),size: model.canvas), name: "Paper", above: nil)
        return (model,id)
    }
    func testSettingsValidationAtomicLockAndSchemaCompatibility() throws {
        var (model,id) = try fixture(); let original = model
        var settings = ScanSettings(); settings.mode = .blackWhite; settings.curveY = 0.7
        try model.setScan(id,settings)
        XCTAssertEqual(ProjectSchema(model).formatVersion,3)
        XCTAssertEqual(try ProjectSchema.decode(ProjectSchema(model).encoded()).model(),model)
        var downgraded = ProjectSchema(model); downgraded.formatVersion = 1
        XCTAssertThrowsError(try downgraded.encoded())
        let valid = model
        let duplicateID = try model.duplicate(id,name:"Scan copy")
        XCTAssertEqual(model.layer(duplicateID)?.scan,model.layer(id)?.scan)
        XCTAssertEqual(model.sources,valid.sources)
        model = valid
        settings.paper = .nan; XCTAssertThrowsError(try model.setScan(id,settings)); XCTAssertEqual(model,valid)
        settings = ScanSettings(); settings.curveX = 1.01; XCTAssertThrowsError(try model.setScan(id,settings))
        try model.setLock(id,true); XCTAssertThrowsError(try model.setScan(id,nil))
        XCTAssertEqual(try ProjectSchema.decode(ProjectSchema(original).encoded()).model(), original)
        XCTAssertEqual(ProjectSchema(original).formatVersion,1)
    }
    func testDeskewGeometryKeepsSourcesClipsAndNormalizesWithoutStretch() throws {
        var (model,id) = try fixture(); let source = model.sources, original = model
        try model.deskewScan(degrees: -5)
        XCTAssertEqual(model.sources,source); XCTAssertEqual(model.layers[0].content,original.layers[0].content)
        XCTAssertGreaterThan(model.canvas.width,600); XCTAssertGreaterThan(model.canvas.height,800)
        XCTAssertFalse(model.layers[0].clip.isEmpty)
        let center = try model.layer(id)!.transform.applying(to: Point2D(x: 300,y: 400))
        XCTAssertEqual(center.x,Double(model.canvas.width)/2,accuracy: 0.00001)
        XCTAssertEqual(center.y,Double(model.canvas.height)/2,accuracy: 0.00001)
        let before = model; XCTAssertThrowsError(try model.deskewScan(degrees: 16)); XCTAssertEqual(model,before)
        model = original; try model.normalizeScan(to: CanvasSize(width: 1000,height: 1000),ppi: 300)
        let p0 = try model.layer(id)!.transform.applying(to: .init(x:0,y:0)), p1 = try model.layer(id)!.transform.applying(to: .init(x:600,y:800))
        XCTAssertEqual((p1.x-p0.x)/(p1.y-p0.y),0.75,accuracy: 0.00001)
        XCTAssertEqual(p0.x,125,accuracy: 0.00001); XCTAssertEqual(p0.y,0,accuracy: 0.00001)
        XCTAssertEqual(model.ppi,300); XCTAssertEqual(model.sources,source)
    }
}

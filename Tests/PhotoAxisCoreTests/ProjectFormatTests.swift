import Foundation
import XCTest
@testable import PhotoAxisCore

final class ProjectFormatTests: XCTestCase {
    func empty() throws -> ProjectSchema { ProjectSchema(try PhotoDocumentModel(name:"Dự án phố biển",canvas:CanvasSize(width:640,height:480),ppi:144)) }
    func archive(_ schema: ProjectSchema) throws -> Data {
        var data = Data(); try BoundedZIP.write([("document.json",schema.encoded()),("preview.png",Data([1,2,3]))]) { data.append($0) }; return data
    }
    func read(_ data: Data) throws -> [String:Data] {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".paxis")
        defer { try? FileManager.default.removeItem(at:url) }; try data.write(to:url); return try BoundedZIP.read(url:url)
    }
    func positions(_ data: Data, signature: [UInt8]) -> [Int] {
        (0..<(data.count-3)).filter { Array(data[$0..<$0+4]) == signature }
    }
    func set32(_ data: inout Data, _ offset: Int, _ value: UInt32) {
        for i in 0..<4 { data[offset+i] = UInt8((value >> (i*8)) & 255) }
    }
    func testSchemaTypedRoundTripClipsPrecisionAndImageParameters() throws {
        var model = try empty().model()
        let source = SourceDescriptor(id:String(repeating:"a",count:64),size:try CanvasSize(width:640,height:480))
        let image = try model.place(source,name:"Ảnh gốc",above:nil)
        var parameters = ImageAdjustments(); parameters.enabled = false; parameters.exposure = -3.125; parameters.brightness = 19.25; parameters.contrast = -100; parameters.saturation = 100
        try model.setAdjustments(image,parameters)
        let copy = try model.duplicate(image,name:"Bản sao dùng chung nguồn"); try model.setVisibility(copy,false); try model.setLock(copy,true)
        var text = TextContent(text:"Chữ Việt\nDòng hai",fontName:"PhotoAxisMissingFont-Fixture",fontSize:28.25,color:RGBAColor(red:0.4,green:0.7,blue:1,alpha:0.9))
        text.fontFamily = "Gốc"; text.fontStyle = "Bold"; text.alignment = .right; text.lineSpacing = 2.125; text.layoutSize = try CanvasSize(width:200,height:80)
        _ = try model.insertContent(.text(text),name:"Chữ có dấu",transform:LayerGeometry.translation(x:12.125,y:16.875),above:nil)
        let removed = try model.insertContent(.shape(.init(kind:.ellipse,size:CanvasSize(width:20,height:20),fill:.clear)),name:"Fully clipped",transform:.identity,above:nil)
        let idx = model.layers.firstIndex { $0.id == removed }!; model.layers[idx].clip = [[]]
        let schema = ProjectSchema(model), encoded = try schema.encoded(), loaded = try ProjectSchema.decode(encoded).model()
        XCTAssertEqual(loaded,model); XCTAssertEqual(loaded.sources.count,1); XCTAssertEqual(loaded.layers[idx].clip,[[]])
        XCTAssertFalse(String(decoding:encoded,as:UTF8.self).contains("language")); XCTAssertFalse(String(decoding:encoded,as:UTF8.self).contains("savedID"))
        let result = try read(archive(try empty())); XCTAssertNotNil(result["document.json"])
        var pole = try empty().model()
        _ = try pole.insertContent(.shape(.init(kind:.rectangle,size:CanvasSize(width:10,height:10),fill:.white)),name:"Pole outside retained clip",transform:.identity,above:nil)
        pole.layers[0].transform = try ProjectiveTransform([1,0,0,0,1,0,-0.25,0,1])
        pole.layers[0].clip = [[.init(x:0,y:0),.init(x:2,y:0),.init(x:2,y:2),.init(x:0,y:2)]]
        XCTAssertEqual(try ProjectSchema.decode(ProjectSchema(pole).encoded()).model(),pole)
    }
    func testSchemaRejectsInvalidVersionPayloadMatrixReferenceAndQuotas() throws {
        var schema = try empty(); schema.formatVersion = 5
        XCTAssertThrowsError(try schema.model()) { XCTAssertEqual($0 as? ProjectError,.newerVersion(5)) }
        XCTAssertThrowsError(try ProjectSchema.decode(Data("{\"formatIdentifier\":\"photoaxis.document\",\"formatVersion\":5,\"futureLayout\":{}}".utf8))) { XCTAssertEqual($0 as? ProjectError,.newerVersion(5)) }
        schema.formatVersion = 1; schema.formatIdentifier = "other"; XCTAssertThrowsError(try schema.model())
        schema = try empty(); schema.ppi = .nan; XCTAssertThrowsError(try schema.model())
        var model = try empty().model(); _ = try model.insertContent(.shape(.init(kind:.rectangle,size:CanvasSize(width:10,height:10),fill:.white)),name:"Shape",transform:.identity,above:nil)
        schema = ProjectSchema(model); schema.layers[0].transform = [1,2]; XCTAssertThrowsError(try schema.model())
        schema = ProjectSchema(model); schema.layers[0].imageAdjustments = ImageAdjustments(); XCTAssertThrowsError(try schema.model())
        schema = ProjectSchema(model); schema.layers[0].opacity = 1.01; XCTAssertThrowsError(try schema.model())
        schema = ProjectSchema(model); schema.layers = Array(repeating:schema.layers[0],count:51); XCTAssertThrowsError(try schema.model())
        let tooDeep = Data((String(repeating:"[",count:25) + "0" + String(repeating:"]",count:25)).utf8)
        XCTAssertThrowsError(try ProjectSchema.decode(tooDeep))
        XCTAssertThrowsError(try ProjectSchema.decode(Data("{\"formatVersion\":2,\"formatVersion\":1}".utf8)))
        XCTAssertThrowsError(try ProjectSchema.decode(Data("{\"formatVersion\":2,\"format\\u0056ersion\":1}".utf8)))
        XCTAssertThrowsError(try ProjectSchema.decode(Data("{\"canvas\":{\"width\":8001,\"height\":1}}".utf8)))
    }
    func testZIPRejectsCRCTruncationTraversalSymlinkEncryptionOverlapAndBombBeforeInflate() throws {
        let good = try archive(empty()); _ = try read(good)
        XCTAssertThrowsError(try read(Data(good.dropLast())))
        let central = positions(good,signature:[0x50,0x4b,0x01,0x02]), local = positions(good,signature:[0x50,0x4b,0x03,0x04])
        XCTAssertEqual(central.count,2); XCTAssertEqual(local.count,2)
        var bad = good; bad[local[1]+30+"preview.png".count] ^= 1; XCTAssertThrowsError(try read(bad))
        bad = good; set32(&bad,central[1]+38,0xa1ff0000); XCTAssertThrowsError(try read(bad))
        bad = good; bad[central[0]+8] = 1; XCTAssertThrowsError(try read(bad))
        bad = good; set32(&bad,central[1]+42,0); XCTAssertThrowsError(try read(bad))
        bad = good; set32(&bad,central[1]+24,UInt32(BoundedZIP.previewLimit+1)); XCTAssertThrowsError(try read(bad))
        bad = good; bad.replaceSubrange(central[1]+46..<central[1]+57,with:Data("../evil.png".utf8)); XCTAssertThrowsError(try read(bad))
        bad = good; bad[central[0]+28] = 0xff; XCTAssertThrowsError(try read(bad))
        var duplicate = Data(); XCTAssertThrowsError(try BoundedZIP.write([("preview.png",Data()),("preview.png",Data())]) { duplicate.append($0) })
    }
    func testZIPDeclaredAssetsAndSparseArchiveSizeAreBounded() throws {
        let schema = try empty()
        var data = Data(); try BoundedZIP.write([("document.json",schema.encoded()),("preview.png",Data()),("assets/"+String(repeating:"a",count:64),Data([1]))]) { data.append($0) }
        XCTAssertThrowsError(try read(data)) { XCTAssertEqual($0 as? ProjectError,.assetMismatch) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath:url.path,contents:nil); defer { try? FileManager.default.removeItem(at:url) }
        let handle = try FileHandle(forWritingTo:url); try handle.truncate(atOffset:UInt64(BoundedZIP.archiveLimit)+1); try handle.close()
        XCTAssertThrowsError(try BoundedZIP.read(url:url)) { XCTAssertEqual($0 as? ProjectError,.resourceLimit) }
    }
}

import XCTest
@testable import PhotoAxisCore

final class ExportOptionsTests: XCTestCase {
    func testExportBoundsQualityPPIAndOpaqueMatte() throws {
        var options = ExportOptions(size:try CanvasSize(width:1,height:1),ppi:72)
        try options.validate(); XCTAssertEqual(options.format,.png); XCTAssertTrue(options.transparency); XCTAssertEqual(options.matte,.white)
        for quality in [1,100] { options.quality = quality; try options.validate() }
        for quality in [0,101] { options.quality = quality; XCTAssertThrowsError(try options.validate()) }
        options.quality = 90
        for ppi in [Double.nan,Double.infinity,0,-1] { options.ppi = ppi; XCTAssertThrowsError(try options.validate()) }
        options.ppi = 144.125; options.matte = .clear; XCTAssertThrowsError(try options.validate())
        options.matte = RGBAColor(red:0.1,green:0.3,blue:0.8); try options.validate()
        XCTAssertThrowsError(try CanvasSize(width:8001,height:1)); XCTAssertThrowsError(try CanvasSize(width:8000,height:5001))
    }
}

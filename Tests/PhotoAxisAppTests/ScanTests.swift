import AppKit
import XCTest
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class ScanTests: XCTestCase {
    let pipeline = ImagePipeline()
    var evidence: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["PHOTOAXIS_BUILD_ROOT"] ?? NSHomeDirectory()+"/Library/Developer/PhotoAxisBuilds/83990cd22abb").appendingPathComponent("scan-tests") }
    func image(width: Int = 600, height: Int = 800, pageBoundary: Bool = false, textAngle: Double? = nil) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil,width: width,height: height,bitsPerComponent: 8,bytesPerRow: width*4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        if pageBoundary {
            context.setFillColor(CGColor(red: 0.08,green: 0.15,blue: 0.22,alpha: 1)); context.fill(CGRect(x:0,y:0,width:width,height:height))
            context.setFillColor(CGColor(gray: 0.95,alpha: 1)); context.fill(CGRect(x:80,y:80,width:width-160,height:height-160))
        } else {
            for x in 0..<width {
                let value = 0.52+0.32*Double(x)/Double(width)
                context.setFillColor(CGColor(red: value,green: value*0.94,blue: value*0.86,alpha: 1)); context.fill(CGRect(x:x,y:0,width:1,height:height))
            }
        }
        if let textAngle {
            context.saveGState(); context.translateBy(x: Double(width)/2,y:Double(height)/2); context.rotate(by:textAngle * .pi/180)
            context.translateBy(x: -Double(width)/2,y:-Double(height)/2)
            let previous = NSGraphicsContext.current
            NSGraphicsContext.current = NSGraphicsContext(cgContext:context,flipped:false)
            for y in stride(from:150,through:height-150,by:55) {
                ("PhotoAxis document scan 12345" as NSString).draw(at: NSPoint(x:100,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:22),.foregroundColor:NSColor.black])
            }
            NSGraphicsContext.current = previous; context.restoreGState()
        } else {
            context.setFillColor(CGColor(gray: 0.05,alpha: 1))
            for y in stride(from:150,through:height-150,by:45) { context.fill(CGRect(x:120,y:y,width:width-240,height:3)) }
        }
        return try XCTUnwrap(context.makeImage())
    }
    func write(_ image: CGImage, _ url: URL) throws {
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil))
        CGImageDestinationAddImage(destination,image,nil); XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
    func fixture(_ name: String, _ input: CGImage) async throws -> PhotoDocument {
        try FileManager.default.createDirectory(at:evidence,withIntermediateDirectories:true)
        let url = evidence.appendingPathComponent(name); try write(input,url)
        let asset = try await pipeline.prepare(.file(url),budget:ImportBudget())
        let document = PhotoDocument(model:try PhotoDocumentModel(name:name,canvas:asset.descriptor.size,ppi:72),localization:L10n(choice:.english))
        try document.place(asset,recordHistory:false); document.markSaved(stateID:document.history.stateID); return document
    }
    func pixel(_ image: CGImage, x: Int, y: Int) throws -> NSColor {
        try XCTUnwrap(NSBitmapImageRep(cgImage:image).colorAt(x:x,y:y)?.usingColorSpace(.sRGB))
    }
    func testCleanupWhiteningAdaptiveTextAndSourceRoundTrip() async throws {
        let document = try await fixture("dirty-paper.png",image()), original = document.model, bytes = document.assets.mapValues(\.data)
        let before = try await pipeline.renderDocument(model:original,assets:document.assets)
        var settings = ScanSettings(); settings.paper = 1; settings.denoise = 0; settings.sharpness = 0
        try document.perform(.scan) { try $0.setScan(document.selectedLayerID!,settings) }
        let clean = try await pipeline.renderDocument(model:document.model,assets:document.assets); try write(clean,evidence.appendingPathComponent("paper-clean.png"))
        let old = try pixel(before,x:60,y:400), white = try pixel(clean,x:60,y:400)
        XCTAssertGreaterThan(white.redComponent,0.96); XCTAssertGreaterThan(white.redComponent,old.redComponent+0.2)
        XCTAssertEqual(white.redComponent,white.blueComponent,accuracy:0.025)
        settings.mode = .blackWhite; settings.threshold = 0.05
        try document.perform(.scan) { try $0.setScan(document.selectedLayerID!,settings) }
        let bw = try await pipeline.renderDocument(model:document.model,assets:document.assets); try write(bw,evidence.appendingPathComponent("paper-bw.png"))
        XCTAssertGreaterThan(try pixel(bw,x:60,y:400).redComponent,0.99)
        // Search the expected line region rather than treating raster row origin as a UI coordinate.
        let darkRows = try (100..<700).filter { try pixel(bw,x:200,y:$0).redComponent < 0.01 }
        XCTAssertGreaterThan(darkRows.count,20); XCTAssertLessThan(darkRows.count,100)
        XCTAssertEqual(document.assets.mapValues(\.data),bytes)
        let project = evidence.appendingPathComponent("scan-roundtrip.paxis"), store = ProjectStore(pipeline:pipeline)
        try await store.save(document.snapshot(),to:project); let loaded = try await store.open(project)
        XCTAssertEqual(loaded.model,document.model); XCTAssertEqual(loaded.assets.mapValues(\.data),bytes)
        let reopened = try await pipeline.renderDocument(model:loaded.model,assets:loaded.assets)
        XCTAssertEqual(reopened.dataProvider?.data as Data?,bw.dataProvider?.data as Data?)
        document.undoManager?.undo(); document.undoManager?.undo(); XCTAssertEqual(document.model,original)
    }
    func testPageDetectionAndTextDeskewRefuseBlank() async throws {
        let detector = ScanDetector(), boundary = try image(pageBoundary:true)
        let page = try await detector.page(in:boundary,canvas:CanvasSize(width:600,height:800))
        XCTAssertGreaterThanOrEqual(page.confidence,0.6)
        let center = page.quad.points.reduce(Point2D(x:0,y:0)) { .init(x:$0.x+$1.x/4,y:$0.y+$1.y/4) }
        XCTAssertEqual(center.x,300,accuracy:10); XCTAssertEqual(center.y,400,accuracy:10)
        let angle = try await detector.deskew(in:image(width:800,height:1000,textAngle:4))
        XCTAssertEqual(abs(angle),4,accuracy:1)
        let blank = try XCTUnwrap(CGContext(data:nil,width:400,height:400,bitsPerComponent:8,bytesPerRow:1600,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage())
        do { _ = try await detector.page(in:blank,canvas:CanvasSize(width:400,height:400)); XCTFail("Blank page must not fabricate a boundary") } catch ScanError.noPage {}
        do { _ = try await detector.deskew(in:blank); XCTFail("Blank page must not fabricate an angle") } catch ScanError.noTextAngle {}
    }
    func testBowChangesPixelsWithoutExposingClippedSource() async throws {
        let document = try await fixture("bow-input.png",image()), id = document.selectedLayerID!, bytes = document.assets.mapValues(\.data)
        try document.perform(.crop) { try $0.crop(to:.init(x:0,y:0,width:300,height:800)) }
        try document.perform(.canvasSize) { try $0.canvasSize(CanvasSize(width:600,height:800),anchorX:0,anchorY:0) }
        let before = try await pipeline.renderDocument(model:document.model,assets:document.assets)
        var settings = ScanSettings(); settings.paper = 0; settings.denoise = 0; settings.sharpness = 0; settings.curveX = -1; settings.curveY = 0.7
        try document.perform(.scan) { try $0.setScan(id,settings) }
        let after = try await pipeline.renderDocument(model:document.model,assets:document.assets); try write(after,evidence.appendingPathComponent("bow-clipped.png"))
        XCTAssertNotEqual(after.dataProvider?.data as Data?,before.dataProvider?.data as Data?)
        for x in stride(from:330,to:600,by:35) { XCTAssertEqual(try pixel(after,x:x,y:400).alphaComponent,0,accuracy:1.0/255) }
        XCTAssertEqual(document.assets.mapValues(\.data),bytes)
    }
    func testBowCorrectionStraightensKnownCurvedBaseline() async throws {
        let w = 600, h = 800, baseline = 250.0
        let context = try XCTUnwrap(CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray:1,alpha:1)); context.fill(CGRect(x:0,y:0,width:w,height:h))
        context.setStrokeColor(CGColor(gray:0,alpha:1)); context.setLineWidth(3); context.beginPath()
        // A photographed horizontal baseline with a smooth, known center bow.
        for x in 0..<w {
            let u = Double(x)/Double(w), y = baseline + 96*4*u*(1-u)*sin(.pi*baseline/Double(h))
            if x == 0 { context.move(to:CGPoint(x:Double(x),y:y)) } else { context.addLine(to:CGPoint(x:Double(x),y:y)) }
        }
        context.strokePath()
        let d = try await fixture("known-bow.png",XCTUnwrap(context.makeImage())), id = d.selectedLayerID!
        let before = try await pipeline.renderDocument(model:d.model,assets:d.assets)
        func spread(_ image:CGImage) throws -> Double {
            var centers:[Double] = []
            for x in stride(from:40,through:560,by:40) {
                let rows = try (100..<700).filter { try pixel(image,x:x,y:$0).redComponent < 0.3 }
                XCTAssertFalse(rows.isEmpty)
                if !rows.isEmpty { centers.append(Double(rows.reduce(0,+))/Double(rows.count)) }
            }
            return (centers.max() ?? 0)-(centers.min() ?? 0)
        }
        var settings = ScanSettings(); settings.paper = 0; settings.denoise = 0; settings.sharpness = 0; settings.curveY = 1
        try d.perform(.scan) { try $0.setScan(id,settings) }
        let after = try await pipeline.renderDocument(model:d.model,assets:d.assets)
        let oldSpread = try spread(before), newSpread = try spread(after)
        try write(after,evidence.appendingPathComponent("known-bow-corrected.png"))
        XCTAssertGreaterThan(oldSpread,35); XCTAssertLessThan(newSpread,oldSpread*0.2)
        try JSONSerialization.data(withJSONObject:["baselineBeforeSpreadPx":oldSpread,"baselineAfterSpreadPx":newSpread]).write(to:evidence.appendingPathComponent("bow-metrics.json"))
    }
    func testCleanupPreservesAlphaAndDisabledIsExact() async throws {
        let url = Bundle(for:Self.self).resourceURL!.appendingPathComponent("P02/alpha-edges.png")
        let asset = try await pipeline.prepare(.file(url),budget:ImportBudget())
        let d = PhotoDocument(model:try PhotoDocumentModel(name:"alpha",canvas:asset.descriptor.size,ppi:72),localization:L10n(choice:.english))
        try d.place(asset,recordHistory:false); let before = try await pipeline.renderDocument(model:d.model,assets:d.assets)
        var settings = ScanSettings(); settings.mode = .gray
        try d.perform(.scan) { try $0.setScan(d.selectedLayerID!,settings) }
        let after = try await pipeline.renderDocument(model:d.model,assets:d.assets)
        for y in stride(from:0,to:after.height,by:19) { for x in stride(from:0,to:after.width,by:23) {
            XCTAssertEqual(try pixel(after,x:x,y:y).alphaComponent,try pixel(before,x:x,y:y).alphaComponent,accuracy:1.0/255)
        } }
        settings.enabled = false; try d.perform(.scan) { try $0.setScan(d.selectedLayerID!,settings) }
        let bypass = try await pipeline.renderDocument(model:d.model,assets:d.assets)
        XCTAssertEqual(bypass.dataProvider?.data as Data?,before.dataProvider?.data as Data?)
    }
    func waitForPreview(_ controller: ScanController) async throws {
        for _ in 0..<200 { if controller.applyButton.isEnabled { return }; try await Task.sleep(for:.milliseconds(50)) }
        XCTFail(controller.notice.stringValue)
    }
    func testNativePreviewCancelSingleUndoAndBilingualControls() async throws {
        for language in [InterfaceLanguage.vietnamese,.english] {
            let document = try await fixture("native-"+language.rawValue+".png",image()), before = document.model
            let sheet = try ScanController(document:document,pipeline:pipeline,localization:L10n(choice:language))
            sheet.showWindow(nil); defer { sheet.cancel(); sheet.close() }
            try await waitForPreview(sheet); XCTAssertEqual(document.model,before); XCTAssertEqual(document.history.entries.count,0)
            for value in [0.1,0.3,0.5,0.8] { sheet.sliders[0].doubleValue=value; sheet.changed() }
            XCTAssertFalse(sheet.applyButton.isEnabled); XCTAssertEqual(document.model,before)
            sheet.preview(); try await waitForPreview(sheet); sheet.apply()
            XCTAssertEqual(document.history.entries.count,1); XCTAssertNotNil(document.model.layers[0].scan)
            document.undoManager?.undo(); XCTAssertEqual(document.model,before); document.undoManager?.redo()
            let applied = document.model
            let cancel = try ScanController(document:document,pipeline:pipeline,localization:L10n(choice:language))
            try await waitForPreview(cancel); cancel.sliders[0].doubleValue=0; cancel.changed(); cancel.cancel()
            XCTAssertEqual(document.model,applied)
        }
    }
    func testNativeBatchOrderAndInvalidSizeCannotApply() async throws {
        let document = try await fixture("batch-preview.png",image())
        let files = [evidence.appendingPathComponent("First.png"),evidence.appendingPathComponent("Second.png")]
        let sheet = try ScanController(document:document,pipeline:pipeline,localization:L10n(choice:.vietnamese),batchFiles:files)
        sheet.showWindow(nil); defer { sheet.cancel(); sheet.close() }
        try await waitForPreview(sheet)
        XCTAssertEqual(sheet.width.accessibilityLabel(),L10n(choice:.vietnamese).text("document.width"))
        XCTAssertEqual(sheet.numberOfRows(in:sheet.pageList),2)
        sheet.pageList.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false); sheet.movePageDown()
        let first = sheet.tableView(sheet.pageList,viewFor:nil,row:0) as? NSTextField
        XCTAssertEqual(first?.stringValue,"1. Second.png")
        sheet.movePageUp()
        let restored = sheet.tableView(sheet.pageList,viewFor:nil,row:0) as? NSTextField
        XCTAssertEqual(restored?.stringValue,"1. First.png")
        // A folder picker's text notification must not invalidate a ready scan recipe.
        NotificationCenter.default.post(name:NSControl.textDidChangeNotification,object:NSTextField())
        XCTAssertTrue(sheet.applyButton.isEnabled)
        sheet.paperSize.selectItem(at:4); sheet.width.stringValue = "8001"; sheet.changed(); sheet.preview()
        try await Task.sleep(for:.milliseconds(150)); XCTAssertFalse(sheet.applyButton.isEnabled)
        XCTAssertNil(document.model.layers[0].scan)
        sheet.width.stringValue = "600"; sheet.height.stringValue = "800"; sheet.changed(); sheet.preview()
        try await waitForPreview(sheet); XCTAssertTrue(sheet.applyButton.isEnabled)
    }
    func testBatchOutputsPageOrderHashesPDFAndRollback() async throws {
        try FileManager.default.createDirectory(at:evidence,withIntermediateDirectories:true)
        let parent = evidence.appendingPathComponent("batch-"+UUID().uuidString); try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:false)
        let input = evidence.appendingPathComponent("batch-source.png"); try write(image(),input)
        let original = try Data(contentsOf:input), store = ScanBatchStore()
        var recipe = ScanRecipe(); recipe.settings.mode = .gray; recipe.size = try CanvasSize(width:300,height:400); recipe.ppi = 100
        let result = try await store.run([input,input],recipe:recipe,autoPage:false,autoDeskew:false,parent:parent)
        let pdf = try XCTUnwrap(PDFDocument(url:result.appendingPathComponent("pages.pdf")))
        XCTAssertEqual(pdf.pageCount,2); XCTAssertEqual(pdf.page(at:0)!.bounds(for:.mediaBox).width,216,accuracy:0.01)
        let receipt = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:result.appendingPathComponent("manifest.json"))) as? [String:Any])
        XCTAssertEqual(receipt["applicationBuild"] as? String,"4")
        XCTAssertNotNil(receipt["operatingSystem"] as? String)
        XCTAssertEqual((receipt["targetCanvas"] as? [String:Int])?["width"],300)
        let pages = try XCTUnwrap(receipt["pages"] as? [[String:Any]]); XCTAssertEqual(pages.count,2)
        for n in 1...2 {
            let number = String(format:"%04d",n), png = result.appendingPathComponent("pages/"+number+".png"), project = result.appendingPathComponent("projects/"+number+".paxis")
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(png as CFURL,nil)), props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any])
            XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int,300); XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int,400)
            XCTAssertEqual(props[kCGImagePropertyDPIWidth] as? Double,100); XCTAssertNil(props[kCGImagePropertyGPSDictionary])
            let loaded = try await ProjectStore(pipeline:pipeline).open(project)
            XCTAssertEqual(loaded.assets.values.first?.data,original)
            XCTAssertEqual(pages[n-1]["pngSHA256"] as? String,ImagePipeline.digest(try Data(contentsOf:png)))
        }
        XCTAssertEqual(try Data(contentsOf:input),original)
        let invalid = parent.appendingPathComponent("invalid.txt"); try Data("invalid".utf8).write(to:invalid)
        let names = Set(try FileManager.default.contentsOfDirectory(atPath:parent.path))
        do { _ = try await store.run([input,invalid],recipe:recipe,autoPage:false,autoDeskew:false,parent:parent); XCTFail("Must rollback failed batch") } catch {}
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath:parent.path)),names)
        let task = Task { try await store.run([input],recipe:recipe,autoPage:false,autoDeskew:false,parent:parent) { _,_,_ in try? await Task.sleep(for:.seconds(5)) } }
        try await Task.sleep(for:.milliseconds(100)); task.cancel()
        do { _ = try await task.value; XCTFail("Must cancel") } catch is CancellationError {}
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath:parent.path)),names)
    }
}

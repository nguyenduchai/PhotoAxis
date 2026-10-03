import AppKit
import XCTest
import ImageIO
import UniformTypeIdentifiers
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class ExportTests: XCTestCase {
    var outputRoot: URL { (0..<5).reduce(Bundle.main.bundleURL) { url,_ in url.deletingLastPathComponent() }.appendingPathComponent("p10-native-tests") }
    func output(_ name:String) throws -> URL { try FileManager.default.createDirectory(at:outputRoot,withIntermediateDirectories:true); return outputRoot.appendingPathComponent(name) }
    func fixture(_ name:String) -> URL { Bundle(for:Self.self).resourceURL!.appendingPathComponent(name) }
    func document(_ name:String) async throws -> (PhotoDocument,ImagePipeline) {
        let pipeline = ImagePipeline(), asset = try await pipeline.prepare(.file(fixture(name)),budget:ImportBudget())
        let document = PhotoDocument(model:try PhotoDocumentModel(name:"Export fixture",canvas:asset.descriptor.size,ppi:144),localization:L10n(choice:.english))
        try document.place(asset,recordHistory:false); return (document,pipeline)
    }
    func inspect(_ url:URL) throws -> (CGImage,[CFString:Any],Data) {
        let bytes = try Data(contentsOf:url), source = try XCTUnwrap(CGImageSourceCreateWithData(bytes as CFData,nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source,0,nil)), props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any])
        XCTAssertNil(props[kCGImagePropertyGPSDictionary]); XCTAssertEqual(image.bitsPerComponent,8)
        return (image,props,bytes)
    }
    func rgba(_ image:CGImage,_ x:Int,_ y:Int) throws -> [Double] {
        let rep = NSBitmapImageRep(cgImage:image), c = try XCTUnwrap(rep.colorAt(x:x,y:y))
        var v = [c.redComponent,c.greenComponent,c.blueComponent,c.alphaComponent]
        let color = try XCTUnwrap(NSColor(colorSpace:rep.colorSpace,components:&v,count:4).usingColorSpace(.sRGB))
        return [color.redComponent,color.greenComponent,color.blueComponent,color.alphaComponent]
    }
    func testPNGAlphaICCResizePPIAndNoDocumentMutation() async throws {
        let (document,pipeline) = try await document("P02/alpha-edges.png"), snapshot = document.snapshot()
        let store = ExportStore(pipeline:pipeline), url = try output("alpha.png"), original = try await pipeline.renderDocument(model:document.model,assets:document.assets)
        var options = ExportOptions(size:document.model.canvas,ppi:144.125)
        try await store.write(snapshot,options:options,to:url)
        let (image,props,bytes) = try inspect(url)
        XCTAssertNotNil(bytes.range(of:Data("iCCP".utf8))); XCTAssertNotNil(props[kCGImagePropertyProfileName]); XCTAssertNotNil(image.colorSpace?.copyICCData())
        XCTAssertEqual(props[kCGImagePropertyDPIWidth] as? Double ?? 0,144.125,accuracy:0.025)
        var partial = 0
        for y in stride(from:0,to:480,by:17) { for x in stride(from:0,to:640,by:17) {
            let expected = try rgba(original,x,y), actual = try rgba(image,x,y)
            XCTAssertEqual(actual[3],expected[3],accuracy:1.0/255)
            if expected[3]>0.1 && expected[3]<0.9 { partial += 1; for c in 0..<3 { XCTAssertEqual(actual[c],expected[c],accuracy:0.025) } }
        } }; XCTAssertGreaterThan(partial,10)
        options.size = try CanvasSize(width:320,height:240); options.ppi = 300
        try await store.write(snapshot,options:options,to:output("resized.png"))
        let (resized,resizedProps,_) = try inspect(output("resized.png")); XCTAssertEqual(resized.width,320); XCTAssertEqual(resized.height,240)
        XCTAssertEqual(resizedProps[kCGImagePropertyDPIHeight] as? Double ?? 0,300,accuracy:0.025)
        XCTAssertEqual(document.model,snapshot.model); XCTAssertEqual(document.assets.mapValues(\.data),snapshot.assets.mapValues(\.data)); XCTAssertTrue(document.isDocumentEdited)
        XCTAssertEqual(document.history.stateID,snapshot.stateID)
    }
    func testJPEGWhiteAndColoredMattePNGFlattenQualityAndLinearAlphaEdges() async throws {
        let (d,p) = try await document("P02/alpha-edges.png"), snapshot = d.snapshot(), store = ExportStore(pipeline:p)
        var options = ExportOptions(size:d.model.canvas,ppi:96); options.format = .jpeg; options.quality = 100
        let white = try output("matte-white.jpg"); try await store.write(snapshot,options:options,to:white)
        let (whiteImage,_,jpeg) = try inspect(white); XCTAssertNotNil(jpeg.range(of:Data("ICC_PROFILE\0".utf8)))
        let whiteCorner = try rgba(whiteImage,0,0); for component in whiteCorner { XCTAssertEqual(component,1,accuracy:0.01) }
        options.matte = RGBAColor(red:0.1,green:0.3,blue:0.8)
        let colored = try output("matte-blue.jpg"); try await store.write(snapshot,options:options,to:colored)
        let (coloredImage,_,_) = try inspect(colored), corner = try rgba(coloredImage,0,0)
        for (a,b) in zip(corner.prefix(3),[0.1,0.3,0.8]) { XCTAssertEqual(a,b,accuracy:0.015) }; XCTAssertEqual(corner[3],1)
        options.format = .png; options.transparency = false
        let flat = try output("matte-blue.png"); try await store.write(snapshot,options:options,to:flat)
        let (flatImage,_,_) = try inspect(flat), source = try await p.renderDocument(model:d.model,assets:d.assets)
        func linear(_ c:Double)->Double { c<=0.04045 ? c/12.92 : pow((c+0.055)/1.055,2.4) }
        func srgb(_ c:Double)->Double { c<=0.0031308 ? c*12.92 : 1.055*pow(c,1/2.4)-0.055 }
        var count = 0
        for y in stride(from:0,to:480,by:17) { for x in stride(from:0,to:640,by:17) {
            let original = try rgba(source,x,y), actual = try rgba(flatImage,x,y)
            if original[3]>0.05 && original[3]<0.95 {
                count += 1
                for c in 0..<3 { let expected = srgb(linear(original[c])*original[3]+linear([0.1,0.3,0.8][c])*(1-original[3])); XCTAssertEqual(actual[c],expected,accuracy:0.017) }
            }; XCTAssertEqual(actual[3],1)
        } }; XCTAssertGreaterThan(count,20)
        options.format = .jpeg; options.quality = 1; try await store.write(snapshot,options:options,to:output("quality-1.jpg"))
        XCTAssertLessThan(try Data(contentsOf:output("quality-1.jpg")).count,jpeg.count)
    }
    func testFreshMetadataDropsGPSKeepsEXIFOrientationAndConvertsP3GrayDepth() async throws {
        let base = try XCTUnwrap(CGImageSourceCreateWithURL(fixture("P02/grid-corners.png") as CFURL,nil))
        let raw = try XCTUnwrap(CGImageSourceCreateImageAtIndex(base,0,nil)), gps = try output("synthetic-gps.jpg")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(gps as CFURL,UTType.jpeg.identifier as CFString,1,nil))
        let properties: [CFString:Any] = [kCGImagePropertyGPSDictionary:[kCGImagePropertyGPSLatitude:10.123,kCGImagePropertyGPSLatitudeRef:"N",kCGImagePropertyGPSLongitude:108.456,kCGImagePropertyGPSLongitudeRef:"E"],kCGImagePropertyOrientation:6]
        CGImageDestinationAddImage(destination,raw,properties as CFDictionary); XCTAssertTrue(CGImageDestinationFinalize(destination))
        let gpsProbe = try XCTUnwrap(CGImageSourceCreateWithURL(gps as CFURL,nil)), gpsProps = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(gpsProbe,0,nil) as? [CFString:Any])
        XCTAssertNotNil(gpsProps[kCGImagePropertyGPSDictionary])
        let pipeline = ImagePipeline(), asset = try await pipeline.prepare(.file(gps),budget:ImportBudget())
        let d = PhotoDocument(model:try PhotoDocumentModel(name:"GPS synthetic",canvas:asset.descriptor.size,ppi:72)); try d.place(asset,recordHistory:false)
        let snapshot = d.snapshot(), store = ExportStore(pipeline:pipeline)
        for format in ExportFormat.allCases {
            var options = ExportOptions(size:d.model.canvas,ppi:144); options.format = format
            let url = try output("gps-stripped."+(format == .png ? "png":"jpg")); try await store.write(snapshot,options:options,to:url)
            let (image,props,_) = try inspect(url); XCTAssertEqual(image.width,480); XCTAssertEqual(image.height,640)
            XCTAssertNil(props[kCGImagePropertyGPSDictionary]); XCTAssertEqual(props[kCGImagePropertyOrientation] as? Int ?? 1,1)
            let corner = try rgba(image,30,30); XCTAssertGreaterThan(corner[0],0.95); XCTAssertGreaterThan(corner[1],0.95); XCTAssertLessThan(corner[2],0.05)
        }
        for name in ["P02/colors-display-p3.png","P10/gray-8.png","P10/gray-16.png"] {
            let (doc,p) = try await document(name), options = ExportOptions(size:doc.model.canvas,ppi:72), url = try output(name.components(separatedBy:"/").last!)
            try await ExportStore(pipeline:p).write(doc.snapshot(),options:options,to:url)
            let (image,_,_) = try inspect(url), expected = try await p.renderDocument(model:doc.model,assets:doc.assets)
            let actual = try rgba(image,image.width/2,image.height/2), reference = try rgba(expected,expected.width/2,expected.height/2)
            for (a,b) in zip(actual,reference) { XCTAssertEqual(a,b,accuracy:0.012) }
            if name.contains("gray") { XCTAssertEqual(actual[0],actual[1],accuracy:0.004); XCTAssertEqual(actual[1],actual[2],accuracy:0.004) }
            if name.contains("16") { XCTAssertTrue(doc.assets.values.first!.convertedToSDR) }
        }
    }
    func testActualISOGainMapIsImportedAsSDRAndExportedWithoutHDRMetadata() async throws {
        guard #available(macOS 15, *) else { throw XCTSkip("ISO gain-map fixture verification requires macOS 15+; macOS 14 remains a separate target-machine check") }
        let url = fixture("P10/iso-gainmap.heic"), source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL,nil))
        if #available(macOS 15, *) {
            XCTAssertNotNil(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source,0,kCGImageAuxiliaryDataTypeISOGainMap))
            let hdr = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldAllowFloat:true,kCGImageSourceDecodeRequest:kCGImageSourceDecodeToHDR] as CFDictionary))
            XCTAssertGreaterThan(hdr.contentHeadroom,2.9)
            if #available(macOS 26, *) { XCTAssertGreaterThan(hdr.calculatedContentHeadroom,1.5) }
        }
        let pipeline = ImagePipeline(), original = try Data(contentsOf:url), asset = try await pipeline.prepare(.file(url),budget:ImportBudget())
        XCTAssertTrue(asset.convertedToSDR); XCTAssertEqual(asset.data,original)
        let normalized = try await pipeline.normalizedImage(asset); XCTAssertEqual(normalized.bitsPerComponent,8); XCTAssertEqual(normalized.colorSpace?.name,CGColorSpace.sRGB)
        let d = PhotoDocument(model:try PhotoDocumentModel(name:"Synthetic HDR",canvas:asset.descriptor.size,ppi:72)); try d.place(asset,recordHistory:false)
        let store = ExportStore(pipeline:pipeline)
        let project = ProjectStore(pipeline:pipeline), projectURL = try output("hdr-embedded.paxis")
        try await project.save(d.snapshot(),to:projectURL)
        let loaded = try await project.open(projectURL); XCTAssertEqual(loaded.assets[asset.descriptor.id]?.data,original); XCTAssertTrue(loaded.assets[asset.descriptor.id]!.convertedToSDR)
        let fresh = ImagePipeline(), restored = try await fresh.renderDocument(model:loaded.model,assets:loaded.assets)
        for (a,b) in zip(try rgba(restored,32,32),try rgba(normalized,32,32)) { XCTAssertEqual(a,b,accuracy:0.01) }
        for format in ExportFormat.allCases {
            var options = ExportOptions(size:d.model.canvas,ppi:72); options.format = format
            let target = try output("hdr-to-sdr."+(format == .png ? "png":"jpg")); try await store.write(d.snapshot(),options:options,to:target)
            let (image,props,_) = try inspect(target); XCTAssertEqual(image.width,64); XCTAssertNotNil(props[kCGImagePropertyProfileName])
            let result = try XCTUnwrap(CGImageSourceCreateWithURL(target as CFURL,nil))
            XCTAssertNil(CGImageSourceCopyAuxiliaryDataInfoAtIndex(result,0,kCGImageAuxiliaryDataTypeHDRGainMap))
            if #available(macOS 15, *) { XCTAssertNil(CGImageSourceCopyAuxiliaryDataInfoAtIndex(result,0,kCGImageAuxiliaryDataTypeISOGainMap)) }
            let pixel = try rgba(image,32,32), expected = try rgba(normalized,32,32)
            for (a,b) in zip(pixel,expected) { XCTAssertEqual(a,b,accuracy:0.015) }
        }
        XCTAssertEqual(d.assets.values.first!.data,original)
    }
    func testMixedCropSaveCloseOpenEditExportCrossLanguageHiddenLayersAndSnapshot() async throws {
        let f = try await MultiLayerPerspectiveTests().fixture(), builder = MultiLayerPerspectiveTests(); try builder.crop(f.d); f.d.applySession()
        let store = ProjectStore(pipeline:f.p), url = try output("mixed.paxis"); try await store.save(f.d.snapshot(),to:url)
        let loaded = try await store.open(url)
        var models: [PhotoDocumentModel] = [], rendered: [Data] = []
        for language in [InterfaceLanguage.vietnamese,.english] {
            let d = PhotoDocument(loaded:loaded,url:url,localization:L10n(choice:language)); XCTAssertTrue(d.history.entries.isEmpty)
            let old = d.model.layer(f.text)!, oldClip = old.clip
            guard case .text(var text) = old.content else { return XCTFail("Missing editable text") }
            text.text = "PHỐ BIỂN\nSửa tiếp sau crop"; text = try ContentRasterizer.measured(text)
            try d.perform(.editText) { try $0.setContent(f.text,.text(text)) }
            XCTAssertEqual(d.model.layer(f.text)?.transform,old.transform); XCTAssertEqual(d.model.layer(f.text)?.clip,oldClip)
            let before = d.snapshot(), options = ExportOptions(size:d.model.canvas,ppi:300), target = try output("mixed-"+language.rawValue+".png")
            try await ExportStore(pipeline:f.p).write(before,options:options,to:target)
            let (image,_,_) = try inspect(target); rendered.append(image.dataProvider!.data! as Data); models.append(d.model)
            XCTAssertTrue(d.isDocumentEdited); XCTAssertEqual(d.history.stateID,before.stateID); XCTAssertEqual(d.model,before.model)
            let reference = try await f.p.renderDocument(model:before.model,assets:before.assets)
            for (x,y) in [(10,10),(100,100),(250,200)] { for (a,b) in zip(try rgba(image,x,y),try rgba(reference,x,y)) { XCTAssertEqual(a,b,accuracy:0.015) } }
        }
        XCTAssertEqual(models[0],models[1]); XCTAssertEqual(rendered[0],rendered[1])
    }
    func testAtomicExportFailureCancellationAndConcurrentEditKeepDestinationAndDirtyState() async throws {
        let (d,p) = try await document("P02/grid-corners.png"), coord = DocumentCoordinator(localization:L10n(choice:.english),pipeline:p)
        try coord.add(d); let target = try output("preserved.png"), previous = Data("old good file".utf8); try previous.write(to:target)
        let snapshot = d.snapshot(), options = ExportOptions(size:d.model.canvas,ppi:72), store = ExportStore(pipeline:p)
        do { try await store.write(snapshot,options:options,to:target,beforeCommit:{ throw POSIXError(.ENOSPC) }); XCTFail("Export failure did not throw") } catch {}
        XCTAssertEqual(try Data(contentsOf:target),previous)
        do { try await store.write(snapshot,options:options,to:target,beforeCommit:{ throw CancellationError() }); XCTFail("Cancelled export did not throw") } catch is CancellationError {}
        XCTAssertEqual(try Data(contentsOf:target),previous)
        let task = Task { await coord.export(snapshot,options:options,destination:target) }
        await Task.yield(); try d.perform(.rename) { try $0.rename(d.model.layers[0].id,to:"Edit while export") }
        let exported = await task.value; XCTAssertTrue(exported); XCTAssertTrue(d.isDocumentEdited)
        XCTAssertEqual(d.model.layers[0].name,"Edit while export"); XCTAssertEqual(d.assets.mapValues(\.data),snapshot.assets.mapValues(\.data)); XCTAssertNil(d.fileURL)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath:outputRoot.path).contains { $0.hasPrefix(".photoaxis-") })
    }
    func testNativeExportFieldsLinkedDimensionsLocaleValidationAndPreviewForBothLanguages() async throws {
        let (d,p) = try await document("P02/alpha-edges.png")
        for language in [InterfaceLanguage.vietnamese,.english] {
            let controller = ExportController(snapshot:d.snapshot(),pipeline:p,localization:L10n(choice:language))
            XCTAssertEqual(try controller.validated().size,d.model.canvas); XCTAssertEqual(controller.link.state,.on); XCTAssertFalse(controller.qualityField.isEnabled)
            controller.widthField.stringValue = "320"; controller.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:controller.widthField))
            XCTAssertEqual(controller.heightField.stringValue,"240"); XCTAssertEqual(try controller.validated().size,try CanvasSize(width:320,height:240))
            controller.widthField.stringValue = "8001"; controller.validateAndPreview(); XCTAssertFalse(controller.exportButton.isEnabled)
            controller.widthField.stringValue = "320"; controller.format.selectItem(at:1); controller.optionsChanged(); XCTAssertTrue(controller.qualityField.isEnabled); XCTAssertFalse(controller.alpha.isEnabled)
            controller.qualityField.stringValue = "0"; controller.validateAndPreview(); XCTAssertFalse(controller.exportButton.isEnabled)
            controller.qualityField.stringValue = "100"; controller.optionsChanged()
            XCTAssertTrue(controller.exportButton.isEnabled); XCTAssertEqual(try controller.validated().quality,100)
            for _ in 0..<100 where controller.preview.image == nil { try await Task.sleep(for:.milliseconds(5)) }
            XCTAssertNotNil(controller.preview.image); controller.cancel()
        }
    }
}

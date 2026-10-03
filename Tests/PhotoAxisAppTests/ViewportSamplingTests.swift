import AppKit
import XCTest
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class ViewportSamplingTests: XCTestCase {
    func testInteractiveSamplingKeepsColorOrientationViewportAndFullQualitySettle() async throws {
        let p = ImagePipeline(), url = Bundle(for:Self.self).resourceURL!.appendingPathComponent("P02/colors-srgb.png")
        let asset = try await p.prepare(.file(url),budget:ImportBudget()), assets = [asset.descriptor.id:asset]
        let d = PhotoDocument(model:try PhotoDocumentModel(name:"Sampling",canvas:asset.descriptor.size,ppi:72),localization:L10n(choice:.vietnamese)); try d.place(asset,recordHistory:false)
        var viewport = ViewportState(); viewport.resize(width:640,height:480,backingScale:2,canvas:d.model.canvas); viewport.fit(d.model.canvas)
        let full = try await p.render(model:d.model,assets:assets,viewport:viewport), low = try await p.render(model:d.model,assets:assets,viewport:viewport,samplingScale:0.5)
        XCTAssertEqual(full.width,1280); XCTAssertEqual(full.height,960); XCTAssertEqual(low.width,640); XCTAssertEqual(low.height,480)
        let large = NSBitmapImageRep(cgImage:full), small = NSBitmapImageRep(cgImage:low)
        for (x,y) in [(100,100),(540,100),(100,380),(540,380),(210,210)] {
            let a = try XCTUnwrap(large.colorAt(x:x*2,y:y*2)), b = try XCTUnwrap(small.colorAt(x:x,y:y))
            for (first,second) in [(a.redComponent,b.redComponent),(a.greenComponent,b.greenComponent),(a.blueComponent,b.blueComponent)] {
                XCTAssertLessThanOrEqual(abs(Int((first*255).rounded())-Int((second*255).rounded())),1,"At most one 8-bit code value; avoid floating-point equality at exactly 1/255")
            }
        }
        let original = d.model, state = d.history.stateID
        let canvas = WelcomeCanvasView(localization:L10n(choice:.vietnamese)), window = NSWindow(contentRect:NSRect(x:0,y:0,width:640,height:480),styleMask:.titled,backing:.buffered,defer:false)
        window.contentView = canvas; window.makeKeyAndOrderFront(nil); defer { window.orderOut(nil) }
        canvas.display(d,pipeline:p); canvas.pan(x:18.5,y:7.25)
        let wanted = d.viewport
        for _ in 0..<100 {
            if canvas.presentedViewport == wanted, canvas.metal.image?.width == Int(640*window.backingScaleFactor) { break }
            try await Task.sleep(for:.milliseconds(10))
        }
        XCTAssertEqual(canvas.presentedViewport,wanted); XCTAssertEqual(canvas.metal.image?.width,Int(640*window.backingScaleFactor)); XCTAssertEqual(d.model,original); XCTAssertEqual(d.history.stateID,state)
        // Coalescing an unchanged display must not cancel its pending latest frame.
        canvas.display(d,pipeline:p); canvas.display(d,pipeline:p)
        try await Task.sleep(for:.milliseconds(200)); XCTAssertEqual(canvas.presentedViewport,wanted)
        canvas.display(nil,pipeline:p); await p.retainCache(for:[])
    }

    func testOneXSamplingSettlesFullClipAndNeverChangesFinalPixels() async throws {
        let f = try await MultiLayerPerspectiveTests().fixture()
        try MultiLayerPerspectiveTests().crop(f.d); f.d.applySession()
        let before = try await f.p.renderDocument(model:f.d.model,assets:f.d.assets)
        let canvas = WelcomeCanvasView(localization:L10n(choice:.english))
        canvas.frame = NSRect(x:0,y:0,width:640,height:480)
        canvas.display(f.d,pipeline:f.p)
        XCTAssertEqual(f.d.viewport.backingScale,1,"A detached native view simulates a 1x viewport")
        canvas.pan(x:13,y:7)
        let wanted = f.d.viewport, original = f.d.model, state = f.d.history.stateID
        var sawInteractive = false
        for _ in 0..<150 {
            sawInteractive = sawInteractive || canvas.presentedIsInteractive
            if sawInteractive && !canvas.presentedIsInteractive && canvas.presentedViewport == wanted { break }
            try await Task.sleep(for:.milliseconds(5))
        }
        XCTAssertTrue(sawInteractive)
        XCTAssertFalse(canvas.presentedIsInteractive,"1x frames still require a separate full-resolution clip pass")
        XCTAssertEqual(canvas.presentedViewport,wanted)
        XCTAssertEqual(f.d.model,original); XCTAssertEqual(f.d.history.stateID,state)
        let after = try await f.p.renderDocument(model:f.d.model,assets:f.d.assets)
        XCTAssertEqual(before.dataProvider?.data as Data?,after.dataProvider?.data as Data?)
        canvas.display(nil,pipeline:f.p); await f.p.retainCache(for:[])
    }
}

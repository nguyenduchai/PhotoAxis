import AppKit
import CoreGraphics
import ImageIO
import Metal
import UniformTypeIdentifiers
import Darwin
import XCTest
import PhotoAxisCore
@testable import PhotoAxis

/// Explicit opt-in Release measurements. These time the actual worker and data
/// lifecycle; desktop/pointer-to-present latency remains a separate native gate.
@MainActor final class BenchmarkTests: XCTestCase {
    var root: URL { (0..<5).reduce(Bundle.main.bundleURL) { url,_ in url.deletingLastPathComponent() }.appendingPathComponent("p12-benchmark") }
    func requireOptIn() throws {
        guard ProcessInfo.processInfo.environment["PHOTOAXIS_BENCHMARK"] == "1" else { throw XCTSkip("Run scripts/benchmark.sh for the opt-in Release benchmark") }
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    }
    func now() -> Double { ProcessInfo.processInfo.systemUptime }
    func stats(_ samples:[Double]) -> [String:Any] {
        let sorted = samples.sorted(), count = sorted.count
        let median = (sorted[(count-1)/2]+sorted[count/2])/2
        return ["samplesSeconds":samples,"count":count,"medianSeconds":median,"maximumSeconds":sorted.last!,"p95Seconds":sorted[min(count-1,Int(ceil(Double(count)*0.95))-1)]]
    }
    func memory() -> [String:Any] {
        var info = mach_task_basic_info(), count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to:&info) { ptr in ptr.withMemoryRebound(to:integer_t.self,capacity:Int(count)) { task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count) } }
        var usage = rusage(); getrusage(RUSAGE_SELF,&usage)
        return ["residentBytes":status == KERN_SUCCESS ? info.resident_size : 0,"processHighWaterRSSBytes":usage.ru_maxrss,"metalCurrentAllocatedBytes":MTLCreateSystemDefaultDevice()?.currentAllocatedSize ?? 0]
    }
    func write(_ name:String,_ value:[String:Any]) throws { try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent(name)) }
    func jpeg(_ size:CanvasSize,seed:Int) throws -> URL {
        let url = root.appendingPathComponent("synthetic-\(size.width)x\(size.height)-\(seed).jpg")
        if FileManager.default.fileExists(atPath:url.path) { return url }
        try autoreleasepool {
            let c = try ContentRasterizer.context(size)
            let colors = [CGColor(red:0.08,green:0.18,blue:0.5,alpha:1),CGColor(red:0.85,green:0.7,blue:0.12,alpha:1)]
            let gradient = CGGradient(colorsSpace:ContentRasterizer.srgb,colors:colors as CFArray,locations:[0,1])!
            c.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:size.width,y:size.height),options:[])
            var state = UInt64(seed+12345)
            for _ in 0..<2000 {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                let x = Int(state%UInt64(size.width)), y = Int((state>>16)%UInt64(size.height))
                c.setFillColor(CGColor(red:Double((state>>32)&255)/255,green:Double((state>>40)&255)/255,blue:Double((state>>48)&255)/255,alpha:0.6))
                c.fill(CGRect(x:x,y:y,width:20+Int(state%170),height:10+Int((state>>24)%120)))
            }
            let data = NSMutableData(), destination = CGImageDestinationCreateWithData(data,UTType.jpeg.identifier as CFString,1,nil)!
            CGImageDestinationAddImage(destination,c.makeImage()!,[kCGImageDestinationLossyCompressionQuality:0.92] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw ImageImportError.unreadable }
            try ICCEmbedding.attachSRGB(to:data as Data,format:.jpeg).write(to:url)
        }
        return url
    }
    func model(_ size:CanvasSize,assets:[EmbeddedImage],extraLayers:Int) throws -> PhotoDocumentModel {
        var model = try PhotoDocumentModel(name:"PhotoAxis benchmark",canvas:size,ppi:144)
        for asset in assets { _ = try model.place(asset.descriptor,name:asset.name,above:model.layers.last?.id) }
        for n in 0..<extraLayers {
            let content: LayerContent
            if n<4 {
                content = .text(try ContentRasterizer.measured(TextContent(text:"PHỐI CẢNH \(n)\nPhotoAxis benchmark",fontName:"Helvetica",fontSize:72,color:.white)))
            } else {
                content = .shape(.init(kind:n%2 == 0 ? .rectangle : .ellipse,size:try CanvasSize(width:600,height:450),fill:RGBAColor(red:0.2,green:Double(n%5)/5,blue:0.8,alpha:0.3)))
            }
            _ = try model.insertContent(content,name:"Typed \(n)",transform:LayerGeometry.translation(x:Double(100+n*97),y:Double(100+n*53)),above:model.layers.last?.id)
        }
        return model
    }
    func viewport(_ size:CanvasSize) -> ViewportState {
        var v = ViewportState(); v.resize(width:1000,height:680,backingScale:2,canvas:size); v.fit(size); return v
    }
    func testFiveRunOpenAndFullPNGExport24MP() async throws {
        try requireOptIn()
        let size = try CanvasSize(width:6000,height:4000), url = try jpeg(size,seed:0)
        let warm = ImagePipeline(); _ = try await warm.prepare(.file(url),budget:ImportBudget()); await warm.retainCache(for:[])
        var opens:[Double] = [], exports:[Double] = [], memoryRows:[[String:Any]] = []
        for n in 0..<5 {
            let p = ImagePipeline(), start = now(), asset = try await p.prepare(.file(url),budget:ImportBudget())
            let model = try model(size,assets:[asset],extraLayers:0), assets = [asset.descriptor.id:asset]
            _ = try await p.render(model:model,assets:assets,viewport:viewport(size)); opens.append(now()-start)
            let begin = now(); try await ExportStore(pipeline:p).write(ProjectSnapshot(model:model,assets:assets,stateID:UUID()),options:ExportOptions(size:size,ppi:144),to:root.appendingPathComponent("export24MP-\(n).png")); exports.append(now()-begin)
            memoryRows.append(memory()); await p.retainCache(for:[]); let cache = await p.cacheBytes; XCTAssertEqual(cache,0)
        }
        try write("open-export.json",["configuration":"Release arm64; 6000x4000 synthetic JPEG on internal SSD; worker prepare through completed usable viewport bitmap, excludes SavePanel and desktop presentation","fixtureSHA256":ImagePipeline.digest(try Data(contentsOf:url)),"open":stats(opens),"export":stats(exports),"memorySnapshots":memoryRows,"openGoalSeconds":3,"exportGoalSeconds":10,"openWorkerGoalMet":opens.max()!<=3,"exportGoalMet":exports.max()!<=10])
    }
    func testFiveRunMixedTenLayerInteractionWorkerLatency() async throws {
        try requireOptIn(); let size = try CanvasSize(width:6000,height:4000), p = ImagePipeline()
        let base = try await p.prepare(.file(jpeg(size,seed:0)),budget:ImportBudget())
        let overlay = try await p.prepare(.file(jpeg(CanvasSize(width:2000,height:2000),seed:4)),budget:ImportBudget())
        let original = try model(size,assets:[base,overlay],extraLayers:8), assets = [base.descriptor.id:base,overlay.descriptor.id:overlay]
        XCTAssertEqual(original.layers.count,10); let v = viewport(size); _ = try await p.render(model:original,assets:assets,viewport:v)
        let initialDecodes = await p.normalizedDecodeCount; var kinds:[String:Any] = [:]
        for kind in ["pan","zoom","perspectiveCorner","slider"] {
            var runs:[[String:Any]] = [], all:[Double] = [], settled:[Double] = []
            for _ in 0..<5 {
                var frames:[Double] = [], finalModel = original, finalViewport = v
                for n in 0..<20 {
                    var candidate = original, view = v; let start = now()
                    switch kind {
                    case "pan": view.pan(x:Double(n*2),y:Double(n))
                    case "zoom": view.setZoom(v.zoom*(1+Double(n)/80),anchor:Point2D(x:500,y:340))
                    case "slider": var a = ImageAdjustments(); a.exposure = Double(n)/10-1; try candidate.setAdjustments(candidate.layers[0].id,a)
                    default:
                        try candidate.perspectiveCrop(PerspectiveQuad([Point2D(x:100+Double(n*3),y:100),Point2D(x:5900,y:150),Point2D(x:5800,y:3900),Point2D(x:150,y:3800)]),output:size)
                    }
                    _ = try await p.render(model:candidate,assets:assets,viewport:view,samplingScale:0.5,lightweightClip:true); frames.append(now()-start)
                    finalModel = candidate; finalViewport = view
                }
                all+=frames; runs.append(stats(frames)); let settle = now(); _ = try await p.render(model:finalModel,assets:assets,viewport:finalViewport); settled.append(now()-settle)
            }
            var item = stats(all); item["runs"] = runs; item["fullQualitySettledWorker"] = stats(settled); item["workerFramesWithin33msFraction"] = Double(all.filter{$0<=1.0/30}.count)/Double(all.count); kinds[kind] = item
        }
        let finalDecodes = await p.normalizedDecodeCount; XCTAssertEqual(finalDecodes,initialDecodes)
        let settleStart = now(); _ = try await p.render(model:original,assets:assets,viewport:v)
        try write("interactions.json",["scope":"100 completed interactive worker renders per interaction in 5 runs at one pixel per point, followed by 5 full Retina quality settles; request start to evaluated viewport bitmap. Synthetic input; not physical pointer or GPU present timestamps. Native input-to-present/fps gate remains unverified while desktop is locked.","canvas":[6000,4000],"layers":10,"viewportPoints":[1000,680],"backingScale":2,"interactiveSamplingScale":0.5,"interactions":kinds,"settledWorkerSeconds":now()-settleStart,"normalizedDecodesDuringWarmFrames":finalDecodes-initialDecodes,"memorySnapshot":memory()])
        await p.retainCache(for:[])
    }
    func testFullQuotaFiveTabsRepeatedLifecycleAndRecovery() async throws {
        try requireOptIn(); let size = try CanvasSize(width:8000,height:5000), p = ImagePipeline()
        var assets:[EmbeddedImage] = []
        for n in 1...3 { assets.append(try await p.prepare(.file(jpeg(size,seed:n)),budget:ImportBudget(remainingPixels:(4-n)*40_000_000))) }
        let values = Dictionary(uniqueKeysWithValues:assets.map{($0.descriptor.id,$0)}), base = try model(size,assets:assets,extraLayers:47)
        XCTAssertEqual(base.layers.count,50); XCTAssertEqual(base.uniqueSourcePixels,120_000_000)
        var rejected = base; XCTAssertThrowsError(try rejected.insertContent(.shape(.init(kind:.rectangle,size:CanvasSize(width:1,height:1),fill:.white)),name:"51",transform:.identity,above:nil)); XCTAssertEqual(rejected,base)
        var sourceLimited = try model(size,assets:assets,extraLayers:0), before = sourceLimited
        XCTAssertThrowsError(try sourceLimited.place(SourceDescriptor(id:String(repeating:"a",count:64),size:CanvasSize(width:1,height:1)),name:"120MP+1",above:nil)); XCTAssertEqual(sourceLimited,before)
        let folder = root.appendingPathComponent(".qa-recovery-benchmark-"+UUID().uuidString), c = DocumentCoordinator(localization:L10n(choice:.vietnamese),pipeline:p,recoveryRoot:folder)
        c.confirmClose = { _ in .discard }; var cycles:[[String:Any]] = [], recoverySeconds:Double = 0, fullExportSeconds:Double = 0
        for cycle in 0..<5 {
            let begin = now()
            for tab in 0..<5 {
                let fresh = try model(size,assets:assets,extraLayers:47), url = root.appendingPathComponent("stress-\(tab).paxis")
                try await c.projectStore.save(ProjectSnapshot(model:fresh,assets:values,stateID:UUID()),to:url)
                let loaded = try await c.projectStore.open(url), d = PhotoDocument(loaded:loaded,url:url,localization:L10n(choice:.vietnamese)); try c.add(d)
                try d.perform(.opacity) { try $0.setOpacity(d.model.layers.last!.id,0.4+Double(cycle)/10) }
            }
            XCTAssertEqual(c.documents.count,5)
            XCTAssertThrowsError(try c.create(name:"Sixth",size:CanvasSize(width:1,height:1),ppi:72,background:.transparent))
            for d in c.documents {
                c.select(d.model.id); _ = try await p.render(model:d.model,assets:d.assets,viewport:viewport(size))
                let options = ExportOptions(size:try CanvasSize(width:800,height:500),ppi:72)
                try await c.exportStore.write(d.snapshot(),options:options,to:root.appendingPathComponent("stress-small.png"))
            }
            if cycle == 0 {
                let start = now(); c.startRecovery()
                while await c.recoveryEntries().count < 5, now()-start<40 { try await Task.sleep(for:.milliseconds(100)) }
                recoverySeconds = now()-start; c.stopRecovery(); let entries = await c.recoveryEntries(); XCTAssertEqual(entries.count,5)
                let exportStart = now(); try await c.exportStore.write(c.active!.snapshot(),options:ExportOptions(size:size,ppi:72),to:root.appendingPathComponent("stress-full40MP.png")); fullExportSeconds = now()-exportStart
            } else { await c.flushRecovery() }
            let memoryBeforeClose = memory(), cacheBefore = await p.cacheBytes
            let closed = await c.requestCloseAll(); XCTAssertTrue(closed); await p.retainCache(for:[])
            let cacheAfter = await p.cacheBytes; XCTAssertEqual(cacheAfter,0); let remaining = await c.recoveryEntries(); XCTAssertTrue(remaining.isEmpty)
            cycles.append(["cycle":cycle,"seconds":now()-begin,"memoryBeforeClose":memoryBeforeClose,"memoryAfterClose":memory(),"decodedCacheBeforeClose":cacheBefore,"decodedCacheAfterClose":cacheAfter])
        }
        try write("stress.json",["canvasPixels":40_000_000,"layersPerDocument":50,"uniqueSourcePixelsPerDocument":120_000_000,"tabs":5,"cycles":cycles,"completedRecoveryFiveTabsSeconds":recoverySeconds,"recoveryGoalSeconds":30,"recoveryGoalMet":recoverySeconds<=30,"full40MPPNGExportSeconds":fullExportSeconds,"fixtureSHA256":assets.map{$0.descriptor.id},"scope":"real Image I/O/renderer/ZIP/atomic writes, five separately reopened projects; screenshots/physical input and macOS14 not covered. Memory samples include allocator/driver retention; high-water RSS is cumulative, Metal allocated size is a sampled API value, not a GPU peak trace."])
    }
}

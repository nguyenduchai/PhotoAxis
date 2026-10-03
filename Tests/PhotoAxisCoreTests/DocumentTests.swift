import Foundation
import Testing
@testable import PhotoAxisCore

struct DocumentTests {
    @Test func backgroundsStayTypedAndLocked() throws {
        let size = try CanvasSize(width: 2480, height: 3508)
        for background in DocumentBackground.allCases {
            let model = try PhotoDocumentModel(name: "Ảnh Việt", canvas: size, ppi: 300, background: background)
            #expect(model.canvas == size); #expect(model.ppi == 300)
            if background == .transparent { #expect(model.layers.isEmpty) }
            else {
                #expect(model.layers.count == 1); #expect(model.layers[0].isLocked)
                guard case .shape(let shape) = model.layers[0].content else { Issue.record("Background was flattened"); return }
                #expect(shape.kind == .rectangle); #expect(shape.size == size)
                #expect(shape.fill == (background == .white ? .white : .black))
            }
        }
        #expect(throws: DocumentError.invalidPPI) { try PhotoDocumentModel(name: "", canvas: size, ppi: .nan) }
    }
    @Test func placementPreservesSourceAndInsertsAboveSelection() throws {
        var model = try PhotoDocumentModel(name: "A", canvas: CanvasSize(width: 1000, height: 800), ppi: 72, background: .white)
        let background = model.layers[0].id
        let large = SourceDescriptor(id: "large", size: try CanvasSize(width: 2000, height: 1000))
        let first = try model.place(large, name: "Large", above: background)
        let small = SourceDescriptor(id: "small", size: try CanvasSize(width: 100, height: 100))
        let second = try model.place(small, name: "Small", above: background)
        #expect(model.layers.map(\.id) == [background, second, first])
        #expect(try model.layers[2].transform.applying(to: .init(x: 0, y: 0)) == .init(x: 0, y: 150))
        #expect(try model.layers[1].transform.applying(to: .init(x: 100, y: 100)) == .init(x: 550, y: 450))
        #expect(model.sources["large"]?.size == large.size)
        #expect(model.layers.allSatisfy { $0.clip.isEmpty })
    }
    @Test func quotasAreAtomicAndDeduplicateSources() throws {
        var model = try PhotoDocumentModel(name: "limits", canvas: CanvasSize(width: 100, height: 100), ppi: 72)
        let size = try CanvasSize(width: 8000, height: 5000)
        for id in ["a", "b", "c"] { _ = try model.place(SourceDescriptor(id: id, size: size), name: id, above: nil) }
        let before = model
        #expect(throws: DocumentError.sourceLimit) { try model.place(SourceDescriptor(id: "d", size: size), name: "d", above: nil) }
        #expect(model == before)
        for _ in 3..<50 { _ = try model.place(SourceDescriptor(id: "a", size: size), name: "shared", above: nil) }
        #expect(model.uniqueSourcePixels == 120_000_000)
        let full = model
        #expect(throws: DocumentError.layerLimit) { try model.place(SourceDescriptor(id: "a", size: size), name: "overflow", above: nil) }
        #expect(model == full)
    }
    @Test func anchoredZoomAndBackingChangePreserveDocumentPoint() throws {
        let size = try CanvasSize(width: 640, height: 480)
        for scale in [1.0, 2.0] {
            var viewport = ViewportState(); viewport.resize(width: 800, height: 600, backingScale: scale, canvas: size)
            let anchor = Point2D(x: 237, y: 319)
            let before = viewport.transform.documentPoint(fromView: anchor)
            for zoom in [0.05, 1, 16, 2.5] {
                viewport.setZoom(zoom, anchor: anchor)
                let after = viewport.transform.documentPoint(fromView: anchor)
                #expect(abs(before.x - after.x) < 1e-8); #expect(abs(before.y - after.y) < 1e-8)
            }
            viewport.setZoom(1)
            let pixel0 = viewport.transform.viewPoint(fromDocument: .init(x: 0, y: 0))
            let pixel1 = viewport.transform.viewPoint(fromDocument: .init(x: 1, y: 0))
            #expect(abs((pixel1.x - pixel0.x) * scale - 1) < 1e-8)
            let center = viewport.transform.documentPoint(fromView: .init(x: 400, y: 300))
            viewport.resize(width: 800, height: 600, backingScale: scale == 1 ? 2 : 1, canvas: size)
            let adjusted = viewport.transform.documentPoint(fromView: .init(x: 400, y: 300))
            #expect(abs(adjusted.x - center.x) < 1e-8); #expect(abs(adjusted.y - center.y) < 1e-8)
            viewport.pan(x: 21, y: -39)
            let stable = viewport; viewport.setZoom(.nan); viewport.pan(x: .infinity, y: 1)
            #expect(viewport == stable)
        }
    }
}

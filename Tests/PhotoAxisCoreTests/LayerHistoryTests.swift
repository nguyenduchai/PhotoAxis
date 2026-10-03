import Foundation
import Testing
@testable import PhotoAxisCore

struct LayerHistoryTests {
    private func document() throws -> (PhotoDocumentModel, UUID) {
        var model = try PhotoDocumentModel(name: "Layers", canvas: CanvasSize(width: 800,height: 600), ppi: 72)
        let id = try model.place(SourceDescriptor(id: "source", size: CanvasSize(width: 400,height: 300)), name: "Ảnh biển", above: nil)
        return (model,id)
    }
    @Test func lockedLayerProtectionAndSharedDuplicate() throws {
        var (model,id) = try document(); try model.setLock(id,true)
        let before = model
        #expect(throws: DocumentError.lockedLayer) { try model.rename(id,to: "Changed") }
        #expect(throws: DocumentError.lockedLayer) { try model.setOpacity(id,0.5) }
        #expect(throws: DocumentError.lockedLayer) { try model.delete(id) }
        #expect(throws: DocumentError.lockedLayer) { try model.reorder(id,to: 0) }
        #expect(throws: DocumentError.lockedLayer) { try model.setTransform(id,.identity) }
        #expect(model == before)
        try model.setVisibility(id,false)
        let copy = try model.duplicate(id,name: "Bản sao")
        #expect(model.sources.count == 1 && model.uniqueSourcePixels == 120_000)
        #expect(model.layer(copy)?.isLocked == true)
        try model.setLock(copy,false); try model.setOpacity(copy,0.4); try model.setVisibility(copy,true)
        #expect(model.layer(id)?.opacity == 1 && model.layer(id)?.isVisible == false)
        try model.delete(copy); #expect(model.sources.count == 1)
        try model.setLock(id,false); try model.delete(id); #expect(model.sources.isEmpty)
    }
    @Test func geometryComposesWithoutLosingProjectiveMapping() throws {
        var (model,id) = try document()
        let perspective = try ProjectiveTransform([1,0.2,40,0.1,1,30,0.0002,0.0001,1])
        try model.setTransform(id,perspective)
        let originalPoint = try perspective.applying(to: Point2D(x: 140,y: 120))
        let bounds = try model.bounds(of: id)
        let scale = try LayerGeometry.scale(x: 1.5,y: 0.75,around: bounds.center)
        let rotate = try LayerGeometry.rotation(degrees: 30,around: bounds.center)
        let moved = try perspective.followed(by: scale).followed(by: rotate).followed(by: LayerGeometry.translation(x: -123,y: 87))
        try model.setTransform(id,moved)
        let expected = try rotate.applying(to: scale.applying(to: originalPoint))
        let actual = try moved.applying(to: Point2D(x: 140,y: 120))
        #expect(abs(actual.x - expected.x + 123) < 1e-8)
        #expect(abs(actual.y - expected.y - 87) < 1e-8)
        #expect(moved.coefficients[6] == perspective.coefficients[6])
        #expect(model.sources.count == 1)
        let reflection = try LayerGeometry.scale(x: -1,y: 1,around: bounds.center)
        let twice = try perspective.followed(by: reflection).followed(by: reflection)
        let restored = try twice.applying(to: Point2D(x: 140,y: 120))
        #expect(abs(restored.x-originalPoint.x) < 1e-8)
    }
    @Test func unsafeGeometryIsRejectedAtomically() throws {
        var (model,id) = try document(); let before = model
        let pole = try ProjectiveTransform([1,0,0,0,1,0,-0.01,0,1])
        #expect(throws: GeometryError.pointAtInfinity) { try model.setTransform(id,pole) }
        #expect(throws: DocumentError.invalidValue) { try model.setTransform(id,LayerGeometry.translation(x: 2_000_000,y: 0)) }
        #expect(throws: DocumentError.invalidValue) { try model.setOpacity(id,.nan) }
        #expect(model == before)
    }
    @Test func historyBranchAndSavedIdentitySurviveTrimming() throws {
        var (model,id) = try document(); var history = DocumentHistory(model:model)
        let saved = history.stateID; history.markSaved(stateID: saved)
        try model.rename(id,to:"A"); history.record(model,command:.rename,sourceBytes:[:])
        let stateA = history.stateID
        try model.setOpacity(id,0.5); history.record(model,command:.opacity,sourceBytes:[:])
        history.select(0); #expect(!history.isDirty)
        history.select(1); #expect(history.isDirty && history.canRedo)
        model = history.current; try model.rename(id,to:"B")
        history.record(model,command:.rename,sourceBytes:[:],maximumSteps:1)
        #expect(history.entries.count == 1 && !history.canRedo)
        #expect(history.baseID == stateA)
        history.select(0); #expect(history.isDirty) // Removed saved state must not become a false clean marker.
    }
    @Test func historyBudgetCountsRedoOnlyAssetsOnce() throws {
        let empty = try PhotoDocumentModel(name:"Budget",canvas:CanvasSize(width:800,height:600),ppi:72)
        var model = empty, history = DocumentHistory(model:empty)
        let id = try model.place(SourceDescriptor(id:"pixels",size:CanvasSize(width:400,height:300)),name:"Image",above:nil)
        history.record(model,command:.importImage,sourceBytes:["pixels":20_000],maximumBytes:30_000)
        #expect(history.retainedBytes >= 20_000)
        history.select(0); #expect(history.retainedSourceIDs.contains("pixels"))
        history.select(1)
        for i in 0..<105 { try model.rename(id,to:"Name \(i)"); history.record(model,command:.rename,sourceBytes:["pixels":20_000]) }
        #expect(history.entries.count == 100 && history.cursor == 100)
        #expect(history.retainedBytes < 1_000_000) // Source bytes are never copied into each entry.
        try model.delete(id)
        history.record(model,command:.delete,sourceBytes:["pixels":20_000],maximumBytes:1_000)
        #expect(history.entries.isEmpty && history.retainedSourceIDs.isEmpty)
    }
}

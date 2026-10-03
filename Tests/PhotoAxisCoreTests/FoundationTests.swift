import Testing
@testable import PhotoAxisCore

@Test func validatesDimensionsBeforeAllocation() throws {
    #expect(try CanvasSize(width: 8_000, height: 5_000).pixelCount == 40_000_000)
    #expect(throws: DimensionError.pixelBudgetExceeded) { try CanvasSize(width: 8_000, height: 5_001) }
    for invalid in [0, -1, 8_001, Int.max, Int.min] {
        #expect(throws: DimensionError.edgeOutOfRange) { try CanvasSize(width: invalid, height: 1) }
        #expect(throws: DimensionError.edgeOutOfRange) { try CanvasSize(width: 1, height: invalid) }
    }
    #expect(throws: DimensionError.edgeOutOfRange) { try CanvasSize(width: 1, height: 2, minimumEdge: 2) }
    #expect(try CanvasSize(width: 2, height: 2, minimumEdge: 2).pixelCount == 4)
}

@Test func documentOperationsComposeAfterLayerMapping() throws {
    let layer = try ProjectiveTransform([1, 0, 100, 0, 1, 50, 0, 0, 1])
    let crop = try ProjectiveTransform([2, 0, -200, 0, 2, -100, 0, 0, 1])
    let composite = try layer.followed(by: crop)
    #expect(try composite.applying(to: Point2D(x: 20, y: 10)) == Point2D(x: 40, y: 20))
    // A newly added layer uses the new canvas, without inheriting the crop.
    #expect(try ProjectiveTransform.identity.applying(to: Point2D(x: 20, y: 10)) == Point2D(x: 20, y: 10))
}

@Test func perspectiveRoundTripPreservesCornerIdentity() throws {
    let transform = try ProjectiveTransform([1.2, 0.1, 12, 0.05, 0.9, 8, 0.001, 0.0005, 1])
    let inverse = try transform.inverted()
    for corner in [Point2D(x: 0, y: 0), Point2D(x: 640, y: 0),
                   Point2D(x: 640, y: 480), Point2D(x: 0, y: 480)] {
        let restored = try inverse.applying(to: transform.applying(to: corner))
        #expect(abs(restored.x - corner.x) < 1e-8)
        #expect(abs(restored.y - corner.y) < 1e-8)
    }
    let scaled = try ProjectiveTransform(transform.coefficients.map { $0 * 1e-20 })
    let probe = Point2D(x: 100, y: 200)
    #expect(abs(try scaled.applying(to: probe).x - transform.applying(to: probe).x) < 1e-8)
}

@Test func rejectsSingularityAndNonFiniteInput() throws {
    #expect(throws: GeometryError.invalidMatrix) { try ProjectiveTransform([1, 2]) }
    #expect(throws: GeometryError.invalidMatrix) { try ProjectiveTransform([1, 0, 0, 0, 0, 0, 0, 0, 1]) }
    #expect(throws: GeometryError.invalidMatrix) { try ProjectiveTransform([1, 0, .nan, 0, 1, 0, 0, 0, 1]) }
    let horizon = try ProjectiveTransform([1, 0, 0, 0, 1, 0, 1, 0, -10])
    #expect(throws: GeometryError.pointAtInfinity) { try horizon.applying(to: Point2D(x: 10, y: 2)) }
}

@Test func largeTranslationIsNotMistakenForSingularity() throws {
    let transform = try ProjectiveTransform([1, 0, 16_000, 0, 1, -16_000, 0, 0, 1])
    let restored = try transform.inverted().applying(to: transform.applying(to: Point2D(x: 400, y: 300)))
    #expect(abs(restored.x - 400) < 1e-8)
    #expect(abs(restored.y - 300) < 1e-8)
}

@Test func retinaZoomAndPanRoundTrip() throws {
    for backing in [1.0, 2.0] {
        for zoom in [0.05, 1.0, 16.0] {
            let viewport = try ViewportTransform(zoom: zoom, backingScale: backing,
                                                 originInView: Point2D(x: -36, y: 90))
            let point = Point2D(x: 345.25, y: 187.5)
            let projected = viewport.viewPoint(fromDocument: point)
            let restored = viewport.documentPoint(fromView: projected)
            #expect(abs(restored.x - point.x) < 1e-8)
            #expect(abs(restored.y - point.y) < 1e-8)
            #expect(abs((projected.x + 36) * backing - point.x * zoom) < 1e-8)
        }
    }
    #expect(throws: GeometryError.invalidViewport) {
        try ViewportTransform(zoom: 1, backingScale: 0, originInView: Point2D(x: 0, y: 0))
    }
}

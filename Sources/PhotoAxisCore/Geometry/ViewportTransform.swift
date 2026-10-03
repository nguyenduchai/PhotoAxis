/// zoom = device pixels per document pixel. At 100%, one image pixel = one device pixel.
public struct ViewportTransform: Sendable {
    public let zoom: Double
    public let backingScale: Double
    public let originInView: Point2D

    public init(zoom: Double, backingScale: Double, originInView: Point2D) throws {
        guard zoom.isFinite, (0.05...16).contains(zoom), backingScale.isFinite, backingScale > 0,
              originInView.x.isFinite, originInView.y.isFinite else { throw GeometryError.invalidViewport }
        self.zoom = zoom
        self.backingScale = backingScale
        self.originInView = originInView
    }

    public func viewPoint(fromDocument point: Point2D) -> Point2D {
        Point2D(x: originInView.x + point.x * zoom / backingScale,
                y: originInView.y + point.y * zoom / backingScale)
    }

    public func documentPoint(fromView point: Point2D) -> Point2D {
        Point2D(x: (point.x - originInView.x) * backingScale / zoom,
                y: (point.y - originInView.y) * backingScale / zoom)
    }
}

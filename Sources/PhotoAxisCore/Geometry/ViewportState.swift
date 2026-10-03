import Foundation

/// Navigation belongs to a tab, never to its saved model or undo history.
public struct ViewportState: Equatable, Sendable {
    public private(set) var zoom = 1.0
    public private(set) var origin = Point2D(x: 0, y: 0)
    public private(set) var backingScale = 1.0
    public private(set) var width = 0.0
    public private(set) var height = 0.0
    public private(set) var fitsCanvas = true
    public var transform: ViewportTransform { try! ViewportTransform(zoom: zoom, backingScale: backingScale, originInView: origin) }
    public init() {}

    public mutating func resize(width: Double, height: Double, backingScale: Double, canvas: CanvasSize) {
        guard width.isFinite, height.isFinite, width > 0, height > 0, backingScale.isFinite, backingScale > 0 else { return }
        let oldCenter = transform.documentPoint(fromView: Point2D(x: self.width / 2, y: self.height / 2))
        self.width = width; self.height = height; self.backingScale = backingScale
        if fitsCanvas { fit(canvas) }
        else { origin = Point2D(x: width / 2 - oldCenter.x * zoom / backingScale, y: height / 2 - oldCenter.y * zoom / backingScale) }
    }
    public mutating func fit(_ canvas: CanvasSize) {
        guard width > 0, height > 0 else { return }
        zoom = min(16, max(0.05, min(max(1, width - 48) / Double(canvas.width), max(1, height - 48) / Double(canvas.height)) * backingScale))
        origin = Point2D(x: (width - Double(canvas.width) * zoom / backingScale) / 2,
                         y: (height - Double(canvas.height) * zoom / backingScale) / 2)
        fitsCanvas = true
    }
    public mutating func setZoom(_ value: Double, anchor: Point2D? = nil) {
        guard value.isFinite else { return }
        let anchor = anchor ?? Point2D(x: width / 2, y: height / 2)
        let documentPoint = transform.documentPoint(fromView: anchor)
        zoom = min(16, max(0.05, value)); fitsCanvas = false
        origin = Point2D(x: anchor.x - documentPoint.x * zoom / backingScale, y: anchor.y - documentPoint.y * zoom / backingScale)
    }
    public mutating func pan(x: Double, y: Double) {
        guard x.isFinite, y.isFinite, (origin.x + x).isFinite, (origin.y + y).isFinite else { return }
        origin = Point2D(x: origin.x + x, y: origin.y + y); fitsCanvas = false
    }
}

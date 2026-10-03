import AppKit

enum CanvasCursorKind: Hashable {
    case arrow, tool(ToolKind), openHand, closedHand, text, zoomIn, zoomOut, cloneSample
    case resizeHorizontal, resizeVertical, resizeDownDiagonal, resizeUpDiagonal, rotate
    static func handle(_ index: Int) -> Self {
        switch index {
        case 0, 4: .resizeDownDiagonal
        case 2, 6: .resizeUpDiagonal
        case 1, 5: .resizeVertical
        case 3, 7: .resizeHorizontal
        default: .rotate
        }
    }
}

/// Actual AppKit cursors, cached once per role. The crosshair's hotspot is the
/// input pixel; the small owned vector beside it identifies the selected tool.
@MainActor
enum CanvasCursors {
    private static var cache: [CanvasCursorKind: NSCursor] = [:]
    static func cursor(_ kind: CanvasCursorKind) -> NSCursor {
        switch kind {
        case .arrow: return .arrow
        case .openHand: return .openHand
        case .closedHand: return .closedHand
        case .text: return .iBeam
        case .resizeHorizontal: return .resizeLeftRight
        case .resizeVertical: return .resizeUpDown
        default: break
        }
        if let value = cache[kind] { return value }
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size, flipped: true) { _ in
            let path = NSBezierPath(); path.lineCapStyle = .round; path.lineJoinStyle = .round
            func line(_ points: [NSPoint]) {
                guard let first = points.first else { return }; path.move(to: first)
                points.dropFirst().forEach { path.line(to: $0) }
            }
            let badge: ToolKind?
            switch kind {
            case .resizeDownDiagonal, .resizeUpDiagonal:
                let a: NSPoint = kind == .resizeDownDiagonal ? .init(x: 3,y: 3) : .init(x: 3,y: 21)
                let b: NSPoint = kind == .resizeDownDiagonal ? .init(x: 21,y: 21) : .init(x: 21,y: 3)
                line([a,b]); let sign: CGFloat = kind == .resizeDownDiagonal ? 1 : -1
                line([.init(x:a.x+6,y:a.y),a,.init(x:a.x,y:a.y+6*sign)])
                line([.init(x:b.x-6,y:b.y),b,.init(x:b.x,y:b.y-6*sign)]); badge = nil
            case .rotate:
                path.appendArc(withCenter: .init(x:12,y:12), radius:8, startAngle:35, endAngle:310, clockwise:false)
                line([.init(x:18,y:2),.init(x:19,y:8),.init(x:13,y:7)]); badge = nil
            default:
                line([.init(x:1,y:5),.init(x:9,y:5)]); line([.init(x:5,y:1),.init(x:5,y:9)])
                switch kind {
                case .tool(let tool): badge = tool
                case .zoomIn, .zoomOut: badge = .zoom
                case .cloneSample: badge = .cloneStamp
                default: badge = nil
                }
            }
            NSColor.black.setStroke(); path.lineWidth = 3; path.stroke()
            NSColor.white.setStroke(); path.lineWidth = 1; path.stroke()
            if let badge {
                NSGraphicsContext.saveGraphicsState()
                let shadow = NSShadow(); shadow.shadowColor = NSColor.black; shadow.shadowBlurRadius = 2; shadow.shadowOffset = .zero; shadow.set()
                badge.icon().draw(in: .init(x:10,y:10,width:21,height:21)); NSGraphicsContext.restoreGraphicsState()
            }
            if kind == .zoomIn || kind == .zoomOut || kind == .cloneSample {
                let sign = NSBezierPath(); sign.lineWidth = 1
                sign.move(to:.init(x:17,y:20)); sign.line(to:.init(x:23,y:20))
                if kind != .zoomOut { sign.move(to:.init(x:20,y:17)); sign.line(to:.init(x:20,y:23)) }
                NSColor.black.setStroke(); sign.lineWidth = 3; sign.stroke()
                NSColor.white.setStroke(); sign.lineWidth = 1; sign.stroke()
            }
            return true
        }
        let hotspot = [.resizeDownDiagonal, .resizeUpDiagonal, .rotate].contains(kind) ? NSPoint(x:12,y:12) : NSPoint(x:5,y:5)
        let value = NSCursor(image: image, hotSpot: hotspot); cache[kind] = value; return value
    }
}

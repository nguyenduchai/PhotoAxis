import AppKit

enum ToolKind: String, CaseIterable, Hashable {
    case brush, cloneStamp, move, crop, perspectiveCrop, eyedropper, type, rectangle, ellipse, line, hand, zoom
    var key: String { "tool." + rawValue }
    var shortcut: String {
        switch self {
        case .brush: "B"
        case .cloneStamp: "S"
        case .move: "V"
        case .crop: "C"
        case .perspectiveCrop: "Shift+C"
        case .eyedropper: "I"
        case .type: "T"
        case .rectangle, .ellipse, .line: "U"
        case .hand: "H"
        case .zoom: "Z"
        }
    }

    @MainActor func icon() -> NSImage {
        // Native template vectors; no borrowed Photoshop assets or bitmap scaling.
        let kind = self
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { _ in
            NSColor.white.setStroke()
            NSColor.white.setFill()
            let p = NSBezierPath(); p.lineWidth = 1.4; p.lineCapStyle = .round; p.lineJoinStyle = .round
            func segment(_ points: [NSPoint]) {
                guard let first = points.first else { return }
                p.move(to: first); for point in points.dropFirst() { p.line(to: point) }
            }
            switch kind {
            case .brush:
                segment([.init(x:7,y:6),.init(x:17,y:18),.init(x:20,y:15),.init(x:10,y:4)])
                p.appendOval(in:.init(x:3,y:2,width:7,height:5))
            case .cloneStamp:
                p.appendOval(in:.init(x:8,y:13,width:6,height:7))
                segment([.init(x:9,y:13),.init(x:9,y:9),.init(x:5,y:7),.init(x:5,y:4),.init(x:18,y:4),.init(x:18,y:7),.init(x:13,y:9),.init(x:13,y:13)])
            case .move:
                segment([.init(x: 11,y: 3), .init(x: 11,y: 19)])
                segment([.init(x: 3,y: 11), .init(x: 19,y: 11)])
                for (x,y,dx,dy) in [(11.0,19.0,3.0,-3.0),(11,3,3,3)] {
                    segment([.init(x:x-dx,y:y+dy), .init(x:x,y:y), .init(x:x+dx,y:y+dy)])
                }
                segment([.init(x:6,y:8),.init(x:3,y:11),.init(x:6,y:14)])
                segment([.init(x:16,y:8),.init(x:19,y:11),.init(x:16,y:14)])
            case .crop:
                segment([.init(x:6,y:20),.init(x:6,y:6),.init(x:20,y:6)])
                segment([.init(x:2,y:16),.init(x:16,y:16),.init(x:16,y:2)])
            case .perspectiveCrop:
                segment([.init(x:4,y:4),.init(x:18,y:4),.init(x:16,y:18),.init(x:7,y:16),.init(x:4,y:4)])
                segment([.init(x:6,y:10),.init(x:17,y:11)])
                segment([.init(x:11,y:4),.init(x:11.5,y:17)])
            case .type:
                segment([.init(x:4,y:16),.init(x:4,y:19),.init(x:18,y:19),.init(x:18,y:16)])
                segment([.init(x:11,y:19),.init(x:11,y:3)])
                segment([.init(x:7,y:3),.init(x:15,y:3)])
            case .rectangle: p.appendRect(.init(x:4,y:4,width:14,height:14))
            case .ellipse: p.appendOval(in:.init(x:4,y:4,width:14,height:14))
            case .line: segment([.init(x:4,y:4),.init(x:18,y:18)])
            case .eyedropper:
                segment([.init(x:4,y:3),.init(x:6,y:8),.init(x:14,y:16),.init(x:18,y:12),.init(x:10,y:4),.init(x:4,y:3)])
                segment([.init(x:12,y:18),.init(x:20,y:10)])
            case .zoom:
                p.appendOval(in:.init(x:4,y:8,width:10,height:10))
                segment([.init(x:13,y:9),.init(x:19,y:3)])
            case .hand:
                segment([.init(x:5,y:8),.init(x:3,y:13),.init(x:5,y:14),.init(x:8,y:11),.init(x:8,y:19),.init(x:10,y:19),.init(x:10,y:13),.init(x:11,y:20),.init(x:13,y:20),.init(x:13,y:13),.init(x:14,y:18),.init(x:16,y:18),.init(x:16,y:12),.init(x:17,y:15),.init(x:19,y:14),.init(x:18,y:7),.init(x:15,y:3),.init(x:9,y:3),.init(x:5,y:8)])
            }
            p.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}

import AppKit
import PhotoAxisCore

/// Ruler coordinates share the canvas viewport; labels are never drawn partially.
@MainActor final class RulerView: SurfaceView {
    static let horizontalHeight: CGFloat = 28
    static let verticalWidth: CGFloat = 48
    struct Tick {
        let pixels: Double
        let position: CGFloat
        let major: Bool
        let label: String?
        let labelRect: NSRect?
    }
    let vertical: Bool
    var viewport: ViewportState? { didSet { needsDisplay = true } }
    var unit: RulerUnit = .pixels { didSet { needsDisplay = true } }
    var ppi = 72.0 { didSet { needsDisplay = true } }
    private static let font = NSFont.monospacedDigitSystemFont(ofSize:9,weight:.regular)
    init(vertical: Bool) {
        self.vertical = vertical
        super.init(color:WorkspaceStyle.toolbar)
        identifier = .init(vertical ? "workspace.ruler.vertical" : "workspace.ruler.horizontal")
        layer?.masksToBounds = true
    }
    required init?(coder:NSCoder) { fatalError("Use init(vertical:)") }
    func ticks() -> [Tick] {
        guard let viewport else { return [] }
        let origin = vertical ? viewport.origin.y : viewport.origin.x
        let scale = viewport.zoom/viewport.backingScale
        let length = vertical ? bounds.height : bounds.width
        let pixelsPerUnit = unit.pixelsPerUnit(ppi:ppi)
        guard length > 0, scale.isFinite, scale > 0 else { return [] }
        let desired = 80/(scale*pixelsPerUnit), power = pow(10,floor(log10(desired)))
        let step = ([1.0,2,5,10].first { $0*power >= desired } ?? 10)*power
        let first = floor(-origin/(scale*pixelsPerUnit)/step)*step
        guard step.isFinite, step > 0, first.isFinite, abs(first) < 1e12 else { return [] }
        let count = min(1024,max(1,Int(ceil(Double(length)/(step*scale*pixelsPerUnit)))+2))
        let formatter = NumberFormatter(); formatter.locale = .current; formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = max(0,min(6,Int(ceil(-log10(step)))))
        let attributes: [NSAttributedString.Key:Any] = [.font:Self.font]
        var ticks: [Tick] = []
        for i in 0..<count {
            for subdivision in 0..<5 {
                let value = first+(Double(i)+Double(subdivision)/5)*step
                let pixels = value*pixelsPerUnit, position = origin+pixels*scale
                guard position >= 0, position <= Double(length) else { continue }
                var label: String?, rect: NSRect?
                if subdivision == 0 {
                    let text = formatter.string(from:NSNumber(value:abs(value) < step*1e-6 ? 0:value)) ?? ""
                    let size = (text as NSString).size(withAttributes:attributes)
                    let proposed = vertical
                        ? NSRect(x:bounds.width-10-size.width,y:position-size.height/2,width:size.width,height:size.height)
                        : NSRect(x:position-size.width/2,y:3,width:size.width,height:size.height)
                    if bounds.insetBy(dx:3,dy:3).contains(proposed) { label = text; rect = proposed }
                }
                ticks.append(Tick(pixels:pixels,position:position,major:subdivision==0,label:label,labelRect:rect))
            }
        }
        return ticks
    }
    override func draw(_ dirtyRect:NSRect) {
        super.draw(dirtyRect)
        NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect:bounds).addClip()
        let path = NSBezierPath(); path.lineWidth = 0.5
        let attributes: [NSAttributedString.Key:Any] = [.font:Self.font,.foregroundColor:WorkspaceStyle.text]
        for tick in ticks() {
            if vertical {
                path.move(to:NSPoint(x:bounds.width-(tick.major ? 7:4),y:tick.position)); path.line(to:NSPoint(x:bounds.width,y:tick.position))
            } else {
                path.move(to:NSPoint(x:tick.position,y:bounds.height-(tick.major ? 7:4))); path.line(to:NSPoint(x:tick.position,y:bounds.height))
            }
            if let label = tick.label, let rect = tick.labelRect { (label as NSString).draw(in:rect,withAttributes:attributes) }
        }
        WorkspaceStyle.text.setStroke(); path.stroke()
        WorkspaceStyle.divider.setFill()
        (vertical ? NSRect(x:bounds.maxX-1,y:0,width:1,height:bounds.height) : NSRect(x:0,y:bounds.maxY-1,width:bounds.width,height:1)).fill()
    }
}

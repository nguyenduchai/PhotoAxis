import Foundation

public enum InvestigationAnnotation: String, CaseIterable, Sendable { case arrow, ellipse, number, label, magnifier }

public extension PhotoDocumentModel {
    /// All pieces stay typed/editable. The caller commits this entire operation as
    /// one history transaction and one durable processing event.
    mutating func addInvestigationAnnotation(_ kind: InvestigationAnnotation, region: EvidenceRegion, text: TextContent,
                                            name: String, sourceLayerID: UUID? = nil) throws -> [UUID] {
        try region.validate(in: canvas)
        let red = RGBAColor(red: 1, green: 0.1, blue: 0.1)
        var ids: [UUID] = []
        func translation(_ x: Double, _ y: Double) throws -> ProjectiveTransform { try ProjectiveTransform([1, 0, x, 0, 1, y, 0, 0, 1]) }
        func line(_ a: Point2D, _ b: Point2D) throws -> (ShapeContent, ProjectiveTransform) {
            let x = min(a.x, b.x), y = min(a.y, b.y)
            let width = max(1, Int(ceil(abs(b.x - a.x)))), height = max(1, Int(ceil(abs(b.y - a.y))))
            var shape = ShapeContent(kind: .line, size: try CanvasSize(width: width, height: height), fill: .clear)
            shape.stroke = red; shape.strokeWidth = 3
            shape.lineStart = Point2D(x: (a.x - x) / Double(width), y: (a.y - y) / Double(height))
            shape.lineEnd = Point2D(x: (b.x - x) / Double(width), y: (b.y - y) / Double(height))
            return (shape, try translation(x, y))
        }
        func corners(_ r: EvidenceRegion) -> [Point2D] {
            [Point2D(x: Double(r.x), y: Double(r.y)), Point2D(x: Double(r.x + r.width), y: Double(r.y)),
             Point2D(x: Double(r.x + r.width), y: Double(r.y + r.height)), Point2D(x: Double(r.x), y: Double(r.y + r.height))]
        }
        switch kind {
        case .arrow:
            let start = Point2D(x: Double(region.x), y: Double(region.y)), end = Point2D(x: Double(region.x + region.width), y: Double(region.y + region.height))
            let angle = atan2(end.y - start.y, end.x - start.x), length = min(24, hypot(end.x - start.x, end.y - start.y) / 3)
            for pair in [(start, end), (end, Point2D(x: end.x - length * cos(angle - .pi / 6), y: end.y - length * sin(angle - .pi / 6))),
                         (end, Point2D(x: end.x - length * cos(angle + .pi / 6), y: end.y - length * sin(angle + .pi / 6)))] {
                let segment = try line(pair.0, pair.1)
                ids.append(try insertContent(.shape(segment.0), name: name, transform: segment.1, above: layers.last?.id))
            }
        case .ellipse, .number:
            var shape = ShapeContent(kind: .ellipse, size: try CanvasSize(width: region.width, height: region.height), fill: .clear)
            shape.stroke = red; shape.strokeWidth = 3
            ids.append(try insertContent(.shape(shape), name: name, transform: translation(Double(region.x), Double(region.y)), above: layers.last?.id))
            if kind == .number { ids.append(try insertContent(.text(text), name: name, transform: translation(Double(region.x + 4), Double(region.y + 4)), above: layers.last?.id)) }
        case .label:
            ids.append(try insertContent(.text(text), name: name, transform: translation(Double(region.x), Double(region.y)), above: layers.last?.id))
        case .magnifier:
            guard let original = sourceLayerID.flatMap(layer), case .image(let sourceID) = original.content,
                  let source = sources[sourceID] else { throw DocumentError.missingSource }
            // Source-pixel ROI, limited by the existing clip. Magnifiers cannot
            // resurrect data discarded by a crop.
            try region.validate(in: source.size)
            let scale = min(2, min(Double(canvas.width) / Double(region.width), Double(canvas.height) / Double(region.height)))
            let outW = Double(region.width) * scale, outH = Double(region.height) * scale
            let outX = max(0, Double(canvas.width) - outW - 12), outY = max(0, Double(canvas.height) - outH - 12)
            let transform = try ProjectiveTransform([scale, 0, outX - Double(region.x) * scale, 0, scale, outY - Double(region.y) * scale, 0, 0, 1])
            let id = try insertContent(.image(sourceID: sourceID), name: name + " [" + sourceID.prefix(8) + "]", transform: transform, above: layers.last?.id)
            let index = layers.firstIndex { $0.id == id }!
            layers[index].clip = original.clip + [corners(region)]; layers[index].adjustments = original.adjustments
            ids.append(id)
            let sourceCorners = try corners(region).map { try original.transform.applying(to: $0) }
            for i in 0..<4 {
                let segment = try line(sourceCorners[i], sourceCorners[(i + 1) % 4])
                ids.append(try insertContent(.shape(segment.0), name: name, transform: segment.1, above: layers.last?.id))
            }
            var frame = ShapeContent(kind: .rectangle, size: try CanvasSize(width: max(1, Int(ceil(outW))), height: max(1, Int(ceil(outH)))), fill: .clear)
            frame.stroke = red; frame.strokeWidth = 3
            ids.append(try insertContent(.shape(frame), name: name, transform: translation(outX, outY), above: layers.last?.id))
        }
        return ids
    }
}

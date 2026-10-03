import Foundation

public extension PhotoDocumentModel {
    func layer(_ id: UUID) -> PhotoLayer? { layers.first { $0.id == id } }
    func localSize(of layer: PhotoLayer) throws -> CanvasSize {
        switch layer.content {
        case .image(let id):
            guard let source = sources[id] else { throw DocumentError.missingSource }; return source.size
        case .shape(let shape): return shape.size
        case .text(let text): return text.layoutSize
        }
    }
    func bounds(of id: UUID) throws -> LayerBounds {
        guard let layer = layer(id) else { throw DocumentError.missingLayer }
        return try LayerGeometry.bounds(size: localSize(of: layer), transform: layer.transform, clips:layer.clip)
    }
    mutating func rename(_ id: UUID, to name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.utf8.count <= 4096 else { throw DocumentError.invalidValue }
        try edit(id) { $0.name = name }
    }
    mutating func setVisibility(_ id: UUID, _ visible: Bool) throws { try edit(id, allowLocked: true) { $0.isVisible = visible } }
    mutating func setLock(_ id: UUID, _ locked: Bool) throws { try edit(id, allowLocked: true) { $0.isLocked = locked } }
    mutating func setOpacity(_ id: UUID, _ value: Double) throws {
        guard value.isFinite, (0...1).contains(value) else { throw DocumentError.invalidValue }
        try edit(id) { $0.opacity = value }
    }
    mutating func setTransform(_ id: UUID, _ matrix: ProjectiveTransform) throws {
        guard let layer = layer(id) else { throw DocumentError.missingLayer }
        _ = try LayerGeometry.bounds(size: localSize(of: layer), transform: matrix, clips:layer.clip)
        try edit(id) { $0.transform = matrix }
    }
    mutating func duplicate(_ id: UUID, name: String) throws -> UUID {
        guard layers.count < DocumentLimits.maximumLayers else { throw DocumentError.layerLimit }
        guard let index = layers.firstIndex(where: { $0.id == id }) else { throw DocumentError.missingLayer }
        let original = layers[index]
        // Duplication does not mutate the protected original. Its lock is preserved.
        var copy = PhotoLayer(name: name, content: original.content, transform: original.transform)
        copy.clip = original.clip; copy.isVisible = original.isVisible; copy.isLocked = original.isLocked; copy.opacity = original.opacity
        copy.adjustments = original.adjustments
        layers.insert(copy, at: index + 1); revision &+= 1; return copy.id
    }
    mutating func delete(_ id: UUID) throws {
        let index = try editableIndex(id)
        layers.remove(at: index)
        let used = Set(layers.compactMap { layer -> String? in if case .image(let id) = layer.content { return id }; return nil })
        sources = sources.filter { used.contains($0.key) }; revision &+= 1
    }
    /// Final index in bottom-to-top model order, after removing the moving layer.
    mutating func reorder(_ id: UUID, to index: Int) throws {
        let old = try editableIndex(id)
        guard layers.indices.contains(index) else { throw DocumentError.invalidValue }
        guard old != index else { return }
        let moving = layers.remove(at: old); layers.insert(moving, at: index); revision &+= 1
    }
    private func editableIndex(_ id: UUID, allowLocked: Bool = false) throws -> Int {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { throw DocumentError.missingLayer }
        guard allowLocked || !layers[index].isLocked else { throw DocumentError.lockedLayer }; return index
    }
    private mutating func edit(_ id: UUID, allowLocked: Bool = false, change: (inout PhotoLayer) -> Void) throws {
        let index = try editableIndex(id, allowLocked: allowLocked), old = layers[index]
        change(&layers[index]); if layers[index] != old { revision &+= 1 }
    }
}

import Foundation

public enum DocumentCommand: String, Sendable {
    case privacy, brush, cloneStamp, scan, annotation, adjustments, createText, editText, createShape, editShape, importImage, rename, duplicate, delete, reorder, visibility, lock, opacity, move, transform, align, crop, perspectiveCrop, imageSize, canvasSize, rotateCanvas, flipCanvas
    public var localizationKey: String { "command." + rawValue }
}

/// Small value snapshots contain only metadata/source IDs. Encoded pixels are owned
/// once by the document and are never captured by individual undo closures.
public struct DocumentHistory: Sendable {
    public struct Entry: Sendable {
        public let command: DocumentCommand
        public let before, after: PhotoDocumentModel
        public let beforeID, afterID: UUID
        public let metadataBytes: Int
    }
    public private(set) var entries: [Entry] = []
    public private(set) var cursor = 0
    public private(set) var base: PhotoDocumentModel
    public private(set) var baseID = UUID()
    public private(set) var savedID: UUID?
    public private(set) var retainedBytes = 0
    public var current: PhotoDocumentModel { cursor == 0 ? base : entries[cursor-1].after }
    public var stateID: UUID { cursor == 0 ? baseID : entries[cursor-1].afterID }
    public var isDirty: Bool { stateID != savedID }
    public var canUndo: Bool { cursor > 0 }
    public var canRedo: Bool { cursor < entries.count }
    public func index(of stateID: UUID) -> Int? {
        stateID == baseID ? 0 : entries.firstIndex { $0.afterID == stateID }.map { $0 + 1 }
    }
    public init(model: PhotoDocumentModel, stateID: UUID = UUID()) { base = model; baseID = stateID }
    public mutating func markSaved(stateID: UUID) { savedID = stateID }
    public mutating func select(_ index: Int) { precondition((0...entries.count).contains(index)); cursor = index }
    public var retainedSourceIDs: Set<String> {
        entries.reduce(Set(base.sources.keys)) { result, entry in result.union(entry.before.sources.keys).union(entry.after.sources.keys) }
    }
    @discardableResult
    public mutating func record(_ model: PhotoDocumentModel, command: DocumentCommand, sourceBytes: [String: Int],
                                maximumSteps: Int = DocumentLimits.maximumHistorySteps,
                                maximumBytes: Int = DocumentLimits.maximumHistoryBytes) -> Bool {
        var comparable = current; comparable.revision = model.revision
        guard model != comparable else { return false }
        let before = current, beforeID = stateID
        if cursor < entries.count { entries.removeSubrange(cursor...) }
        entries.append(Entry(command: command, before: before, after: model, beforeID: beforeID, afterID: UUID(),
                             metadataBytes: Self.cost(before) + Self.cost(model)))
        cursor = entries.count
        func bytes(_ history: Self) -> Int {
            // Count sources that may be held only by history at ANY cursor, including
            // redo after undoing an import. Sources present in every state are live data.
            let common = history.entries.reduce(Set(history.base.sources.keys)) { $0.intersection($1.after.sources.keys) }
            let extra = history.retainedSourceIDs.subtracting(common)
            return history.entries.reduce(0) { $0 + $1.metadataBytes } + extra.reduce(0) { $0 + (sourceBytes[$1] ?? 0) }
        }
        while !entries.isEmpty && (entries.count > max(0, maximumSteps) || bytes(self) > max(0, maximumBytes)) {
            let removed = entries.removeFirst(); base = removed.after; baseID = removed.afterID; cursor -= 1
        }
        retainedBytes = bytes(self); return true
    }
    private static func cost(_ model: PhotoDocumentModel) -> Int {
        512 + model.name.utf8.count + model.sources.count * 192 + model.layers.reduce(0) { total, layer in
            let textBytes: Int
            if case .text(let text) = layer.content { textBytes = text.text.utf8.count + text.fontName.utf8.count + text.fontFamily.utf8.count + text.fontStyle.utf8.count } else { textBytes = 0 }
            let paintBytes: Int
            if case .paint(let paint) = layer.content { paintBytes = paint.metadataBytes } else { paintBytes = 0 }
            return total + 512 + layer.name.utf8.count + textBytes + paintBytes + layer.clip.reduce(0) { $0 + $1.count * 16 }
        }
    }
}

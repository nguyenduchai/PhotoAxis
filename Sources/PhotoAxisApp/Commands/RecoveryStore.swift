import Foundation
import PhotoAxisCore

struct RecoveryEntry: Identifiable, Sendable {
    let id: UUID
    let name: String
    let date: Date
    let stateID: UUID?
    let revision: UInt64?
    let isCorrupt: Bool
}

/// Each manifest points to one completely committed archive. A crash between the
/// archive and manifest commits leaves the previous manifest usable. No user URL
/// is ever stored or written here. Actor tokens prevent suspended writes reviving
/// a recovery that the user has deliberately discarded.
actor RecoveryStore {
    struct Record: Codable {
        let version: Int
        let id, stateID: UUID
        let revision: UInt64
        let name: String
        let date: Date
        let archive: UUID
    }
    let root: URL
    let projects: ProjectStore
    private var writing: [UUID:(token:UUID,stateID:UUID)] = [:]
    init(root: URL, pipeline: ImagePipeline) { self.root = root; projects = ProjectStore(pipeline:pipeline) }
    static var defaultRoot: URL {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.photoaxis.app",isDirectory:true)
            .appendingPathComponent("Recovery",isDirectory:true)
    }
    private func directory(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString,isDirectory:true) }
    private func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        let values = try url.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw ProjectError.invalidDocument }
    }
    private func record(_ id: UUID) throws -> Record {
        let folder = directory(id), url = folder.appendingPathComponent("record.json")
        for path in [root,folder,url] {
            let v = try path.resourceValues(forKeys:[.isSymbolicLinkKey,.isRegularFileKey,.fileSizeKey])
            guard v.isSymbolicLink != true else { throw ProjectError.invalidDocument }
            if path == url { guard v.isRegularFile == true, (v.fileSize ?? Int.max) <= 16384 else { throw ProjectError.resourceLimit } }
        }
        let item = try JSONDecoder().decode(Record.self,from:Data(contentsOf:url))
        guard item.version == 1, item.id == id, item.name.utf8.count <= 8192,
              item.date.timeIntervalSince1970.isFinite else { throw ProjectError.invalidDocument }
        return item
    }
    func list() throws -> [RecoveryEntry] {
        guard FileManager.default.fileExists(atPath:root.path) else { return [] }
        let v = try root.resourceValues(forKeys:[.isSymbolicLinkKey,.isDirectoryKey])
        guard v.isDirectory == true, v.isSymbolicLink != true else { throw ProjectError.invalidDocument }
        let children = try FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil)
        let ids = children.compactMap { UUID(uuidString:$0.lastPathComponent) }
        guard ids.count <= 100 else { throw ProjectError.resourceLimit }
        return ids.compactMap { id -> RecoveryEntry? in
            if let r = try? record(id) {
                return RecoveryEntry(id:id,name:r.name,date:r.date,stateID:r.stateID,revision:r.revision,isCorrupt:false)
            }
            // A new directory becomes visible before its first manifest commit.
            // Hide our in-flight write and harmless empty directories.
            if writing[id] != nil { return nil }
            if let contents = try? FileManager.default.contentsOfDirectory(atPath:directory(id).path), contents.isEmpty { return nil }
            return RecoveryEntry(id:id,name:id.uuidString,date:.distantPast,stateID:nil,revision:nil,isCorrupt:true)
        }.sorted { $0.date > $1.date }
    }
    @discardableResult func write(_ snapshot: ProjectSnapshot, beforeManifest: @Sendable () async throws -> Void = {}) async throws -> Bool {
        let id = snapshot.model.id, token = UUID(), archive = UUID()
        writing[id] = (token,snapshot.stateID)
        defer { if writing[id]?.token == token { writing[id] = nil } }
        try ensureDirectory(root); let folder = directory(id); try ensureDirectory(folder)
        let url = folder.appendingPathComponent(archive.uuidString+".paxis")
        do { try await projects.save(snapshot,to:url); try await beforeManifest() }
        catch { try? FileManager.default.removeItem(at:url); throw error }
        guard writing[id]?.token == token else { try? FileManager.default.removeItem(at:url); return false }
        let r = Record(version:1,id:id,stateID:snapshot.stateID,revision:snapshot.model.revision,name:snapshot.model.name,date:Date(),archive:archive)
        let data = try JSONEncoder().encode(r)
        do { try AtomicFile.write(to:folder.appendingPathComponent("record.json")) { try $0.write(contentsOf:data) } }
        catch { try? FileManager.default.removeItem(at:url); throw error }
        try pruneArchives(folder,keeping:archive)
        return true
    }
    func open(_ entry: RecoveryEntry) async throws -> ProjectSnapshot {
        let r = try record(entry.id)
        guard !entry.isCorrupt, entry.stateID == r.stateID else { throw ProjectError.invalidDocument }
        let url = directory(entry.id).appendingPathComponent(r.archive.uuidString+".paxis")
        let v = try url.resourceValues(forKeys:[.isSymbolicLinkKey,.isRegularFileKey])
        guard v.isSymbolicLink != true, v.isRegularFile == true else { throw ProjectError.invalidDocument }
        let snapshot = try await projects.open(url)
        guard snapshot.model.id == r.id, snapshot.model.revision == r.revision else { throw ProjectError.invalidDocument }
        return ProjectSnapshot(model:snapshot.model,assets:snapshot.assets,stateID:r.stateID)
    }
    /// nil means the deliberate final Don't Save/Discard decision. A successful
    /// Save removes only its own state, preserving a newer committed recovery.
    func discard(_ id: UUID, stateID: UUID? = nil) throws {
        if stateID == nil || writing[id]?.stateID == stateID { writing[id] = nil }
        let folder = directory(id)
        guard FileManager.default.fileExists(atPath:folder.path) else { return }
        if let stateID { guard (try? record(id))?.stateID == stateID else { return } }
        let v = try folder.resourceValues(forKeys:[.isSymbolicLinkKey,.isDirectoryKey])
        guard v.isDirectory == true, v.isSymbolicLink != true else { throw ProjectError.invalidDocument }
        let manifest = folder.appendingPathComponent("record.json")
        if FileManager.default.fileExists(atPath:manifest.path) { try FileManager.default.removeItem(at:manifest) }
        try pruneArchives(folder,keeping:nil)
        // Empty directories are harmless; keeping them during an in-flight write
        // avoids deleting a temporary archive the suspended writer still owns.
        if (try FileManager.default.contentsOfDirectory(atPath:folder.path)).isEmpty { try FileManager.default.removeItem(at:folder) }
    }
    private func pruneArchives(_ folder: URL, keeping: UUID?) throws {
        for url in try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil) {
            guard url.pathExtension == "paxis", let id = UUID(uuidString:url.deletingPathExtension().lastPathComponent), id != keeping else { continue }
            try FileManager.default.removeItem(at:url)
        }
    }
}

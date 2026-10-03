import AppKit
import ImageIO
import CryptoKit
import Darwin
import PhotoAxisCore

enum InvestigationFiles {
    static func read(_ url: URL, limit: Int) throws -> Data {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true); defer { try? handle.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_size >= 0, info.st_size <= limit else { throw InvestigationError.limit }
        guard let data = try handle.read(upToCount: limit + 1), data.count == info.st_size else { throw InvestigationError.integrity }
        var after = stat()
        guard fstat(fd, &after) == 0, after.st_size == info.st_size,
              after.st_mtimespec.tv_sec == info.st_mtimespec.tv_sec, after.st_mtimespec.tv_nsec == info.st_mtimespec.tv_nsec,
              after.st_ctimespec.tv_sec == info.st_ctimespec.tv_sec, after.st_ctimespec.tv_nsec == info.st_ctimespec.tv_nsec else { throw InvestigationError.integrity }
        return data
    }
    static func hashFile(_ url: URL, limit: Int = BoundedZIP.archiveLimit) throws -> String {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw InvestigationError.integrity }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true); defer { try? handle.close() }
        var info = stat(), digest = SHA256()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_size > 0, info.st_size <= limit else { throw InvestigationError.limit }
        var count = 0
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { try Task.checkCancellation(); count += data.count; guard count <= limit else { throw InvestigationError.limit }; digest.update(data: data) }
        var after = stat()
        guard count == info.st_size, fstat(fd, &after) == 0, after.st_size == info.st_size,
              after.st_mtimespec.tv_sec == info.st_mtimespec.tv_sec, after.st_mtimespec.tv_nsec == info.st_mtimespec.tv_nsec,
              after.st_ctimespec.tv_sec == info.st_ctimespec.tv_sec, after.st_ctimespec.tv_nsec == info.st_ctimespec.tv_nsec else { throw InvestigationError.integrity }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    static func directory(_ url: URL) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else { throw InvestigationError.invalidCase }
    }
    struct Captured: Sendable { let stagedURL: URL; let sha256: String; let byteCount: Int; let metadataJSON: String }
    static func capture(_ url: URL, stage: URL) throws -> Captured {
        let data = try read(url, limit: InvestigationCase.maximumOriginalBytes)
        guard !data.isEmpty, let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1 else { throw ImageImportError.unreadable }
        func jsonValue(_ value: Any) -> Any {
            if let dictionary = value as? [String: Any] { return dictionary.mapValues(jsonValue) }
            if let array = value as? [Any] { return array.map(jsonValue) }
            if let bytes = value as? Data { return ["type": "Data", "base64": bytes.base64EncodedString()] }
            if let date = value as? Date { return ["type": "Date", "value": ISO8601DateFormatter().string(from: date)] }
            if value is String || value is NSNumber || value is NSNull { return value }
            return ["type": String(describing: type(of: value)), "value": String(describing: value)]
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        let raw = try JSONSerialization.data(withJSONObject: jsonValue(properties), options: [.sortedKeys, .fragmentsAllowed])
        guard raw.count <= 262_144 else { throw InvestigationError.limit }
        try AtomicFile.write(to: stage) { try $0.write(contentsOf: data) }
        return Captured(stagedURL: stage, sha256: InvestigationDigest.hash(data), byteCount: data.count, metadataJSON: String(decoding: raw, as: UTF8.self))
    }
}

/// One writer per case; originals are separate from working pixels and never
/// written by an editing/export path. Every case mutation is an atomic manifest.
@MainActor
final class InvestigationCaseStore {
    let root: URL
    private(set) var value: InvestigationCase
    private var manifestSHA256: String
    private let lockFD: Int32
    let appVersion: String
    var changed: (() -> Void)?
    var beforeManifestCommit: (() throws -> Void)?
    private var busy = false
    var manifestURL: URL { root.appendingPathComponent("case.json") }
    func projectURL(_ id: UUID) -> URL {
        let hash = value.items.first(where: { $0.id == id })?.workingFileSHA256
        return archiveURL(id, hash: hash)
    }
    func archiveURL(_ id: UUID, hash: String?) -> URL {
        root.appendingPathComponent("projects/" + id.uuidString.lowercased() + (hash.map { "-" + $0 } ?? "") + ".paxis")
    }
    func originalURL(_ item: EvidenceItem) -> URL { root.appendingPathComponent("originals/" + item.originalSHA256) }
    func item(_ id: UUID) throws -> EvidenceItem { guard let item = value.items.first(where: { $0.id == id }) else { throw InvestigationError.invalidCase }; return item }
    init(root: URL, creating: InvestigationCase? = nil, appVersion: String = "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"))") throws {
        self.root = root.standardizedFileURL; self.appVersion = appVersion
        if let creating {
            guard !FileManager.default.fileExists(atPath: root.path) else { throw InvestigationError.protectedDestination }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            for name in ["originals", "projects"] { try FileManager.default.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]) }
            var initial = creating; try initial.record(operation: "caseCreated", details: ["code": creating.code, "title": creating.title], appVersion: appVersion)
            let data = try initial.encoded(); try AtomicFile.write(to: root.appendingPathComponent("case.json")) { try $0.write(contentsOf: data) }
        }
        try InvestigationFiles.directory(root)
        for name in ["originals", "projects"] { try InvestigationFiles.directory(root.appendingPathComponent(name)) }
        let fd = open(root.appendingPathComponent(".case-lock").path, O_RDWR | O_CREAT | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw InvestigationError.locked }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { close(fd); throw InvestigationError.locked }
        do {
            let data = try InvestigationFiles.read(root.appendingPathComponent("case.json"), limit: InvestigationCase.maximumManifestBytes)
            value = try InvestigationCase.decode(data); manifestSHA256 = InvestigationDigest.hash(data); lockFD = fd
        } catch { flock(fd, LOCK_UN); close(fd); throw error }
    }
    deinit { flock(lockFD, LOCK_UN); close(lockFD) }
    func verifyManifest() throws {
        try InvestigationFiles.directory(root)
        for name in ["originals", "projects"] { try InvestigationFiles.directory(root.appendingPathComponent(name)) }
        guard InvestigationDigest.hash(try InvestigationFiles.read(manifestURL, limit: InvestigationCase.maximumManifestBytes)) == manifestSHA256 else { throw InvestigationError.integrity }
    }
    func mutate(_ operation: String, itemID: UUID? = nil, details: [String: String] = [:],
                modelAfter: Data? = nil, change: (inout InvestigationCase) throws -> Void = { _ in }) throws {
        try verifyManifest()
        var next = value; try change(&next)
        try next.record(operation: operation, itemID: itemID, details: details, modelAfterJSON: modelAfter, appVersion: appVersion)
        let data = try next.encoded()
        try AtomicFile.write(to: manifestURL, beforeCommit: { try self.beforeManifestCommit?() }) { try $0.write(contentsOf: data) }
        value = next; manifestSHA256 = InvestigationDigest.hash(data); changed?()
    }
    func verifyOriginal(_ item: EvidenceItem) async throws {
        try verifyManifest(); let url = originalURL(item)
        let digest = try await Task.detached { try InvestigationFiles.hashFile(url, limit: InvestigationCase.maximumOriginalBytes) }.value
        guard digest == item.originalSHA256 else { throw InvestigationError.integrity }
    }
    func protectDestination(_ url: URL) throws {
        let target = url.standardizedFileURL.resolvingSymlinksInPath().path
        let parent = root.resolvingSymlinksInPath().path
        guard target != parent, !target.hasPrefix(parent + "/") else { throw InvestigationError.protectedDestination }
    }
    func importFile(_ url: URL, intake: EvidenceIntake, pipeline: ImagePipeline, projects: ProjectStore,
                    allowResize: Bool = false, frame: (EvidenceVideo, Int, EvidenceMediaTime, Double, String)? = nil) async throws -> EvidenceItem {
        guard !busy, value.items.count < 100 else { throw InvestigationError.limit }
        busy = true; defer { busy = false }; try intake.validate(); try verifyManifest()
        let stage = root.appendingPathComponent("originals/.intake-" + UUID().uuidString)
        defer { _ = unlink(stage.path) }
        let captured = try await Task.detached { try InvestigationFiles.capture(url, stage: stage) }.value
        guard value.items.reduce(0, { $0 + $1.originalByteCount }) + (value.analysis?.videos.reduce(0, { $0 + $1.byteCount }) ?? 0) <= 10_737_418_240 - captured.byteCount else { throw InvestigationError.limit }
        // Decode the captured bytes, so changes to the received file cannot switch
        // the working image away from the original that was actually hashed.
        let asset = try await pipeline.prepare(.file(stage), budget: ImportBudget(), allowResize: allowResize)
        let id = UUID(), number = (value.items.map(\.number).max() ?? 0) + 1
        let reference = InvestigationReference(caseID: value.id, itemID: id)
        var model = try PhotoDocumentModel(id: id, name: String(format: "IMG-%04d", number), canvas: asset.descriptor.size, ppi: asset.ppi)
        model.investigation = reference; _ = try model.place(asset.descriptor, name: url.lastPathComponent, above: nil)
        let snapshot = ProjectSnapshot(model: model, assets: [asset.descriptor.id: asset], stateID: UUID())
        let work = projectURL(id)
        var accepted = false, createdOriginal: URL?, publishedWork: URL?
        defer {
            try? FileManager.default.removeItem(at: work)
            if !accepted { if let publishedWork { try? FileManager.default.removeItem(at: publishedWork) }; if let createdOriginal { try? FileManager.default.removeItem(at: createdOriginal) } }
        }
        try InvestigationFiles.directory(root.appendingPathComponent("projects"))
        try await projects.save(snapshot, to: work)
        let workHash = try await Task.detached { try InvestigationFiles.hashFile(work) }.value
        let versionedWork = archiveURL(id, hash: workHash)
        guard rename(work.path, versionedWork.path) == 0 else { throw POSIXError(.EIO) }
        publishedWork = versionedWork
        let original = root.appendingPathComponent("originals/" + captured.sha256)
        try InvestigationFiles.directory(root.appendingPathComponent("originals"))
        if FileManager.default.fileExists(atPath: original.path) {
            guard try InvestigationFiles.hashFile(original, limit: InvestigationCase.maximumOriginalBytes) == captured.sha256 else { throw InvestigationError.integrity }
        } else {
            guard rename(stage.path, original.path) == 0 else { throw POSIXError(.EIO) }
            createdOriginal = original
            guard chmod(original.path, S_IRUSR | S_IRGRP | S_IROTH) == 0 else { throw POSIXError(.EIO) }
        }
        let json = try ProjectSchema(model).encoded()
        let entry = EvidenceItem(id: id, number: number, caption: "", intake: intake, importedAt: InvestigationDigest.timestamp(),
                                 originalName: url.lastPathComponent, originalSHA256: captured.sha256, originalByteCount: captured.byteCount,
                                 originalMetadataJSON: captured.metadataJSON, workingSourceSHA256: asset.descriptor.id,
                                 modelJSON: json, workingFileSHA256: workHash)
        do { try mutate("intake", itemID: id, details: ["originalSHA256": captured.sha256, "workingSourceSHA256": asset.descriptor.id,
                                                      "originalName": entry.originalName, "resizeAllowed": String(allowResize),
                                                      "intakeJSON": String(decoding: try InvestigationDigest.encode(intake), as: UTF8.self)], modelAfter: json) { next in
                next.items.append(entry)
                if let frame {
                    next.formatVersion = 2; if next.analysis == nil { next.analysis = InvestigationAnalysis() }
                    next.analysis!.frames.append(EvidenceVideoFrame(videoID: frame.0.id, itemID: entry.id, videoSHA256: frame.0.sha256, frameSHA256: entry.originalSHA256, trackID: frame.0.trackID, frameIndex: frame.1, presentationTime: frame.2, timeOffsetSeconds: frame.3, offsetReason: frame.4))
                }
            } }
        catch { try? FileManager.default.removeItem(at: work); throw error }
        accepted = true
        return entry
    }
    func openSnapshot(_ id: UUID, projects: ProjectStore) async throws -> ProjectSnapshot {
        let entry = try item(id); try await verifyOriginal(entry)
        let url = projectURL(id), expected = entry.workingFileSHA256
        let hash = try await Task.detached { try InvestigationFiles.hashFile(url) }.value
        guard hash == expected else { throw InvestigationError.integrity }
        let saved = try await projects.open(url)
        let current = try item(id).model
        var assets = saved.assets
        let intakeHash = entry.intakeWorkingFileSHA256 ?? entry.workingFileSHA256
        let intakeURL = archiveURL(id, hash: intakeHash)
        if intakeHash != expected {
            let hash = try await Task.detached { try InvestigationFiles.hashFile(intakeURL) }.value
            guard hash == intakeHash else { throw InvestigationError.integrity }
        }
        if !Set(current.sources.keys).isSubset(of: Set(assets.keys)) {
            let intake = try await projects.open(intakeURL)
            assets.merge(intake.assets) { existing, _ in existing }
        }
        for descriptor in current.sources.values where assets[descriptor.id] == nil {
            let folder = root.appendingPathComponent("derived")
            try InvestigationFiles.directory(folder)
            let url = folder.appendingPathComponent(descriptor.id)
            let data = try await Task.detached { try InvestigationFiles.read(url,limit:BoundedZIP.assetLimit) }.value
            guard InvestigationDigest.hash(data) == descriptor.id else { throw InvestigationError.integrity }
            let asset = try await projects.pipeline.prepare(.clipboard(data,name:"Clone source snapshot"),budget:ImportBudget(remainingPixels:descriptor.size.pixelCount))
            // Clipboard preparation can re-encode PNG. File preparation retains the hashed bytes.
            guard asset.descriptor.size == descriptor.size else { throw InvestigationError.integrity }
            assets[descriptor.id] = EmbeddedImage(descriptor:descriptor,data:data,name:"Clone source snapshot",ppi:current.ppi,convertedToSDR:false)
        }
        guard Set(current.sources.keys).isSubset(of: Set(assets.keys)) else { throw InvestigationError.integrity }
        return ProjectSnapshot(model: current, assets: assets, stateID: UUID())
    }
    func commitModel(_ id: UUID, operation: String, before: PhotoDocumentModel, after: PhotoDocumentModel, assets: [String: EmbeddedImage] = [:]) throws {
        let previous = try ProjectSchema(before).encoded(), next = try ProjectSchema(after).encoded()
        guard try item(id).currentModelJSON == previous, before.investigation == after.investigation else { throw InvestigationError.integrity }
        let added = Set(after.sources.keys).subtracting(before.sources.keys)
        var published: [URL] = []
        do {
            if !added.isEmpty {
                let folder = root.appendingPathComponent("derived")
                if !FileManager.default.fileExists(atPath:folder.path) { try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700]) }
                try InvestigationFiles.directory(folder)
                var stored = 0
                for url in try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil) {
                    guard ProjectSchema.isSourceID(url.lastPathComponent) else { throw InvestigationError.integrity }
                    var info = stat(); guard lstat(url.path,&info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw InvestigationError.integrity }
                    stored += Int(info.st_size)
                }
                let originalBytes = value.items.reduce(Int64(0),{ $0+Int64($1.originalByteCount) }) + (value.analysis?.videos.reduce(Int64(0),{ $0+Int64($1.byteCount) }) ?? 0)
                let capacity = min(Int64(BoundedZIP.archiveLimit),10_737_418_240-originalBytes)
                guard Int64(stored) <= capacity else { throw InvestigationError.limit }
                for sourceID in added.sorted() {
                    let url = folder.appendingPathComponent(sourceID)
                    if FileManager.default.fileExists(atPath:url.path) {
                        guard try InvestigationFiles.hashFile(url,limit:BoundedZIP.assetLimit) == sourceID else { throw InvestigationError.integrity }
                    } else {
                        guard let asset = assets[sourceID], asset.descriptor == after.sources[sourceID], asset.data.count <= BoundedZIP.assetLimit,
                              InvestigationDigest.hash(asset.data) == sourceID, Int64(stored)+Int64(asset.data.count) <= capacity else { throw InvestigationError.limit }
                        try AtomicFile.write(to:url) { try $0.write(contentsOf:asset.data) }; published.append(url)
                        try FileManager.default.setAttributes([.posixPermissions:0o444],ofItemAtPath:url.path); stored += asset.data.count
                    }
                }
            }
        try mutate(operation, itemID: id, details: ["beforeModelSHA256": InvestigationDigest.hash(previous), "afterModelSHA256": InvestigationDigest.hash(next),"addedSourcesJSON":String(decoding:try InvestigationDigest.encode(added.sorted()),as:UTF8.self)], modelAfter: next) { value in
            guard let i = value.items.firstIndex(where: { $0.id == id }) else { throw InvestigationError.invalidCase }
            value.items[i].currentModelJSON = next
        }
        } catch { for url in published { try? FileManager.default.removeItem(at:url) }; throw error }
    }
    func updateIntake(_ id: UUID, caption: String, intake: EvidenceIntake) throws {
        let old = try item(id)
        try mutate("intakeAmended", itemID: id, details: ["previousIntakeJSON": String(decoding: try InvestigationDigest.encode(old.intake), as: UTF8.self),
                                                        "intakeJSON": String(decoding: try InvestigationDigest.encode(intake), as: UTF8.self), "previousCaption": old.caption, "caption": caption]) { value in
            guard let i = value.items.firstIndex(where: { $0.id == id }) else { throw InvestigationError.invalidCase }
            value.items[i].caption = caption; value.items[i].intake = intake
        }
    }
    func setRedactions(_ id: UUID, regions: [EvidenceRegion]) throws {
        let entry = try item(id), model = try entry.model
        for region in regions { try region.validate(in: model.canvas) }
        try mutate("redactionsReviewed", itemID: id, details: ["regionsJSON": String(decoding: try InvestigationDigest.encode(regions), as: UTF8.self)]) { value in
            let i = value.items.firstIndex { $0.id == id }!
            value.items[i].redactions = regions; value.items[i].redactionModelSHA256 = InvestigationDigest.hash(entry.currentModelJSON)
        }
    }
    /// Publish a fresh archive first, then atomically point the manifest to it.
    /// A failed journal write leaves the previous checkpoint usable on restart.
    func saveWorking(_ id: UUID, snapshot: ProjectSnapshot, projects: ProjectStore) async throws -> URL {
        let entry = try item(id), json = try ProjectSchema(snapshot.model).encoded(), oldURL = projectURL(id)
        let intakeHash = entry.intakeWorkingFileSHA256 ?? entry.workingFileSHA256
        let stage = root.appendingPathComponent("projects/.save-" + UUID().uuidString + ".paxis")
        defer { _ = unlink(stage.path) }
        try verifyManifest(); try InvestigationFiles.directory(root.appendingPathComponent("projects"))
        try await projects.save(snapshot, to: stage)
        let hash = try await Task.detached { try InvestigationFiles.hashFile(stage) }.value
        let published = archiveURL(id, hash: hash)
        var created = false, committed = false
        defer { if created && !committed { try? FileManager.default.removeItem(at: published) } }
        if FileManager.default.fileExists(atPath: published.path) {
            guard try InvestigationFiles.hashFile(published) == hash else { throw InvestigationError.integrity }
        } else {
            guard rename(stage.path, published.path) == 0 else { throw POSIXError(.EIO) }; created = true
        }
        try mutate("workingSaved", itemID: id, details: ["workingFileSHA256": hash, "savedModelSHA256": InvestigationDigest.hash(json)]) { value in
            let i = value.items.firstIndex { $0.id == id }!
            value.items[i].intakeWorkingFileSHA256 = intakeHash
            value.items[i].savedModelJSON = json; value.items[i].workingFileSHA256 = hash
        }
        committed = true
        if oldURL != published, oldURL != archiveURL(id, hash: intakeHash) { try? FileManager.default.removeItem(at: oldURL) }
        return published
    }
    func discard(_ id: UUID) throws {
        let json = try item(id).savedModelJSON
        try mutate("workingEditsDiscarded", itemID: id, modelAfter: json) { value in value.items[value.items.firstIndex { $0.id == id }!].currentModelJSON = json }
    }
    func discardMany(_ ids: [UUID]) throws {
        try mutate("documentsClosedWithoutSaving", details: ["items": ids.map(\.uuidString).joined(separator: ",")]) { next in
            for id in ids {
                guard let i = next.items.firstIndex(where: { $0.id == id }) else { throw InvestigationError.invalidCase }
                let saved = next.items[i].savedModelJSON; next.items[i].currentModelJSON = saved
                try next.record(operation: "workingEditsDiscarded", itemID: id, modelAfterJSON: saved, appVersion: appVersion)
            }
        }
    }
}

@MainActor
final class InvestigationSession {
    let store: InvestigationCaseStore
    let itemID: UUID
    init(store: InvestigationCaseStore, itemID: UUID) { self.store = store; self.itemID = itemID }
    func record(_ operation: String, before: PhotoDocumentModel, after: PhotoDocumentModel, assets: [String: EmbeddedImage] = [:]) throws { try store.commitModel(itemID, operation: operation, before: before, after: after, assets: assets) }
}

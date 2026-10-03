import AppKit
import PhotoAxisCore

/// A frozen, derived canvas for analysis of an ordinary tab. It does not attach
/// an evidence reference to the user's document or claim received-file provenance.
@MainActor
final class OpenImageAnalysis {
    let documentID: UUID
    let modelSHA256: String
    let store: InvestigationCaseStore
    let itemID: UUID
    let baseline: ProjectSnapshot
    let isTemporary: Bool
    private let itemModelSHA256: String

    init(documentID: UUID, modelSHA256: String, store: InvestigationCaseStore, itemID: UUID,
         baseline: ProjectSnapshot, isTemporary: Bool = true) {
        self.documentID = documentID; self.modelSHA256 = modelSHA256; self.store = store
        self.itemID = itemID; self.baseline = baseline; self.isTemporary = isTemporary
        itemModelSHA256 = store.value.items.first(where: { $0.id == itemID }).map { InvestigationDigest.hash($0.currentModelJSON) } ?? ""
    }
    func matches(_ document: PhotoDocument?) -> Bool {
        guard let document, document.model.id == documentID,
              let json = try? ProjectSchema(document.model).encoded(),
              let item = store.value.items.first(where: { $0.id == itemID }),
              InvestigationDigest.hash(item.currentModelJSON) == itemModelSHA256 else { return false }
        return InvestigationDigest.hash(json) == modelSHA256
    }
    static func capture(_ document: PhotoDocument, coordinator: DocumentCoordinator, localization: L10n,
                        parent: URL = FileManager.default.temporaryDirectory) async throws -> OpenImageAnalysis {
        let snapshot = document.snapshot(), json = try ProjectSchema(snapshot.model).encoded()
        let root = parent.appendingPathComponent("PhotoAxis-analysis-" + UUID().uuidString + ".paxcase")
        var accepted = false
        defer { if !accepted { try? FileManager.default.removeItem(at: root) } }
        let store = try InvestigationCaseStore(root: root, creating: InvestigationCase(code: "CANVAS", title: snapshot.model.name,
            examiner: ""), removeOnClose: true)
        let image = try await coordinator.pipeline.exportImage(snapshot: snapshot,
            options: ExportOptions(size: snapshot.model.canvas, ppi: snapshot.model.ppi))
        let bytes = try await Task.detached { try InvestigationSharing.pngBytes(image, ppi: snapshot.model.ppi) }.value
        let input = root.appendingPathComponent("canvas-snapshot.png")
        try await InvestigationSharing.write(bytes, to: input)
        defer { try? FileManager.default.removeItem(at: input) }
        let notice = localization.text("investigation.currentImageProvenance")
        let item = try await store.importFile(input, intake: EvidenceIntake(source: notice),
            pipeline: coordinator.pipeline, projects: coordinator.projectStore)
        try store.mutate("openImageSnapshot", itemID: item.id, details: [
            "origin": "rendered-current-canvas-not-received-original", "documentID": snapshot.model.id.uuidString,
            "documentModelSHA256": InvestigationDigest.hash(json), "renderedPNG_SHA256": InvestigationDigest.hash(bytes),
            "embeddedSourceIDsJSON": String(decoding: try InvestigationDigest.encode(snapshot.model.sources.keys.sorted()), as: UTF8.self)
        ]) { value in value.items[0].caption = notice }
        accepted = true
        return OpenImageAnalysis(documentID: snapshot.model.id, modelSHA256: InvestigationDigest.hash(json), store: store,
            itemID: item.id, baseline: document.analysisBaseline ?? snapshot)
    }
    /// Preserve the complete local ledger and derived raster, without switching
    /// or replacing the editable tab. Destination must be a fresh case package.
    func save(to destination: URL, code: String, title: String, examiner: String) async throws -> OpenImageAnalysis {
        try store.verifyManifest(); try store.protectDestination(destination)
        guard destination.pathExtension.lowercased() == "paxcase",
              !FileManager.default.fileExists(atPath: destination.path) else { throw InvestigationError.protectedDestination }
        var accepted = false
        defer { if !accepted { try? FileManager.default.removeItem(at: destination) } }
        let source = store.root, manifestHash = try InvestigationFiles.hashFile(store.manifestURL)
        var files: [(URL, String)] = [(store.manifestURL, manifestHash)]
        for item in store.value.items {
            files.append((store.originalURL(item), item.originalSHA256))
            files.append((store.projectURL(item.id), item.workingFileSHA256))
            if let hash = item.intakeWorkingFileSHA256 { files.append((store.archiveURL(item.id, hash: hash), hash)) }
        }
        for video in store.value.analysis?.videos ?? [] { files.append((store.videoURL(video), video.sha256)) }
        let capturedFiles = files
        try await Task.detached {
            for (url, hash) in capturedFiles { guard try InvestigationFiles.hashFile(url) == hash else { throw InvestigationError.integrity } }
            try FileManager.default.copyItem(at: source, to: destination)
            for (url, hash) in capturedFiles {
                let relative = String(url.path.dropFirst(source.path.count + 1))
                guard try InvestigationFiles.hashFile(destination.appendingPathComponent(relative)) == hash else { throw InvestigationError.integrity }
            }
        }.value
        try store.verifyManifest()
        // A copied advisory lock file carries no OS lock. The new store owns it.
        let saved = try InvestigationCaseStore(root: destination)
        try saved.mutate("openImageAnalysisSaved", itemID: itemID, details: ["origin": "rendered-current-canvas-not-received-original"]) {
            $0.code = code; $0.title = title; $0.examiner = examiner
        }
        accepted = true
        return OpenImageAnalysis(documentID: documentID, modelSHA256: modelSHA256, store: saved,
            itemID: itemID, baseline: baseline, isTemporary: false)
    }
}

import AppKit
import PhotoAxisCore

struct PrivacyPatch: Sendable {
    let region: EvidenceRegion
    let asset: EmbeddedImage?
}

extension PhotoDocument {
    /// Validate every patch before publishing sources or committing a single Undo step.
    func applyPrivacy(_ patches: [PrivacyPatch], style: PrivacyStyle) throws {
        guard !hasSession, !isInteractionLocked, !patches.isEmpty, patches.count <= 20 else { throw DocumentError.activeSession }
        guard patches.allSatisfy({ style == .cover ? $0.asset == nil : $0.asset != nil }) else { throw DocumentError.invalidValue }
        var next = model
        var selection: UUID?
        for patch in patches {
            selection = try next.insertPrivacy(region: patch.region, source: patch.asset?.descriptor,
                                                name: localization.text("privacy.layer." + style.rawValue))
        }
        let previousAssets = assets, previousSelection = selectedLayerID
        for patch in patches { if let asset = patch.asset { retainPaintAsset(asset) } }
        selectedLayerID = selection
        guard commit(next, command: .privacy) else {
            assetsRestoreAfterFailedPrivacy(previousAssets, selected: previousSelection)
            throw InvestigationError.auditUnavailable
        }
    }
}

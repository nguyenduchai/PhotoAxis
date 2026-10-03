import Foundation

enum InterfaceLanguage: String, CaseIterable, Sendable {
    case system, vietnamese = "vi", english = "en"

    func resolved(preferredLanguages: [String]) -> String {
        if self != .system { return rawValue }
        for language in preferredLanguages {
            let base = language.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first
            if base == "vi" || base == "en" { return String(base!) }
        }
        return "en"
    }
}

struct WorkspaceLayout: Codable, Equatable {
    var panelWidth: Double = 300
    var toolColumns: Int = 1
    var panelCollapsed = false
    var rulersVisible = true

    func validated() -> Self {
        var result = self
        result.panelWidth = panelWidth.isFinite ? min(420, max(260, panelWidth)) : 300
        result.toolColumns = toolColumns == 2 ? 2 : 1
        return result
    }
}

@MainActor
final class WorkspacePreferences {
    static let layoutKey = "workspace.layout.v1"
    static let languageKey = "interface.language"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var language: InterfaceLanguage {
        get { InterfaceLanguage(rawValue: defaults.string(forKey: Self.languageKey) ?? "system") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Self.languageKey) }
    }

    var layout: WorkspaceLayout {
        get {
            guard let data = defaults.data(forKey: Self.layoutKey),
                  let layout = try? JSONDecoder().decode(WorkspaceLayout.self, from: data) else { return WorkspaceLayout() }
            return layout.validated()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue.validated()) { defaults.set(data, forKey: Self.layoutKey) }
        }
    }

    func resetLayout() { layout = WorkspaceLayout() }
}

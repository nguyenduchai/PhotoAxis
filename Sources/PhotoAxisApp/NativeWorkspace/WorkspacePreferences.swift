import AppKit

enum InterfaceAppearance: String, CaseIterable, Sendable {
    case system, dark, light
    var nativeAppearance: NSAppearance? {
        switch self { case .system: return nil; case .dark: return NSAppearance(named: .darkAqua); case .light: return NSAppearance(named: .aqua) }
    }
    @MainActor func apply() { NSApp.appearance = nativeAppearance }
}

struct FilePreferences: Codable, Equatable, Sendable {
    var recoverySeconds = 10
    var exportJPEG = false
    var jpegQuality = 90
    var linkExportDimensions = true
    func validated() -> Self {
        var value = self
        if ![10,30,60].contains(value.recoverySeconds) { value.recoverySeconds = 10 }
        value.jpegQuality = min(100,max(1,value.jpegQuality))
        return value
    }
}

enum RulerUnit: String, Codable, CaseIterable, Sendable {
    case pixels = "px", millimeters = "mm", centimeters = "cm", inches = "in"
    func pixelsPerUnit(ppi: Double) -> Double {
        let ppi = ppi.isFinite && ppi > 0 ? ppi : 72
        switch self { case .pixels: return 1; case .millimeters: return ppi/25.4; case .centimeters: return ppi/2.54; case .inches: return ppi }
    }
}

struct CanvasAppearance: Codable, Equatable, Sendable {
    enum Background: String, Codable, CaseIterable, Sendable {
        case dark, medium, light
        var gray: Double { switch self { case .dark: 30.0/255; case .medium: 0.28; case .light: 0.78 } }
    }
    enum GridSize: String, Codable, CaseIterable, Sendable {
        case small, medium, large
        var points: Double { switch self { case .small: 4; case .medium: 8; case .large: 16 } }
    }
    var background: Background = .dark
    var gridSize: GridSize = .medium
    var showsTransparency = true
}

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
    static let appearanceKey = "canvas.appearance.v1"
    static let brushKey = "paint.defaults.v1"
    static let themeKey = "interface.appearance.v1"
    static let filesKey = "files.defaults.v1"
    static let outlineKey = "tools.brushOutline.v1"
    static let rulerKey = "workspace.rulerUnit.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var language: InterfaceLanguage {
        get { InterfaceLanguage(rawValue: defaults.string(forKey: Self.languageKey) ?? "system") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Self.languageKey) }
    }

    var interfaceAppearance: InterfaceAppearance {
        get { InterfaceAppearance(rawValue: defaults.string(forKey:Self.themeKey) ?? "system") ?? .system }
        set { defaults.set(newValue.rawValue,forKey:Self.themeKey) }
    }
    var showsBrushOutline: Bool {
        get { defaults.object(forKey:Self.outlineKey) == nil || defaults.bool(forKey:Self.outlineKey) }
        set { defaults.set(newValue,forKey:Self.outlineKey) }
    }
    var files: FilePreferences {
        get { (defaults.data(forKey:Self.filesKey).flatMap { try? JSONDecoder().decode(FilePreferences.self,from:$0) } ?? FilePreferences()).validated() }
        set { if let data = try? JSONEncoder().encode(newValue.validated()) { defaults.set(data,forKey:Self.filesKey) } }
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
    var rulerUnit: RulerUnit {
        get { RulerUnit(rawValue:defaults.string(forKey:Self.rulerKey) ?? "px") ?? .pixels }
        set { defaults.set(newValue.rawValue,forKey:Self.rulerKey) }
    }
    var canvasAppearance: CanvasAppearance {
        get { defaults.data(forKey:Self.appearanceKey).flatMap { try? JSONDecoder().decode(CanvasAppearance.self,from:$0) } ?? CanvasAppearance() }
        set { if let data = try? JSONEncoder().encode(newValue) { defaults.set(data,forKey:Self.appearanceKey) } }
    }
    var brushDefaults: BrushSettings {
        get { (defaults.data(forKey:Self.brushKey).flatMap { try? JSONDecoder().decode(BrushSettings.self,from:$0) } ?? BrushSettings()).validated() }
        set { if let data = try? JSONEncoder().encode(newValue.validated()) { defaults.set(data,forKey:Self.brushKey) } }
    }
    func resetPresentation() { resetLayout(); rulerUnit = .pixels; canvasAppearance = CanvasAppearance() }
}

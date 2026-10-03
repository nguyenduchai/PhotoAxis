import AppKit
import XCTest
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class PreferencesAppearanceTests: XCTestCase {
    private func fixture() -> (WorkspacePreferences, UserDefaults, String) {
        let name = "PhotoAxis.Preferences9."+UUID().uuidString
        // Use one unique domain for both initial and reopened preference reads.
        let domain = UserDefaults(suiteName:name)!
        return (WorkspacePreferences(defaults:domain),domain,name)
    }
    func testAppearancePersistenceImmediateApplicationAndSystemInheritance() {
        let (preferences,defaults,name) = fixture(); defer { defaults.removePersistentDomain(forName:name) }
        let original = NSApp.appearance; defer { NSApp.appearance = original }
        let settings = SettingsWindowController(preferences:preferences,localization:L10n(choice:.english)); defer { settings.close() }
        XCTAssertEqual(preferences.interfaceAppearance,.system)
        for (index,choice) in InterfaceAppearance.allCases.enumerated() {
            settings.appearanceChoices.selectedSegment = index; settings.changeAppearance()
            XCTAssertEqual(WorkspacePreferences(defaults:UserDefaults(suiteName:name)!).interfaceAppearance,choice)
            XCTAssertEqual(NSApp.appearance?.name,choice.nativeAppearance?.name)
        }
        settings.selectCategory(4); settings.resetSection(); XCTAssertNil(NSApp.appearance)
    }
    func testDynamicSurfacesResolveTextBorderAndSelectionWithSufficientContrast() throws {
        let host = SurfaceView(color:WorkspaceStyle.panel); host.surfaceBorderColor = WorkspaceStyle.divider
        var grays: [CGFloat] = []
        for name in [NSAppearance.Name.darkAqua,.aqua] {
            host.appearance = NSAppearance(named:name); host.viewDidChangeEffectiveAppearance()
            let surface = try XCTUnwrap(NSColor(cgColor:host.layer!.backgroundColor!)?.usingColorSpace(.genericGray))
            var foreground: CGFloat = 0
            host.effectiveAppearance.performAsCurrentDrawingAppearance { foreground = WorkspaceStyle.text.usingColorSpace(.genericGray)!.whiteComponent }
            XCTAssertGreaterThan(abs(foreground-surface.whiteComponent),0.65)
            XCTAssertNotNil(host.layer?.borderColor); grays.append(surface.whiteComponent)
        }
        XCTAssertGreaterThan(grays[1]-grays[0],0.65)
    }
    func testFilesDefaultsPersistValidateAndOnlyAffectNewExportDialogs() throws {
        let (preferences,defaults,name) = fixture(); defer { defaults.removePersistentDomain(forName:name) }
        let coordinator = DocumentCoordinator(localization:L10n(choice:.english),preferences:preferences)
        try coordinator.create(name:"Synthetic",size:CanvasSize(width:64,height:32),ppi:72,background:.transparent)
        let snapshot = coordinator.active!.snapshot(), initial = ExportController(snapshot:snapshot,pipeline:coordinator.pipeline,localization:L10n(choice:.english),defaults:preferences.files)
        defer { initial.cancel(); initial.close() }
        let settings = SettingsWindowController(preferences:preferences,localization:L10n(choice:.english)); defer { settings.close() }
        settings.recoveryInterval.selectItem(at:2); settings.exportFormat.selectItem(at:1); settings.jpegQuality.stringValue = "74"; settings.exportLinked.state = .off; settings.changeFiles()
        let restored = WorkspacePreferences(defaults:UserDefaults(suiteName:name)!)
        XCTAssertEqual(restored.files,FilePreferences(recoverySeconds:60,exportJPEG:true,jpegQuality:74,linkExportDimensions:false))
        let next = ExportController(snapshot:snapshot,pipeline:coordinator.pipeline,localization:L10n(choice:.english),defaults:restored.files)
        defer { next.cancel(); next.close() }
        XCTAssertEqual(try next.validated().format,.jpeg); XCTAssertEqual(try next.validated().quality,74); XCTAssertEqual(next.link.state,.off)
        XCTAssertEqual(try initial.validated().format,.png); XCTAssertEqual(initial.link.state,.on)
        let accepted = preferences.files
        for invalid in ["0","101","NaN","90.5",""] { settings.jpegQuality.stringValue = invalid; settings.changeFiles(); XCTAssertEqual(preferences.files,accepted); XCTAssertFalse(settings.fileValidation.isHidden) }
        XCTAssertEqual(coordinator.active!.model,snapshot.model)
    }
    func testInvalidJPEGQualityDoesNotBlockIndependentValidFilePreferences() {
        let (preferences,defaults,name) = fixture(); defer { defaults.removePersistentDomain(forName:name) }
        let settings = SettingsWindowController(preferences:preferences,localization:L10n(choice:.english)); defer { settings.close() }
        settings.jpegQuality.stringValue = "NaN"
        settings.recoveryInterval.selectItem(at:1); settings.exportFormat.selectItem(at:1); settings.exportLinked.state = .off
        settings.changeFiles()
        XCTAssertEqual(preferences.files.recoverySeconds,30); XCTAssertTrue(preferences.files.exportJPEG)
        XCTAssertFalse(preferences.files.linkExportDimensions); XCTAssertEqual(preferences.files.jpegQuality,90)
        XCTAssertFalse(settings.fileValidation.isHidden)
    }
    func testCorruptPreferenceFallbackAndResetsAreScoped() {
        let (preferences,defaults,name) = fixture(); defer { defaults.removePersistentDomain(forName:name) }
        defaults.set("unknown",forKey:WorkspacePreferences.themeKey); defaults.set(Data("{}".utf8),forKey:WorkspacePreferences.filesKey)
        XCTAssertEqual(preferences.interfaceAppearance,.system); XCTAssertEqual(preferences.files,FilePreferences())
        preferences.files = FilePreferences(recoverySeconds:2,exportJPEG:true,jpegQuality:1000,linkExportDimensions:false)
        XCTAssertEqual(preferences.files.recoverySeconds,10); XCTAssertEqual(preferences.files.jpegQuality,100)
        let settings = SettingsWindowController(preferences:preferences,localization:L10n(choice:.english)); defer { settings.close() }
        let original = NSApp.appearance; defer { NSApp.appearance = original }
        preferences.interfaceAppearance = .dark; preferences.brushDefaults = BrushSettings(diameter:75); preferences.language = .vietnamese
        settings.selectCategory(5); settings.resetSection()
        XCTAssertEqual(preferences.files,FilePreferences()); XCTAssertEqual(preferences.interfaceAppearance,.dark)
        XCTAssertEqual(preferences.brushDefaults.diameter,75); XCTAssertEqual(preferences.language,.vietnamese)
    }
    func testBrushOutlineChangesLiveWithoutChangingDocumentOrToolCursor() throws {
        let (preferences,defaults,name) = fixture(); defer { defaults.removePersistentDomain(forName:name) }
        let host = WorkspaceWindowController(preferences:preferences,localization:L10n(choice:.english),restoreFrame:false); defer { host.close() }
        let coordinator = DocumentCoordinator(localization:L10n(choice:.english),preferences:preferences)
        try coordinator.create(name:"Synthetic",size:CanvasSize(width:64,height:32),ppi:72,background:.transparent)
        let document = coordinator.active!, before = document.model, state = document.history.stateID
        document.activeTool = .brush; host.workspaceView.refreshDocuments(coordinator)
        let canvas = host.workspaceView.canvas, kind = canvas.cursorKind(at:nil)
        XCTAssertFalse(canvas.paintCursor.isHidden)
        preferences.showsBrushOutline = false; host.reloadLayout(); XCTAssertTrue(canvas.paintCursor.isHidden)
        XCTAssertEqual(canvas.cursorKind(at:nil),kind)
        preferences.showsBrushOutline = true; host.reloadLayout(); XCTAssertFalse(canvas.paintCursor.isHidden)
        XCTAssertEqual(document.model,before); XCTAssertEqual(document.history.stateID,state)
    }
    func testAllSettingsPagesFitAtMinimumSizeInBothAppearancesAndLanguages() {
        for language in [InterfaceLanguage.vietnamese,.english] {
            let (preferences,defaults,name) = fixture(); defer { defaults.removePersistentDomain(forName:name) }
            let settings = SettingsWindowController(preferences:preferences,localization:L10n(choice:language)); defer { settings.close() }
            settings.showWindow(nil); settings.window!.setContentSize(NSSize(width:880,height:538))
            for appearance in [NSAppearance.Name.darkAqua,.aqua] {
                settings.window!.appearance = NSAppearance(named:appearance)
                for index in 0..<6 {
                    settings.selectCategory(index); settings.window!.contentView!.layoutSubtreeIfNeeded()
                    for button in settings.categoryButtons { XCTAssertTrue(button.superview!.bounds.contains(button.frame)); XCTAssertEqual(button.state,button.tag == index ? .on:.off) }
                    func inspect(_ view:NSView) {
                        guard !view.isHidden else { return }
                        if view is NSControl, let parent = view.superview, parent is NSStackView {
                            XCTAssertGreaterThan(view.frame.width,0,"\(view.identifier?.rawValue ?? view.description)")
                            // AppKit text controls include 2pt drawing padding outside their alignment rect.
                            let rect = view.alignmentRect(forFrame:view.frame)
                            XCTAssertLessThanOrEqual(rect.maxX,parent.bounds.maxX+1,"Clipped control \(view.identifier?.rawValue ?? view.description)")
                            XCTAssertGreaterThanOrEqual(rect.minX,-1)
                        }
                        view.subviews.forEach(inspect)
                    }
                    inspect(settings.window!.contentView!)
                }
            }
        }
    }
}

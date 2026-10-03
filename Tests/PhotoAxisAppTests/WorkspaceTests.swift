import AppKit
import XCTest
import PhotoAxisCore
@testable import PhotoAxis

@MainActor
final class WorkspaceTests: XCTestCase {
    private func fixture() -> (WorkspacePreferences, UserDefaults, String) {
        let name = "local.photoaxis.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        return (WorkspacePreferences(defaults: defaults), defaults, name)
    }

    func testSaveAndExportProgressSurviveRefreshTabSwitchAndViewportChanges() throws {
        for language in [InterfaceLanguage.vietnamese, .english] {
            let (preferences, defaults, name) = fixture()
            defer { defaults.removePersistentDomain(forName: name) }
            let l10n = L10n(choice: language)
            let host = WorkspaceWindowController(preferences: preferences, localization: l10n, restoreFrame: false)
            defer { host.close() }
            let documents = DocumentCoordinator(localization: l10n)
            let view = host.workspaceView
            documents.changed = { view.refreshDocuments(documents) }
            documents.progressChanged = { view.setImportProgress($0) }
            try documents.create(name: "First", size: CanvasSize(width: 640, height: 480), ppi: 144, background: .transparent)
            try documents.create(name: "Second", size: CanvasSize(width: 400, height: 300), ppi: 72, background: .transparent)
            host.showWindow(nil); host.reloadLayout()
            let status = try XCTUnwrap(view.statusBar.subviews.compactMap { $0 as? NSTextField }
                .first { $0.identifier?.rawValue == "workspace.taskStatus" })
            for key in ["project.saving", "export.progress"] {
                let message = String(format: l10n.text(key), "First")
                documents.progressChanged?(message)
                view.refreshDocuments(documents)
                documents.select(documents.documents[0].model.id)
                view.canvas.zoom(to: 1)
                documents.select(documents.documents[1].model.id)
                view.canvas.zoom(to: 2)
                XCTAssertEqual(status.stringValue, message, "Refreshing document state must preserve the running task's visible message")
                XCTAssertEqual(status.toolTip, message)
                XCTAssertFalse(view.cancelImportButton.isHidden)
                documents.progressChanged?(nil)
                XCTAssertTrue(view.cancelImportButton.isHidden)
                XCTAssertNil(status.toolTip)
                XCTAssertTrue(status.stringValue.contains("400"))
                XCTAssertFalse(status.stringValue.contains(message))
            }
            documents.remove(documents.documents[0].model.id)
            documents.remove(documents.documents[0].model.id)
        }
    }

    func testSystemLanguageOrderAndEnglishFallback() {
        XCTAssertEqual(InterfaceLanguage.system.resolved(preferredLanguages: ["fr-FR", "vi-VN", "en"]), "vi")
        XCTAssertEqual(InterfaceLanguage.system.resolved(preferredLanguages: ["de", "en-GB", "vi"]), "en")
        XCTAssertEqual(InterfaceLanguage.system.resolved(preferredLanguages: ["ja", "zh"]), "en")
        XCTAssertEqual(InterfaceLanguage.system.resolved(preferredLanguages: []), "en")
        XCTAssertEqual(InterfaceLanguage.vietnamese.resolved(preferredLanguages: ["en"]), "vi")
        XCTAssertEqual(InterfaceLanguage.english.resolved(preferredLanguages: ["vi"]), "en")
    }

    func testLanguageChangeWaitsForNextLaunchAndResetPreservesIt() throws {
        let (preferences, defaults, name) = fixture()
        defer { defaults.removePersistentDomain(forName: name) }
        let current = L10n(choice: .system, preferredLanguages: ["vi-VN"])
        let settings = SettingsWindowController(preferences: preferences, localization: current)
        defer { settings.close() }
        settings.showWindow(nil)
        settings.languagePopup.selectItem(at: 2)
        settings.changeLanguage()
        XCTAssertEqual(preferences.language, .english)
        XCTAssertEqual(current.text("menu.file"), "Tệp")
        XCTAssertFalse(settings.restartNotice.isHidden)
        XCTAssertTrue(settings.window!.isVisible, "Changing language must not quit the app")
        let reopenedPreferences = WorkspacePreferences(defaults: UserDefaults(suiteName: name)!)
        XCTAssertEqual(L10n(choice: reopenedPreferences.language).text("menu.file"), "File")
        preferences.resetLayout()
        XCTAssertEqual(preferences.language, .english)
        settings.languagePopup.selectItem(at: 0); settings.changeLanguage()
        XCTAssertTrue(settings.restartNotice.isHidden)
    }

    func testLayoutPersistenceAndCorruptPreferencesRecovery() throws {
        let (preferences, defaults, name) = fixture()
        defer { defaults.removePersistentDomain(forName: name) }
        let controller = WorkspaceWindowController(preferences: preferences, localization: L10n(choice: .english), restoreFrame: false)
        controller.showWindow(nil)
        controller.toggleToolsColumns()
        controller.workspaceView.divider.resize?(392)
        controller.togglePanel(); controller.toggleRulers()
        controller.close()
        let restored = WorkspacePreferences(defaults: UserDefaults(suiteName: name)!)
        XCTAssertEqual(restored.layout.panelWidth, 392)
        XCTAssertEqual(restored.layout.toolColumns, 2)
        XCTAssertTrue(restored.layout.panelCollapsed)
        XCTAssertFalse(restored.layout.rulersVisible)
        let reopened = WorkspaceWindowController(preferences: restored, localization: L10n(choice: .english), restoreFrame: false)
        defer { reopened.close() }
        reopened.showWindow(nil); reopened.reloadLayout()
        XCTAssertEqual(reopened.workspaceView.tools.frame.width, 72)
        XCTAssertTrue(reopened.workspaceView.sidebar.isHidden)
        reopened.resetWorkspace()
        XCTAssertEqual(restored.layout, WorkspaceLayout())
        defaults.set(Data("not json".utf8), forKey: WorkspacePreferences.layoutKey)
        XCTAssertEqual(restored.layout, WorkspaceLayout())
        var invalid = WorkspaceLayout(); invalid.panelWidth = 900; invalid.toolColumns = 9
        defaults.set(try JSONEncoder().encode(invalid), forKey: WorkspacePreferences.layoutKey)
        XCTAssertEqual(restored.layout.panelWidth, 420)
        XCTAssertEqual(restored.layout.toolColumns, 1)
    }

    func testSidebarResizeAndNumericValidation() {
        let (preferences, defaults, name) = fixture()
        defer { defaults.removePersistentDomain(forName: name) }
        let controller = WorkspaceWindowController(preferences: preferences, localization: L10n(choice: .vietnamese), restoreFrame: false)
        let settings = SettingsWindowController(preferences: preferences, localization: L10n(choice: .vietnamese))
        defer { controller.close(); settings.close() }
        settings.layoutChanged = { controller.reloadLayout() }
        controller.showWindow(nil)
        controller.reloadLayout()
        let divider = controller.workspaceView.divider
        let root = controller.workspaceView
        for targetWidth: CGFloat in [260, 350, 420] {
            let point = root.convert(NSPoint(x: root.bounds.maxX - targetWidth, y: 200), to: nil)
            let start = divider.convert(NSPoint(x: divider.bounds.midX, y: 160), to: nil)
            XCTAssertTrue(divider.hitTest(root.convert(start, from: nil)) === divider,
                          "Divider hit testing: \(divider.frame), hidden=\(divider.isHidden), enabled=\(divider.isEnabled)")
            XCTAssertTrue(root.superview?.hitTest(start) === divider, "Window hit view: \(String(describing: root.superview?.hitTest(start))) at \(start)")
            let down = NSEvent.mouseEvent(with: .leftMouseDown, location: start, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: controller.window!.windowNumber, context: nil,
                                          eventNumber: 0, clickCount: 1, pressure: 1)!
            let drag = NSEvent.mouseEvent(with: .leftMouseDragged, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: controller.window!.windowNumber, context: nil,
                                          eventNumber: 0, clickCount: 1, pressure: 1)!
            // Verify hit testing and the responder's window-coordinate conversion.
            // Physical WindowServer dispatch remains a separate native acceptance check.
            divider.mouseDown(with: down)
            XCTAssertTrue(controller.window!.firstResponder === divider)
            divider.mouseDragged(with: drag); controller.reloadLayout()
            XCTAssertEqual(root.sidebar.frame.width, targetWidth)
        }
        divider.resize?(120); controller.reloadLayout()
        XCTAssertEqual(controller.workspaceView.sidebar.frame.width, 260)
        divider.resize?(900); controller.reloadLayout()
        XCTAssertEqual(controller.workspaceView.sidebar.frame.width, 420)
        XCTAssertTrue(divider.accessibilityPerformDecrement()); controller.reloadLayout()
        XCTAssertEqual(controller.workspaceView.sidebar.frame.width, 412)
        for invalid in ["300abc", "500", "259", "300.5", "", "nan", "∞"] {
            settings.widthField.stringValue = invalid; settings.changeWidth()
            XCTAssertEqual(preferences.layout.panelWidth, 412)
            XCTAssertFalse(settings.validationNotice.isHidden)
        }
        settings.widthField.stringValue = "320"; settings.changeWidth()
        XCTAssertEqual(preferences.layout.panelWidth, 320)
        XCTAssertTrue(settings.validationNotice.isHidden)
        settings.showWindow(nil); settings.widthField.selectText(nil); settings.close()
        controller.resetWorkspace(); settings.refreshLayoutControls(); settings.showWindow(nil)
        XCTAssertEqual(settings.widthField.stringValue, "300", "A closed Settings editor must refresh after workspace reset")
    }

    func testTabIsScopedToCanvasAndDoesNotStealTextEditing() {
        let (preferences, defaults, name) = fixture()
        defer { defaults.removePersistentDomain(forName: name) }
        let controller = WorkspaceWindowController(preferences: preferences, localization: L10n(choice: .english), restoreFrame: false)
        let settings = SettingsWindowController(preferences: preferences, localization: L10n(choice: .english))
        defer { controller.close(); settings.close() }
        controller.showWindow(nil)
        let window = controller.window!
        let root = controller.workspaceView
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(root.canvas)
        let tab = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: window.windowNumber, context: nil, characters: "\t",
                                  charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48)!
        window.sendEvent(tab); controller.reloadLayout()
        XCTAssertTrue(root.chromeHidden)
        XCTAssertTrue(root.tools.isHidden); XCTAssertTrue(root.sidebar.isHidden)
        window.sendEvent(tab); controller.reloadLayout()
        XCTAssertFalse(root.chromeHidden)
        settings.showWindow(nil); settings.window?.makeKeyAndOrderFront(nil)
        settings.widthField.selectText(nil)
        XCTAssertTrue(settings.window?.firstResponder is NSTextView)
        let fieldTab = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                       windowNumber: settings.window!.windowNumber, context: nil, characters: "\t",
                                       charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48)!
        settings.window!.sendEvent(fieldTab)
        XCTAssertFalse(root.chromeHidden)
    }

    func testDisabledToolsAndInspectorSwitch() {
        let (preferences, defaults, name) = fixture()
        defer { defaults.removePersistentDomain(forName: name) }
        let controller = WorkspaceWindowController(preferences: preferences, localization: L10n(choice: .vietnamese), restoreFrame: false)
        defer { controller.close() }
        let root = controller.workspaceView
        for view in root.tools.subviews {
            guard let button = view as? NSButton, button.identifier?.rawValue.hasPrefix("tool.") == true else { continue }
            XCTAssertNotNil(button.accessibilityLabel())
            if let group = button as? ToolGroupButton {
                XCTAssertTrue(group.isEnabled)
                XCTAssertFalse(group.flyout!.items.isEmpty)
                XCTAssertTrue(group.flyout!.items.allSatisfy { !$0.isEnabled })
            } else { XCTAssertFalse(button.isEnabled) }
        }
        root.sidebar.inspectorTabs.selectedSegment = 1; root.sidebar.changeInspector()
        XCTAssertEqual(root.sidebar.inspectorMessage.stringValue, "Chưa có lịch sử chỉnh sửa.")
        XCTAssertFalse(root.optionsBar.applyButton.isEnabled)
        XCTAssertFalse(root.optionsBar.cancelButton.isEnabled)
    }

    func testNativeLayoutsAndSnapshotsInBothLanguages() throws {
        let output = (0..<5).reduce(Bundle.main.bundleURL) { url, _ in url.deletingLastPathComponent() }
            .appendingPathComponent("p01-native-tests", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var measurements: [[String: Any]] = []
        for choice in [InterfaceLanguage.vietnamese, .english] {
            let (preferences, defaults, name) = fixture()
            defer { defaults.removePersistentDomain(forName: name) }
            let controller = WorkspaceWindowController(preferences: preferences, localization: L10n(choice: choice), restoreFrame: false)
            defer { controller.close() }
            let window = controller.window!
            controller.showWindow(nil)
            for (width, height) in [(1440, 900), (1280, 800), (1100, 700)] {
                window.setFrame(NSRect(x: 30, y: 30, width: width, height: height), display: true)
                controller.reloadLayout()
                let root = controller.workspaceView
                root.layoutSubtreeIfNeeded(); window.displayIfNeeded()
                XCTAssertEqual(window.frame.width, CGFloat(width), accuracy: 0.1)
                XCTAssertEqual(window.frame.height, CGFloat(height), accuracy: 0.1)
                XCTAssertEqual(root.tools.frame.width, 44)
                XCTAssertEqual(root.sidebar.frame.width, 300)
                XCTAssertEqual(root.optionsBar.frame.height, 36)
                XCTAssertEqual(root.tabBar.frame.height, 28)
                XCTAssertEqual(root.statusBar.frame.height, 24)
                XCTAssertGreaterThan(root.canvas.frame.width, 500)
                let options = root.optionsBar
                XCTAssertTrue(options.bounds.contains(options.applyButton.frame))
                XCTAssertTrue(options.bounds.contains(options.cancelButton.frame))
                XCTAssertFalse(options.applyButton.frame.intersects(options.cancelButton.frame))
                XCTAssertTrue(root.sidebar.frame.minX > root.canvas.frame.maxX)
                guard let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) else { XCTFail("Cannot capture native view"); return }
                root.cacheDisplay(in: root.bounds, to: bitmap)
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                let filename = "workspace-\(choice.rawValue)-\(width)x\(height).png"
                try data.write(to: output.appendingPathComponent(filename))
                measurements.append(["language": choice.rawValue, "windowWidthPt": window.frame.width,
                    "windowHeightPt": window.frame.height, "contentWidthPt": root.bounds.width,
                    "contentHeightPt": root.bounds.height, "backingScale": window.backingScaleFactor,
                    "toolsWidthPt": root.tools.frame.width, "panelWidthPt": root.sidebar.frame.width,
                    "optionsHeightPt": options.frame.height, "tabHeightPt": root.tabBar.frame.height,
                    "statusHeightPt": root.statusBar.frame.height, "snapshot": filename])
            }
            let options = controller.workspaceView.optionsBar
            options.configure(for: .perspectiveCrop)
            options.frame.size.width = 600; options.layoutSubtreeIfNeeded()
            XCTAssertTrue(options.usesOverflow, "Long options must overflow rather than cover Apply/Cancel")
            XCTAssertFalse(options.overflowButton.isHidden)
            XCTAssertTrue(options.bounds.contains(options.applyButton.frame))
            XCTAssertTrue(options.bounds.contains(options.cancelButton.frame))
        }
        try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("layout-measurements.json"))
    }
}

import XCTest
import AppKit
import PhotoAxisCore
@testable import PhotoAxis

@MainActor final class WorkspaceRefinementTests: XCTestCase {
    private func fixture() -> (WorkspacePreferences,UserDefaults,String) {
        let name = "PhotoAxis.UI7."+UUID().uuidString
        // A dedicated persistent domain prevents changing the user's preferences.
        let isolated = UserDefaults(suiteName:name)!
        return (WorkspacePreferences(defaults:isolated),isolated,name)
    }
    func testRulerLabelsStayInsideAndTicksMatchViewportAtEveryScale() throws {
        let canvas = try CanvasSize(width:1200,height:900)
        for backing in [1.0,2.0] {
            for zoom in [0.05,0.25,1,4,16] {
                var viewport = ViewportState(); viewport.resize(width:640,height:480,backingScale:backing,canvas:canvas)
                viewport.setZoom(zoom); viewport.pan(x:84-viewport.origin.x,y:65-viewport.origin.y)
                for unit in RulerUnit.allCases {
                    for vertical in [false,true] {
                        let ruler = RulerView(vertical:vertical); ruler.unit = unit; ruler.ppi = 300; ruler.viewport = viewport
                        ruler.frame = vertical ? NSRect(x:0,y:0,width:RulerView.verticalWidth,height:480) : NSRect(x:0,y:0,width:640,height:RulerView.horizontalHeight)
                        let ticks = ruler.ticks(); XCTAssertFalse(ticks.isEmpty)
                        let zero = try XCTUnwrap(ticks.first { $0.major && abs($0.pixels) < 1e-7 })
                        XCTAssertEqual(zero.position,vertical ? 65:84,accuracy:0.001)
                        for tick in ticks {
                            let mapped = viewport.transform.viewPoint(fromDocument:vertical ? Point2D(x:0,y:tick.pixels):Point2D(x:tick.pixels,y:0))
                            XCTAssertEqual(tick.position,vertical ? mapped.y:mapped.x,accuracy:0.001)
                            if let rect = tick.labelRect { XCTAssertTrue(ruler.bounds.insetBy(dx:3,dy:3).contains(rect)) }
                        }
                        XCTAssertLessThan(ticks.count,150)
                    }
                }
            }
        }
        XCTAssertEqual(RulerUnit.millimeters.pixelsPerUnit(ppi:300)*25.4,300,accuracy:0.0001)
        XCTAssertEqual(RulerUnit.centimeters.pixelsPerUnit(ppi:72)*2.54,72,accuracy:0.0001)
    }
    func testRulerCornerAlignmentAndHideRestoreDoNotTouchDocument() throws {
        let (preferences,defaults,name) = fixture(); defer { defaults.removePersistentDomain(forName:name) }
        let host = WorkspaceWindowController(preferences:preferences,localization:L10n(choice:.english),restoreFrame:false); defer { host.close() }
        let coordinator = DocumentCoordinator(localization:L10n(choice:.english))
        try coordinator.create(name:"Ruler",size:CanvasSize(width:600,height:400),ppi:300,background:.white)
        host.showWindow(nil); host.workspaceView.refreshDocuments(coordinator); host.reloadLayout()
        let root = host.workspaceView, original = coordinator.active!.model, state = coordinator.active!.history.stateID
        XCTAssertEqual(root.verticalRuler.frame.minY,root.canvas.frame.minY)
        XCTAssertEqual(root.horizontalRuler.frame.minX,root.canvas.frame.minX)
        XCTAssertFalse(root.horizontalRuler.frame.intersects(root.verticalRuler.frame))
        preferences.rulerUnit = .millimeters; host.reloadLayout()
        XCTAssertEqual(root.rulerUnitLabel.stringValue,"mm"); XCTAssertEqual(root.horizontalRuler.ppi,300)
        host.toggleRulers(); XCTAssertTrue(root.rulerCorner.isHidden)
        host.toggleRulers(); XCTAssertFalse(root.rulerCorner.isHidden)
        XCTAssertEqual(coordinator.active!.model,original); XCTAssertEqual(coordinator.active!.history.stateID,state)
    }
    func testLegacyAndNewPreferencePersistenceAndSectionResetIsolation() throws {
        let (preferences,defaults,name) = fixture(); defer { defaults.removePersistentDomain(forName:name) }
        defaults.set(Data("{\"panelWidth\":392,\"toolColumns\":2,\"panelCollapsed\":false,\"rulersVisible\":false}".utf8),forKey:WorkspacePreferences.layoutKey)
        preferences.language = .english; preferences.rulerUnit = .centimeters
        preferences.canvasAppearance = CanvasAppearance(background:.light,gridSize:.large,showsTransparency:false)
        preferences.brushDefaults = BrushSettings(diameter:90,hardness:0.3,opacity:0.6,aligned:false)
        let restored = WorkspacePreferences(defaults:UserDefaults(suiteName:name)!)
        XCTAssertEqual(restored.layout.panelWidth,392); XCTAssertEqual(restored.layout.toolColumns,2)
        XCTAssertEqual(restored.rulerUnit,.centimeters); XCTAssertEqual(restored.canvasAppearance.background,.light)
        XCTAssertEqual(restored.brushDefaults.diameter,90)
        let settings = SettingsWindowController(preferences:restored,localization:L10n(choice:.english)); defer { settings.close() }
        settings.selectCategory(2); settings.resetSection()
        XCTAssertEqual(restored.canvasAppearance,CanvasAppearance()); XCTAssertEqual(restored.rulerUnit,.centimeters)
        XCTAssertEqual(restored.brushDefaults.diameter,90); XCTAssertEqual(restored.language,.english)
        settings.selectCategory(1); settings.resetSection()
        XCTAssertEqual(restored.layout,WorkspaceLayout()); XCTAssertEqual(restored.rulerUnit,.pixels)
        XCTAssertEqual(restored.brushDefaults.diameter,90); XCTAssertEqual(restored.language,.english)
        defaults.set(Data("bad".utf8),forKey:WorkspacePreferences.brushKey); defaults.set(Data("bad".utf8),forKey:WorkspacePreferences.appearanceKey)
        XCTAssertEqual(restored.brushDefaults,BrushSettings()); XCTAssertEqual(restored.canvasAppearance,CanvasAppearance())
    }
    func testSettingsBrushValidationAndDefaultsApplyOnlyToNextDocument() throws {
        let (preferences,defaults,name) = fixture(); defer { defaults.removePersistentDomain(forName:name) }
        let settings = SettingsWindowController(preferences:preferences,localization:L10n(choice:.vietnamese)); defer { settings.close() }
        let coordinator = DocumentCoordinator(localization:L10n(choice:.english),preferences:preferences)
        try coordinator.create(name:"Before",size:CanvasSize(width:100,height:100),ppi:72,background:.transparent)
        let first = coordinator.active!, model = first.model
        settings.brushFields[0].stringValue = "9000"; settings.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:settings.brushFields[0]))
        XCTAssertEqual(preferences.brushDefaults.diameter,40); XCTAssertFalse(settings.brushValidation.isHidden)
        settings.brushFields[0].stringValue = "125"; settings.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:settings.brushFields[0]))
        settings.brushSliders[2].doubleValue = 35; settings.changeBrushSlider(settings.brushSliders[2])
        settings.brushAligned.state = .off; settings.changeBrushAligned()
        XCTAssertTrue(settings.brushValidation.isHidden); XCTAssertEqual(first.brushSettings.diameter,40)
        try coordinator.create(name:"After",size:CanvasSize(width:100,height:100),ppi:72,background:.transparent)
        XCTAssertEqual(coordinator.active!.brushSettings.diameter,125); XCTAssertEqual(coordinator.active!.brushSettings.opacity,0.35)
        XCTAssertFalse(coordinator.active!.brushSettings.aligned); XCTAssertEqual(first.model,model)
    }
    func testCanvasAppearanceChangesDisplayAndPreservesExportPixels() async throws {
        let pipeline = ImagePipeline(), size = try CanvasSize(width:100,height:100)
        let model = try PhotoDocumentModel(name:"Transparent",canvas:size,ppi:72)
        var viewport = ViewportState(); viewport.resize(width:400,height:300,backingScale:1,canvas:size)
        let before = try await pipeline.renderDocument(model:model,assets:[:])
        let dark = try await pipeline.render(model:model,assets:[:],viewport:viewport)
        let light = try await pipeline.render(model:model,assets:[:],viewport:viewport,appearance:CanvasAppearance(background:.light,gridSize:.small,showsTransparency:false))
        XCTAssertNotEqual(dark.dataProvider!.data! as Data,light.dataProvider!.data! as Data)
        let after = try await pipeline.renderDocument(model:model,assets:[:])
        XCTAssertEqual(before.dataProvider!.data! as Data,after.dataProvider!.data! as Data)
        let bytes = [UInt8](after.dataProvider!.data! as Data)
        XCTAssertTrue(stride(from:3,to:bytes.count,by:4).allSatisfy { bytes[$0] == 0 })
    }
    func testVisibleWorkspacePagesInBothLanguagesAtMinimumPanelWidth() {
        for language in [InterfaceLanguage.vietnamese,.english] {
            let sidebar = SidebarView(localization:L10n(choice:language))
            let pages = (0..<3).map { _ in SurfaceView() }; sidebar.installPages(pages)
            sidebar.frame = NSRect(x:0,y:0,width:260,height:640); sidebar.layoutSubtreeIfNeeded()
            XCTAssertEqual(sidebar.pageButtons.count,4); XCTAssertTrue(sidebar.pageSelector.isHidden)
            var changes: [Int] = []; sidebar.pageChanged = { changes.append($0) }
            for (i,button) in sidebar.pageButtons.enumerated() {
                XCTAssertFalse(button.isHidden); XCTAssertTrue(sidebar.bounds.contains(button.frame))
                let textWidth = (button.title as NSString).size(withAttributes:[.font:button.font!]).width
                XCTAssertLessThan(textWidth+32,button.frame.width)
                button.performClick(nil); XCTAssertEqual(sidebar.selectedPage,i)
                XCTAssertEqual(button.state,.on)
                for (j,page) in pages.enumerated() { XCTAssertEqual(page.isHidden,i != j+1) }
            }
            XCTAssertEqual(changes,[1,2,3]); XCTAssertFalse(sidebar.pageHelp.stringValue.isEmpty)
        }
    }
    func testSettingsCategoriesBilingualMinimumLayoutAndLiveWorkspaceControls() {
        for language in [InterfaceLanguage.vietnamese,.english] {
            let (preferences,defaults,name) = fixture(); defer { defaults.removePersistentDomain(forName:name) }
            let settings = SettingsWindowController(preferences:preferences,localization:L10n(choice:language)); defer { settings.close() }
            var changes = 0; settings.layoutChanged = { changes += 1 }
            settings.showWindow(nil); settings.window!.setContentSize(NSSize(width:880,height:540)); settings.window!.contentView!.layoutSubtreeIfNeeded()
            XCTAssertEqual(settings.categoryButtons.count,6)
            for i in 0..<6 { settings.selectCategory(i); settings.window!.contentView!.layoutSubtreeIfNeeded() }
            settings.rulers.state = .off; settings.rulerUnits.selectItem(at:3); settings.changeWorkspace()
            XCTAssertFalse(preferences.layout.rulersVisible); XCTAssertEqual(preferences.rulerUnit,.inches)
            settings.canvasBackground.selectItem(at:2); settings.transparency.state = .off; settings.changeCanvas()
            XCTAssertEqual(preferences.canvasAppearance.background,.light); XCTAssertFalse(settings.gridSizes.isEnabled)
            XCTAssertEqual(changes,2)
        }
    }
}

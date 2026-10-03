import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    let preferences: WorkspacePreferences
    let localization: L10n
    let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let widthField = NSTextField(string: "")
    let columns = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
    let restartNotice: NSTextField
    let validationNotice: NSTextField
    private let widthStepper = NSStepper()
    var layoutChanged: (() -> Void)?
    private let initialLanguage: InterfaceLanguage
    private let formatter: NumberFormatter

    init(preferences: WorkspacePreferences, localization: L10n, launchLanguage: InterfaceLanguage? = nil) {
        self.preferences = preferences
        self.localization = localization
        initialLanguage = launchLanguage ?? preferences.language
        restartNotice = NSTextField(wrappingLabelWithString: localization.text("settings.restart"))
        validationNotice = NSTextField(wrappingLabelWithString: localization.text("settings.widthError"))
        formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.isLenient = false
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 530, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = localization.text("menu.settings")
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("settings.window")
        super.init(window: window)
        buildContent()
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("Use init(preferences:localization:)") }

    private func buildContent() {
        let root = SurfaceView()
        root.frame = NSRect(x: 0, y: 0, width: 530, height: 300)
        window?.contentView = root
        let languageLabel = WorkspaceStyle.label(localization.text("settings.language"))
        languageLabel.frame = NSRect(x: 24, y: 30, width: 185, height: 20)
        languagePopup.addItems(withTitles: [localization.text("language.system"), "Tiếng Việt", "English"])
        languagePopup.selectItem(at: InterfaceLanguage.allCases.firstIndex(of: preferences.language) ?? 0)
        languagePopup.frame = NSRect(x: 220, y: 25, width: 280, height: 28)
        languagePopup.target = self; languagePopup.action = #selector(changeLanguage)
        languagePopup.setAccessibilityLabel(localization.text("settings.language"))
        languagePopup.identifier = .init("settings.language")
        restartNotice.font = .systemFont(ofSize: 12)
        restartNotice.textColor = .secondaryLabelColor
        restartNotice.frame = NSRect(x: 24, y: 67, width: 480, height: 40)
        restartNotice.isHidden = preferences.language == initialLanguage
        let separator = NSBox(); separator.boxType = .separator
        separator.frame = NSRect(x: 24, y: 119, width: 480, height: 1)
        let widthLabel = WorkspaceStyle.label(localization.text("settings.panelWidth"))
        widthLabel.frame = NSRect(x: 24, y: 144, width: 185, height: 20)
        widthField.frame = NSRect(x: 224, y: 140, width: 82, height: 24)
        widthField.stringValue = formatter.string(from: NSNumber(value: preferences.layout.panelWidth)) ?? "300"
        widthField.target = self; widthField.action = #selector(changeWidth)
        widthField.setAccessibilityLabel(localization.text("settings.panelWidth"))
        widthField.identifier = .init("settings.panelWidth")
        let range = WorkspaceStyle.label(localization.text("settings.widthRange"), size: 11, secondary: true)
        range.frame = NSRect(x: 318, y: 146, width: 180, height: 18)
        let stepper = widthStepper
        stepper.frame = NSRect(x: 308, y: 138, width: 14, height: 28)
        stepper.minValue = 260; stepper.maxValue = 420; stepper.increment = 8
        stepper.doubleValue = preferences.layout.panelWidth
        stepper.target = self; stepper.action = #selector(stepWidth(_:))
        stepper.setAccessibilityLabel(localization.text("settings.panelWidth"))
        range.frame.origin.x = 336
        validationNotice.font = .systemFont(ofSize: 11)
        validationNotice.textColor = .systemOrange
        validationNotice.frame = NSRect(x: 224, y: 171, width: 280, height: 30)
        validationNotice.isHidden = true
        let columnsLabel = WorkspaceStyle.label(localization.text("settings.toolColumns"))
        columnsLabel.frame = NSRect(x: 24, y: 216, width: 185, height: 20)
        columns.segmentCount = 2
        columns.setLabel(localization.text("tools.oneColumn"), forSegment: 0)
        columns.setLabel(localization.text("tools.twoColumns"), forSegment: 1)
        columns.selectedSegment = preferences.layout.toolColumns - 1
        columns.frame = NSRect(x: 220, y: 209, width: 280, height: 28)
        columns.target = self; columns.action = #selector(changeColumns)
        columns.setAccessibilityLabel(localization.text("settings.toolColumns"))
        columns.identifier = .init("settings.toolColumns")
        for child in [languageLabel, languagePopup, restartNotice, separator, widthLabel, widthField,
                      stepper, range, validationNotice, columnsLabel, columns] { root.addSubview(child) }
    }

    @objc func changeLanguage() {
        let choices = InterfaceLanguage.allCases
        guard choices.indices.contains(languagePopup.indexOfSelectedItem) else { return }
        preferences.language = choices[languagePopup.indexOfSelectedItem]
        restartNotice.isHidden = preferences.language == initialLanguage
        // The current L10n instance is immutable; document content is never touched.
    }

    @objc func changeWidth() {
        let text = widthField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // Decimal digits only; no partial NumberFormatter parses such as "300abc".
        let digits = text.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
        guard !text.isEmpty, digits, let number = formatter.number(from: text),
              (260...420).contains(number.doubleValue), number.doubleValue.rounded() == number.doubleValue else {
            validationNotice.isHidden = false; return
        }
        var layout = preferences.layout; layout.panelWidth = number.doubleValue; preferences.layout = layout
        widthStepper.doubleValue = number.doubleValue
        validationNotice.isHidden = true
        layoutChanged?()
    }

    @objc private func stepWidth(_ sender: NSStepper) {
        widthField.stringValue = formatter.string(from: NSNumber(value: sender.doubleValue)) ?? "300"
        changeWidth()
    }

    @objc func changeColumns() {
        var layout = preferences.layout; layout.toolColumns = columns.selectedSegment + 1; preferences.layout = layout
        layoutChanged?()
    }

    func refreshLayoutControls() {
        guard !(window?.isVisible == true && window?.isKeyWindow == true && window?.firstResponder is NSTextView) else { return }
        widthField.stringValue = formatter.string(from: NSNumber(value: preferences.layout.panelWidth)) ?? "300"
        widthStepper.doubleValue = preferences.layout.panelWidth
        columns.selectedSegment = preferences.layout.toolColumns - 1
    }
}

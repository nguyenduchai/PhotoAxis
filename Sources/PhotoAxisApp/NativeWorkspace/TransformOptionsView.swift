import AppKit

@MainActor
final class TransformOptionsView:NSStackView, NSTextFieldDelegate {
    weak var document:PhotoDocument?
    var focusCanvas:(()->Void)?
    private let localization:L10n
    private var fields:[TransformField:NSTextField]=[:]
    private let linked=NSButton(), flipH=NSButton(), flipV=NSButton()
    init(localization:L10n) {
        self.localization=localization
        super.init(frame:NSRect(x:0,y:0,width:650,height:26))
        orientation = .horizontal; alignment = .centerY; spacing=5
        for (index,key) in TransformField.allCases.enumerated() {
            let label=WorkspaceStyle.label(localization.text("transform."+key.rawValue),size:11)
            let field=NSTextField(string:""); field.font = .systemFont(ofSize:11); field.controlSize = .small
            field.widthAnchor.constraint(equalToConstant:54).isActive=true
            field.tag=index; field.delegate=self; field.target=self; field.action=#selector(finishField)
            field.identifier = .init("transform.input."+key.rawValue)
            field.setAccessibilityLabel(localization.text("transform."+key.rawValue)); fields[key]=field
            addArrangedSubview(label); addArrangedSubview(field)
        }
        for (button,key,symbol,selector) in [(linked,"transform.link","link",#selector(toggleLink)),(flipH,"transform.flipH","arrow.left.and.right.righttriangle.left.righttriangle.right",#selector(horizontal)),(flipV,"transform.flipV","arrow.up.and.down.righttriangle.up.righttriangle.down",#selector(vertical))] {
            button.image=NSImage(systemSymbolName:symbol,accessibilityDescription:localization.text(key))
            button.title=""; button.imagePosition = .imageOnly; button.bezelStyle = .regularSquare; button.isBordered=false
            button.widthAnchor.constraint(equalToConstant:25).isActive=true
            button.setAccessibilityLabel(localization.text(key)); button.toolTip=localization.text(key)
            button.target=self; button.action=selector; addArrangedSubview(button)
        }
        linked.setButtonType(.toggle)
    }
    required init?(coder:NSCoder){fatalError("Use init(localization:)")}
    func refresh(_ document:PhotoDocument?) {
        self.document=document
        for (key,field) in fields {
            field.isEnabled=document?.canEditSelection == true
            if field.currentEditor() == nil {
                field.stringValue=(try? document?.transformValue(key)).map{DocumentNumber.format($0,language:Locale.current.identifier)} ?? ""
            }
            field.toolTip=document?.toolSession?.isValid == false ? localization.text("transform.invalid") : localization.text("transform."+key.rawValue)
        }
        linked.state=document?.linkedProportions == true ? .on : .off
        for button in [linked,flipH,flipV]{button.isEnabled=document?.canEditSelection == true}
    }
    func controlTextDidChange(_ notification:Notification) {
        guard let field=notification.object as? NSTextField, let document else{return}
        guard let value=DocumentNumber.parse(field.stringValue,language:Locale.current.identifier,signed:true) else {document.invalidateSession();return}
        let key=TransformField.allCases[field.tag]
        do {try document.setTransformValue(key,value)} catch {document.invalidateSession()}
    }
    @objc private func finishField(){focusCanvas?()}
    @objc private func toggleLink(){document?.linkedProportions=linked.state == .on}
    @objc private func horizontal(){do {try document?.flip(horizontal:true)} catch {NSSound.beep()}}
    @objc private func vertical(){do {try document?.flip(horizontal:false)} catch {NSSound.beep()}}
}

import AppKit
import PhotoAxisCore

@MainActor final class AdjustmentControlsView: NSScrollView, NSTextFieldDelegate {
    let enable=NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let reset=NSButton(title:"",target:nil,action:nil)
    let message=NSTextField(wrappingLabelWithString:"")
    let sliders=ImageAdjustmentField.allCases.map { _ in TransactionSlider() }
    let fields=ImageAdjustmentField.allCases.map { _ in NSTextField(string:"0") }
    private let body=SurfaceView()
    private var rows:[AdjustmentRow]=[]
    private weak var document:PhotoDocument?
    private weak var gestureOwner:PhotoDocument?
    private let localization:L10n
    private var finishing=false
    init(localization:L10n) {
        self.localization=localization
        super.init(frame:.zero);documentView=body;hasVerticalScroller=true;autohidesScrollers=true;drawsBackground=false
        enable.title=localization.text("adjustment.enabled");enable.target=self;enable.action=#selector(toggleEnabled)
        enable.identifier = .init("adjustment.enabled");enable.setAccessibilityLabel(enable.title)
        reset.title=localization.text("action.reset");reset.target=self;reset.action=#selector(resetValues);reset.bezelStyle = .rounded
        reset.identifier = .init("adjustment.reset");reset.setAccessibilityLabel(localization.text("adjustment.reset"))
        body.addSubview(enable);body.addSubview(reset);body.addSubview(message)
        message.font = .systemFont(ofSize:11);message.textColor = .secondaryLabelColor
        for (index,parameter) in ImageAdjustmentField.allCases.enumerated() {
            let label=localization.text(parameter.localizationKey),slider=sliders[index],field=fields[index]
            slider.minValue=parameter.range.lowerBound;slider.maxValue=parameter.range.upperBound;slider.isContinuous=true
            slider.tag=index;slider.target=self;slider.action=#selector(slide(_:));slider.identifier = .init(parameter.localizationKey+".slider")
            slider.setAccessibilityLabel(label);slider.toolTip=localization.text("adjustment.help")
            slider.begin={ [weak self] in self?.beginGesture() };slider.end={ [weak self] in self?.endGesture() }
            field.tag=index;field.target=self;field.action=#selector(commitNumber(_:));field.delegate=self;field.cell?.sendsActionOnEndEditing=false
            field.font = .systemFont(ofSize:11);field.identifier = .init(parameter.localizationKey);field.setAccessibilityLabel(label)
            let row=AdjustmentRow(label:WorkspaceStyle.label(label,size:11),field:field,slider:slider,unit:WorkspaceStyle.label(parameter == .exposure ? "EV":"%",size:11,secondary:true))
            rows.append(row);body.addSubview(row)
        }
    }
    required init?(coder:NSCoder){fatalError("Use init(localization:)")}
    func refresh(_ document:PhotoDocument?) {
        let switched=self.document !== document
        self.document=document
        guard let d=document,let layer=d.selectedLayer,case .image=layer.content,d.contentSession==nil else {isHidden=true;return}
        isHidden=false
        let editable=d.canEditSelection && (!d.hasSession || d.hasAdjustmentSession)
        enable.isEnabled=editable;reset.isEnabled=editable
        enable.state=layer.adjustments.enabled ? .on:.off
        for (index,parameter) in ImageAdjustmentField.allCases.enumerated() {
            let value=layer.adjustments[parameter]
            fields[index].isEnabled=editable
            // The active pointer gesture owns this cell until mouseUp.
            if !sliders[index].trackingGesture {sliders[index].isEnabled=editable;sliders[index].doubleValue=value}
            if switched || fields[index].currentEditor()==nil {fields[index].stringValue=DocumentNumber.format(value,language:Locale.current.identifier)}
        }
        let invalid=d.hasAdjustmentSession && !d.sessionIsValid
        message.stringValue=localization.text(!editable ? "adjustment.unavailable":invalid ? "adjustment.invalid":"adjustment.help")
        message.textColor=invalid ? .systemRed:.secondaryLabelColor
        for control in [enable,reset] as [NSControl] {control.toolTip=message.stringValue}
        if !sliders.contains(where: { $0.trackingGesture }) {needsLayout=true}
    }
    private func beginGesture() {
        gestureOwner=nil
        guard let d=document else {return}
        do {try d.startAdjustments();gestureOwner=d} catch {NSSound.beep()}
    }
    private func endGesture() {
        let owner=gestureOwner;gestureOwner=nil
        if owner?.hasAdjustmentSession==true {owner?.applySession()}
    }
    @objc private func slide(_ sender:TransactionSlider) {
        let value=(sender.doubleValue*100).rounded()/100
        if !sender.trackingGesture {beginGesture()}
        guard let owner=gestureOwner,owner === document,owner.hasAdjustmentSession else {return}
        let parameter=ImageAdjustmentField.allCases[sender.tag]
        do {try owner.previewAdjustment(parameter,value:value)} catch {NSSound.beep()}
        if !sender.trackingGesture {endGesture()}
    }
    private func previewNumber(_ sender:NSTextField) {
        guard !finishing,let d=document else {return}
        let input=sender.stringValue
        do {
            try d.startAdjustments()
            guard let value=DocumentNumber.parse(input,language:Locale.current.identifier,signed:true) else {throw DocumentError.invalidValue}
            try d.previewAdjustment(ImageAdjustmentField.allCases[sender.tag],value:value)
        } catch {
            if d.hasAdjustmentSession {d.invalidateSession()}
            message.stringValue=localization.text("adjustment.invalid");message.textColor = .systemRed
        }
    }
    func controlTextDidChange(_ notification:Notification) {if let field=notification.object as? NSTextField {previewNumber(field)}}
    @objc private func commitNumber(_ sender:NSTextField) {
        guard !finishing,let d=document else {return}
        previewNumber(sender)
        guard d.hasAdjustmentSession,d.sessionIsValid else {return}
        finishing=true;window?.makeFirstResponder(nil);d.applySession();finishing=false;refresh(d)
    }
    func control(_ control:NSControl,textView:NSTextView,doCommandBy commandSelector:Selector)->Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            finishing=true;document?.cancelSession();window?.makeFirstResponder(nil);finishing=false;refresh(document);return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)),let field=control as? NSTextField {commitNumber(field);return true}
        return false
    }
    @objc private func toggleEnabled() {
        guard let d=document else {return}
        do {try d.setAdjustmentsEnabled(enable.state == .on)} catch {NSSound.beep()}
    }
    @objc private func resetValues() {do {try document?.resetAdjustments()} catch {NSSound.beep()}}
    override func layout() {
        super.layout();guard contentSize.width>=100 else {return}
        let width=contentSize.width-8
        enable.frame=NSRect(x:4,y:2,width:width-72,height:24);reset.frame=NSRect(x:width-64,y:0,width:68,height:26)
        for (index,row) in rows.enumerated() {row.frame=NSRect(x:4,y:CGFloat(32+index*54),width:width,height:50)}
        message.frame=NSRect(x:4,y:254,width:width,height:64)
        body.frame=NSRect(x:0,y:0,width:contentSize.width,height:max(contentSize.height,322))
    }
}

@MainActor private final class AdjustmentRow:SurfaceView {
    let label:NSTextField,field:NSTextField,slider:NSSlider,unit:NSTextField
    init(label:NSTextField,field:NSTextField,slider:NSSlider,unit:NSTextField) {
        self.label=label;self.field=field;self.slider=slider;self.unit=unit;super.init()
        [label,field,slider,unit].forEach{addSubview($0)}
    }
    required init?(coder:NSCoder){fatalError("Use init(label:field:slider:unit:)")}
    override func layout() {
        super.layout();let width=bounds.width
        label.frame=NSRect(x:0,y:4,width:max(0,width-84),height:18)
        field.frame=NSRect(x:width-80,y:0,width:58,height:24);unit.frame=NSRect(x:width-19,y:4,width:19,height:18)
        slider.frame=NSRect(x:0,y:28,width:width,height:18)
    }
}

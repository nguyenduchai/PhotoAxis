import AppKit
import PhotoAxisCore

@MainActor
final class PerspectiveOptionsView:NSStackView,NSTextFieldDelegate {
    weak var document:PhotoDocument?
    var focusCanvas:(()->Void)?
    let mode=NSPopUpButton(),ratio=NSPopUpButton()
    let widthField=NSTextField(string:""),heightField=NSTextField(string:"")
    let preview=NSButton(checkboxWithTitle:"",target:nil,action:nil)
    private let grid=NSButton(checkboxWithTitle:"",target:nil,action:nil)
    private let output=WorkspaceStyle.label("",size:11)
    private let localization:L10n
    init(localization:L10n) {
        self.localization=localization
        super.init(frame:NSRect(x:0,y:0,width:940,height:26));orientation = .horizontal;spacing=6;alignment = .centerY
        mode.addItems(withTitles:[localization.text("perspective.auto"),localization.text("perspective.ratio"),"W × H"])
        ratio.addItems(withTitles:[localization.text("crop.custom"),localization.text("crop.original"),"1:1","4:3","3:2","16:9","A4"])
        for (control,selector,key) in [(mode,#selector(changeOutputMode),"options.mode"),(ratio,#selector(changeRatio),"perspective.ratio")] {
            control.target=self;control.action=selector;control.setAccessibilityLabel(localization.text(key));addArrangedSubview(control)
        }
        for (field,key) in [(widthField,"document.width"),(heightField,"document.height")] {
            field.widthAnchor.constraint(equalToConstant:54).isActive=true;field.font = .systemFont(ofSize:11);field.delegate=self
            field.target=self;field.action=#selector(finishField);field.setAccessibilityLabel(localization.text(key));addArrangedSubview(field)
        }
        for (key,selector) in [("document.swap",#selector(swapOutput)),("perspective.clear",#selector(clear)),("action.reset",#selector(reset))] {
            let button=NSButton(title:localization.text(key),target:self,action:selector);button.controlSize = .small;button.bezelStyle = .rounded;addArrangedSubview(button)
        }
        for (button,key,selector) in [(grid,"options.grid",#selector(toggleGrid)),(preview,"options.preview",#selector(togglePreview))] {
            button.title=localization.text(key);button.target=self;button.action=selector;button.font = .systemFont(ofSize:11);addArrangedSubview(button)
        }
        output.maximumNumberOfLines=1;output.lineBreakMode = .byTruncatingTail
        output.widthAnchor.constraint(lessThanOrEqualToConstant:245).isActive=true;addArrangedSubview(output)
    }
    required init?(coder:NSCoder){fatalError("Use init(localization:)")}
    func refresh(_ document:PhotoDocument?) {
        self.document=document;guard let state=document?.perspectiveSession else{return}
        mode.selectItem(at:state.mode);ratio.selectItem(at:state.ratioPreset);ratio.isHidden=state.mode != 1
        let width=state.mode==0 ? state.output.map{String($0.width)} ?? "" : state.widthText
        let height=state.mode==0 ? state.output.map{String($0.height)} ?? "" : state.heightText
        for (field,value) in [(widthField,width),(heightField,height)] {
            field.isEnabled=state.mode != 0
            if field.currentEditor()==nil {field.stringValue=value}
            field.toolTip=localization.text(state.mode==0 ? "perspective.auto":state.mode==2 ? "crop.pixelsHelp":"crop.ratioHelp")
        }
        grid.state=state.grid ? .on:.off;grid.isEnabled = !state.showsPreview
        preview.state=state.showsPreview ? .on:.off;preview.isEnabled=state.isValid
        if let error=state.error {output.stringValue=localization.text(error.localizationKey);output.textColor = .systemRed}
        else if let size=state.output {output.stringValue="\(size.width) × \(size.height) px";output.textColor = .secondaryLabelColor}
        output.toolTip=output.stringValue
    }
    private func updateFields() {
        document?.updatePerspective {state in state.widthText=widthField.stringValue;state.heightText=heightField.stringValue;state.ratioPreset=0}
    }
    func controlTextDidChange(_ notification:Notification){updateFields()}
    @objc private func finishField(){focusCanvas?()}
    @objc private func changeOutputMode(){let value=mode.indexOfSelectedItem;document?.updatePerspective{$0.mode=value;$0.autoSwapped=false};focusCanvas?()}
    @objc private func changeRatio() {
        guard let d=document else{return}
        let index=ratio.indexOfSelectedItem
        let values=[1:(d.model.canvas.width,d.model.canvas.height),2:(1,1),3:(4,3),4:(3,2),5:(16,9),6:(210,297)]
        d.updatePerspective {state in state.ratioPreset=index;if let (w,h)=values[index]{state.widthText=String(w);state.heightText=String(h)}}
        focusCanvas?()
    }
    @objc private func swapOutput(){document?.swapPerspective();focusCanvas?()}
    @objc private func clear(){document?.clearPerspective();focusCanvas?()}
    @objc private func reset(){document?.resetPerspective();focusCanvas?()}
    @objc private func toggleGrid(){let value=grid.state == .on;document?.updatePerspective{$0.grid=value};focusCanvas?()}
    @objc private func togglePreview(){document?.previewPerspective(preview.state == .on);focusCanvas?()}
}

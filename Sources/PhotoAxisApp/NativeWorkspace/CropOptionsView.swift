import AppKit
import PhotoAxisCore

@MainActor
final class CropOptionsView:NSStackView,NSTextFieldDelegate {
    weak var document:PhotoDocument?
    var focusCanvas:(()->Void)?
    let preset=NSPopUpButton(),widthField=NSTextField(string:""),heightField=NSTextField(string:"")
    private let output=WorkspaceStyle.label("",size:11),grid=NSButton(checkboxWithTitle:"",target:nil,action:nil)
    private let localization:L10n
    init(localization:L10n) {
        self.localization=localization
        super.init(frame:NSRect(x:0,y:0,width:650,height:26));orientation = .horizontal;spacing=6;alignment = .centerY
        preset.addItems(withTitles:[localization.text("crop.free"),localization.text("crop.original"),"1:1","4:3","3:2","16:9","A4",localization.text("crop.custom"),"W × H"])
        preset.target=self;preset.action=#selector(changeCropMode);preset.setAccessibilityLabel(localization.text("crop.mode"));addArrangedSubview(preset)
        for (field,key) in [(widthField,"document.width"),(heightField,"document.height")] {
            field.widthAnchor.constraint(equalToConstant:52).isActive=true;field.font = .systemFont(ofSize:11);field.delegate=self
            field.target=self;field.action=#selector(finishField);field.setAccessibilityLabel(localization.text(key));addArrangedSubview(field)
        }
        for (key,selector) in [("document.swap",#selector(swap)),("action.reset",#selector(reset))] {
            let button=NSButton(title:localization.text(key),target:self,action:selector);button.controlSize = .small;button.bezelStyle = .rounded;addArrangedSubview(button)
        }
        grid.title=localization.text("crop.grid");grid.target=self;grid.action=#selector(toggleGrid);grid.font = .systemFont(ofSize:11);addArrangedSubview(grid);addArrangedSubview(output)
    }
    required init?(coder:NSCoder){fatalError("Use init(localization:)")}
    func refresh(_ document:PhotoDocument?) {
        self.document=document;guard let crop=document?.cropSession else{return}
        preset.selectItem(at:crop.preset);grid.state=crop.grid ? .on:.off
        for (field,value) in [(widthField,crop.widthText),(heightField,crop.heightText)] {
            field.isEnabled=crop.preset>=7;if field.currentEditor()==nil {field.stringValue=value}
            field.toolTip=localization.text(crop.preset==8 ? "crop.pixelsHelp":"crop.ratioHelp")
        }
        if crop.isValid,let size=try? crop.output ?? crop.region.outputSize(){output.stringValue="\(size.width) × \(size.height) px";output.textColor = .secondaryLabelColor}
        else {output.stringValue=localization.text("crop.invalid");output.textColor = .systemRed}
    }
    @objc private func changeCropMode() {
        if preset.indexOfSelectedItem>=7,let d=document {widthField.stringValue=String(d.model.canvas.width);heightField.stringValue=String(d.model.canvas.height)}
        update();focusCanvas?()
    }
    private func update(){document?.configureCrop(preset:preset.indexOfSelectedItem,width:widthField.stringValue,height:heightField.stringValue)}
    func controlTextDidChange(_ notification:Notification){update()}
    @objc private func finishField(){focusCanvas?()}
    @objc private func swap(){document?.swapCrop();focusCanvas?()}
    @objc private func reset(){document?.resetCrop();focusCanvas?()}
    @objc private func toggleGrid(){document?.cropSession?.grid=grid.state == .on;document?.changed?()}
}

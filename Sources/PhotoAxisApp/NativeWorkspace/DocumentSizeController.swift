import AppKit
import PhotoAxisCore

@MainActor
final class DocumentSizeController:NSWindowController,NSTextFieldDelegate {
    let widthField=NSTextField(),heightField=NSTextField(),ppiField=NSTextField()
    let link=NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let notice=NSTextField(wrappingLabelWithString:"")
    let apply=NSButton()
    var anchor=4
    private var anchors:[NSButton]=[]
    private let photoDocument:PhotoDocument,localization:L10n,isCanvas:Bool
    private let ratio:Double
    init(document photoDocument:PhotoDocument,canvas:Bool,localization:L10n) {
        photoDocument.geometrySession = PhotoDocument.GeometrySession(original:photoDocument.model,viewport:photoDocument.viewport,command:canvas ? .canvasSize:.imageSize,candidate:photoDocument.model)
        self.photoDocument=photoDocument;self.localization=localization;isCanvas=canvas;ratio=Double(photoDocument.model.canvas.width)/Double(photoDocument.model.canvas.height)
        let panel=NSPanel(contentRect:NSRect(x:0,y:0,width:460,height:365),styleMask:[.titled],backing:.buffered,defer:false)
        panel.title=localization.text(canvas ? "image.canvasSize":"image.size");panel.isReleasedWhenClosed=false
        let root=SurfaceView();panel.contentView=root;super.init(window:panel)
        widthField.stringValue=String(photoDocument.model.canvas.width);heightField.stringValue=String(photoDocument.model.canvas.height);ppiField.stringValue=DocumentNumber.format(photoDocument.model.ppi,language:Locale.current.identifier)
        for (i,pair) in [("document.width",widthField),("document.height",heightField),("document.ppi",ppiField)].enumerated() {
            let label=WorkspaceStyle.label(localization.text(pair.0));label.frame=NSRect(x:20,y:25+i*40,width:155,height:24)
            let field=pair.1;field.frame=NSRect(x:180,y:21+i*40,width:240,height:26);field.setAccessibilityLabel(localization.text(pair.0));field.delegate=self
            if canvas && i==2{label.isHidden=true;field.isHidden=true};root.addSubview(label);root.addSubview(field)
        }
        link.title=localization.text("transform.link");link.state = .on;link.frame=NSRect(x:180,y:145,width:240,height:24);link.isHidden=canvas;root.addSubview(link)
        if canvas {
            let label=WorkspaceStyle.label(localization.text("image.anchor"));label.frame=NSRect(x:20,y:146,width:150,height:24);root.addSubview(label)
            for index in 0..<9 {
                let button=NSButton(title:["↖","↑","↗","←","•","→","↙","↓","↘"][index],target:self,action:#selector(selectAnchor(_:)))
                button.tag=index;button.setButtonType(.toggle);button.bezelStyle = .rounded;button.state=index==4 ? .on:.off
                button.setAccessibilityLabel(localization.text("image.anchor")+" \(index/3+1), \(index%3+1)")
                button.frame=NSRect(x:190+(index%3)*37,y:135+(index/3)*30,width:35,height:28);anchors.append(button);root.addSubview(button)
            }
        }
        notice.font = .systemFont(ofSize:11);notice.frame=NSRect(x:20,y:239,width:420,height:65);notice.stringValue=localization.text(canvas ? "image.canvasHelp":"image.sizeHelp");root.addSubview(notice)
        let cancel=NSButton(title:localization.text("action.cancel"),target:self,action:#selector(cancel));cancel.keyEquivalent="\u{1b}";cancel.bezelStyle = .rounded;cancel.frame=NSRect(x:216,y:320,width:105,height:30);root.addSubview(cancel)
        apply.title=localization.text("action.apply");apply.target=self;apply.action=#selector(confirm);apply.keyEquivalent="\r";apply.bezelStyle = .rounded;apply.frame=NSRect(x:325,y:320,width:115,height:30);root.addSubview(apply)
        validate()
    }
    required init?(coder:NSCoder){fatalError("Use init(photoDocument:canvas:localization:)")}
    @objc private func selectAnchor(_ sender:NSButton){anchor=sender.tag;for button in anchors{button.state=button.tag==anchor ? .on:.off};validate()}
    func validated() throws -> (CanvasSize,Double) {
        guard let w=Int(widthField.stringValue),let h=Int(heightField.stringValue) else{throw DocumentError.invalidValue}
        let size=try CanvasSize(width:w,height:h)
        guard let ppi=DocumentNumber.parse(ppiField.stringValue,language:Locale.current.identifier),ppi>0 else{throw DocumentError.invalidPPI}
        return (size,ppi)
    }
    func controlTextDidChange(_ notification:Notification) {
        if !isCanvas,link.state == .on,let field=notification.object as? NSTextField,let value=Int(field.stringValue),(1...8000).contains(value) {
            if field === widthField {heightField.stringValue=String(Int((Double(value)/ratio).rounded()))}
            else if field === heightField {widthField.stringValue=String(Int((Double(value)*ratio).rounded()))}
        }
        validate()
    }
    func validate() {
        guard var state = photoDocument.geometrySession else { apply.isEnabled = false; return }
        do {
            let (size,ppi) = try validated(); var candidate = state.original
            if isCanvas { try candidate.canvasSize(size,anchorX:anchor%3,anchorY:anchor/3) } else { try candidate.imageSize(size,ppi:ppi) }
            state.candidate = candidate; photoDocument.geometrySession = state; photoDocument.viewport.fit(candidate.canvas)
            apply.isEnabled = true; notice.textColor = .secondaryLabelColor; notice.stringValue = localization.text(isCanvas ? "image.canvasHelp":"image.sizeHelp")
        } catch {
            state.candidate = nil; photoDocument.geometrySession = state; photoDocument.viewport = state.viewport
            apply.isEnabled = false; notice.textColor = .systemRed; notice.stringValue = localization.text("document.invalidSize")
        }
        photoDocument.changed?()
    }
    @objc func confirm() {
        validate(); guard apply.isEnabled else { return }
        photoDocument.applySession()
        guard photoDocument.geometrySession == nil else { notice.textColor = .systemRed; notice.stringValue = localization.text("investigation.error.auditUnavailable"); return }
        end()
    }
    @objc func cancel() { photoDocument.cancelSession(); end() }
    private func end() { if let window,let parent=window.sheetParent { parent.endSheet(window) } }
}

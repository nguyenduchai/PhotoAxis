import AppKit
import PhotoAxisCore

extension RGBAColor {
    @MainActor var nsColor:NSColor {NSColor(srgbRed:red,green:green,blue:blue,alpha:alpha)}
    @MainActor init?(_ color:NSColor){guard let c=color.usingColorSpace(.sRGB) else{return nil};self.init(red:c.redComponent,green:c.greenComponent,blue:c.blueComponent,alpha:c.alphaComponent)}
}

@MainActor final class ContentControlsView:NSScrollView {
    private let body=SurfaceView()
    private var rows:[NSView]=[]
    let family=NSPopUpButton(),style=NSPopUpButton(),alignment=NSPopUpButton()
    let size=NSTextField(string:"48"),spacing=NSTextField(string:"0")
    let fill=NSColorWell(),stroke=NSColorWell(),textColor=NSColorWell()
    let strokeWidth=NSTextField(string:"0"),width=NSTextField(string:"1"),height=NSTextField(string:"1")
    let fillEnabled=NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let editButton=NSButton(title:"",target:nil,action:nil)
    let message=NSTextField(wrappingLabelWithString:"")
    let propertiesEditor:NativeTextEditor
    var editContent:((UUID)->Void)?
    private weak var document:PhotoDocument?
    private let localization:L10n
    private var textRows:[NSView]=[],shapeRows:[NSView]=[],fontMembers:[[Any]]=[]
    private var renderedFamily=""
    init(localization:L10n) {
        self.localization=localization;propertiesEditor=NativeTextEditor(localization:localization)
        super.init(frame:.zero);documentView=body;hasVerticalScroller=true;drawsBackground=false
        autohidesScrollers=true
        func row(_ key:String,_ control:NSControl)->NSView {
            let label=WorkspaceStyle.label(localization.text(key),size:11)
            let r=ContentControlRow(label:label,control:control)
            control.setAccessibilityLabel(localization.text(key));control.font = .systemFont(ofSize:11)
            control.target=self;control.action=#selector(change(_:));control.identifier = .init(key)
            rows.append(r);body.addSubview(r);return r
        }
        family.addItems(withTitles:NSFontManager.shared.availableFontFamilies.sorted())
        alignment.addItems(withTitles:[localization.text("type.left"),localization.text("type.center"),localization.text("type.right")])
        textRows=[row("type.family",family),row("type.style",style),row("type.size",size),row("type.color",textColor),row("type.alignment",alignment),row("type.spacing",spacing)]
        fillEnabled.title=localization.text("shape.fill");fillEnabled.target=self;fillEnabled.action=#selector(change(_:));fillEnabled.identifier = .init("shape.fill")
        rows.append(fillEnabled);body.addSubview(fillEnabled)
        shapeRows=[fillEnabled,row("shape.fillColor",fill),row("shape.stroke",stroke),row("shape.strokeWidth",strokeWidth),row("document.width",width),row("document.height",height)]
        editButton.title=localization.text("type.edit");editButton.target=self;editButton.action=#selector(beginEditing);editButton.bezelStyle = .rounded
        rows.append(editButton);body.addSubview(editButton)
        message.font = .systemFont(ofSize:11);message.textColor = .secondaryLabelColor
        rows += [message,propertiesEditor];body.addSubview(message);body.addSubview(propertiesEditor)
    }
    required init?(coder:NSCoder){fatalError("Use init(localization:)")}
    var content:LayerContent? {
        guard let d=document else{return nil}
        if let draft=d.contentSession?.draft{return draft}
        if let c=d.selectedLayer?.content {switch c {case .text,.shape:return c;case .image,.paint:break}}
        switch d.activeTool {case .type:return .text(d.textDefaults);case .rectangle,.ellipse,.line:return .shape(d.shapeDefaults);default:return nil}
    }
    func refresh(_ document:PhotoDocument?) {
        self.document=document;guard let d=document,let content else{isHidden=true;return};isHidden=false
        let isText:Bool;if case .text=content{isText=true}else{isText=false}
        textRows.forEach{$0.isHidden = !isText};shapeRows.forEach{$0.isHidden=isText}
        let editable = !d.isInteractionLocked && (d.selectedLayer?.isLocked != true || d.contentSession != nil)
        for c in [family,style,alignment,size,spacing,fill,stroke,textColor,strokeWidth,width,height,fillEnabled] as [NSControl]{c.isEnabled=editable}
        editButton.isHidden = !isText || d.contentSession != nil
        editButton.isEnabled=editable && d.selectedLayer.map{if case .text=$0.content{return true};return false} == true
        func field(_ f:NSTextField,_ v:Double){if f.currentEditor()==nil{f.stringValue=DocumentNumber.format(v,language:Locale.current.identifier)}}
        switch content {
        case .text(let text):
            let f=NSFont(name:text.fontName,size:12),familyName=f?.familyName ?? text.fontFamily
            if let item = family.itemArray.first(where:{$0.tag == 777}) { family.menu?.removeItem(item) }
            if f == nil {
                family.insertItem(withTitle:String(format:localization.text("type.missingChoice"),text.fontName),at:0)
                family.item(at:0)?.tag = 777; family.item(at:0)?.isEnabled = false; family.selectItem(at:0)
                refreshStyles(""); style.addItem(withTitle:text.fontStyle.isEmpty ? text.fontName : text.fontStyle); style.isEnabled = false
            } else {
                family.selectItem(withTitle:familyName)
                if familyName != renderedFamily { refreshStyles(familyName) }
                if let i=fontMembers.firstIndex(where:{$0.first as? String == text.fontName}){style.selectItem(at:i)}
            }
            field(size,text.fontSize);field(spacing,text.lineSpacing);textColor.color=text.color.nsColor;alignment.selectItem(at:TextAlignment.allCases.firstIndex(of:text.alignment)!)
            message.stringValue=ContentRasterizer.missingFont(text) ? String(format:localization.text("type.missingFont"),text.fontName):localization.text("type.help")
        case .shape(let shape):
            fillEnabled.state=shape.fill.alpha>0 ? .on:.off;fill.color=shape.fill.nsColor;stroke.color=shape.stroke.nsColor
            field(strokeWidth,shape.strokeWidth);field(width,Double(shape.size.width));field(height,Double(shape.size.height));message.stringValue=localization.text("shape.help")
        case .image,.paint:break
        }
        if d.contentSession?.isValid==false{message.stringValue=localization.text("content.invalid")}
        message.textColor=(d.contentSession?.isValid==false) ? .systemRed:.secondaryLabelColor
        if d.contentSession?.usesProperties==true,isText{propertiesEditor.refresh(d)}else{propertiesEditor.refresh(nil)}
        needsLayout=true
    }
    private func refreshStyles(_ name:String) {
        renderedFamily=name;fontMembers=NSFontManager.shared.availableMembers(ofFontFamily:name) ?? []
        style.removeAllItems();style.addItems(withTitles:fontMembers.map{$0[1] as? String ?? ""})
    }
    func focusContentEditor() {
        layoutSubtreeIfNeeded()
        if content?.isText==true {
            propertiesEditor.scrollToVisible(propertiesEditor.bounds)
            propertiesEditor.focus()
        } else {
            width.scrollToVisible(width.bounds)
            window?.makeFirstResponder(width)
        }
    }
    @objc private func beginEditing(){if let id=document?.selectedLayerID{editContent?(id)}}
    @objc private func change(_ sender:NSControl) {
        guard let d=document,!d.isInteractionLocked,var c=content else{return}
        do {
            let numeric:(NSTextField)throws->Double={guard let n=DocumentNumber.parse($0.stringValue,language:Locale.current.identifier) else{throw DocumentError.invalidValue};return n}
            switch c {
            case .text(var t):
                if sender === family {refreshStyles(family.titleOfSelectedItem ?? "")}
                if sender === family || sender === style {
                    guard fontMembers.indices.contains(style.indexOfSelectedItem),let name=fontMembers[style.indexOfSelectedItem][0] as? String else{throw DocumentError.invalidValue}
                    t.fontName=name;t.fontFamily=family.titleOfSelectedItem ?? "";t.fontStyle=style.titleOfSelectedItem ?? ""
                }
                t.fontSize=try numeric(size);t.lineSpacing=try numeric(spacing);t.alignment=TextAlignment.allCases[alignment.indexOfSelectedItem];t.color=RGBAColor(textColor.color) ?? t.color;c = .text(t)
            case .shape(var s):
                let w=try numeric(width),h=try numeric(height)
                guard w.rounded()==w,h.rounded()==h,w>=1,h>=1,w<=8000,h<=8000 else{throw DocumentError.invalidValue}
                s.size=try CanvasSize(width:Int(w),height:Int(h));s.fill=fillEnabled.state == .on ? RGBAColor(fill.color) ?? .black:.clear
                if sender === fillEnabled,s.fill.alpha==0,fillEnabled.state == .on{s.fill=d.foreground}
                s.stroke=RGBAColor(stroke.color) ?? .black;s.strokeWidth=try numeric(strokeWidth);c = .shape(s)
            case .image,.paint:return
            }
            if d.contentSession==nil,let layer=d.selectedLayer {
                switch layer.content{case .text,.shape:try d.startContentEdit(layer.id);case .image,.paint:break}
            }
            if d.contentSession != nil{d.updateContent(c)}
            else if case .text(let t)=c{d.textDefaults=try ContentRasterizer.measured(t);d.changed?()}
            else if case .shape(let s)=c{try s.validate();d.shapeDefaults=s;d.changed?()}
        }catch{message.stringValue=localization.text("content.invalid");message.textColor = .systemRed;if d.contentSession != nil{d.contentSession?.isValid=false;d.changed?()}}
    }
    override func layout() {
        super.layout()
        guard contentSize.width>=100 else{return}
        // Manual rows match the rest of the native workspace and adapt to the
        // narrow inspector without constraining hidden controls to zero sizes.
        let rowWidth=contentSize.width-8
        var y:CGFloat=4
        for row in rows where !row.isHidden {
            let height:CGFloat
            if row === propertiesEditor{height=130}
            else if row === message {
                height=max(32,message.attributedStringValue.boundingRect(with:NSSize(width:rowWidth,height:1000),options:[.usesLineFragmentOrigin,.usesFontLeading]).height.rounded(.up)+4)
            }else{height=26}
            row.frame=NSRect(x:4,y:y,width:rowWidth,height:height);y+=height+6
        }
        body.frame=NSRect(x:0,y:0,width:contentSize.width,height:max(contentSize.height,y))
    }
}

@MainActor private final class ContentControlRow:SurfaceView {
    private let label:NSTextField,control:NSControl
    init(label:NSTextField,control:NSControl) {
        self.label=label;self.control=control;super.init();addSubview(label);addSubview(control)
    }
    required init?(coder:NSCoder){fatalError("Use init(label:control:)")}
    override func layout() {
        super.layout()
        let labelWidth=min(88,bounds.width*0.4)
        label.frame=NSRect(x:0,y:5,width:labelWidth,height:18)
        control.frame=NSRect(x:labelWidth+6,y:0,width:max(0,bounds.width-labelWidth-6),height:26)
    }
}

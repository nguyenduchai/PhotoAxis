import AppKit
import PhotoAxisCore

@MainActor final class ColorControlsView:SurfaceView {
    let hex=NSTextField(string:"#000000"),alpha=NSTextField(string:"100")
    let channels=(0..<3).map{_ in NSTextField(string:"0")}
    let foreground=NSColorWell(),background=NSColorWell()
    private var labels:[NSTextField]=[]
    private weak var document:PhotoDocument?
    private let localization:L10n
    init(localization:L10n) {
        self.localization=localization;super.init()
        for (control,key) in [(foreground,"color.foreground"),(background,"color.background"),(hex,"color.hex"),(alpha,"color.alpha")]+zip(channels,["color.R","color.G","color.B"]).map({($0.0 as NSControl,$0.1)}) {
            control.setAccessibilityLabel(localization.text(key));control.toolTip=localization.text(key);control.target=self;control.action=#selector(change(_:));control.font = .systemFont(ofSize:11);addSubview(control)
        }
        for key in ["color.foreground","color.background","color.hex","color.alpha","color.R","color.G","color.B"]{let label=WorkspaceStyle.label(key.hasPrefix("color.") && ["color.R","color.G","color.B"].contains(key) ? String(key.suffix(1)):localization.text(key),size:10,secondary:true);labels.append(label);addSubview(label)}
    }
    required init?(coder:NSCoder){fatalError("Use init(localization:)")}
    func refresh(_ d:PhotoDocument?) {
        document=d;let c=d?.foreground ?? .black
        foreground.color=c.nsColor;background.color=d?.background.nsColor ?? .white
        for field in [hex,alpha]+channels{field.isEnabled=d != nil}
        foreground.isEnabled=d != nil;background.isEnabled=d != nil
        if hex.currentEditor()==nil{hex.stringValue=c.hex}
        if alpha.currentEditor()==nil{alpha.stringValue=DocumentNumber.format(c.alpha*100,language:Locale.current.identifier)}
        for (field,value) in zip(channels,[c.red,c.green,c.blue]) where field.currentEditor()==nil{field.stringValue=String(Int((value*255).rounded()))}
    }
    @objc private func change(_ sender:NSControl) {
        guard let d=document else{return}
        let color:RGBAColor?
        if sender === foreground{color=RGBAColor(foreground.color)}
        else if sender === background{if let c=RGBAColor(background.color){d.background=c;d.changed?()};return}
        else {
            guard let a=DocumentNumber.parse(alpha.stringValue,language:Locale.current.identifier),(0...100).contains(a) else{reject(sender);return}
            if sender === hex{color=RGBAColor(hex:hex.stringValue,alpha:a/100)}
            else {
                let values=channels.compactMap{Double($0.stringValue)}
                guard values.count==3,values.allSatisfy({$0.isFinite && (0...255).contains($0) && $0.rounded()==$0}) else{reject(sender);return}
                color=RGBAColor(red:values[0]/255,green:values[1]/255,blue:values[2]/255,alpha:a/100)
            }
        }
        guard let color else{reject(sender);return};d.setForeground(color)
    }
    private func reject(_ sender:NSControl){sender.toolTip=localization.text("color.invalid");NSSound.beep()}
    override func layout() {
        super.layout();let w=bounds.width
        labels[0].frame=NSRect(x:0,y:0,width:w/2-4,height:15);labels[1].frame=NSRect(x:w/2,y:0,width:w/2,height:15)
        foreground.frame=NSRect(x:0,y:19,width:w/2-8,height:28);background.frame=NSRect(x:w/2,y:19,width:w/2-2,height:28)
        labels[2].frame=NSRect(x:0,y:55,width:32,height:16);hex.frame=NSRect(x:35,y:52,width:93,height:24)
        labels[3].frame=NSRect(x:130,y:55,width:50,height:16);alpha.frame=NSRect(x:184,y:52,width:max(40,w-184),height:24)
        for i in 0..<3{let x=CGFloat(i)*w/3;labels[i+4].frame=NSRect(x:x,y:88,width:16,height:17);channels[i].frame=NSRect(x:x+18,y:84,width:w/3-24,height:24)}
    }
}

import AppKit
import PhotoAxisCore

@MainActor final class ExportController: NSWindowController, NSTextFieldDelegate {
    let format = NSPopUpButton(), widthField = NSTextField(), heightField = NSTextField(), ppiField = NSTextField(), qualityField = NSTextField()
    let link = NSButton(checkboxWithTitle:"",target:nil,action:nil), alpha = NSButton(checkboxWithTitle:"",target:nil,action:nil)
    let matte = NSColorWell(), preview = ExportPreviewView(), notice = NSTextField(wrappingLabelWithString:""), exportButton = NSButton()
    var confirmed: ((ProjectSnapshot,ExportOptions) -> Void)?
    let snapshot: ProjectSnapshot
    private let pipeline: ImagePipeline, localization: L10n, ratio: Double
    private var previewTask: Task<Void,Never>?, generation = 0
    init(snapshot: ProjectSnapshot, pipeline: ImagePipeline, localization: L10n, defaults: FilePreferences = FilePreferences()) {
        self.snapshot = snapshot; self.pipeline = pipeline; self.localization = localization
        ratio = Double(snapshot.model.canvas.width)/Double(snapshot.model.canvas.height)
        let panel = NSPanel(contentRect:NSRect(x:0,y:0,width:680,height:460),styleMask:[.titled],backing:.buffered,defer:false)
        panel.title = localization.text("action.export"); panel.isReleasedWhenClosed = false
        let root = SurfaceView(); panel.contentView = root; super.init(window:panel)
        preview.frame = NSRect(x:20,y:25,width:280,height:325); preview.imageScaling = .scaleProportionallyUpOrDown
        preview.setAccessibilityLabel(localization.text("export.preview")); root.addSubview(preview)
        format.addItems(withTitles:["PNG","JPEG"]); format.target = self; format.action = #selector(optionsChanged)
        widthField.stringValue = String(snapshot.model.canvas.width); heightField.stringValue = String(snapshot.model.canvas.height)
        ppiField.stringValue = DocumentNumber.format(snapshot.model.ppi,language:Locale.current.identifier); qualityField.stringValue = String(defaults.validated().jpegQuality)
        format.selectItem(at:defaults.exportJPEG ? 1:0)
        let fields: [(String,NSControl)] = [("export.format",format),("document.width",widthField),("document.height",heightField),("document.ppi",ppiField),("export.quality",qualityField),("export.matte",matte)]
        for (index,pair) in fields.enumerated() {
            let label = WorkspaceStyle.label(localization.text(pair.0)); label.frame = NSRect(x:315,y:25+index*43,width:170,height:28); root.addSubview(label)
            pair.1.frame = NSRect(x:490,y:23+index*43,width:170,height:28); pair.1.setAccessibilityLabel(localization.text(pair.0)); root.addSubview(pair.1)
            if let text = pair.1 as? NSTextField { text.delegate = self }
        }
        link.title = localization.text("transform.link"); link.state = defaults.linkExportDimensions ? .on:.off; link.frame = NSRect(x:315,y:290,width:345,height:24); root.addSubview(link)
        alpha.title = localization.text("export.alpha"); alpha.state = .on; alpha.target = self; alpha.action = #selector(optionsChanged)
        alpha.frame = NSRect(x:315,y:322,width:345,height:24); root.addSubview(alpha)
        matte.color = .white; matte.supportsAlpha = false; matte.target = self; matte.action = #selector(optionsChanged)
        notice.frame = NSRect(x:20,y:355,width:640,height:48); notice.font = .systemFont(ofSize:11); root.addSubview(notice)
        let cancel = NSButton(title:localization.text("action.cancel"),target:self,action:#selector(cancel)); cancel.keyEquivalent = "\u{1b}"; cancel.bezelStyle = .rounded
        cancel.frame = NSRect(x:405,y:415,width:115,height:30); root.addSubview(cancel)
        exportButton.title = localization.text("export.chooseLocation"); exportButton.target = self; exportButton.action = #selector(confirm)
        exportButton.bezelStyle = .rounded; exportButton.keyEquivalent = "\r"; exportButton.frame = NSRect(x:525,y:415,width:135,height:30); root.addSubview(exportButton)
        validateAndPreview()
    }
    required init?(coder:NSCoder) { fatalError("Use snapshot initializer") }
    func validated() throws -> ExportOptions {
        guard let width = Int(widthField.stringValue), let height = Int(heightField.stringValue),
              let ppi = DocumentNumber.parse(ppiField.stringValue,language:Locale.current.identifier),
              let quality = format.indexOfSelectedItem == 1 ? Int(qualityField.stringValue) : 90,
              let color = matte.color.usingColorSpace(.sRGB) else { throw DocumentError.invalidValue }
        var options = ExportOptions(size:try CanvasSize(width:width,height:height),ppi:ppi)
        options.format = format.indexOfSelectedItem == 0 ? .png : .jpeg; options.transparency = alpha.state == .on; options.quality = quality
        options.matte = RGBAColor(red:color.redComponent,green:color.greenComponent,blue:color.blueComponent)
        try options.validate(); return options
    }
    func controlTextDidChange(_ notification: Notification) {
        if link.state == .on, let field = notification.object as? NSTextField, let value = Int(field.stringValue), (1...8000).contains(value) {
            if field === widthField { heightField.stringValue = String(Int((Double(value)/ratio).rounded())) }
            else if field === heightField { widthField.stringValue = String(Int((Double(value)*ratio).rounded())) }
        }
        validateAndPreview()
    }
    @objc func optionsChanged() { validateAndPreview() }
    func validateAndPreview() {
        generation += 1; let requested = generation; previewTask?.cancel()
        qualityField.isEnabled = format.indexOfSelectedItem == 1; alpha.isEnabled = format.indexOfSelectedItem == 0
        matte.isEnabled = format.indexOfSelectedItem == 1 || alpha.state == .off
        do {
            let options = try validated(); exportButton.isEnabled = true; notice.textColor = .secondaryLabelColor
            notice.stringValue = localization.text("export.help")
            previewTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let image = try await pipeline.exportImage(snapshot:snapshot,options:options,previewEdge:512)
                    guard !Task.isCancelled, generation == requested else { return }
                    preview.image = NSImage(cgImage:image,size:NSSize(width:image.width,height:image.height))
                } catch is CancellationError {} catch {
                    guard generation == requested else { return }; exportButton.isEnabled = false
                    notice.stringValue = localization.text("export.previewError"); notice.textColor = .systemRed
                }
            }
        } catch { exportButton.isEnabled = false; preview.image = nil; notice.textColor = .systemRed; notice.stringValue = localization.text("export.invalid") }
    }
    @objc func confirm() {
        guard let options = try? validated(), exportButton.isEnabled else { return }
        confirmed?(snapshot,options); cancel()
    }
    @objc func cancel() { previewTask?.cancel(); if let window, let parent = window.sheetParent { parent.endSheet(window) } }
}

@MainActor final class ExportPreviewView: NSImageView {
    override func draw(_ dirtyRect: NSRect) {
        for y in stride(from:0,to:Int(bounds.height),by:12) { for x in stride(from:0,to:Int(bounds.width),by:12) {
            NSColor(white:(x/12+y/12)%2 == 0 ? 0.65 : 0.45,alpha:1).setFill()
            NSRect(x:x,y:y,width:12,height:12).fill()
        } }
        super.draw(dirtyRect)
    }
}

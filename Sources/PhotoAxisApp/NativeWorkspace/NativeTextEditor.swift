import AppKit
import PhotoAxisCore

/// NSTextView owns input context, marked text and local typing undo. Canvas tool
/// shortcuts never see key events while this editor is first responder.
@MainActor final class NativeTextView:NSTextView {
    var apply:(()->Void)?,cancel:(()->Void)?
    private let typingUndo=UndoManager()
    override var undoManager:UndoManager? {typingUndo}
    override func keyDown(with event:NSEvent) {
        if [36,76].contains(event.keyCode),event.modifierFlags.contains(.command) {
            if hasMarkedText(){unmarkText();didChangeText()};apply?();return
        }
        if event.keyCode==53,!hasMarkedText(){cancel?();return}
        super.keyDown(with:event)
    }
}

@MainActor final class NativeTextEditor:NSScrollView,NSTextViewDelegate {
    let editor=NativeTextView(frame:.zero)
    weak var document:PhotoDocument?
    var focusCanvas:(()->Void)?
    private var sessionID:UUID?,documentID:UUID?
    private var syncing=false
    init(localization:L10n) {
        super.init(frame:.zero)
        drawsBackground=true;backgroundColor=NSColor(white:0.94,alpha:1);borderType = .lineBorder
        hasVerticalScroller=true;hasHorizontalScroller=true
        editor.isRichText=false;editor.importsGraphics=false;editor.allowsUndo=true
        editor.isAutomaticQuoteSubstitutionEnabled=false;editor.isAutomaticDashSubstitutionEnabled=false;editor.isAutomaticTextReplacementEnabled=false
        editor.isAutomaticSpellingCorrectionEnabled=false;editor.isContinuousSpellCheckingEnabled=false
        editor.isHorizontallyResizable=true;editor.isVerticallyResizable=true
        editor.textContainer?.widthTracksTextView=false;editor.textContainer?.containerSize=NSSize(width:1_000_000,height:1_000_000)
        editor.textContainerInset=NSSize(width:4,height:4);editor.textContainer?.lineFragmentPadding=0
        editor.minSize=NSSize(width:20,height:20);editor.maxSize=NSSize(width:1_000_000,height:1_000_000)
        editor.backgroundColor=backgroundColor;editor.insertionPointColor = .black
        editor.setAccessibilityLabel(localization.text("type.content"));editor.delegate=self;documentView=editor
        editor.apply={ [weak self] in self?.document?.applySession();self?.focusCanvas?() }
        editor.cancel={ [weak self] in self?.document?.cancelSession();self?.focusCanvas?() }
    }
    required init?(coder:NSCoder){fatalError("Use init(localization:)")}
    func refresh(_ document:PhotoDocument?,scale:Double=1) {
        self.document=document
        guard let d=document,let session=d.contentSession,case .text(let draft)=session.draft else{isHidden=true;sessionID=nil;return}
        // Invalid controls keep the last validated formatting/extent. Never
        // hand an unbounded font size to AppKit while Apply is disabled.
        var text=draft
        if !session.isValid,case .text(let valid)=session.candidate.layer(session.layerID)?.content{text=valid}
        isHidden=false;syncing=true;defer{syncing=false}
        if sessionID != session.layerID || documentID != d.model.id {
            sessionID=session.layerID;documentID=d.model.id;editor.string=text.text;editor.undoManager?.removeAllActions();editor.setSelectedRange(NSRange(location:(text.text as NSString).length,length:0))
        }
        guard !editor.hasMarkedText() else{return}
        let font=NSFont(name:text.fontName,size:text.fontSize*scale) ?? NSFont.systemFont(ofSize:text.fontSize*scale)
        let paragraph=NSMutableParagraphStyle();paragraph.lineSpacing=text.lineSpacing*scale
        paragraph.alignment=text.alignment == .left ? .left:text.alignment == .center ? .center:.right
        // Editing uses a readable paper surface; canvas behind it previews the actual color/alpha.
        let attributes:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:NSColor.black,.paragraphStyle:paragraph]
        editor.textContainer?.containerSize=NSSize(width:max(20,Double(text.layoutSize.width)*scale),height:1_000_000)
        editor.typingAttributes=attributes
        editor.textStorage?.setAttributes(attributes,range:NSRange(location:0,length:editor.textStorage?.length ?? 0))
        editor.sizeToFit()
    }
    func focus(){window?.makeFirstResponder(editor)}
    func textDidChange(_ notification:Notification) {
        guard !syncing,let d=document,let session=d.contentSession,case .text(var text)=session.draft else{return}
        text.text=editor.string;d.contentSession?.isComposing=editor.hasMarkedText();d.updateContent(.text(text))
    }
}

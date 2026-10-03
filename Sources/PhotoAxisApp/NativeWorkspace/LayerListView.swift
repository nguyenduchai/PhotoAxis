import AppKit
import PhotoAxisCore

@MainActor
private final class LayerRowView: NSTableCellView {
    let eye = WorkspaceButton(symbol: "eye"), lock = WorkspaceButton(symbol: "lock.open")
    let thumbnail = NSImageView(), name = WorkspaceStyle.label("", size: 11), kind = WorkspaceStyle.label("", size: 9, secondary: true)
    var toggleVisibility: (() -> Void)?, toggleLock: (() -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        for view in [eye,thumbnail,name,kind,lock] { addSubview(view) }
        eye.target = self; eye.action = #selector(visibility)
        lock.target = self; lock.action = #selector(locking)
        thumbnail.imageScaling = .scaleProportionallyUpOrDown
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    @objc private func visibility() { toggleVisibility?() }
    @objc private func locking() { toggleLock?() }
    override func layout() {
        super.layout()
        eye.frame = NSRect(x: 0,y: 8,width: 22,height: 26)
        thumbnail.frame = NSRect(x: 25,y: 4,width: 36,height: 36)
        name.frame = NSRect(x: 67,y: 23,width: max(10,bounds.width-94),height: 18)
        kind.frame = NSRect(x: 67,y: 6,width: max(10,bounds.width-94),height: 14)
        lock.frame = NSRect(x: bounds.width-24,y: 8,width: 24,height: 26)
    }
}

@MainActor
final class LayerSelectionList: NSScrollView, NSTableViewDataSource, NSTableViewDelegate {
    let table = NSTableView()
    private weak var document: PhotoDocument?
    private var localization = L10n(choice: .system)
    private var displayed: [PhotoLayer] = []
    private var refreshing = false
    private var thumbnails: [UUID: (LayerContent, ImageAdjustments, NSImage)] = [:]
    private var thumbnailTask: Task<Void,Never>?
    private var generation = UUID()
    private static let dragType = NSPasteboard.PasteboardType("local.photoaxis.layer")
    var selected: ((UUID) -> Void)?
    var editContent:((UUID)->Void)?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let column = NSTableColumn(identifier: .init("layer")); table.addTableColumn(column)
        table.headerView = nil; table.rowHeight = 44; table.backgroundColor = WorkspaceStyle.panel
        table.dataSource = self; table.delegate = self; table.allowsEmptySelection = false
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.target = self; table.doubleAction = #selector(doubleClick)
        table.registerForDraggedTypes([Self.dragType]); table.setDraggingSourceOperationMask(.move, forLocal: true)
        documentView = table; hasVerticalScroller = true; drawsBackground = false
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    func update(_ document: PhotoDocument?, localization: L10n? = nil, pipeline: ImagePipeline? = nil) {
        if let localization { self.localization = localization }
        let switched = self.document !== document
        if switched { thumbnails = [:]; thumbnailTask?.cancel(); generation = UUID() }
        self.document = document; displayed = document.map { Array($0.presentedModel.layers.reversed()) } ?? []
        refreshing = true; table.reloadData()
        if let row = displayed.firstIndex(where: { $0.id == document?.selectedLayerID }) { table.selectRowIndexes(IndexSet(integer:row), byExtendingSelection:false) }
        else { table.deselectAll(nil) }
        refreshing = false
        guard let document, let pipeline else { return }
        let missing = displayed.filter { thumbnails[$0.id]?.0 != $0.content || thumbnails[$0.id]?.1 != $0.adjustments }
        thumbnailTask?.cancel(); generation = UUID()
        guard !missing.isEmpty else { return }
        let token = generation, assets = document.assets
        thumbnailTask = Task { [weak self] in
            for layer in missing {
                guard !Task.isCancelled else { return }
                let image = try? await pipeline.thumbnail(layer:layer,assets:assets)
                guard let self, !Task.isCancelled, generation == token else { return }
                if let image { thumbnails[layer.id] = (layer.content, layer.adjustments, NSImage(cgImage:image,size:NSSize(width:image.width,height:image.height))) }
                if let row = displayed.firstIndex(where: { $0.id == layer.id }) {
                    (table.view(atColumn:0,row:row,makeIfNecessary:false) as? LayerRowView)?.thumbnail.image = thumbnails[layer.id]?.2
                }
            }
        }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { displayed.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard displayed.indices.contains(row), let document else { return nil }
        let layer = displayed[row], cell = LayerRowView(frame:NSRect(x:0,y:0,width:table.bounds.width,height:44))
        cell.name.stringValue = layer.name; cell.name.toolTip = layer.name
        let typeKey: String
        switch layer.content { case .image: typeKey="layer.imageKind"; case .shape: typeKey="layer.shapeKind"; case .text: typeKey="layer.textKind" }
        cell.kind.stringValue = localization.text(typeKey)
        cell.thumbnail.image = thumbnails[layer.id]?.2
        cell.eye.image = NSImage(systemSymbolName:layer.isVisible ? "eye" : "eye.slash",accessibilityDescription:localization.text("layer.visible"))
        cell.lock.image = NSImage(systemSymbolName:layer.isLocked ? "lock.fill" : "lock.open",accessibilityDescription:localization.text("layer.locked"))
        cell.eye.setAccessibilityLabel(localization.text("layer.visible") + ": " + layer.name)
        cell.lock.setAccessibilityLabel(localization.text("layer.locked") + ": " + layer.name)
        cell.eye.toolTip = localization.text("layer.visible"); cell.lock.toolTip = localization.text("layer.locked")
        cell.eye.isEnabled = !document.isInteractionLocked; cell.lock.isEnabled = !document.isInteractionLocked
        cell.toggleVisibility = { [weak self] in self?.edit(.visibility) { try $0.setVisibility(layer.id,!layer.isVisible) } }
        cell.toggleLock = { [weak self] in self?.edit(.lock) { try $0.setLock(layer.id,!layer.isLocked) } }
        return cell
    }
    private func edit(_ command:DocumentCommand, _ operation:(inout PhotoDocumentModel)throws->Void) {
        guard let document, document.resolveSession() else { return }
        do { try document.perform(command,operation) } catch { NSSound.beep() }
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !refreshing, let document, displayed.indices.contains(table.selectedRow) else { return }
        let id = displayed[table.selectedRow].id
        if document.selectedLayerID != id {
            document.selectLayer(id)
            if document.selectedLayerID == id { selected?(id) }
            else if let row = displayed.firstIndex(where: { $0.id == document.selectedLayerID }) {
                refreshing = true; table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false); refreshing = false
            }
        }
    }
    @objc private func doubleClick() {
        guard let d=document,let layer=d.selectedLayer else{return}
        let point=table.convert(table.window?.mouseLocationOutsideOfEventStream ?? .zero,from:nil)
        // Double-click the name still renames; the thumbnail/body opens typed content.
        if point.x<65 {switch layer.content{case .text,.shape:editContent?(layer.id);return;case .image:break}}
        renameSelected()
    }
    @objc func renameSelected() {
        guard let document, let id = document.selectedLayerID, let layer = document.model.layer(id), !layer.isLocked, document.resolveSession() else { return }
        let alert=NSAlert(); alert.messageText=localization.text("layer.rename")
        let field=NSTextField(string:layer.name); field.frame=NSRect(x:0,y:0,width:280,height:24); alert.accessoryView=field
        alert.addButton(withTitle:localization.text("action.apply")); alert.addButton(withTitle:localization.text("action.cancel"))
        alert.window.initialFirstResponder=field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try document.perform(.rename) { try $0.rename(id,to:field.stringValue) } } catch { NSSound.beep() }
    }
    func tableView(_ tableView:NSTableView,pasteboardWriterForRow row:Int)->(any NSPasteboardWriting)? {
        guard displayed.indices.contains(row), !displayed[row].isLocked, document?.hasSession == false, document?.isInteractionLocked == false else { return nil }
        let item=NSPasteboardItem(); item.setString(displayed[row].id.uuidString,forType:Self.dragType); return item
    }
    func tableView(_ tableView:NSTableView,validateDrop info:any NSDraggingInfo,proposedRow row:Int,proposedDropOperation operation:NSTableView.DropOperation)->NSDragOperation {
        guard info.draggingSource as? NSTableView === table, operation == .above, document?.hasSession == false, document?.isInteractionLocked == false else { return [] }
        return .move
    }
    func tableView(_ tableView:NSTableView,acceptDrop info:any NSDraggingInfo,row:Int,dropOperation:NSTableView.DropOperation)->Bool {
        guard info.draggingSource as? NSTableView === table, let text=info.draggingPasteboard.string(forType:Self.dragType), let id=UUID(uuidString:text),
              let old=displayed.firstIndex(where:{$0.id==id}), let document, !document.hasSession else { return false }
        let targetTop=max(0,min(displayed.count-1,row > old ? row-1 : row))
        do { try document.perform(.reorder) { try $0.reorder(id,to:displayed.count-1-targetTop) }; return true } catch { return false }
    }
}

@MainActor
final class HistoryListView: NSScrollView, NSTableViewDataSource, NSTableViewDelegate {
    private let table=NSTableView()
    private weak var document:PhotoDocument?
    private var labels:[String]=[]
    private var stateIDs:[UUID]=[]
    private var refreshing=false
    override init(frame:NSRect) {
        super.init(frame:frame)
        table.addTableColumn(NSTableColumn(identifier:.init("history"))); table.headerView=nil; table.rowHeight=23
        table.backgroundColor=WorkspaceStyle.panel; table.dataSource=self; table.delegate=self
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle; documentView=table; hasVerticalScroller=true; drawsBackground=false
    }
    required init?(coder:NSCoder){fatalError("Use init(frame:)")}
    func update(_ document:PhotoDocument?, localization:L10n) {
        self.document=document; labels=document.map { [localization.text("history.initial")] + $0.history.entries.map { localization.text($0.command.localizationKey) } } ?? []
        stateIDs=document.map { [$0.history.baseID] + $0.history.entries.map(\.afterID) } ?? []
        refreshing=true; table.reloadData()
        if let document {table.selectRowIndexes(IndexSet(integer:document.history.cursor),byExtendingSelection:false)}
        refreshing=false; table.setAccessibilityLabel(localization.text("history.title"))
    }
    func numberOfRows(in tableView:NSTableView)->Int{labels.count}
    func tableView(_ tableView:NSTableView,viewFor tableColumn:NSTableColumn?,row:Int)->NSView? {
        let label=WorkspaceStyle.label(labels[row],size:11)
        if row > (document?.history.cursor ?? 0) {label.textColor = .tertiaryLabelColor}; return label
    }
    func tableViewSelectionDidChange(_ notification:Notification) {
        guard !refreshing, let document, labels.indices.contains(table.selectedRow) else{return}
        let stateID=stateIDs[table.selectedRow]
        if document.resolveSession(), let index=document.history.index(of:stateID) {document.jumpHistory(to:index)}
        refreshing=true; table.selectRowIndexes(IndexSet(integer:document.history.cursor),byExtendingSelection:false); refreshing=false
    }
}

@MainActor
final class TransactionSlider:NSSlider {
    var begin:(()->Void)?, end:(()->Void)?
    private(set) var trackingGesture=false
    private var dragOffset:CGFloat=0
    override func mouseDown(with event:NSEvent) {
        guard isEnabled,let cell=cell as? NSSliderCell else {return}
        let point=convert(event.locationInWindow,from:nil),knob=cell.knobRect(flipped:isFlipped)
        dragOffset=knob.contains(point) ? point.x-knob.midX:0
        trackingGesture=true;begin?();updatePointer(event)
    }
    override func mouseDragged(with event:NSEvent) {if trackingGesture {updatePointer(event)}}
    override func mouseUp(with event:NSEvent) {
        guard trackingGesture else {return}
        updatePointer(event);trackingGesture=false;end?()
    }
    private func updatePointer(_ event:NSEvent) {
        guard let cell=cell as? NSSliderCell else {return}
        let bar=cell.barRect(flipped:isFlipped),knob=cell.knobRect(flipped:isFlipped)
        let low=bar.minX+knob.width/2,span=max(1,bar.width-knob.width)
        let fraction=min(1,max(0,(convert(event.locationInWindow,from:nil).x-dragOffset-low)/span))
        doubleValue=minValue+Double(fraction)*(maxValue-minValue)
        needsDisplay=true;sendAction(action,to:target)
    }
}

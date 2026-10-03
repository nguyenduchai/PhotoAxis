import AppKit

@MainActor final class RecoveryController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let entries: [RecoveryEntry], localization: L10n
    let table = NSTableView(), openButton = NSButton(), discardButton = NSButton()
    var openRecovered: ((RecoveryEntry) -> Void)?
    var discard: ((RecoveryEntry) -> Void)?
    private var removed = Set<UUID>()
    var visibleEntries: [RecoveryEntry] { entries.filter { !removed.contains($0.id) } }
    init(entries: [RecoveryEntry], localization: L10n) {
        self.entries = entries; self.localization = localization
        let panel = NSPanel(contentRect:NSRect(x:0,y:0,width:640,height:360),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        panel.title = localization.text("recovery.title"); panel.isReleasedWhenClosed = false
        super.init(window:panel)
        let root = SurfaceView(); panel.contentView = root
        let help = NSTextField(wrappingLabelWithString:localization.text("recovery.help")); help.frame = NSRect(x:20,y:18,width:600,height:50); root.addSubview(help)
        let column = NSTableColumn(identifier:.init("recovery")); column.width = 598; column.resizingMask = .autoresizingMask
        table.addTableColumn(column); table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle; table.headerView = nil; table.rowHeight = 46
        table.dataSource = self; table.delegate = self; table.setAccessibilityLabel(localization.text("recovery.list"))
        let scroll = NSScrollView(frame:NSRect(x:20,y:80,width:600,height:210)); scroll.documentView = table; scroll.hasVerticalScroller = true; root.addSubview(scroll)
        let later = NSButton(title:localization.text("action.close"),target:self,action:#selector(closeList)); later.frame = NSRect(x:20,y:310,width:100,height:30); later.bezelStyle = .rounded; root.addSubview(later)
        discardButton.title = localization.text("recovery.discard"); discardButton.target = self; discardButton.action = #selector(discardSelected)
        openButton.title = localization.text("recovery.open"); openButton.target = self; openButton.action = #selector(openSelected); openButton.keyEquivalent = "\r"
        for (button,x) in [(discardButton,340),(openButton,480)] { button.frame = NSRect(x:x,y:310,width:140,height:30); button.bezelStyle = .rounded; root.addSubview(button) }
        if !entries.isEmpty { table.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false) }; updateButtons()
    }
    required init?(coder:NSCoder) { fatalError("Use entries initializer") }
    func numberOfRows(in tableView:NSTableView) -> Int { visibleEntries.count }
    func tableView(_ tableView:NSTableView,viewFor tableColumn:NSTableColumn?,row:Int) -> NSView? {
        let entry = visibleEntries[row], date = DateFormatter(); date.locale = .current; date.dateStyle = .medium; date.timeStyle = .short
        let suffix = entry.isCorrupt ? localization.text("recovery.corrupt") : date.string(from:entry.date)
        let label = NSTextField(wrappingLabelWithString:entry.name+"\n"+suffix); label.font = .systemFont(ofSize:12); label.maximumNumberOfLines = 2; label.lineBreakMode = .byTruncatingTail; return label
    }
    func tableViewSelectionDidChange(_ notification:Notification) { updateButtons() }
    private var selected: RecoveryEntry? { visibleEntries.indices.contains(table.selectedRow) ? visibleEntries[table.selectedRow] : nil }
    private func updateButtons() { openButton.isEnabled = selected?.isCorrupt == false; discardButton.isEnabled = selected != nil }
    func completed(_ entry:RecoveryEntry) { removed.insert(entry.id); table.reloadData(); if !visibleEntries.isEmpty {table.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false)}; updateButtons(); if visibleEntries.isEmpty { closeList() } }
    @objc private func openSelected() { if let selected { openRecovered?(selected) } }
    @objc private func discardSelected() { if let selected { discard?(selected) } }
    @objc private func closeList() { if let window, let parent = window.sheetParent { parent.endSheet(window) } else { close() } }
}

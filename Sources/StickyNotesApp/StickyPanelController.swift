import AppKit
import StickyNotesCore

final class DismissiblePanel: NSPanel {
    var handleOverlayMouseDown: ((NSPoint) -> Void)?
    var handleModifierChange: ((NSEvent.ModifierFlags) -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown || event.type == .otherMouseDown {
            handleOverlayMouseDown?(event.locationInWindow)
        }
        if event.type == .flagsChanged {
            handleModifierChange?(event.modifierFlags)
        }
        super.sendEvent(event)
    }
}

final class StickyPanelController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    private let repository: NoteRepository
    private let panel: DismissiblePanel
    private let editor = RichTextView()
    private let tableView = NSTableView()
    private let searchField = NSSearchField()
    private let scopeControl = NSSegmentedControl(labels: ["노트", "휴지통"], trackingMode: .selectOne, target: nil, action: nil)
    private let sidebar = NSVisualEffectView()
    private let formatOverlay = NSVisualEffectView()
    private let noteSwitchOverlay = NSVisualEffectView()
    private let noteSwitchList = NSStackView()
    private let headerTitleLabel = NSTextField(labelWithString: "")
    private let noteSwitchPositionLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(labelWithString: "")
    private let wordCountLabel = NSTextField(labelWithString: "0단어")
    private let restoreButton = NSButton(title: "복원", target: nil, action: nil)
    private let emptyTrashButton = NSButton(title: "휴지통 비우기", target: nil, action: nil)
    private let accentColor = NSColor(calibratedRed: 0.88, green: 0.27, blue: 0.23, alpha: 1)
    private var currentID = UUID()
    private let dailyEditor = RichTextView()
    private let dailyScroll = NSScrollView()
    private let todayPane = NSView()
    private let paneDivider = PaneDivider()
    private lazy var weekStrip = WeekStripView(accentColor: accentColor)
    private lazy var monthCalendar = MonthCalendarView(accentColor: accentColor)
    /// Height the month grid needs; while it is open the pane grows to at least this much
    /// and returns to the user's own height when it closes.
    private let monthCalendarHeight: CGFloat = 300
    private let zoomSteps: [CGFloat] = [0.8, 0.9, 1, 1.1, 1.25, 1.4, 1.6]
    private lazy var todayPaneHeight = todayPane.heightAnchor.constraint(equalToConstant: storedTodayPaneHeight)
    private lazy var dividerHeight = paneDivider.heightAnchor.constraint(equalToConstant: dividerThickness)
    private let dividerThickness: CGFloat = 11
    private let minimumTodayPaneHeight: CGFloat = 112
    private let minimumNoteHeight: CGFloat = 150
    private var dragStartTodayPaneHeight: CGFloat = 0
    /// The day shown in the top pane, and the today it was chosen against: when the date rolls
    /// over while "today" was showing, the next show moves on to the new day.
    private var selectedDay = Date()
    private var todayKeyAtLastRefresh = DailyNote.dayKey(for: Date())
    private var dailyID = UUID()
    /// True while the day's page is still the untouched empty checkbox: it is not saved until
    /// the first edit, so looking at a day leaves no empty page behind.
    private var dailyTemplateIsUntouched = false
    private var dailyAutosaveTimer: Timer?
    private weak var lastFocusedEditor: RichTextView?
    private weak var todayToggleButton: NSButton?
    private var rows: [NoteMetadata] = []
    private var autosaveTimer: Timer?
    private var errorTimer: Timer?
    private var noteSwitchTimer: Timer?
    /// True while the switcher was opened with Control held: it then lives exactly as long
    /// as the key, like the app switcher. Opened from the menu, it falls back to a timer.
    private var noteSwitchFollowsControlKey = false
    private var suppressChanges = false
    private var isRefreshingRows = false
    private var showingTrash = false
    private var noteCycle: [NoteMetadata] = []
    private let noteSwitchVisibleRows = 7
    private var escapeEventMonitor: Any?
    private weak var sidebarToggleButton: NSButton?
    private weak var formatToggleButton: NSButton?

    init(repository: NoteRepository) {
        self.repository = repository
        panel = DismissiblePanel(
            contentRect: CGRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)
        configurePanel()
        configureContents()
        configureOverlayDismissal()
        let firstNoteID = repository.list().first?.id
        reloadRows(selecting: firstNoteID)
        if let firstNoteID {
            loadNote(id: firstNoteID)
        }
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        if let escapeEventMonitor {
            NSEvent.removeMonitor(escapeEventMonitor)
        }
    }

    func showOnCurrentScreen() {
        guard let screen = screenUnderMouse() ?? NSScreen.main else { return }
        closeOverlays(focusEditor: false)
        followDayRollover(now: Date())
        let remembered = rememberedFrame(for: screen)
        panel.setFrame(WindowPlacement.frame(remembered: remembered, visibleFrame: screen.visibleFrame), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(activeEditor)
    }

    func toggleOnCurrentScreen() {
        if panel.isVisible && panel.isKeyWindow {
            hidePanel()
        } else {
            showOnCurrentScreen()
        }
    }

    /// The today shortcut mirrors Option+`: pressed while writing on today's page it hides the
    /// panel, anywhere else it brings the panel up with the cursor on today's page.
    func toggleTodayOnCurrentScreen(now: Date = Date()) {
        if panel.isVisible, panel.isKeyWindow, !todayPane.isHidden,
           lastFocusedEditor === dailyEditor,
           DailyNote.dayKey(for: selectedDay) == DailyNote.dayKey(for: now) {
            hidePanel()
            return
        }
        showOnCurrentScreen()
        openToday(now: now)
    }

    func openToday(now: Date = Date()) {
        setTodayPaneCollapsed(false)
        setMonthCalendarShown(false)
        if DailyNote.dayKey(for: selectedDay) != DailyNote.dayKey(for: now) {
            selectDay(now)
        }
        panel.makeFirstResponder(dailyEditor)
        dailyEditor.setSelectedRange(NSRange(location: dailyEditor.string.utf16.count, length: 0))
    }

    @objc func toggleTodayPane() {
        let collapsing = !todayPane.isHidden
        setTodayPaneCollapsed(collapsing)
        panel.makeFirstResponder(collapsing ? editor : dailyEditor)
    }

    func selectDay(_ date: Date) {
        saveDaily()
        selectedDay = date
        loadDaily()
    }

    @objc func hidePanel() {
        closeOverlays(focusEditor: false)
        saveNow()
        saveDaily()
        panel.orderOut(nil)
    }

    @objc func newNote() {
        saveNow()
        noteCycle.removeAll()
        showingTrash = false
        scopeControl.selectedSegment = 0
        currentID = UUID()
        replaceEditorContent(with: NSAttributedString())
        reloadRows(selecting: nil)
        editor.isEditable = true
        panel.makeFirstResponder(editor)
        closeOverlays()
    }

    @objc func toggleSidebar() {
        let opening = sidebar.isHidden
        formatOverlay.isHidden = true
        sidebar.isHidden = !opening
        if opening {
            sidebar.superview?.addSubview(sidebar, positioned: .above, relativeTo: nil)
            panel.makeFirstResponder(searchField)
        } else {
            panel.makeFirstResponder(editor)
        }
    }

    @objc func toggleFormatOverlay() {
        let opening = formatOverlay.isHidden
        sidebar.isHidden = true
        formatOverlay.isHidden = !opening
        if opening {
            formatOverlay.superview?.addSubview(formatOverlay, positioned: .above, relativeTo: nil)
        } else {
            panel.makeFirstResponder(editor)
        }
    }

    @objc func trashCurrent() {
        trash(id: currentID)
    }

    /// Moving to the trash is reversible from the trash scope, so it runs without a confirm.
    /// An unsaved empty draft has nothing to move and stays where it is.
    private func trash(id: UUID) {
        guard !showingTrash else { return }
        saveNow()
        guard repository.list().contains(where: { $0.id == id }) else { return }
        do {
            try repository.moveToTrash(id: id)
            guard id == currentID else {
                reloadRows(selecting: currentID)
                return
            }
            reloadRows(selecting: nil)
            if let next = rows.first {
                loadNote(id: next.id)
            } else {
                newNoteForCurrentScope()
            }
        } catch { showError(error.localizedDescription) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateRowMenu(menu, row: tableView.clickedRow)
    }

    /// Right-click on a list row acts on that row, not on the note open in the editor.
    func updateRowMenu(_ menu: NSMenu, row: Int) {
        menu.removeAllItems()
        guard row >= 0, row < rows.count else { return }
        let id = rows[row].id
        if showingTrash {
            let restore = NSMenuItem(title: "복원", action: #selector(restoreRow(_:)), keyEquivalent: "")
            restore.representedObject = id
            restore.target = self
            menu.addItem(restore)
        } else {
            let trash = NSMenuItem(title: "휴지통으로 이동", action: #selector(trashRow(_:)), keyEquivalent: "")
            trash.representedObject = id
            trash.target = self
            menu.addItem(trash)
        }
    }

    @objc private func trashRow(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        trash(id: id)
    }

    @objc private func restoreRow(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        restore(id: id)
    }

    @objc func toggleBold() {
        let target = activeEditor
        panel.makeFirstResponder(target)
        let selection = target.selectedRange()
        let baseFont = target.typingAttributes[.font] as? NSFont ?? .systemFont(ofSize: 16)
        let traits = NSFontManager.shared.traits(of: baseFont)
        let makeBold = !traits.contains(.boldFontMask)
        if selection.length == 0 {
            target.typingAttributes[.font] = makeBold
                ? NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(baseFont, toNotHaveTrait: .boldFontMask)
        } else {
            editAttributes(of: target, in: selection, actionName: "굵게") {
                target.requiredTextStorage.enumerateAttribute(.font, in: selection) { value, range, _ in
                    let font = value as? NSFont ?? baseFont
                    let converted = makeBold
                        ? NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                        : NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                    target.requiredTextStorage.addAttribute(.font, value: converted, range: range)
                }
            }
        }
    }

    @objc func toggleStrikethrough() {
        let target = activeEditor
        panel.makeFirstResponder(target)
        let selection = target.selectedRange()
        let turningOn = !strikethroughIsActive(in: selection, of: target)
        guard selection.length > 0 else {
            if turningOn {
                target.typingAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            } else {
                target.typingAttributes.removeValue(forKey: .strikethroughStyle)
            }
            return
        }
        editAttributes(of: target, in: selection, actionName: "취소선") {
            if turningOn {
                target.requiredTextStorage.addAttribute(
                    .strikethroughStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: selection
                )
            } else {
                target.requiredTextStorage.removeAttribute(.strikethroughStyle, range: selection)
            }
        }
    }

    private func strikethroughIsActive(in selection: NSRange, of target: RichTextView) -> Bool {
        let value: Any?
        if selection.length == 0 {
            value = target.typingAttributes[.strikethroughStyle]
        } else {
            value = target.requiredTextStorage.attribute(
                .strikethroughStyle,
                at: selection.location,
                effectiveRange: nil
            )
        }
        return (value as? Int ?? 0) != 0
    }

    /// An attribute-only edit still has to pass through the text view's change cycle, or the
    /// formatting command lands outside the undo stack and Cmd+Z skips over it.
    private func editAttributes(of target: RichTextView, in range: NSRange, actionName: String, mutation: () -> Void) {
        guard target.shouldChangeText(in: range, replacementString: nil) else { return }
        mutation()
        target.didChangeText()
        target.undoManager?.setActionName(actionName)
    }

    @objc func toggleChecklistLine() {
        let target = activeEditor
        panel.makeFirstResponder(target)
        target.toggleChecklistOnCurrentLine()
    }

    @objc func undoEditor() {
        let target = activeEditor
        panel.makeFirstResponder(target)
        target.undoManager?.undo()
    }

    @objc func redoEditor() {
        let target = activeEditor
        panel.makeFirstResponder(target)
        target.undoManager?.redo()
    }

    @objc func showPreviousNote() {
        cycleNote(step: 1, controlHeld: NSEvent.modifierFlags.contains(.control))
    }

    @objc func showNextNote() {
        cycleNote(step: -1, controlHeld: NSEvent.modifierFlags.contains(.control))
    }

    /// Only failures reach the footer: a save that did not land, or a command that needs a
    /// selection first. Routine progress ("saving", "saved") is nothing the writer acts on.
    func showError(_ message: String) {
        errorTimer?.invalidate()
        errorLabel.stringValue = "  \(message)  "
        errorLabel.toolTip = message
        errorLabel.isHidden = false
        errorTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            self?.errorLabel.isHidden = true
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hidePanel()
        return false
    }

    func windowDidMove(_ notification: Notification) { rememberCurrentFrame() }
    func windowDidResignKey(_ notification: Notification) {
        closeOverlays(focusEditor: false)
    }
    func windowDidResize(_ notification: Notification) {
        if !todayPane.isHidden {
            todayPaneHeight.constant = clampedTodayPaneHeight(
                monthCalendar.isHidden ? storedTodayPaneHeight : max(storedTodayPaneHeight, monthCalendarHeight)
            )
        }
        relayoutEditors()
        rememberCurrentFrame()
    }

    func textDidChange(_ notification: Notification) {
        guard !suppressChanges else { return }
        if (notification.object as? RichTextView) === dailyEditor {
            dailyTemplateIsUntouched = false
            dailyAutosaveTimer?.invalidate()
            dailyAutosaveTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                self?.saveDaily()
            }
            return
        }
        noteCycle.removeAll()
        autosaveTimer?.invalidate()
        updateTitle()
        updateWordCount()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.saveNow()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        reloadRows(selecting: currentID)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === searchField,
              commandSelector == #selector(NSResponder.cancelOperation(_:)) else {
            return false
        }
        closeOverlays()
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("NoteCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView) ?? {
            let view = NSTableCellView()
            view.identifier = identifier
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            view.textField = label
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
            return view
        }()
        cell.textField?.stringValue = rows[row].title
        cell.toolTip = rows[row].title
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isRefreshingRows else { return }
        let index = tableView.selectedRow
        guard index >= 0, index < rows.count, rows[index].id != currentID else { return }
        noteCycle.removeAll()
        saveNow()
        loadNote(id: rows[index].id)
        closeOverlays()
        panel.makeFirstResponder(editor)
    }

    private func configurePanel() {
        applyTitle("새 노트")
        // The system title is drawn inside the titlebar strip, which sits above the header row
        // of a full-size-content window; the header's own centred label carries the title instead.
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = CGSize(width: 340, height: 480)
        panel.maxSize = CGSize(width: 640, height: 900)
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = NSColor(calibratedRed: 0.052, green: 0.055, blue: 0.062, alpha: 1)
        panel.isOpaque = true
        panel.delegate = self
    }

    private func configureContents() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedRed: 0.052, green: 0.055, blue: 0.062, alpha: 1).cgColor
        panel.contentView = root

        configureHeaderTitleLabel()
        let header = makeHeader()
        let formatButton = makeFooterFormatButton()
        let editorScroll = NSScrollView()
        configureEditor(editor, in: editorScroll, label: "노트 편집기", inset: CGSize(width: 20, height: 18))
        configureEditor(dailyEditor, in: dailyScroll, label: "오늘 할 일 편집기", inset: CGSize(width: 20, height: 4))
        configureTodayPane()

        configureSidebar()
        configureFormatOverlay()
        configureNoteSwitchOverlay()
        configureErrorLabel()
        configureWordCountLabel()
        root.addSubview(editorScroll)
        root.addSubview(todayPane)
        root.addSubview(paneDivider)
        root.addSubview(header)
        root.addSubview(sidebar)
        root.addSubview(formatOverlay)
        root.addSubview(noteSwitchOverlay)
        root.addSubview(errorLabel)
        root.addSubview(wordCountLabel)
        root.addSubview(formatButton)

        sidebar.isHidden = true
        formatOverlay.isHidden = true
        noteSwitchOverlay.isHidden = true
        let preferredSwitchOverlayWidth = noteSwitchOverlay.widthAnchor.constraint(equalToConstant: 320)
        preferredSwitchOverlayWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            header.heightAnchor.constraint(equalToConstant: 34),
            todayPane.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 2),
            todayPane.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            todayPane.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            todayPaneHeight,
            paneDivider.topAnchor.constraint(equalTo: todayPane.bottomAnchor),
            paneDivider.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            paneDivider.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            dividerHeight,
            editorScroll.topAnchor.constraint(equalTo: paneDivider.bottomAnchor),
            editorScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            editorScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            editorScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -48),
            sidebar.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            sidebar.widthAnchor.constraint(equalToConstant: 306),
            sidebar.heightAnchor.constraint(equalToConstant: 360),
            sidebar.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),
            sidebar.bottomAnchor.constraint(lessThanOrEqualTo: editorScroll.bottomAnchor, constant: -8),
            formatOverlay.topAnchor.constraint(greaterThanOrEqualTo: header.bottomAnchor, constant: 8),
            formatOverlay.trailingAnchor.constraint(equalTo: formatButton.trailingAnchor),
            formatOverlay.widthAnchor.constraint(equalToConstant: 216),
            formatOverlay.bottomAnchor.constraint(equalTo: formatButton.topAnchor, constant: -8),
            noteSwitchOverlay.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            noteSwitchOverlay.centerYAnchor.constraint(equalTo: editorScroll.centerYAnchor),
            preferredSwitchOverlayWidth,
            noteSwitchOverlay.widthAnchor.constraint(lessThanOrEqualTo: root.widthAnchor, constant: -40),
            formatButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            formatButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10),
            wordCountLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            wordCountLabel.centerYAnchor.constraint(equalTo: formatButton.centerYAnchor),
            errorLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: formatButton.centerYAnchor),
            errorLabel.heightAnchor.constraint(equalToConstant: 26),
            errorLabel.widthAnchor.constraint(lessThanOrEqualTo: root.widthAnchor, constant: -180),
        ])
        setTodayPaneCollapsed(UserDefaults.standard.bool(forKey: "todayPane.collapsed"))
        for scroll in [editorScroll, dailyScroll] {
            scroll.allowsMagnification = false
            scroll.minMagnification = zoomSteps[0]
            scroll.maxMagnification = zoomSteps[zoomSteps.count - 1]
            scroll.magnification = zoom
        }
        root.layoutSubtreeIfNeeded()
        editor.layoutForScrollableViewport()
        dailyEditor.layoutForScrollableViewport()
        updateWordCount()
        loadDaily()
    }

    private func configureEditor(_ target: RichTextView, in scroll: NSScrollView, label: String, inset: CGSize) {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = target

        target.isRichText = true
        target.importsGraphics = true
        target.allowsUndo = true
        target.linkTextAttributes = [
            .foregroundColor: accentColor,
            .underlineStyle: 0,
        ]
        target.drawsBackground = true
        target.backgroundColor = NSColor(calibratedRed: 0.052, green: 0.055, blue: 0.062, alpha: 1)
        target.textColor = NSColor(calibratedWhite: 0.91, alpha: 1)
        target.insertionPointColor = NSColor(calibratedWhite: 0.95, alpha: 1)
        target.font = .systemFont(ofSize: 17)
        target.defaultParagraphStyle = editorParagraphStyle()
        target.typingAttributes = defaultTypingAttributes()
        target.textContainerInset = inset
        target.isVerticallyResizable = true
        target.isHorizontallyResizable = false
        target.autoresizingMask = [.width]
        target.delegate = self
        target.setAccessibilityLabel(label)
        target.onAttachmentDoubleClick = { [weak self] image in self?.showImagePreview(image) }
        target.onBecomeFirstResponder = { [weak self, weak target] in self?.lastFocusedEditor = target }
        target.checklistAccentColor = accentColor
    }

    /// The top pane holds the week and the chosen day's tasks. Its height is the user's, kept
    /// between launches; collapsing it gives the whole window back to the note.
    private func configureTodayPane() {
        todayPane.translatesAutoresizingMaskIntoConstraints = false
        todayPane.setAccessibilityLabel("오늘 할 일")
        weekStrip.onSelectDay = { [weak self] day in
            self?.selectDay(day)
            self?.panel.makeFirstResponder(self?.dailyEditor)
        }
        weekStrip.onShowMonth = { [weak self] in self?.setMonthCalendarShown(true) }
        monthCalendar.onClose = { [weak self] in self?.setMonthCalendarShown(false) }
        monthCalendar.onSelectDay = { [weak self] day in
            guard let self else { return }
            setMonthCalendarShown(false)
            selectDay(day)
            panel.makeFirstResponder(dailyEditor)
        }
        monthCalendar.isHidden = true
        todayPane.addSubview(weekStrip)
        todayPane.addSubview(dailyScroll)
        todayPane.addSubview(monthCalendar)
        paneDivider.translatesAutoresizingMaskIntoConstraints = false
        paneDivider.setAccessibilityLabel("오늘 할 일 높이 조절")
        paneDivider.onDragBegan = { [weak self] in
            guard let self else { return }
            dragStartTodayPaneHeight = todayPaneHeight.constant
        }
        paneDivider.onDrag = { [weak self] distance in
            guard let self else { return }
            setTodayPaneHeight(dragStartTodayPaneHeight + distance)
        }
        NSLayoutConstraint.activate([
            weekStrip.topAnchor.constraint(equalTo: todayPane.topAnchor, constant: 2),
            weekStrip.leadingAnchor.constraint(equalTo: todayPane.leadingAnchor, constant: 12),
            weekStrip.trailingAnchor.constraint(equalTo: todayPane.trailingAnchor, constant: -12),
            dailyScroll.topAnchor.constraint(equalTo: weekStrip.bottomAnchor, constant: 4),
            dailyScroll.leadingAnchor.constraint(equalTo: todayPane.leadingAnchor),
            dailyScroll.trailingAnchor.constraint(equalTo: todayPane.trailingAnchor),
            dailyScroll.bottomAnchor.constraint(equalTo: todayPane.bottomAnchor),
            monthCalendar.topAnchor.constraint(equalTo: todayPane.topAnchor, constant: 2),
            monthCalendar.leadingAnchor.constraint(equalTo: todayPane.leadingAnchor, constant: 12),
            monthCalendar.trailingAnchor.constraint(equalTo: todayPane.trailingAnchor, constant: -12),
            monthCalendar.bottomAnchor.constraint(equalTo: todayPane.bottomAnchor, constant: -4),
        ])
    }

    func setMonthCalendarShown(_ shown: Bool) {
        if shown {
            setTodayPaneCollapsed(false)
            monthCalendar.show(selected: selectedDay, today: Date(), taskCounts: repository.dailyTaskCounts())
            todayPaneHeight.constant = clampedTodayPaneHeight(max(storedTodayPaneHeight, monthCalendarHeight))
        } else if !todayPane.isHidden {
            todayPaneHeight.constant = clampedTodayPaneHeight(storedTodayPaneHeight)
        }
        monthCalendar.isHidden = !shown
        weekStrip.isHidden = shown
        dailyScroll.isHidden = shown
        relayoutEditors()
    }

    @objc func showMonthCalendar() { setMonthCalendarShown(monthCalendar.isHidden) }

    @objc func zoomIn() { stepZoom(by: 1) }
    @objc func zoomOut() { stepZoom(by: -1) }
    @objc func resetZoom() { applyZoom(1) }

    var zoom: CGFloat {
        let stored = UserDefaults.standard.double(forKey: "editor.zoom")
        return stored > 0 ? stored : 1
    }

    private func stepZoom(by step: Int) {
        let current = zoomSteps.enumerated().min { abs($0.element - zoom) < abs($1.element - zoom) }?.offset ?? 2
        applyZoom(zoomSteps[min(max(current + step, 0), zoomSteps.count - 1)])
    }

    /// Zoom magnifies both editors' scroll views rather than rewriting font sizes, so a
    /// note's stored formatting never depends on how large it was read.
    private func applyZoom(_ value: CGFloat) {
        UserDefaults.standard.set(Double(value), forKey: "editor.zoom")
        for scroll in [editor.enclosingScrollView, dailyEditor.enclosingScrollView].compactMap({ $0 }) {
            scroll.magnification = value
        }
        relayoutEditors()
    }

    private var storedTodayPaneHeight: CGFloat {
        let stored = UserDefaults.standard.double(forKey: "todayPane.height")
        return stored > 0 ? stored : 220
    }

    private func setTodayPaneCollapsed(_ collapsed: Bool) {
        if collapsed, !monthCalendar.isHidden { setMonthCalendarShown(false) }
        todayPane.isHidden = collapsed
        paneDivider.isHidden = collapsed
        todayPaneHeight.constant = collapsed ? 0 : clampedTodayPaneHeight(storedTodayPaneHeight)
        dividerHeight.constant = collapsed ? 0 : dividerThickness
        todayToggleButton?.contentTintColor = collapsed
            ? NSColor(calibratedWhite: 0.64, alpha: 1)
            : accentColor
        UserDefaults.standard.set(collapsed, forKey: "todayPane.collapsed")
        relayoutEditors()
    }

    private func setTodayPaneHeight(_ height: CGFloat) {
        guard !todayPane.isHidden, monthCalendar.isHidden else { return }
        let clamped = clampedTodayPaneHeight(height)
        todayPaneHeight.constant = clamped
        UserDefaults.standard.set(Double(clamped), forKey: "todayPane.height")
        relayoutEditors()
    }

    /// The note below always keeps a usable height; the pane gives way when the window shrinks.
    private func clampedTodayPaneHeight(_ height: CGFloat) -> CGFloat {
        let windowHeight = panel.contentView?.bounds.height ?? panel.frame.height
        let ceiling = max(minimumTodayPaneHeight, windowHeight - 44 - dividerThickness - 48 - minimumNoteHeight)
        return min(max(height, minimumTodayPaneHeight), ceiling)
    }

    private func relayoutEditors() {
        guard let root = panel.contentView else { return }
        root.layoutSubtreeIfNeeded()
        editor.layoutForScrollableViewport()
        dailyEditor.layoutForScrollableViewport()
    }

    private func configureOverlayDismissal() {
        panel.handleOverlayMouseDown = { [weak self] point in
            self?.dismissOverlaysForMouseDown(at: point)
        }
        panel.handleModifierChange = { [weak self] flags in
            guard let self, noteSwitchFollowsControlKey, !flags.contains(.control) else { return }
            hideNoteSwitchOverlay()
        }
        escapeEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  event.window === panel,
                  event.keyCode == 53,
                  dismissOpenOverlays(focusEditor: true) else {
                return event
            }
            return nil
        }
    }

    private func makeHeader() -> NSView {
        let listButton = toolbarButton(symbol: "sidebar.left", label: "노트 목록 열기 또는 닫기", action: #selector(toggleSidebar))
        sidebarToggleButton = listButton
        listButton.toolTip = "노트 목록 열기/닫기 (⌘⇧L)"
        let newButton = toolbarButton(symbol: "square.and.pencil", label: "새 노트", action: #selector(newNote))
        newButton.toolTip = "새 노트 (⌘N)"
        let closeButton = toolbarButton(symbol: "xmark", label: "노트 숨기기", action: #selector(hidePanel))
        closeButton.toolTip = "숨기기 (⌘Q)"
        let todayButton = toolbarButton(symbol: "calendar", label: "오늘 할 일 펼치기 또는 접기", action: #selector(toggleTodayPane))
        todayButton.toolTip = "오늘 할 일 펼치기/접기 (⌥⇧`로 바로 열기)"
        todayToggleButton = todayButton
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(listButton)
        header.addSubview(todayButton)
        header.addSubview(newButton)
        header.addSubview(closeButton)
        header.addSubview(headerTitleLabel)
        NSLayoutConstraint.activate([
            listButton.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            listButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            newButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            newButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            todayButton.trailingAnchor.constraint(equalTo: newButton.leadingAnchor, constant: -4),
            todayButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            headerTitleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            headerTitleLabel.centerYAnchor.constraint(equalTo: listButton.centerYAnchor),
            headerTitleLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: listButton.trailingAnchor,
                constant: 10
            ),
            headerTitleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: todayButton.leadingAnchor,
                constant: -10
            ),
        ])
        return header
    }

    private func configureHeaderTitleLabel() {
        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerTitleLabel.textColor = NSColor(calibratedWhite: 0.72, alpha: 1)
        headerTitleLabel.alignment = .center
        headerTitleLabel.lineBreakMode = .byTruncatingTail
        headerTitleLabel.maximumNumberOfLines = 1
        headerTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headerTitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerTitleLabel.setAccessibilityLabel("현재 노트 제목")
    }

    private func makeFooterFormatButton() -> NSButton {
        let button = NSButton(title: "T", target: self, action: #selector(toggleFormatOverlay))
        formatToggleButton = button
        button.isBordered = false
        button.font = .systemFont(ofSize: 17, weight: .medium)
        button.contentTintColor = NSColor(calibratedWhite: 0.68, alpha: 1)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityLabel("서식 메뉴 열기 또는 닫기")
        button.toolTip = "서식 메뉴 열기/닫기 (⌘⇧F)"
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return button
    }

    private func toolbarButton(symbol: String, label: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: label)!, target: self, action: action)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = NSColor(calibratedWhite: 0.64, alpha: 1)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityLabel(label)
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return button
    }

    private func configureSidebar() {
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.material = .hudWindow
        sidebar.blendingMode = .withinWindow
        sidebar.state = .active
        sidebar.wantsLayer = true
        sidebar.layer?.cornerRadius = 14
        sidebar.layer?.masksToBounds = true
        sidebar.layer?.borderWidth = 1
        sidebar.layer?.borderColor = NSColor(calibratedWhite: 0.32, alpha: 0.55).cgColor
        sidebar.setAccessibilityLabel("노트와 휴지통 목록")
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "제목과 본문 검색"
        searchField.setAccessibilityLabel("노트 검색")
        searchField.delegate = self
        searchField.focusRingType = .none

        scopeControl.translatesAutoresizingMaskIntoConstraints = false
        scopeControl.selectedSegment = 0
        scopeControl.target = self
        scopeControl.action = #selector(scopeChanged)
        scopeControl.setAccessibilityLabel("노트와 휴지통 전환")
        scopeControl.selectedSegmentBezelColor = accentColor

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Notes"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 34
        tableView.backgroundColor = .clear
        tableView.style = .plain
        tableView.delegate = self
        tableView.dataSource = self
        tableView.setAccessibilityLabel("노트 목록")
        let rowMenu = NSMenu()
        rowMenu.delegate = self
        tableView.menu = rowMenu
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = tableView

        restoreButton.target = self
        restoreButton.action = #selector(restoreCurrent)
        restoreButton.setAccessibilityLabel("선택한 노트 복원")
        restoreButton.contentTintColor = accentColor
        emptyTrashButton.target = self
        emptyTrashButton.action = #selector(confirmEmptyTrash)
        emptyTrashButton.setAccessibilityLabel("휴지통 영구 비우기")
        emptyTrashButton.contentTintColor = accentColor
        let trashActions = NSStackView(views: [restoreButton, emptyTrashButton])
        trashActions.orientation = .vertical
        trashActions.spacing = 6
        trashActions.translatesAutoresizingMaskIntoConstraints = false
        trashActions.isHidden = true
        trashActions.identifier = NSUserInterfaceItemIdentifier("TrashActions")

        sidebar.addSubview(searchField)
        sidebar.addSubview(scopeControl)
        sidebar.addSubview(scroll)
        sidebar.addSubview(trashActions)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -10),
            scopeControl.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scopeControl.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
            scopeControl.trailingAnchor.constraint(equalTo: searchField.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: scopeControl.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: trashActions.topAnchor, constant: -8),
            trashActions.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
            trashActions.trailingAnchor.constraint(equalTo: searchField.trailingAnchor),
            trashActions.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -10),
        ])
    }

    private func configureFormatOverlay() {
        formatOverlay.translatesAutoresizingMaskIntoConstraints = false
        formatOverlay.material = .hudWindow
        formatOverlay.blendingMode = .withinWindow
        formatOverlay.state = .active
        formatOverlay.wantsLayer = true
        formatOverlay.layer?.cornerRadius = 14
        formatOverlay.layer?.masksToBounds = true
        formatOverlay.layer?.borderWidth = 1
        formatOverlay.layer?.borderColor = NSColor(calibratedWhite: 0.32, alpha: 0.55).cgColor
        formatOverlay.setAccessibilityLabel("서식과 노트 동작")

        let buttons = [
            formatActionButton(title: "굵게", symbol: "bold", action: #selector(applyBoldFromMenu)),
            formatActionButton(title: "취소선", symbol: "strikethrough", action: #selector(applyStrikethroughFromMenu)),
            formatActionButton(title: "글머리 기호", symbol: "list.bullet", action: #selector(applyListFromMenu)),
            formatActionButton(title: "번호 목록", symbol: "list.number", action: #selector(applyOrderedListFromMenu)),
            formatActionButton(title: "체크리스트", symbol: "checklist", action: #selector(applyChecklistFromMenu), tint: accentColor),
            formatActionButton(title: "이미지 작게", symbol: "photo.badge.minus", action: #selector(resizeImageSmall)),
            formatActionButton(title: "이미지 보통", symbol: "photo", action: #selector(resizeImageMedium)),
            formatActionButton(title: "이미지 크게", symbol: "photo.badge.plus", action: #selector(resizeImageLarge)),
            formatActionButton(title: "선택한 이미지 삭제", symbol: "xmark.rectangle", action: #selector(deleteSelectedImageFromMenu), tint: accentColor),
            formatActionButton(title: "현재 노트를 휴지통으로", symbol: "trash", action: #selector(trashCurrentFromMenu), tint: accentColor),
        ]
        let stack = NSStackView(views: buttons)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        formatOverlay.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: formatOverlay.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: formatOverlay.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: formatOverlay.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: formatOverlay.bottomAnchor, constant: -10),
        ])
    }

    private func configureNoteSwitchOverlay() {
        noteSwitchOverlay.translatesAutoresizingMaskIntoConstraints = false
        noteSwitchOverlay.material = .hudWindow
        noteSwitchOverlay.blendingMode = .withinWindow
        noteSwitchOverlay.state = .active
        noteSwitchOverlay.wantsLayer = true
        noteSwitchOverlay.layer?.cornerRadius = 14
        noteSwitchOverlay.layer?.masksToBounds = true
        noteSwitchOverlay.layer?.borderWidth = 1
        noteSwitchOverlay.layer?.borderColor = NSColor(calibratedWhite: 0.42, alpha: 0.55).cgColor
        noteSwitchOverlay.setAccessibilityLabel("노트 전환 안내")

        noteSwitchList.translatesAutoresizingMaskIntoConstraints = false
        noteSwitchList.orientation = .vertical
        noteSwitchList.alignment = .leading
        noteSwitchList.spacing = 1
        noteSwitchList.setAccessibilityLabel("전환할 노트 목록")

        noteSwitchPositionLabel.translatesAutoresizingMaskIntoConstraints = false
        noteSwitchPositionLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        noteSwitchPositionLabel.textColor = NSColor(calibratedWhite: 0.62, alpha: 1)
        noteSwitchPositionLabel.alignment = .center
        noteSwitchPositionLabel.setAccessibilityLabel("노트 순서")

        noteSwitchOverlay.addSubview(noteSwitchList)
        noteSwitchOverlay.addSubview(noteSwitchPositionLabel)
        NSLayoutConstraint.activate([
            noteSwitchList.topAnchor.constraint(equalTo: noteSwitchOverlay.topAnchor, constant: 10),
            noteSwitchList.leadingAnchor.constraint(equalTo: noteSwitchOverlay.leadingAnchor, constant: 10),
            noteSwitchList.trailingAnchor.constraint(equalTo: noteSwitchOverlay.trailingAnchor, constant: -10),
            noteSwitchPositionLabel.topAnchor.constraint(equalTo: noteSwitchList.bottomAnchor, constant: 8),
            noteSwitchPositionLabel.leadingAnchor.constraint(equalTo: noteSwitchOverlay.leadingAnchor, constant: 18),
            noteSwitchPositionLabel.trailingAnchor.constraint(equalTo: noteSwitchOverlay.trailingAnchor, constant: -18),
            noteSwitchPositionLabel.bottomAnchor.constraint(equalTo: noteSwitchOverlay.bottomAnchor, constant: -11),
        ])
    }

    /// One row of the Ctrl+Tab list. Only the selected row gets a container: it carries the
    /// selection, which spacing alone cannot express.
    private func noteSwitchRow(title: String, isSelected: Bool) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true
        row.layer?.cornerRadius = 7
        row.layer?.backgroundColor = isSelected ? accentColor.cgColor : NSColor.clear.cgColor

        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular)
        label.alignment = .left
        label.textColor = isSelected
            ? NSColor(calibratedWhite: 1, alpha: 1)
            : NSColor(calibratedWhite: 0.66, alpha: 1)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setAccessibilityLabel(isSelected ? "전환된 노트 제목" : "전환 후보 노트 제목")

        row.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: row.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -5),
        ])
        return row
    }

    /// A long note list is windowed around the selection, so the overlay stays a readable card
    /// instead of growing past the panel.
    private func noteSwitchWindow(count: Int, selected: Int) -> Range<Int> {
        guard count > noteSwitchVisibleRows else { return 0..<count }
        let start = min(max(0, selected - noteSwitchVisibleRows / 2), count - noteSwitchVisibleRows)
        return start..<(start + noteSwitchVisibleRows)
    }

    private func formatActionButton(title: String, symbol: String, action: Selector, tint: NSColor? = nil) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.isBordered = false
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = tint ?? NSColor(calibratedWhite: 0.82, alpha: 1)
        button.setAccessibilityLabel(title)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        return button
    }

    private func configureErrorLabel() {
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font = .systemFont(ofSize: 11, weight: .medium)
        errorLabel.textColor = accentColor
        errorLabel.alignment = .center
        errorLabel.lineBreakMode = .byTruncatingTail
        errorLabel.drawsBackground = true
        errorLabel.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 0.96)
        errorLabel.wantsLayer = true
        errorLabel.layer?.cornerRadius = 8
        errorLabel.layer?.masksToBounds = true
        errorLabel.isHidden = true
        errorLabel.setAccessibilityLabel("오류 안내")
    }

    private func configureWordCountLabel() {
        wordCountLabel.translatesAutoresizingMaskIntoConstraints = false
        wordCountLabel.font = .systemFont(ofSize: 11, weight: .regular)
        wordCountLabel.textColor = NSColor(calibratedWhite: 0.48, alpha: 1)
        wordCountLabel.setAccessibilityLabel("단어 수")
    }

    private func editorParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        style.paragraphSpacing = 2
        return style
    }

    private func hideNoteSwitchOverlay() {
        noteSwitchTimer?.invalidate()
        noteSwitchFollowsControlKey = false
        noteSwitchOverlay.isHidden = true
    }

    private func closeOverlays(focusEditor: Bool = true) {
        hideNoteSwitchOverlay()
        sidebar.isHidden = true
        formatOverlay.isHidden = true
        if focusEditor {
            panel.makeFirstResponder(activeEditor)
        }
    }

    @discardableResult
    func dismissOpenOverlays(focusEditor: Bool = true) -> Bool {
        guard !sidebar.isHidden || !formatOverlay.isHidden || !noteSwitchOverlay.isHidden else { return false }
        closeOverlays(focusEditor: focusEditor)
        return true
    }

    private func dismissOverlaysForMouseDown(at windowPoint: NSPoint) {
        guard !sidebar.isHidden || !formatOverlay.isHidden || !noteSwitchOverlay.isHidden,
              let contentView = panel.contentView else { return }
        if !noteSwitchOverlay.isHidden {
            hideNoteSwitchOverlay()
        }
        let contentPoint = contentView.convert(windowPoint, from: nil)
        if !sidebar.isHidden, sidebar.frame.contains(contentPoint) { return }
        if !formatOverlay.isHidden, formatOverlay.frame.contains(contentPoint) { return }
        if let sidebarToggleButton,
           sidebarToggleButton.convert(sidebarToggleButton.bounds, to: contentView).contains(contentPoint) {
            return
        }
        if let formatToggleButton,
           formatToggleButton.convert(formatToggleButton.bounds, to: contentView).contains(contentPoint) {
            return
        }
        closeOverlays(focusEditor: false)
    }

    @objc private func applyBoldFromMenu() { toggleBold(); closeOverlays() }
    @objc private func applyStrikethroughFromMenu() { toggleStrikethrough(); closeOverlays() }
    @objc private func applyListFromMenu() { activeEditor.insertListItem(.bullet); closeOverlays() }
    @objc private func applyOrderedListFromMenu() { activeEditor.insertListItem(.ordered(1)); closeOverlays() }
    @objc private func applyChecklistFromMenu() { activeEditor.insertListItem(.uncheckedChecklist); closeOverlays() }
    @objc private func resizeImageSmall() { resizeImage(0.45); closeOverlays() }
    @objc private func resizeImageMedium() { resizeImage(0.68); closeOverlays() }
    @objc private func resizeImageLarge() { resizeImage(0.92); closeOverlays() }
    @objc private func deleteSelectedImageFromMenu() {
        if !activeEditor.deleteSelectedImage() { showError("삭제할 이미지를 먼저 선택하세요.") }
        closeOverlays()
    }
    @objc private func trashCurrentFromMenu() { closeOverlays(); trashCurrent() }

    private func updateTitle() {
        applyTitle(NoteContent.isEmpty(editor.attributedString())
            ? "새 노트"
            : NoteContent.title(from: editor.attributedString()))
    }

    /// The window title and the header label are one value; setting them apart would let the
    /// visible title drift from the one the note-switch overlay and the window menu report.
    private func applyTitle(_ title: String) {
        panel.title = title
        headerTitleLabel.stringValue = title
    }

    private func updateWordCount() {
        let count = editor.string.split(whereSeparator: { $0.isWhitespace }).count
        wordCountLabel.stringValue = "\(count)단어"
    }

    private func resizeImage(_ fraction: CGFloat) {
        if !activeEditor.resizeSelectedImage(fraction: fraction) {
            showError("크기를 바꿀 이미지를 먼저 선택하세요.")
        }
    }

    @objc private func scopeChanged() {
        noteCycle.removeAll()
        saveNow()
        showingTrash = scopeControl.selectedSegment == 1
        if let actions = sidebar.subviews.first(where: { $0.identifier?.rawValue == "TrashActions" }) {
            actions.isHidden = !showingTrash
        }
        reloadRows(selecting: nil)
        if let first = rows.first { loadNote(id: first.id) } else { newNoteForCurrentScope() }
    }

    @objc private func restoreCurrent() {
        restore(id: currentID)
    }

    private func restore(id: UUID) {
        guard showingTrash, rows.contains(where: { $0.id == id }) else { return }
        do {
            try repository.restore(id: id)
            guard id == currentID else {
                reloadRows(selecting: currentID)
                return
            }
            reloadRows(selecting: nil)
            newNoteForCurrentScope()
        } catch { showError(error.localizedDescription) }
    }

    @objc private func confirmEmptyTrash() {
        let count = repository.list(includeTrashed: true).count
        guard count > 0 else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "휴지통의 노트 \(count)개를 영구 삭제할까요?"
        alert.informativeText = "노트의 서식과 첨부 이미지도 함께 삭제되며 복구할 수 없습니다."
        alert.addButton(withTitle: "영구 삭제")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try repository.emptyTrash(confirmed: true)
            reloadRows(selecting: nil)
            newNoteForCurrentScope()
        } catch { showError(error.localizedDescription) }
    }

    private func saveNow() {
        autosaveTimer?.invalidate()
        guard !suppressChanges, editor.isEditable else { return }
        do {
            let saved = try repository.save(id: currentID, content: editor.attributedString())
            reloadRows(selecting: saved?.id)
            updateTitle()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func cycleNote(step: Int, controlHeld: Bool) {
        saveNow()
        showingTrash = false
        scopeControl.selectedSegment = 0
        searchField.stringValue = ""
        let active = repository.list()
        if noteCycle.isEmpty
            || Set(noteCycle.map(\.id)) != Set(active.map(\.id))
            || !noteCycle.contains(where: { $0.id == currentID }) {
            noteCycle = active
        }
        // An unsaved empty draft is not in the list; it sits ahead of the newest note, so
        // "previous" lands on the newest saved note and "next" wraps to the oldest.
        let currentIndex = noteCycle.firstIndex(where: { $0.id == currentID })
        guard !noteCycle.isEmpty, currentIndex == nil || noteCycle.count > 1 else {
            closeOverlays()
            return
        }
        let targetIndex: Int
        if let currentIndex {
            targetIndex = (currentIndex + step + noteCycle.count) % noteCycle.count
        } else {
            targetIndex = step > 0 ? 0 : noteCycle.count - 1
        }
        closeOverlays(focusEditor: false)
        loadNote(id: noteCycle[targetIndex].id)
        showNoteSwitchOverlay(selectedIndex: targetIndex, followsControlKey: controlHeld)
        panel.makeFirstResponder(editor)
    }

    private func showNoteSwitchOverlay(selectedIndex: Int, followsControlKey: Bool) {
        noteSwitchTimer?.invalidate()
        for row in noteSwitchList.arrangedSubviews {
            noteSwitchList.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        for index in noteSwitchWindow(count: noteCycle.count, selected: selectedIndex) {
            let row = noteSwitchRow(title: noteCycle[index].title, isSelected: index == selectedIndex)
            noteSwitchList.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: noteSwitchList.widthAnchor).isActive = true
        }
        noteSwitchPositionLabel.stringValue = "\(selectedIndex + 1) / \(noteCycle.count)"
        noteSwitchOverlay.superview?.addSubview(noteSwitchOverlay, positioned: .above, relativeTo: nil)
        noteSwitchOverlay.isHidden = false
        noteSwitchFollowsControlKey = followsControlKey
        guard !noteSwitchFollowsControlKey else { return }
        noteSwitchTimer = Timer.scheduledTimer(withTimeInterval: 1.15, repeats: false) { [weak self] _ in
            self?.hideNoteSwitchOverlay()
        }
    }

    private func reloadRows(selecting id: UUID?) {
        isRefreshingRows = true
        defer { isRefreshingRows = false }
        rows = repository.list(includeTrashed: showingTrash, query: searchField.stringValue)
        tableView.reloadData()
        if let id, let index = rows.firstIndex(where: { $0.id == id }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else {
            tableView.deselectAll(nil)
        }
    }

    private func loadNote(id: UUID) {
        guard id != currentID else { return }
        do {
            let note = try repository.load(id: id)
            currentID = id
            let normalizedAppearance = replaceEditorContent(with: note.content)
            editor.isEditable = !note.metadata.isTrashed
            reloadRows(selecting: id)
            applyTitle(note.metadata.title)
            if normalizedAppearance, editor.isEditable {
                saveNow()
            }
        } catch { showError(error.localizedDescription) }
    }

    @discardableResult
    private func replaceEditorContent(with content: NSAttributedString) -> Bool {
        let normalizedAppearance = setContent(content, of: editor)
        updateTitle()
        updateWordCount()
        return normalizedAppearance
    }

    @discardableResult
    private func setContent(_ content: NSAttributedString, of target: RichTextView) -> Bool {
        suppressChanges = true
        target.requiredTextStorage.setAttributedString(content)
        let normalizedAppearance = target.reloadListPresentation()
        target.layoutForScrollableViewport(scrollToDocumentStart: true)
        target.typingAttributes = defaultTypingAttributes()
        target.resetUndoHistory()
        suppressChanges = false
        return normalizedAppearance
    }

    private func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 17),
            .foregroundColor: NSColor(calibratedWhite: 0.91, alpha: 1),
            .paragraphStyle: editorParagraphStyle(),
        ]
    }

    private var activeEditor: RichTextView {
        lastFocusedEditor ?? editor
    }

    /// Loads the selected day into the top pane: its saved page, or an untouched empty
    /// checkbox that is only saved once something is written into it.
    private func loadDaily() {
        dailyAutosaveTimer?.invalidate()
        let day = DailyNote.dayKey(for: selectedDay)
        todayKeyAtLastRefresh = DailyNote.dayKey(for: Date())
        if let page = repository.dailyNote(day: day) {
            do {
                let stored = try repository.load(id: page.id)
                dailyID = page.id
                dailyTemplateIsUntouched = false
                setContent(stored.content, of: dailyEditor)
            } catch {
                showError(error.localizedDescription)
            }
        } else {
            dailyID = UUID()
            setContent(NSAttributedString(), of: dailyEditor)
            suppressChanges = true
            dailyEditor.insertListItem(.uncheckedChecklist)
            dailyEditor.resetUndoHistory()
            suppressChanges = false
            dailyTemplateIsUntouched = true
        }
        refreshWeekStrip()
    }

    /// A page left with only empty checkboxes is removed rather than kept, so the week's dots
    /// mark only days that hold something.
    private func saveDaily() {
        dailyAutosaveTimer?.invalidate()
        guard !suppressChanges, !dailyTemplateIsUntouched else { return }
        let content = dailyEditor.attributedString()
        do {
            try repository.save(
                id: dailyID,
                content: NoteContent.isBlankList(content) ? NSAttributedString() : content,
                dailyDay: DailyNote.dayKey(for: selectedDay)
            )
            refreshWeekStrip()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func refreshWeekStrip() {
        weekStrip.show(selected: selectedDay, today: Date(), taskCounts: repository.dailyTaskCounts())
    }

    private func followDayRollover(now: Date) {
        let todayKey = DailyNote.dayKey(for: now)
        guard todayKey != todayKeyAtLastRefresh else { return }
        if DailyNote.dayKey(for: selectedDay) == todayKeyAtLastRefresh {
            selectDay(now)
        } else {
            todayKeyAtLastRefresh = todayKey
            refreshWeekStrip()
        }
    }

    private func newNoteForCurrentScope() {
        noteCycle.removeAll()
        currentID = UUID()
        replaceEditorContent(with: NSAttributedString())
        editor.isEditable = !showingTrash
        updateTitle()
    }

    private func showImagePreview(_ image: NSImage) {
        let preview = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: min(image.size.width, 900), height: min(image.size.height, 700)),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        preview.title = "이미지 미리보기"
        preview.level = .floating
        let imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        preview.contentView = imageView
        panel.addChildWindow(preview, ordered: .above)
        preview.center()
        preview.makeKeyAndOrderFront(nil)
    }

    private func screenUnderMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
    }

    private func screenKey(_ screen: NSScreen) -> String {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "main"
    }

    private func rememberedFrame(for screen: NSScreen) -> CGRect? {
        guard let string = UserDefaults.standard.string(forKey: "windowFrame.\(screenKey(screen))") else { return nil }
        return NSRectFromString(string)
    }

    private func rememberCurrentFrame() {
        guard let screen = panel.screen else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "windowFrame.\(screenKey(screen))")
    }
}

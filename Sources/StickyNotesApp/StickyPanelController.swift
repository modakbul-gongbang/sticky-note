import AppKit
import StickyNotesCore

final class StickyPanelController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let repository: NoteRepository
    private let panel: NSPanel
    private let editor = RichTextView()
    private let tableView = NSTableView()
    private let searchField = NSSearchField()
    private let scopeControl = NSSegmentedControl(labels: ["노트", "휴지통"], trackingMode: .selectOne, target: nil, action: nil)
    private let sidebar = NSVisualEffectView()
    private let formatOverlay = NSVisualEffectView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let wordCountLabel = NSTextField(labelWithString: "0단어")
    private let restoreButton = NSButton(title: "복원", target: nil, action: nil)
    private let emptyTrashButton = NSButton(title: "휴지통 비우기", target: nil, action: nil)
    private let accentColor = NSColor(calibratedRed: 0.88, green: 0.27, blue: 0.23, alpha: 1)
    private var currentID = UUID()
    private var rows: [NoteMetadata] = []
    private var autosaveTimer: Timer?
    private var statusTimer: Timer?
    private var suppressChanges = false
    private var isRefreshingRows = false
    private var showingTrash = false

    init(repository: NoteRepository) {
        self.repository = repository
        panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)
        configurePanel()
        configureContents()
        let firstNoteID = repository.list().first?.id
        reloadRows(selecting: firstNoteID)
        if let firstNoteID {
            loadNote(id: firstNoteID)
        }
    }

    required init?(coder: NSCoder) { nil }

    func showOnCurrentScreen() {
        guard let screen = screenUnderMouse() ?? NSScreen.main else { return }
        let remembered = rememberedFrame(for: screen)
        panel.setFrame(WindowPlacement.frame(remembered: remembered, visibleFrame: screen.visibleFrame), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(editor)
    }

    func toggleOnCurrentScreen() {
        if panel.isVisible && panel.isKeyWindow {
            hidePanel()
        } else {
            showOnCurrentScreen()
        }
    }

    @objc func hidePanel() {
        saveNow()
        panel.orderOut(nil)
    }

    @objc func newNote() {
        saveNow()
        showingTrash = false
        scopeControl.selectedSegment = 0
        currentID = UUID()
        replaceEditorContent(with: NSAttributedString())
        reloadRows(selecting: nil)
        editor.isEditable = true
        panel.makeFirstResponder(editor)
        closeOverlays()
        showStatus("새 노트 - 첫 입력부터 자동 저장됩니다.", isError: false)
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

    @objc private func trashCurrent() {
        guard !showingTrash else { return }
        saveNow()
        guard repository.list().contains(where: { $0.id == currentID }) else {
            showStatus("빈 초안은 삭제할 필요가 없습니다.", isError: false)
            return
        }
        do {
            try repository.moveToTrash(id: currentID)
            reloadRows(selecting: nil)
            if let next = rows.first {
                loadNote(id: next.id)
            } else {
                newNoteForCurrentScope()
            }
            showStatus("노트를 휴지통으로 옮겼습니다.", isError: false)
        } catch { showStatus(error.localizedDescription, isError: true) }
    }

    @objc func toggleBold() {
        panel.makeFirstResponder(editor)
        let selection = editor.selectedRange()
        let baseFont = editor.typingAttributes[.font] as? NSFont ?? .systemFont(ofSize: 16)
        let traits = NSFontManager.shared.traits(of: baseFont)
        let makeBold = !traits.contains(.boldFontMask)
        if selection.length == 0 {
            editor.typingAttributes[.font] = makeBold
                ? NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(baseFont, toNotHaveTrait: .boldFontMask)
        } else {
            editor.requiredTextStorage.enumerateAttribute(.font, in: selection) { value, range, _ in
                let font = value as? NSFont ?? baseFont
                let converted = makeBold
                    ? NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                    : NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                editor.requiredTextStorage.addAttribute(.font, value: converted, range: range)
            }
            editor.didChangeText()
        }
    }

    @objc func toggleChecklistLine() {
        panel.makeFirstResponder(editor)
        editor.toggleChecklistOnCurrentLine()
        showStatus("현재 줄 체크리스트 전환", isError: false)
    }

    @objc func undoEditor() {
        panel.makeFirstResponder(editor)
        editor.undoManager?.undo()
    }

    @objc func redoEditor() {
        panel.makeFirstResponder(editor)
        editor.undoManager?.redo()
    }

    func showStatus(_ message: String, isError: Bool) {
        statusTimer?.invalidate()
        statusLabel.stringValue = "  \(message)  "
        statusLabel.textColor = isError ? accentColor : NSColor(calibratedWhite: 0.78, alpha: 1)
        statusLabel.toolTip = message
        statusLabel.isHidden = false
        statusTimer = Timer.scheduledTimer(withTimeInterval: isError ? 6 : 1.4, repeats: false) { [weak self] _ in
            self?.statusLabel.isHidden = true
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hidePanel()
        return false
    }

    func windowDidMove(_ notification: Notification) { rememberCurrentFrame() }
    func windowDidResize(_ notification: Notification) {
        editor.layoutForScrollableViewport()
        rememberCurrentFrame()
    }

    func textDidChange(_ notification: Notification) {
        guard !suppressChanges else { return }
        autosaveTimer?.invalidate()
        updateTitle()
        updateWordCount()
        showStatus("저장 중…", isError: false)
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.saveNow()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        reloadRows(selecting: currentID)
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
        saveNow()
        loadNote(id: rows[index].id)
        closeOverlays()
        panel.makeFirstResponder(editor)
    }

    private func configurePanel() {
        panel.title = "새 노트"
        panel.titleVisibility = .visible
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

        let header = makeHeader()
        let formatButton = makeFooterFormatButton()
        let editorScroll = NSScrollView()
        editorScroll.translatesAutoresizingMaskIntoConstraints = false
        editorScroll.drawsBackground = false
        editorScroll.hasVerticalScroller = true
        editorScroll.autohidesScrollers = true
        editorScroll.documentView = editor

        editor.isRichText = true
        editor.importsGraphics = true
        editor.allowsUndo = true
        editor.linkTextAttributes = [
            .foregroundColor: accentColor,
            .underlineStyle: 0,
        ]
        editor.drawsBackground = true
        editor.backgroundColor = NSColor(calibratedRed: 0.052, green: 0.055, blue: 0.062, alpha: 1)
        editor.textColor = NSColor(calibratedWhite: 0.91, alpha: 1)
        editor.insertionPointColor = NSColor(calibratedWhite: 0.95, alpha: 1)
        editor.font = .systemFont(ofSize: 17)
        editor.defaultParagraphStyle = editorParagraphStyle()
        editor.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 17),
            .foregroundColor: NSColor(calibratedWhite: 0.91, alpha: 1),
            .paragraphStyle: editorParagraphStyle(),
        ]
        editor.textContainerInset = CGSize(width: 20, height: 18)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.delegate = self
        editor.setAccessibilityLabel("노트 편집기")
        editor.onAttachmentDoubleClick = { [weak self] image in self?.showImagePreview(image) }
        editor.checklistAccentColor = accentColor

        configureSidebar()
        configureFormatOverlay()
        configureStatusLabel()
        configureWordCountLabel()
        root.addSubview(editorScroll)
        root.addSubview(header)
        root.addSubview(sidebar)
        root.addSubview(formatOverlay)
        root.addSubview(statusLabel)
        root.addSubview(wordCountLabel)
        root.addSubview(formatButton)

        sidebar.isHidden = true
        formatOverlay.isHidden = true
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            header.heightAnchor.constraint(equalToConstant: 34),
            editorScroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 2),
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
            formatButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            formatButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10),
            wordCountLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            wordCountLabel.centerYAnchor.constraint(equalTo: formatButton.centerYAnchor),
            statusLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: formatButton.centerYAnchor),
            statusLabel.heightAnchor.constraint(equalToConstant: 26),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: root.widthAnchor, constant: -180),
        ])
        root.layoutSubtreeIfNeeded()
        editor.layoutForScrollableViewport()
        updateWordCount()
    }

    private func makeHeader() -> NSView {
        let listButton = toolbarButton(symbol: "sidebar.left", label: "노트 목록 열기 또는 닫기", action: #selector(toggleSidebar))
        listButton.toolTip = "노트 목록 열기/닫기 (⌘⇧L)"
        let newButton = toolbarButton(symbol: "square.and.pencil", label: "새 노트", action: #selector(newNote))
        newButton.toolTip = "새 노트 (⌘N)"
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(listButton)
        header.addSubview(newButton)
        NSLayoutConstraint.activate([
            listButton.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            listButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            newButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            newButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        return header
    }

    private func makeFooterFormatButton() -> NSButton {
        let button = NSButton(title: "T", target: self, action: #selector(toggleFormatOverlay))
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

    private func configureStatusLabel() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.drawsBackground = true
        statusLabel.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 0.96)
        statusLabel.wantsLayer = true
        statusLabel.layer?.cornerRadius = 8
        statusLabel.layer?.masksToBounds = true
        statusLabel.isHidden = true
        statusLabel.setAccessibilityLabel("저장 상태")
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

    private func closeOverlays() {
        sidebar.isHidden = true
        formatOverlay.isHidden = true
        panel.makeFirstResponder(editor)
    }

    @objc private func applyBoldFromMenu() { toggleBold(); closeOverlays() }
    @objc private func applyListFromMenu() { editor.insertListItem(.bullet); closeOverlays() }
    @objc private func applyOrderedListFromMenu() { editor.insertListItem(.ordered(1)); closeOverlays() }
    @objc private func applyChecklistFromMenu() { editor.insertListItem(.uncheckedChecklist); closeOverlays() }
    @objc private func resizeImageSmall() { resizeImage(0.45); closeOverlays() }
    @objc private func resizeImageMedium() { resizeImage(0.68); closeOverlays() }
    @objc private func resizeImageLarge() { resizeImage(0.92); closeOverlays() }
    @objc private func deleteSelectedImageFromMenu() {
        if !editor.deleteSelectedImage() { showStatus("삭제할 이미지를 먼저 선택하세요.", isError: true) }
        closeOverlays()
    }
    @objc private func trashCurrentFromMenu() { closeOverlays(); trashCurrent() }

    private func updateTitle() {
        panel.title = NoteContent.isEmpty(editor.attributedString())
            ? "새 노트"
            : NoteContent.title(from: editor.attributedString())
    }

    private func updateWordCount() {
        let count = editor.string.split(whereSeparator: { $0.isWhitespace }).count
        wordCountLabel.stringValue = "\(count)단어"
    }

    private func resizeImage(_ fraction: CGFloat) {
        if !editor.resizeSelectedImage(fraction: fraction) {
            showStatus("크기를 바꿀 이미지를 먼저 선택하세요.", isError: true)
        }
    }

    @objc private func scopeChanged() {
        saveNow()
        showingTrash = scopeControl.selectedSegment == 1
        if let actions = sidebar.subviews.first(where: { $0.identifier?.rawValue == "TrashActions" }) {
            actions.isHidden = !showingTrash
        }
        reloadRows(selecting: nil)
        if let first = rows.first { loadNote(id: first.id) } else { newNoteForCurrentScope() }
    }

    @objc private func restoreCurrent() {
        guard showingTrash, rows.contains(where: { $0.id == currentID }) else { return }
        do {
            try repository.restore(id: currentID)
            reloadRows(selecting: nil)
            newNoteForCurrentScope()
            showStatus("노트를 복원했습니다.", isError: false)
        } catch { showStatus(error.localizedDescription, isError: true) }
    }

    @objc private func confirmEmptyTrash() {
        let count = repository.list(includeTrashed: true).count
        guard count > 0 else {
            showStatus("휴지통이 비어 있습니다.", isError: false)
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "휴지통의 노트 \(count)개를 영구 삭제할까요?"
        alert.informativeText = "노트의 서식과 첨부 이미지도 함께 삭제되며 복구할 수 없습니다."
        alert.addButton(withTitle: "영구 삭제")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn else {
            showStatus("휴지통 비우기를 취소했습니다. 모든 노트가 유지됩니다.", isError: false)
            return
        }
        do {
            let deleted = try repository.emptyTrash(confirmed: true)
            reloadRows(selecting: nil)
            newNoteForCurrentScope()
            showStatus("휴지통의 테스트 노트 \(deleted)개를 영구 삭제했습니다.", isError: false)
        } catch { showStatus(error.localizedDescription, isError: true) }
    }

    private func saveNow() {
        autosaveTimer?.invalidate()
        guard !suppressChanges, editor.isEditable else { return }
        do {
            let saved = try repository.save(id: currentID, content: editor.attributedString())
            showStatus(saved == nil ? "빈 초안은 저장하지 않습니다." : "저장됨", isError: false)
            reloadRows(selecting: saved?.id)
            updateTitle()
        } catch {
            showStatus(error.localizedDescription, isError: true)
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
            panel.title = note.metadata.title
            if normalizedAppearance, editor.isEditable {
                saveNow()
                showStatus("노트 서식을 정리해 저장했습니다.", isError: false)
            } else {
                showStatus(note.metadata.isTrashed ? "휴지통의 노트 - 복원하기 전에는 읽기 전용입니다." : "저장됨", isError: false)
            }
        } catch { showStatus(error.localizedDescription, isError: true) }
    }

    @discardableResult
    private func replaceEditorContent(with content: NSAttributedString) -> Bool {
        suppressChanges = true
        editor.requiredTextStorage.setAttributedString(content)
        let normalizedAppearance = editor.reloadListPresentation()
        editor.layoutForScrollableViewport(scrollToDocumentStart: true)
        resetTypingAttributes()
        editor.resetUndoHistory()
        suppressChanges = false
        updateTitle()
        updateWordCount()
        return normalizedAppearance
    }

    private func resetTypingAttributes() {
        editor.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 17),
            .foregroundColor: NSColor(calibratedWhite: 0.91, alpha: 1),
            .paragraphStyle: editorParagraphStyle(),
        ]
    }

    private func newNoteForCurrentScope() {
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

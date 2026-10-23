import AppKit
import Foundation
import Testing
@testable import StickyNotesApp
@testable import StickyNotesCore

@MainActor
@Suite struct ApplicationLifecycleTests {
    @Test func commandQHidesAndCompleteQuitRemainsExplicit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let delegate = AppDelegate()
        let mainMenu = delegate.makeMainMenu(for: controller)
        let applicationMenu = try #require(mainMenu.items.first?.submenu)

        let hide = try #require(applicationMenu.items.first(where: { $0.title == "Sticky Notes 숨기기" }))
        #expect(hide.action == NSSelectorFromString("hidePanel"))
        #expect(hide.keyEquivalent == "q")
        #expect(hide.keyEquivalentModifierMask == [.command])

        let close = try #require(applicationMenu.items.first(where: { $0.title == "창 닫기" }))
        #expect(close.action == NSSelectorFromString("hidePanel"))
        #expect(close.keyEquivalent == "w")
        #expect(close.keyEquivalentModifierMask == [.command])

        let completeQuit = try #require(applicationMenu.items.first(where: { $0.title == "완전히 종료" }))
        #expect(completeQuit.action == NSSelectorFromString("terminateApplication"))
        #expect(completeQuit.keyEquivalent == "q")
        #expect(completeQuit.keyEquivalentModifierMask == [.command, .option])

        let statusQuit = try #require(delegate.makeStatusMenu().items.first(where: { $0.title == "완전히 종료" }))
        #expect(statusQuit.action == NSSelectorFromString("terminateApplication"))
        #expect(statusQuit.keyEquivalentModifierMask == [.command, .option])
    }

    @Test func windowCloseHidesThePanelWithoutClosingIt() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let window = try #require(controller.window)
        window.orderFront(nil)
        #expect(window.isVisible)

        #expect(controller.windowShouldClose(window) == false)
        #expect(!window.isVisible)
        #expect(controller.window === window)
    }

    @Test func editorChromeUsesBottomFormatButtonAndNoManualLinkAction() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let delegate = AppDelegate()
        let mainMenu = delegate.makeMainMenu(for: controller)
        let allMenuTitles = mainMenu.items.flatMap { $0.submenu?.items.map(\.title) ?? [] }
        #expect(!allMenuTitles.contains("링크"))

        let contentView = try #require(controller.window?.contentView)
        contentView.layoutSubtreeIfNeeded()
        let descendants = recursiveSubviews(of: contentView)
        let formatButton = try #require(descendants.compactMap { $0 as? NSButton }.first {
            $0.accessibilityLabel() == "서식 메뉴 열기 또는 닫기"
        })
        #expect(formatButton.title == "T")
        #expect(formatButton.frame.midY < 80)
        let wordCount = try #require(descendants.compactMap { $0 as? NSTextField }.first {
            $0.accessibilityLabel() == "단어 수"
        })
        #expect(wordCount.stringValue == "0단어")
        #expect(!wordCount.isHidden)
        #expect(descendants.compactMap { $0 as? NSButton }.contains { $0.title == "번호 목록" })

        let editor = try #require(descendants.compactMap { $0 as? RichTextView }.first)
        editor.insertText("두 단어", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(wordCount.stringValue == "2단어")

        controller.toggleFormatOverlay()
        contentView.layoutSubtreeIfNeeded()
        let overlay = try #require(descendants.first { $0.accessibilityLabel() == "서식과 노트 동작" })
        let editorScroll = try #require(descendants.compactMap { $0 as? NSScrollView }.first { $0.documentView === editor })
        #expect(overlay.frame.minY > formatButton.frame.maxY)
        #expect(editorScroll.frame.minY > formatButton.frame.maxY)
    }

    @Test func controlTabCyclesAcrossEveryNoteAndWraps() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = try NoteRepository(rootURL: root)
        let ids = [UUID(), UUID(), UUID()]
        for (index, id) in ids.enumerated() {
            try repository.save(
                id: id,
                content: NSAttributedString(string: "노트 \(index + 1)"),
                modifiedAt: Date(timeIntervalSince1970: TimeInterval(index + 1))
            )
        }
        let controller = StickyPanelController(repository: repository)
        let editor = try #require(controller.window?.contentView.flatMap { content in
            recursiveSubviews(of: content).compactMap { $0 as? RichTextView }.first
        })

        #expect(editor.string == "노트 3")
        controller.showPreviousNote()
        #expect(editor.string == "노트 2")
        let contentView = try #require(controller.window?.contentView)
        contentView.layoutSubtreeIfNeeded()
        let switchOverlay = try #require(recursiveSubviews(of: contentView).first {
            $0.accessibilityLabel() == "노트 전환 안내"
        })
        let switchLabels = recursiveSubviews(of: switchOverlay).compactMap { $0 as? NSTextField }
        #expect(!switchOverlay.isHidden)
        #expect(switchLabels.first { $0.accessibilityLabel() == "전환된 노트 제목" }?.stringValue == "노트 2")
        #expect(switchLabels.first { $0.accessibilityLabel() == "노트 순서" }?.stringValue == "2 / 3")
        controller.showPreviousNote()
        #expect(editor.string == "노트 1")
        controller.showPreviousNote()
        #expect(editor.string == "노트 3")
        controller.showNextNote()
        #expect(editor.string == "노트 1")

        let noteMenu = try #require(AppDelegate().makeMainMenu(for: controller).items
            .first(where: { $0.submenu?.title == "노트" })?.submenu)
        let previous = try #require(noteMenu.items.first(where: { $0.title == "이전 노트" }))
        #expect(previous.action == #selector(StickyPanelController.showPreviousNote))
        #expect(previous.keyEquivalent == "\t")
        #expect(previous.keyEquivalentModifierMask == [.control])
        let next = try #require(noteMenu.items.first(where: { $0.title == "다음 노트" }))
        #expect(next.action == #selector(StickyPanelController.showNextNote))
        #expect(next.keyEquivalent == "\u{19}")
        #expect(next.keyEquivalentModifierMask == [.control, .shift])

        let previousEvent = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\t",
            charactersIgnoringModifiers: "\t",
            isARepeat: false,
            keyCode: 48
        ))
        #expect(noteMenu.performKeyEquivalent(with: previousEvent))
        #expect(editor.string == "노트 3")

        let nextEvent = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{19}",
            charactersIgnoringModifiers: "\u{19}",
            isARepeat: false,
            keyCode: 48
        ))
        #expect(noteMenu.performKeyEquivalent(with: nextEvent))
        #expect(editor.string == "노트 1")
    }

    @Test func controlTabFromAnEmptyDraftOpensTheNewestNote() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = try NoteRepository(rootURL: root)
        for index in 1...3 {
            try repository.save(
                id: UUID(),
                content: NSAttributedString(string: "노트 \(index)"),
                modifiedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        let controller = StickyPanelController(repository: repository)
        let contentView = try #require(controller.window?.contentView)
        let editor = try #require(recursiveSubviews(of: contentView).compactMap { $0 as? RichTextView }.first)
        let position = try #require(recursiveSubviews(of: contentView).compactMap { $0 as? NSTextField }
            .first { $0.accessibilityLabel() == "노트 순서" })

        controller.newNote()
        #expect(editor.string.isEmpty)
        controller.showPreviousNote()
        #expect(editor.string == "노트 3")
        #expect(position.stringValue == "1 / 3")
        #expect(repository.list().count == 3, "the abandoned empty draft is not saved")

        controller.newNote()
        controller.showNextNote()
        #expect(editor.string == "노트 1")
        #expect(position.stringValue == "3 / 3")
    }

    @Test func noteSwitcherClosesWhenControlIsReleased() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = try NoteRepository(rootURL: root)
        for index in 1...2 {
            try repository.save(
                id: UUID(),
                content: NSAttributedString(string: "노트 \(index)"),
                modifiedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        let controller = StickyPanelController(repository: repository)
        let panel = try #require(controller.window as? DismissiblePanel)
        let contentView = try #require(panel.contentView)
        let switchOverlay = try #require(recursiveSubviews(of: contentView).first {
            $0.accessibilityLabel() == "노트 전환 안내"
        })
        func modifiers(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try #require(NSEvent.keyEvent(
                with: .flagsChanged,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: panel.windowNumber,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: 59
            ))
        }

        // Opened from the menu with no Control held, the overlay is a timed toast and a
        // modifier change elsewhere does not touch it.
        controller.showPreviousNote()
        #expect(!switchOverlay.isHidden)
        panel.sendEvent(try modifiers([]))
        #expect(!switchOverlay.isHidden)

        // Opened while Control is down, it lives exactly as long as the key.
        controller.dismissOpenOverlays()
        controller.cycleNote(step: 1, controlHeld: true)
        #expect(!switchOverlay.isHidden)
        panel.sendEvent(try modifiers([.shift]))
        #expect(switchOverlay.isHidden)
    }

    @Test func headerCloseButtonHidesThePanelFromTheTopRight() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let window = try #require(controller.window)
        let contentView = try #require(window.contentView)
        contentView.layoutSubtreeIfNeeded()
        let descendants = recursiveSubviews(of: contentView)
        let closeButton = try #require(descendants.compactMap { $0 as? NSButton }.first {
            $0.accessibilityLabel() == "노트 숨기기"
        })
        let closeBox = closeButton.convert(closeButton.bounds, to: contentView)
        let otherButtons = descendants.compactMap { $0 as? NSButton }.filter { $0 !== closeButton && !$0.isHidden }
        #expect(closeBox.maxX == descendants.compactMap { $0 as? NSButton }.map { $0.convert($0.bounds, to: contentView).maxX }.max())
        #expect(otherButtons.allSatisfy { $0.convert($0.bounds, to: contentView).minY <= closeBox.minY })
        #expect(window.maxSize == CGSize(width: 640, height: 900))

        window.orderFront(nil)
        #expect(window.isVisible)
        _ = closeButton.target?.perform(closeButton.action, with: closeButton)
        #expect(!window.isVisible)
    }

    @Test func footerCarriesNoSaveStatusOnlyErrors() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let contentView = try #require(controller.window?.contentView)
        let descendants = recursiveSubviews(of: contentView)
        #expect(!descendants.contains { $0.accessibilityLabel() == "저장 상태" })
        let errorLabel = try #require(descendants.compactMap { $0 as? NSTextField }.first {
            $0.accessibilityLabel() == "오류 안내"
        })
        let editor = try #require(descendants.compactMap { $0 as? RichTextView }.first)

        editor.insertText("저장되는 글", replacementRange: NSRange(location: NSNotFound, length: 0))
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        #expect(errorLabel.isHidden)
        controller.newNote()
        #expect(errorLabel.isHidden)

        controller.showError("저장 실패")
        #expect(!errorLabel.isHidden)
        #expect(errorLabel.stringValue.contains("저장 실패"))
    }

    @Test func notesMoveToTheTrashFromTheRowMenuAndCommandDelete() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = try NoteRepository(rootURL: root)
        let ids = [UUID(), UUID(), UUID()]
        for (index, id) in ids.enumerated() {
            try repository.save(
                id: id,
                content: NSAttributedString(string: "노트 \(index + 1)"),
                modifiedAt: Date(timeIntervalSince1970: TimeInterval(index + 1))
            )
        }
        let controller = StickyPanelController(repository: repository)
        let contentView = try #require(controller.window?.contentView)
        let descendants = recursiveSubviews(of: contentView)
        let editor = try #require(descendants.compactMap { $0 as? RichTextView }.first)
        let table = try #require(descendants.compactMap { $0 as? NSTableView }.first)
        #expect(editor.string == "노트 3")

        let noteMenu = try #require(AppDelegate().makeMainMenu(for: controller).items
            .first(where: { $0.submenu?.title == "노트" })?.submenu)
        let trashItem = try #require(noteMenu.items.first(where: { $0.title == "휴지통으로 이동" }))
        #expect(trashItem.action == #selector(StickyPanelController.trashCurrent))
        #expect(trashItem.keyEquivalent == "\u{8}")
        #expect(trashItem.keyEquivalentModifierMask == [.command, .control])

        // ⌘⌫ stays with the editor: inside a note it deletes to the start of the line.
        let deleteToLineStart = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{8}",
            charactersIgnoringModifiers: "\u{8}",
            isARepeat: false,
            keyCode: 51
        ))
        #expect(!noteMenu.performKeyEquivalent(with: deleteToLineStart))

        // Cmd+Delete moves the open note and the editor falls back to the next one.
        controller.trashCurrent()
        #expect(repository.list().map(\.id) == [ids[1], ids[0]])
        #expect(repository.list(includeTrashed: true).map(\.id) == [ids[2]])
        #expect(editor.string == "노트 2")

        // The row menu acts on the clicked row, leaving the open note where it is.
        let rowMenu = try #require(table.menu)
        controller.toggleSidebar()
        #expect(table.numberOfRows == 2)
        controller.updateRowMenu(rowMenu, row: -1)
        #expect(rowMenu.items.isEmpty, "no clicked row, no actions")
        let row = try #require((0..<table.numberOfRows).first {
            (table.view(atColumn: 0, row: $0, makeIfNecessary: true) as? NSTableCellView)?.textField?.stringValue == "노트 1"
        })
        controller.updateRowMenu(rowMenu, row: row)
        let rowTrash = try #require(rowMenu.items.first)
        #expect(rowTrash.title == "휴지통으로 이동")
        _ = rowTrash.target?.perform(rowTrash.action, with: rowTrash)
        #expect(repository.list().map(\.id) == [ids[1]])
        #expect(editor.string == "노트 2")
        #expect(table.numberOfRows == 1)

        // The editor's own ⌘⌫ edits the line; it never reaches the note command.
        editor.setSelectedRange(NSRange(location: editor.requiredTextStorage.length, length: 0))
        editor.deleteToBeginningOfLine(nil)
        #expect(editor.string.isEmpty)
        #expect(Set(repository.list(includeTrashed: true).map(\.id)) == [ids[0], ids[2]], "no note was trashed")
    }

    @Test func overlaysCloseForEscapeOutsideClickResignAndHide() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let panel = try #require(controller.window as? DismissiblePanel)
        panel.orderFront(nil)
        #expect(panel.isVisible)
        let content = try #require(panel.contentView)
        content.layoutSubtreeIfNeeded()
        let descendants = recursiveSubviews(of: content)
        let sidebar = try #require(descendants.first { $0.accessibilityLabel() == "노트와 휴지통 목록" })
        let formatOverlay = try #require(descendants.first { $0.accessibilityLabel() == "서식과 노트 동작" })
        let searchField = try #require(descendants.compactMap { $0 as? NSSearchField }.first)
        _ = try #require(descendants.compactMap { $0 as? RichTextView }.first)

        controller.toggleFormatOverlay()
        #expect(!formatOverlay.isHidden)
        #expect(controller.dismissOpenOverlays())
        #expect(formatOverlay.isHidden)
        #expect(panel.isVisible)

        controller.toggleSidebar()
        #expect(!sidebar.isHidden)
        #expect(controller.control(
            searchField,
            textView: NSTextView(),
            doCommandBy: #selector(NSResponder.cancelOperation(_:))
        ))
        #expect(sidebar.isHidden)

        controller.toggleSidebar()
        let outsidePoint = content.convert(
            NSPoint(x: content.bounds.maxX - 8, y: content.bounds.midY),
            to: nil
        )
        let outsideClick = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: outsidePoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        panel.sendEvent(outsideClick)
        #expect(sidebar.isHidden)

        controller.toggleFormatOverlay()
        controller.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: panel))
        #expect(formatOverlay.isHidden)

        controller.toggleSidebar()
        controller.hidePanel()
        #expect(sidebar.isHidden)
    }

    @Test func controlTabShowsTheNoteListWithTheTargetSelectedAndWindowsLongLists() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = try NoteRepository(rootURL: root)
        for index in 1...10 {
            try repository.save(
                id: UUID(),
                content: NSAttributedString(string: "노트 \(index)"),
                modifiedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        let controller = StickyPanelController(repository: repository)
        let contentView = try #require(controller.window?.contentView)

        controller.showPreviousNote()
        contentView.layoutSubtreeIfNeeded()
        func switchRows() -> [NSTextField] {
            recursiveSubviews(of: contentView)
                .compactMap { $0 as? NSTextField }
                .filter { ["전환된 노트 제목", "전환 후보 노트 제목"].contains($0.accessibilityLabel() ?? "") }
        }

        let rows = switchRows()
        let selected = try #require(rows.first { $0.accessibilityLabel() == "전환된 노트 제목" })
        let position = try #require(recursiveSubviews(of: contentView).compactMap { $0 as? NSTextField }
            .first { $0.accessibilityLabel() == "노트 순서" })

        // Ten notes, seven rows: the switcher stays a card and still shows where the target sits.
        #expect(rows.count == 7)
        #expect(rows.filter { $0.accessibilityLabel() == "전환된 노트 제목" }.count == 1)
        #expect(selected.stringValue == "노트 9")
        #expect(position.stringValue == "2 / 10")
        #expect(rows.allSatisfy { !$0.stringValue.isEmpty })
        #expect(rows.map(\.stringValue).contains("노트 10"))

        // Stepping to the far end of the cycle moves the window with the selection.
        for _ in 0..<6 { controller.showPreviousNote() }
        contentView.layoutSubtreeIfNeeded()
        let laterRows = switchRows()
        let laterSelected = try #require(laterRows.first { $0.accessibilityLabel() == "전환된 노트 제목" })
        #expect(laterRows.count == 7)
        #expect(laterSelected.stringValue == "노트 3")
        #expect(!laterRows.map(\.stringValue).contains("노트 10"))
    }

    @Test func strikethroughMarksASelectionDoneAndIsUndoable() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let contentView = try #require(controller.window?.contentView)
        let descendants = recursiveSubviews(of: contentView)
        let editor = try #require(descendants.compactMap { $0 as? RichTextView }.first)
        let undoManager = try #require(editor.undoManager)
        undoManager.groupsByEvent = false
        func performUserAction(_ action: () -> Void) {
            undoManager.beginUndoGrouping()
            action()
            undoManager.endUndoGrouping()
        }
        performUserAction {
            editor.insertText("끝낸 일 남은 일", replacementRange: NSRange(location: NSNotFound, length: 0))
        }
        let done = (editor.string as NSString).range(of: "끝낸 일")

        func strikethrough(at location: Int) -> Int {
            editor.requiredTextStorage.attribute(
                .strikethroughStyle,
                at: location,
                effectiveRange: nil
            ) as? Int ?? 0
        }

        editor.setSelectedRange(done)
        performUserAction { controller.toggleStrikethrough() }
        #expect(strikethrough(at: done.location) == NSUnderlineStyle.single.rawValue)
        #expect(strikethrough(at: NSMaxRange(done)) == 0, "the rest of the line is untouched")

        undoManager.undo()
        #expect(editor.string == "끝낸 일 남은 일", "undo takes back the formatting, not the text")
        #expect(strikethrough(at: done.location) == 0)
        undoManager.redo()
        #expect(strikethrough(at: done.location) == NSUnderlineStyle.single.rawValue)

        // A second press on the same selection clears it.
        editor.setSelectedRange(done)
        performUserAction { controller.toggleStrikethrough() }
        #expect(strikethrough(at: done.location) == 0)

        // With no selection the command arms the next characters typed.
        editor.setSelectedRange(NSRange(location: editor.requiredTextStorage.length, length: 0))
        controller.toggleStrikethrough()
        performUserAction {
            editor.insertText(" 추가", replacementRange: NSRange(location: NSNotFound, length: 0))
        }
        #expect(strikethrough(at: editor.requiredTextStorage.length - 1) == NSUnderlineStyle.single.rawValue)

        let noteMenu = try #require(AppDelegate().makeMainMenu(for: controller).items
            .first(where: { $0.submenu?.title == "노트" })?.submenu)
        let strike = try #require(noteMenu.items.first(where: { $0.title == "취소선" }))
        #expect(strike.action == #selector(StickyPanelController.toggleStrikethrough))
        #expect(strike.keyEquivalent == "X")
        #expect(strike.keyEquivalentModifierMask == [.command, .shift])
        #expect(recursiveSubviews(of: contentView).compactMap { $0 as? NSButton }.contains { $0.title == "취소선" })
    }

    @Test func headerTitleIsCentredOnTheToolbarRowAndTracksTheNote() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let window = try #require(controller.window)
        let contentView = try #require(window.contentView)
        contentView.layoutSubtreeIfNeeded()
        let descendants = recursiveSubviews(of: contentView)
        let title = try #require(descendants.compactMap { $0 as? NSTextField }.first {
            $0.accessibilityLabel() == "현재 노트 제목"
        })
        let listButton = try #require(descendants.compactMap { $0 as? NSButton }.first {
            $0.accessibilityLabel() == "노트 목록 열기 또는 닫기"
        })
        let newButton = try #require(descendants.compactMap { $0 as? NSButton }.first {
            $0.accessibilityLabel() == "새 노트"
        })

        // A label's alignment rect is inset by a point from its frame, so exact-centre
        // comparisons against a button frame carry that much slack.
        let titleBox = title.convert(title.bounds, to: contentView)
        let listBox = listButton.convert(listButton.bounds, to: contentView)
        let newBox = newButton.convert(newButton.bounds, to: contentView)
        #expect(window.titleVisibility == .hidden)
        #expect(title.stringValue == "새 노트")
        #expect(abs(titleBox.midY - listBox.midY) <= 1)
        #expect(abs(titleBox.midY - newBox.midY) <= 1)
        #expect(abs(titleBox.midX - contentView.bounds.midX) <= 1)
        #expect(titleBox.minX >= listBox.maxX)
        #expect(titleBox.maxX <= newBox.minX)

        let editor = try #require(descendants.compactMap { $0 as? RichTextView }.first)
        let longTitle = String(repeating: "아주 긴 제목 ", count: 12)
        editor.insertText(longTitle, replacementRange: NSRange(location: NSNotFound, length: 0))
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        contentView.layoutSubtreeIfNeeded()

        let longTitleBox = title.convert(title.bounds, to: contentView)
        #expect(title.stringValue == window.title)
        #expect(title.stringValue.hasPrefix("아주 긴 제목"))
        #expect(longTitleBox.minX >= listBox.maxX)
        #expect(longTitleBox.maxX <= newBox.minX)
    }

    @Test func dayPageStartsUntouchedAndIsKeptApartFromTheNoteList() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = try NoteRepository(rootURL: root)
        try repository.save(id: UUID(), content: NSAttributedString(string: "일반 노트"))
        let controller = StickyPanelController(repository: repository)
        let contentView = try #require(controller.window?.contentView)
        let editors = recursiveSubviews(of: contentView).compactMap { $0 as? RichTextView }
        let noteEditor = try #require(editors.first { $0.accessibilityLabel() == "노트 편집기" })
        let dayEditor = try #require(editors.first { $0.accessibilityLabel() == "오늘 할 일 편집기" })
        let friday = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9)))
        let saturday = try #require(Calendar.current.date(byAdding: .day, value: 1, to: friday))

        controller.selectDay(friday)
        #expect(dayEditor.string == "☐\t")
        #expect(noteEditor.string == "일반 노트")
        controller.hidePanel()
        #expect(repository.dailyTaskCounts().isEmpty)

        dayEditor.setSelectedRange(NSRange(location: dayEditor.string.utf16.count, length: 0))
        dayEditor.insertText("장보기", replacementRange: NSRange(location: NSNotFound, length: 0))
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: dayEditor))
        controller.hidePanel()
        #expect(repository.dailyTaskCounts() == ["2026-10-23": TaskCount(total: 1, done: 0)])
        #expect(repository.list().map(\.title) == ["일반 노트"])
        #expect(noteEditor.string == "일반 노트")

        controller.selectDay(saturday)
        #expect(dayEditor.string == "☐\t")
        controller.selectDay(friday)
        #expect(dayEditor.string == "☐\t장보기")
    }

    @Test func pastedObsidianTasksReplaceTheEmptyCheckbox() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let contentView = try #require(controller.window?.contentView)
        let dayEditor = try #require(recursiveSubviews(of: contentView).compactMap { $0 as? RichTextView }.first {
            $0.accessibilityLabel() == "오늘 할 일 편집기"
        })
        let pasted = try #require(MarkdownPaste.lines(from: "#### Core Tasks\n- [ ] Hide 런칭하기\n\t- [x] 글 써보기\n- [ ] "))

        dayEditor.setSelectedRange(NSRange(location: dayEditor.string.utf16.count, length: 0))
        dayEditor.insertMarkdownPaste(pasted)
        #expect(dayEditor.string == "Core Tasks\n☐\tHide 런칭하기\n☑\t글 써보기")
        let headingFont = try #require(dayEditor.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: headingFont).contains(.boldFontMask))
        let childStyle = dayEditor.textStorage?.attribute(
            .paragraphStyle,
            at: (dayEditor.string as NSString).range(of: "☑").location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        #expect((childStyle?.firstLineHeadIndent ?? 0) > 0)
    }

    @Test func headerCalendarButtonCollapsesAndRestoresTheDayPane() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let wasCollapsed = UserDefaults.standard.object(forKey: "todayPane.collapsed")
        defer { UserDefaults.standard.set(wasCollapsed, forKey: "todayPane.collapsed") }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let contentView = try #require(controller.window?.contentView)
        let descendants = recursiveSubviews(of: contentView)
        let toggle = try #require(descendants.compactMap { $0 as? NSButton }.first {
            $0.accessibilityLabel() == "오늘 할 일 펼치기 또는 접기"
        })
        let pane = try #require(descendants.first { $0.accessibilityLabel() == "오늘 할 일" })
        let noteScroll = try #require(descendants.compactMap { $0 as? RichTextView }.first {
            $0.accessibilityLabel() == "노트 편집기"
        }?.enclosingScrollView)

        controller.openToday()
        contentView.layoutSubtreeIfNeeded()
        #expect(!pane.isHidden)
        let sharedHeight = noteScroll.frame.height

        _ = toggle.target?.perform(toggle.action, with: toggle)
        contentView.layoutSubtreeIfNeeded()
        #expect(pane.isHidden)
        #expect(noteScroll.frame.height > sharedHeight)

        _ = toggle.target?.perform(toggle.action, with: toggle)
        contentView.layoutSubtreeIfNeeded()
        #expect(!pane.isHidden)
        #expect(noteScroll.frame.height == sharedHeight)
    }

    @Test func draggingTheDividerResizesThePanesInsteadOfMovingTheWindow() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = UserDefaults.standard
        let saved = (defaults.object(forKey: "todayPane.height"), defaults.object(forKey: "todayPane.collapsed"))
        defer {
            defaults.set(saved.0, forKey: "todayPane.height")
            defaults.set(saved.1, forKey: "todayPane.collapsed")
        }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let window = try #require(controller.window)
        let contentView = try #require(window.contentView)
        controller.openToday()
        contentView.layoutSubtreeIfNeeded()
        let descendants = recursiveSubviews(of: contentView)
        let divider = try #require(descendants.compactMap { $0 as? PaneDivider }.first)
        let noteScroll = try #require(descendants.compactMap { $0 as? RichTextView }.first {
            $0.accessibilityLabel() == "노트 편집기"
        }?.enclosingScrollView)
        #expect(divider.mouseDownCanMoveWindow == false)

        func mouse(_ type: NSEvent.EventType, y: CGFloat) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(
                with: type, location: NSPoint(x: 200, y: y), modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
        }
        let before = noteScroll.frame.height
        let start = divider.convert(NSPoint(x: divider.bounds.midX, y: divider.bounds.midY), to: nil).y
        divider.mouseDown(with: try mouse(.leftMouseDown, y: start))
        divider.mouseDragged(with: try mouse(.leftMouseDragged, y: start + 60))
        divider.mouseUp(with: try mouse(.leftMouseUp, y: start + 60))
        contentView.layoutSubtreeIfNeeded()
        #expect(noteScroll.frame.height == before + 60)
    }

    @Test func zoomMagnifiesBothEditorsAndKeepsTextWrappedToTheWindow() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let savedZoom = UserDefaults.standard.object(forKey: "editor.zoom")
        defer { UserDefaults.standard.set(savedZoom, forKey: "editor.zoom") }

        let controller = StickyPanelController(repository: try NoteRepository(rootURL: root))
        let contentView = try #require(controller.window?.contentView)
        let editors = recursiveSubviews(of: contentView).compactMap { $0 as? RichTextView }
        controller.resetZoom()
        controller.zoomIn()
        controller.zoomIn()
        for editor in editors {
            let scroll = try #require(editor.enclosingScrollView)
            #expect(scroll.magnification == 1.25)
            #expect(abs(editor.frame.width - scroll.contentView.bounds.width) < 1)
            #expect(editor.frame.width < scroll.frame.width)
        }
        controller.resetZoom()
        #expect(editors.allSatisfy { $0.enclosingScrollView?.magnification == 1 })
    }

    @Test func monthCalendarShowsTaskProgressAndPicksADay() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let today = Date()
        let repository = try NoteRepository(rootURL: root)
        try repository.save(
            id: UUID(),
            content: NSAttributedString(string: "☑\tHide 런칭하기\n☐\t글 쓰기"),
            dailyDay: DailyNote.dayKey(for: today)
        )
        let controller = StickyPanelController(repository: repository)
        let contentView = try #require(controller.window?.contentView)
        let descendants = recursiveSubviews(of: contentView)
        let month = try #require(descendants.compactMap { $0 as? MonthCalendarView }.first)
        let dayEditor = try #require(descendants.compactMap { $0 as? RichTextView }.first {
            $0.accessibilityLabel() == "오늘 할 일 편집기"
        })

        controller.setMonthCalendarShown(true)
        #expect(!month.isHidden)
        contentView.layoutSubtreeIfNeeded()
        let cells = recursiveSubviews(of: month).compactMap { $0 as? DayButton }
        #expect(cells.count == 42)
        #expect(cells.allSatisfy { $0.frame.width > 40 && $0.frame.height >= 28 })
        #expect(!month.hasAmbiguousLayout)
        let todayCell = try #require(cells.first { $0.isToday })
        #expect(todayCell.accessibilityLabel() == "\(DailyNote.title(for: today)), 할 일 2개 중 1개 완료")

        let other = try #require(cells.first { !$0.isToday && !$0.isOutsideMonth })
        _ = other.target?.perform(other.action, with: other)
        #expect(month.isHidden)
        #expect(dayEditor.string == "☐\t")
    }

    private func recursiveSubviews(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(recursiveSubviews(of:))
    }
}

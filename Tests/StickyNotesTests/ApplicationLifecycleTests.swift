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

    private func recursiveSubviews(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(recursiveSubviews(of:))
    }
}

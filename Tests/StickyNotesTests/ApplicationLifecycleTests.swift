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

    private func recursiveSubviews(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(recursiveSubviews(of:))
    }
}

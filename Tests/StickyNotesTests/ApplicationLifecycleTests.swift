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
}

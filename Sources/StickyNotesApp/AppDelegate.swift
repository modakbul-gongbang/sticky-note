import AppKit
import ServiceManagement
import StickyNotesCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: StickyPanelController?
    private var hotKeyManager: HotKeyManager?
    private var loginStatus = "로그인 실행 확인 중"
    private var shortcutStatus = "단축키 연결 확인 중"

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing = others.first {
            existing.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let repository = try NoteRepository()
            let controller = StickyPanelController(repository: repository)
            panelController = controller
            configureMainMenu(for: controller)
            configureStatusItem()
            configureLoginItem()
            configureHotKey()
            controller.showOnCurrentScreen()
        } catch {
            showFatalError(error)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController?.showOnCurrentScreen()
        return true
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Sticky Notes")
            button.toolTip = "Sticky Notes"
        }
        statusItem = item
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        statusItem?.menu = makeStatusMenu()
    }

    func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Sticky Notes 열기/숨기기", action: #selector(togglePanel), keyEquivalent: "`")
        menu.items.last?.keyEquivalentModifierMask = [.option]
        menu.addItem(withTitle: "새 노트", action: #selector(newNote), keyEquivalent: "n")
        menu.addItem(.separator())

        let shortcut = NSMenuItem(title: shortcutStatus, action: #selector(retryShortcut), keyEquivalent: "")
        shortcut.image = NSImage(systemSymbolName: shortcutStatus.hasPrefix("연결됨") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill", accessibilityDescription: nil)
        menu.addItem(shortcut)

        let login = NSMenuItem(title: loginStatus, action: #selector(retryLoginItem), keyEquivalent: "")
        login.image = NSImage(systemSymbolName: loginStatus.hasPrefix("등록됨") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill", accessibilityDescription: nil)
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(withTitle: "완전히 종료", action: #selector(terminateApplication), keyEquivalent: "q")
        menu.items.last?.keyEquivalentModifierMask = [.command, .option]
        for item in menu.items where item.action != nil { item.target = self }
        return menu
    }

    private func configureHotKey() {
        let manager = HotKeyManager { [weak self] in self?.togglePanel() }
        hotKeyManager = manager
        do {
            try manager.register()
            shortcutStatus = "연결됨 - Option+`"
            panelController?.showStatus("준비됨 · ⌥`", isError: false)
        } catch {
            shortcutStatus = "연결 실패 - 클릭해 다시 시도"
            panelController?.showStatus(error.localizedDescription, isError: true)
        }
        rebuildStatusMenu()
    }

    private func configureLoginItem() {
        guard Bundle.main.bundleURL.path.hasPrefix("/Applications/") else {
            loginStatus = "로그인 실행 미등록 - Applications 설치 필요"
            rebuildStatusMenu()
            return
        }
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
            loginStatus = SMAppService.mainApp.status == .enabled
                ? "등록됨 - 로그인 시 자동 실행"
                : "로그인 실행 승인 필요 - 클릭해 확인"
            panelController?.showStatus(loginStatus, isError: SMAppService.mainApp.status != .enabled)
        } catch {
            loginStatus = "로그인 실행 실패 - 클릭해 다시 시도"
            panelController?.showStatus("로그인 실행 등록 실패: \(error.localizedDescription)", isError: true)
        }
        rebuildStatusMenu()
    }

    private func configureMainMenu(for controller: StickyPanelController) {
        NSApp.mainMenu = makeMainMenu(for: controller)
    }

    func makeMainMenu(for controller: StickyPanelController) -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu(title: "Sticky Notes")
        let hideItem = NSMenuItem(title: "Sticky Notes 숨기기", action: #selector(hidePanel), keyEquivalent: "q")
        hideItem.keyEquivalentModifierMask = [.command]
        hideItem.target = self
        appMenu.addItem(hideItem)
        appMenu.addItem(.separator())
        let terminateItem = NSMenuItem(title: "완전히 종료", action: #selector(terminateApplication), keyEquivalent: "q")
        terminateItem.keyEquivalentModifierMask = [.command, .option]
        terminateItem.target = self
        appMenu.addItem(terminateItem)
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(withTitle: "실행 취소", action: #selector(StickyPanelController.undoEditor), keyEquivalent: "z")
        editMenu.addItem(withTitle: "다시 실행", action: #selector(StickyPanelController.redoEditor), keyEquivalent: "Z")
        editMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "오려두기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙이기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.items[0].target = controller
        editMenu.items[1].target = controller
        editItem.submenu = editMenu

        let noteItem = NSMenuItem()
        main.addItem(noteItem)
        let noteMenu = NSMenu(title: "노트")
        noteMenu.addItem(withTitle: "새 노트", action: #selector(StickyPanelController.newNote), keyEquivalent: "n")
        noteMenu.addItem(withTitle: "목록 열기/닫기", action: #selector(StickyPanelController.toggleSidebar), keyEquivalent: "l")
        noteMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        noteMenu.addItem(withTitle: "굵게", action: #selector(StickyPanelController.toggleBold), keyEquivalent: "b")
        noteMenu.addItem(withTitle: "현재 줄 체크리스트 전환", action: #selector(StickyPanelController.toggleChecklistLine), keyEquivalent: "l")
        noteMenu.addItem(withTitle: "서식 메뉴 열기/닫기", action: #selector(StickyPanelController.toggleFormatOverlay), keyEquivalent: "f")
        noteMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        for item in noteMenu.items { item.target = controller }
        noteItem.submenu = noteMenu
        return main
    }

    @objc private func togglePanel() {
        panelController?.toggleOnCurrentScreen()
    }

    @objc private func newNote() {
        panelController?.newNote()
    }

    @objc private func retryShortcut() {
        configureHotKey()
    }

    @objc private func retryLoginItem() {
        configureLoginItem()
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    @objc private func hidePanel() {
        panelController?.hidePanel()
    }

    @objc private func terminateApplication() {
        NSApp.terminate(nil)
    }

    private func showFatalError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Sticky Notes를 시작할 수 없습니다"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        NSApp.terminate(nil)
    }
}

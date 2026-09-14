import AppKit
import Foundation
import Testing
@testable import StickyNotesApp
@testable import StickyNotesCore

/// Renders the panel offscreen so a reviewer can look at the editor and the note switcher without
/// driving the installed app. Only runs when `scripts/quick-capture.sh` asks for a scene.
@MainActor
@Suite struct EvidenceCaptureTests {
    private static let outputDirectory = ProcessInfo.processInfo.environment["STICKY_EVIDENCE_DIR"]
    private static let scene = ProcessInfo.processInfo.environment["STICKY_EVIDENCE_SCENE"]

    @Test(.enabled(if: outputDirectory != nil))
    func renderRequestedScene() throws {
        let directory = try #require(Self.outputDirectory)
        let scene = try #require(Self.scene)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = try NoteRepository(rootURL: root)
        for (index, note) in Self.fixtureNotes.enumerated() {
            try repository.save(
                id: UUID(),
                content: note,
                modifiedAt: Date(timeIntervalSince1970: TimeInterval(index + 1))
            )
        }

        let controller = StickyPanelController(repository: repository)
        let window = try #require(controller.window)
        window.setContentSize(NSSize(width: 420, height: 560))
        let contentView = try #require(window.contentView)
        window.orderFront(nil)

        switch scene {
        case "editor":
            break
        case "switcher":
            controller.showPreviousNote()
        default:
            Issue.record("unknown scene '\(scene)'")
            return
        }
        contentView.layoutSubtreeIfNeeded()

        let file = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent("\(scene).png")
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let representation = try #require(contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds))
        contentView.cacheDisplay(in: contentView.bounds, to: representation)
        let png = try #require(representation.representation(using: .png, properties: [:]))
        try png.write(to: file)

        #expect(representation.pixelsWide > 0)
        #expect(FileManager.default.fileExists(atPath: file.path))
        window.orderOut(nil)
    }

    /// The newest note is the one the panel opens on, so the list-heavy note is last.
    private static let fixtureNotes: [NSAttributedString] = [
        "읽을 거리",
        "다음 주 계획",
        "회의 메모",
        "아이디어 창고",
        "버그 목록",
        "질문 모음",
        "장보기 목록\n• 사과\n• 우유",
        "강의 준비\n1.\t자료 훑기\n2.\t예제 만들기",
        "회고 정리\n☐\t남은 일\n☑\t끝낸 일",
    ].map { NSAttributedString(string: $0) } + [nestedListNote()]

    private static func nestedListNote() -> NSAttributedString {
        let text = """
        릴리스 노트 초안
        1.\t목록 깊이 규칙
        1.\t바로 위 줄 기준 한 단계
        1.\t그 아래로 한 단계 더
        • 마커는 강조색으로
        ☐\t남은 확인
        ☑\t끝낸 확인
        직접 그은 취소선
        """
        let content = NSMutableAttributedString(string: text)
        let source = content.string as NSString
        content.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: source.range(of: "직접 그은 취소선")
        )
        for (row, level) in [("바로 위 줄", 1), ("그 아래로", 2), ("마커는", 1)] {
            let style = NSMutableParagraphStyle()
            style.firstLineHeadIndent = CGFloat(level) * 24
            style.headIndent = CGFloat(level) * 24 + 25
            let location = source.range(of: row).location
            content.addAttribute(
                .paragraphStyle,
                value: style,
                range: source.paragraphRange(for: NSRange(location: location, length: 0))
            )
        }
        return content
    }
}

import AppKit
import Foundation
import Testing
@testable import StickyNotesCore

@Suite struct EmptyDraftTests {
    @Test func emptyDraftIsNotPersistedAndFirstLineBecomesTitle() throws {
        let root = try temporaryDirectory()
        let repository = try NoteRepository(rootURL: root)
        let id = UUID()
        #expect(try repository.save(id: id, content: NSAttributedString(string: "  \n")) == nil)
        #expect(repository.list().isEmpty)
        let optionalSaved = try repository.save(id: id, content: NSAttributedString(string: "첫 줄 제목\n본문"))
        let saved = try #require(optionalSaved)
        #expect(saved.title == "첫 줄 제목")
    }
}

@Suite struct NoteRepositoryTests {
    @Test func moreThanSixNotesSurviveRepositoryRestart() throws {
        let root = try temporaryDirectory()
        let repository = try NoteRepository(rootURL: root)
        let ids = (0..<8).map { _ in UUID() }
        for (index, id) in ids.enumerated() {
            try repository.save(id: id, content: NSAttributedString(string: "노트 \(index)\n내용"))
        }
        let reopened = try NoteRepository(rootURL: root)
        #expect(reopened.list().count == 8)
        #expect(Set(reopened.list().map(\.id)) == Set(ids))
    }

    @Test func checklistHierarchyAndCheckedStateSurviveRepositoryRestart() throws {
        let root = try temporaryDirectory()
        let repository = try NoteRepository(rootURL: root)
        let id = UUID()
        let content = NSMutableAttributedString(string: "☐\t상위 항목\n☑\t하위 항목")
        let childStyle = NSMutableParagraphStyle()
        childStyle.firstLineHeadIndent = 24
        childStyle.headIndent = 49
        childStyle.lineSpacing = 4
        childStyle.paragraphSpacing = 8
        let childLocation = (content.string as NSString).range(of: "☑\t하위 항목").location
        content.addAttribute(
            .paragraphStyle,
            value: childStyle,
            range: (content.string as NSString).paragraphRange(for: NSRange(location: childLocation, length: 0))
        )

        try repository.save(id: id, content: content)
        let reopened = try NoteRepository(rootURL: root)
        let restored = try reopened.load(id: id).content
        let restoredChildLocation = (restored.string as NSString).range(of: "☑\t하위 항목").location
        let restoredStyle = try #require(restored.attribute(.paragraphStyle, at: restoredChildLocation, effectiveRange: nil) as? NSParagraphStyle)

        #expect(restored.string == content.string)
        #expect(restoredStyle.firstLineHeadIndent == 24)
        #expect(restoredStyle.headIndent == 49)
        #expect(restoredStyle.lineSpacing == 4)
        #expect(restoredStyle.paragraphSpacing == 8)
    }
}

@Suite struct AutosaveFailureTests {
    @Test func failedIndexCommitKeepsLastSuccessfulContent() throws {
        enum PlannedFailure: Error { case indexCommit }
        let root = try temporaryDirectory()
        let initial = try NoteRepository(rootURL: root)
        let id = UUID()
        try initial.save(id: id, content: NSAttributedString(string: "정상 저장본"))
        let failing = try NoteRepository(rootURL: root) { throw PlannedFailure.indexCommit }
        #expect(throws: (any Error).self) {
            try failing.save(id: id, content: NSAttributedString(string: "유실되면 안 되는 변경"))
        }
        let reopened = try NoteRepository(rootURL: root)
        #expect(try reopened.load(id: id).content.string == "정상 저장본")
    }
}

@Suite struct NoteSearchTests {
    @Test func searchCoversTitleAndBodyAndClearingReturnsRecentOrder() throws {
        let root = try temporaryDirectory()
        let repository = try NoteRepository(rootURL: root)
        let older = UUID()
        let newer = UUID()
        try repository.save(id: older, content: NSAttributedString(string: "사과\n빨간 과일"), modifiedAt: Date(timeIntervalSince1970: 1))
        try repository.save(id: newer, content: NSAttributedString(string: "회의\n사과 공급 논의"), modifiedAt: Date(timeIntervalSince1970: 2))
        #expect(repository.list(query: "회의").map(\.id) == [newer])
        #expect(repository.list(query: "빨간").map(\.id) == [older])
        #expect(repository.list(query: "").map(\.id) == [newer, older])
    }
}

@Suite struct TrashRestoreTests {
    @Test func trashedRichNoteRestoresAfterRestartWithAttachment() throws {
        let root = try temporaryDirectory()
        let repository = try NoteRepository(rootURL: root)
        let id = UUID()
        let content = NSMutableAttributedString(string: "이미지 노트\n")
        let attachment = NSTextAttachment()
        let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        attachment.contents = png
        attachment.fileType = "public.png"
        attachment.image = try #require(NSImage(data: png))
        content.append(NSAttributedString(attachment: attachment))
        try repository.save(id: id, content: content)
        try repository.moveToTrash(id: id)
        let reopened = try NoteRepository(rootURL: root)
        #expect(reopened.list(includeTrashed: true).map(\.id) == [id])
        try reopened.restore(id: id)
        let restored = try reopened.load(id: id)
        var attachmentCount = 0
        restored.content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: restored.content.length)) { value, _, _ in
            if value != nil { attachmentCount += 1 }
        }
        #expect(attachmentCount == 1)
        #expect(!restored.metadata.isTrashed)
    }
}

@Suite struct TrashEmptyTests {
    @Test func cancelPreservesAndConfirmPermanentlyDeletesOnlyTrash() throws {
        let root = try temporaryDirectory()
        let repository = try NoteRepository(rootURL: root)
        let trashed = UUID()
        let active = UUID()
        try repository.save(id: trashed, content: NSAttributedString(string: "지울 테스트 노트"))
        try repository.save(id: active, content: NSAttributedString(string: "남길 테스트 노트"))
        try repository.moveToTrash(id: trashed)
        #expect(try repository.emptyTrash(confirmed: false) == 0)
        #expect(repository.list(includeTrashed: true).map(\.id) == [trashed])
        #expect(try repository.emptyTrash(confirmed: true) == 1)
        let reopened = try NoteRepository(rootURL: root)
        #expect(reopened.list(includeTrashed: true).isEmpty)
        #expect(reopened.list().map(\.id) == [active])
    }
}

@Suite struct WindowPlacementTests {
    @Test func missingDisplayClampsRememberedFrameInsideCurrentVisibleArea() {
        let visible = CGRect(x: 100, y: 100, width: 800, height: 700)
        let missingDisplayFrame = CGRect(x: 2200, y: -500, width: 900, height: 200)
        let result = WindowPlacement.frame(remembered: missingDisplayFrame, visibleFrame: visible)
        #expect(visible.contains(result))
        #expect(result.size == CGSize(width: 800, height: 480))
    }

    @Test func noRememberedFrameUsesDefaultSizeCenteredOnCurrentScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let result = WindowPlacement.frame(remembered: nil, visibleFrame: visible)
        #expect(result.size == CGSize(width: 420, height: 640))
        #expect(result.midX == visible.midX)
        #expect(result.midY == visible.midY)
    }
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

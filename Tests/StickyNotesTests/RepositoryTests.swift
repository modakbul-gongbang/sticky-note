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
        #expect(result.size == CGSize(width: 640, height: 480))
    }

    @Test func rememberedFrameIsCappedAtTheMaximumSize() {
        let visible = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let oversized = CGRect(x: 10, y: 10, width: 1800, height: 1300)
        let result = WindowPlacement.frame(remembered: oversized, visibleFrame: visible)
        #expect(result.size == CGSize(width: 640, height: 900))
        #expect(result.origin == oversized.origin)
    }

    @Test func noRememberedFrameUsesDefaultSizeCenteredOnCurrentScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let result = WindowPlacement.frame(remembered: nil, visibleFrame: visible)
        #expect(result.size == CGSize(width: 420, height: 640))
        #expect(result.midX == visible.midX)
        #expect(result.midY == visible.midY)
    }
}

@Suite struct DailyNoteTests {
    @Test func dayKeyAndTitleFollowTheLocalCalendarDay() throws {
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))
        // 00:30 in Seoul is still the previous day in UTC; the page belongs to the local day.
        let earlyMorning = try #require(ISO8601DateFormatter().date(from: "2026-10-22T15:30:00Z"))
        #expect(DailyNote.dayKey(for: earlyMorning, calendar: seoul) == "2026-10-23")
        #expect(DailyNote.title(for: earlyMorning, calendar: seoul) == "10월 23일 (금)")
    }

    @Test func dailyPageKeepsItsDayAcrossEditsAndRestart() throws {
        let root = try temporaryDirectory()
        let repository = try NoteRepository(rootURL: root)
        let id = UUID()
        try repository.save(id: id, content: NSAttributedString(string: "10월 23일 (금)\n☐\t장보기"), dailyDay: "2026-10-23")
        try repository.save(id: id, content: NSAttributedString(string: "다른 제목\n☑\t장보기"))
        try repository.save(id: UUID(), content: NSAttributedString(string: "일반 노트"))

        let reopened = try NoteRepository(rootURL: root)
        #expect(reopened.dailyNote(day: "2026-10-23")?.id == id)
        #expect(reopened.dailyNote(day: "2026-10-24") == nil)
        #expect(reopened.list().map(\.title) == ["일반 노트"])
        #expect(reopened.dailyTaskCounts() == ["2026-10-23": TaskCount(total: 1, done: 1)])

        try reopened.moveToTrash(id: id)
        #expect(reopened.dailyNote(day: "2026-10-23") == nil)
    }

    @Test func weekRunsMondayToSundayAroundTheDay() throws {
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))
        let sunday = try #require(ISO8601DateFormatter().date(from: "2026-10-25T03:00:00Z"))
        let week = DailyNote.week(containing: sunday, calendar: seoul).map { DailyNote.dayKey(for: $0, calendar: seoul) }
        #expect(week == ["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25"])
    }

    @Test func monthGridIsSixMondayFirstWeeks() throws {
        let october = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9)))
        let grid = DailyNote.monthGrid(containing: october).map { DailyNote.dayKey(for: $0) }
        #expect(grid.count == 42)
        #expect(grid.first == "2026-09-28")
        #expect(grid.contains("2026-10-01") && grid.contains("2026-10-31"))
        #expect(grid.last == "2026-11-08")
    }

    @Test func taskCountIgnoresEmptyCheckboxesAndOtherLines() {
        let count = TaskCount(text: "Core Tasks\n☐\tHide 런칭하기\n☑\t투표 모니터링\n☐\t\n• 메모\n☑\t글 쓰기")
        #expect(count == TaskCount(total: 3, done: 2))
    }

    @Test func pageHoldingOnlyEmptyCheckboxesCountsAsBlank() {
        #expect(NoteContent.isBlankList(NSAttributedString(string: "☐\t\n☐\t  \n")))
        #expect(!NoteContent.isBlankList(NSAttributedString(string: "☐\t\n☐\t장보기")))
        #expect(!NoteContent.isBlankList(NSAttributedString(string: "메모")))
    }

    @Test func obsidianDaySectionBecomesHeadingsAndNestedTasks() throws {
        let section = """
        #### Core Tasks
        - [ ] Atorni 계획 세우기\u{20}
        \t- [ ]\u{20}
        - [ ] Hide 런칭하고 글 써보기\u{20}
        - [x] 투표 모니터링
        \t- [ ] 결과 공유
        \t\t\t- [ ] 너무 깊은 하위

        #### Satellite Tasks
        - [ ]\u{20}

        #### Memo
        Atorni\u{20}
        - 메모 한 줄
        """
        let lines = try #require(MarkdownPaste.lines(from: section))
        #expect(lines == [
            PastedLine(text: "Core Tasks", kind: nil, level: 0, isHeading: true),
            PastedLine(text: "Atorni 계획 세우기", kind: .uncheckedChecklist, level: 0, isHeading: false),
            PastedLine(text: "Hide 런칭하고 글 써보기", kind: .uncheckedChecklist, level: 0, isHeading: false),
            PastedLine(text: "투표 모니터링", kind: .checkedChecklist, level: 0, isHeading: false),
            PastedLine(text: "결과 공유", kind: .uncheckedChecklist, level: 1, isHeading: false),
            PastedLine(text: "너무 깊은 하위", kind: .uncheckedChecklist, level: 2, isHeading: false),
            PastedLine(text: "Satellite Tasks", kind: nil, level: 0, isHeading: true),
            PastedLine(text: "Memo", kind: nil, level: 0, isHeading: true),
            PastedLine(text: "Atorni", kind: nil, level: 0, isHeading: false),
            PastedLine(text: "메모 한 줄", kind: .bullet, level: 0, isHeading: false),
        ])
        #expect(MarkdownPaste.lines(from: "그냥 한 줄\n두 번째 줄") == nil)
    }

    @Test func indexWrittenBeforeDailyPagesStillLoads() throws {
        let root = try temporaryDirectory()
        let id = UUID()
        let storageName = "\(id.uuidString)-legacy.rtfd"
        let content = NSAttributedString(string: "예전 노트")
        let wrapper = try content.fileWrapper(
            from: NSRange(location: 0, length: content.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        let notes = root.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        try wrapper.write(to: notes.appendingPathComponent(storageName), options: .atomic, originalContentsURL: nil)
        let legacyIndex = """
        [{"id":"\(id.uuidString)","isTrashed":false,"modifiedAt":"2026-09-20T10:00:00Z",\
        "searchText":"예전 노트","storageName":"\(storageName)","title":"예전 노트"}]
        """
        try Data(legacyIndex.utf8).write(to: root.appendingPathComponent("index.json"))

        let repository = try NoteRepository(rootURL: root)
        #expect(repository.list().map(\.title) == ["예전 노트"])
        #expect(repository.list().first?.dailyDay == nil)
        #expect(try repository.load(id: id).content.string == "예전 노트")
    }
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

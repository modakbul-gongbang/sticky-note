import Testing
@testable import StickyNotesCore

@Suite struct ListItemSyntaxTests {
    @Test func lineStartSpaceConvertsOnlyTheTwoSupportedInputForms() {
        #expect(ListItemSyntax.conversion(linePrefix: "[]", insertedText: " ") == .init(kind: .uncheckedChecklist, sourceLength: 2))
        #expect(ListItemSyntax.conversion(linePrefix: "-", insertedText: " ") == .init(kind: .bullet, sourceLength: 1))
        #expect(ListItemSyntax.conversion(linePrefix: "text[]", insertedText: " ") == nil)
        #expect(ListItemSyntax.conversion(linePrefix: "text-", insertedText: " ") == nil)
        #expect(ListItemSyntax.conversion(linePrefix: "[]", insertedText: "x") == nil)
    }

    @Test func persistedPrefixesAreTheOnlyRecognizedListRepresentation() {
        #expect(ListItemSyntax.kind(of: "☐\t준비하기") == .uncheckedChecklist)
        #expect(ListItemSyntax.kind(of: "☑\t완료하기") == .checkedChecklist)
        #expect(ListItemSyntax.kind(of: "• 일반 목록") == .bullet)
        #expect(ListItemSyntax.kind(of: "[] 아직 입력 중") == nil)
        #expect(ListItemSyntax.kind(of: "- 아직 입력 중") == nil)
        #expect(ListItemSyntax.kind(of: "☐ 이전 공백 형식") == nil)
        #expect(ListItemSyntax.kind(of: "☐공백 없는 이전 형식") == nil)
    }

    @Test func continuationAndHierarchyFollowEditorConventions() {
        #expect(ListItemKind.checkedChecklist.continuation == .uncheckedChecklist)
        #expect(ListItemKind.bullet.continuation == .bullet)
        #expect(ListItemSyntax.adjustedIndentLevel(0, by: -1) == 0)
        #expect(ListItemSyntax.adjustedIndentLevel(0, by: 1) == 1)
        #expect(ListItemSyntax.adjustedIndentLevel(3, by: -1) == 2)
        #expect(ListItemSyntax.adjustedIndentLevel(8, by: 1) == 8)
    }

    @Test func backspaceAtContentStartRemovesOnlyTheWholeListPrefix() {
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "☐\t", caretOffset: 2) == "")
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "☐\t남길 내용", caretOffset: 2) == "남길 내용")
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "• 글머리", caretOffset: 2) == "글머리")
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "☐\t남길 내용", caretOffset: 3) == nil)
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "일반 문장", caretOffset: 0) == nil)
    }
}

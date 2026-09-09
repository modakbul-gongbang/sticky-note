import Testing
@testable import StickyNotesCore

@Suite struct ListItemSyntaxTests {
    @Test func lineStartSpaceConvertsOnlySupportedInputForms() {
        #expect(ListItemSyntax.conversion(linePrefix: "[]", insertedText: " ") == .init(kind: .uncheckedChecklist, sourceLength: 2))
        #expect(ListItemSyntax.conversion(linePrefix: "-", insertedText: " ") == .init(kind: .bullet, sourceLength: 1))
        #expect(ListItemSyntax.conversion(linePrefix: "1.", insertedText: " ")?.kind.prefix == "1.\t")
        #expect(ListItemSyntax.conversion(linePrefix: "1.", insertedText: " ")?.sourceLength == 2)
        #expect(ListItemSyntax.conversion(linePrefix: "text[]", insertedText: " ") == nil)
        #expect(ListItemSyntax.conversion(linePrefix: "text-", insertedText: " ") == nil)
        #expect(ListItemSyntax.conversion(linePrefix: "text1.", insertedText: " ") == nil)
        #expect(ListItemSyntax.conversion(linePrefix: "[]", insertedText: "x") == nil)
    }

    @Test func persistedPrefixesAreTheOnlyRecognizedListRepresentation() {
        #expect(ListItemSyntax.kind(of: "☐\t준비하기") == .uncheckedChecklist)
        #expect(ListItemSyntax.kind(of: "☑\t완료하기") == .checkedChecklist)
        #expect(ListItemSyntax.kind(of: "• 일반 목록") == .bullet)
        #expect(ListItemSyntax.kind(of: "12.\t순서 목록")?.prefix == "12.\t")
        #expect(ListItemSyntax.kind(of: "[] 아직 입력 중") == nil)
        #expect(ListItemSyntax.kind(of: "- 아직 입력 중") == nil)
        #expect(ListItemSyntax.kind(of: "☐ 이전 공백 형식") == nil)
        #expect(ListItemSyntax.kind(of: "☐공백 없는 이전 형식") == nil)
    }

    @Test func continuationAndHierarchyFollowEditorConventions() {
        #expect(ListItemKind.checkedChecklist.continuation == .uncheckedChecklist)
        #expect(ListItemKind.bullet.continuation == .bullet)
        // A row cannot indent past one level below the row above it, and outdenting stops at 0.
        #expect(ListItemSyntax.indentLevel(0, adjustedBy: 1, levelAbove: nil) == 0)
        #expect(ListItemSyntax.indentLevel(0, adjustedBy: 1, levelAbove: 0) == 1)
        #expect(ListItemSyntax.indentLevel(1, adjustedBy: 1, levelAbove: 0) == 1)
        #expect(ListItemSyntax.indentLevel(1, adjustedBy: 1, levelAbove: 1) == 2)
        #expect(ListItemSyntax.indentLevel(2, adjustedBy: 1, levelAbove: 2) == 3)
        #expect(ListItemSyntax.indentLevel(3, adjustedBy: -1, levelAbove: 3) == 2)
        #expect(ListItemSyntax.indentLevel(0, adjustedBy: -1, levelAbove: 0) == 0)
        // A row that drifted deeper than its parent allows is pulled back to the ceiling.
        #expect(ListItemSyntax.indentLevel(4, adjustedBy: 0, levelAbove: 1) == 2)
        #expect(ListItemSyntax.storedIndentLevel(3) == 3)
        #expect(ListItemSyntax.storedIndentLevel(-1) == 0)
    }

    @Test func backspaceAtContentStartRemovesOnlyTheWholeListPrefix() {
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "☐\t", caretOffset: 2) == "")
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "☐\t남길 내용", caretOffset: 2) == "남길 내용")
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "• 글머리", caretOffset: 2) == "글머리")
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "12.\t순서 목록", caretOffset: 4) == "순서 목록")
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "☐\t남길 내용", caretOffset: 3) == nil)
        #expect(ListItemSyntax.plainTextAfterRemovingPrefix(from: "일반 문장", caretOffset: 0) == nil)
    }
}

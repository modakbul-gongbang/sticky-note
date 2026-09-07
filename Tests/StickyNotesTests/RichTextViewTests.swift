import AppKit
import Testing
@testable import StickyNotesApp

@MainActor
@Suite struct RichTextViewTests {
    @Test func loadedContentOccupiesTheVisibleEditorViewport() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 600))
        scrollView.hasVerticalScroller = true

        let editor = RichTextView()
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainerInset = NSSize(width: 20, height: 18)
        scrollView.documentView = editor
        editor.layoutForScrollableViewport()

        let restoredText = "오늘의 메모\n작은 생각을 빠르게 적고, 필요할 때 다시 꺼내봅니다."
        editor.requiredTextStorage.setAttributedString(NSAttributedString(string: restoredText))
        editor.layoutForScrollableViewport(scrollToDocumentStart: true)

        let glyphRange = editor.requiredLayoutManager.glyphRange(
            forCharacterRange: NSRange(location: 0, length: 1),
            actualCharacterRange: nil
        )
        var firstGlyph = editor.requiredLayoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: editor.requiredTextContainer
        )
        firstGlyph.origin.x += editor.textContainerOrigin.x
        firstGlyph.origin.y += editor.textContainerOrigin.y

        #expect(editor.string == restoredText)
        #expect(editor.selectedRange() == NSRange(location: 0, length: 0))
        #expect(editor.visibleRect.intersects(firstGlyph))
        #expect(editor.frame.height >= scrollView.contentSize.height)
        #expect(scrollView.contentView.bounds.origin == .zero)
    }

    @Test func longDocumentHeightSurvivesViewportResize() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 240))
        scrollView.hasVerticalScroller = true
        let editor = RichTextView()
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainerInset = NSSize(width: 20, height: 18)
        scrollView.documentView = editor

        let longText = (0..<80).map { "줄 \($0) 긴 기존 노트 내용" }.joined(separator: "\n")
        editor.requiredTextStorage.setAttributedString(NSAttributedString(string: longText))
        editor.layoutForScrollableViewport(scrollToDocumentStart: true)
        let initialDocumentHeight = editor.frame.height

        scrollView.frame.size.height = 360
        editor.layoutForScrollableViewport()

        #expect(editor.string == longText)
        #expect(initialDocumentHeight > scrollView.contentSize.height)
        #expect(editor.frame.height >= initialDocumentHeight)
        #expect(editor.frame.height > scrollView.contentSize.height)
    }

    @Test func emptyChecklistHierarchyExitAndPlainTextUndoRoundTrip() {
        let editor = RichTextView()
        editor.isEditable = true
        editor.allowsUndo = true
        let undoManager = editor.undoManager!
        undoManager.groupsByEvent = false
        func performUserAction(_ action: () -> Void) {
            undoManager.beginUndoGrouping()
            action()
            undoManager.endUndoGrouping()
        }

        performUserAction { editor.insertText("[", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        performUserAction { editor.insertText("]", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        performUserAction { editor.insertText(" ", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        #expect(editor.string == "☐\t")

        performUserAction { editor.insertTab(nil) }
        var style = editor.requiredTextStorage.attribute(
            .paragraphStyle,
            at: 0,
            effectiveRange: nil
        ) as? NSParagraphStyle
        #expect(style?.firstLineHeadIndent == 24)

        performUserAction { editor.insertBacktab(nil) }
        style = editor.requiredTextStorage.attribute(
            .paragraphStyle,
            at: 0,
            effectiveRange: nil
        ) as? NSParagraphStyle
        #expect(style?.firstLineHeadIndent == 0)
        #expect(editor.typingAttributes[.paragraphStyle].flatMap { $0 as? NSParagraphStyle }?.firstLineHeadIndent == 0)

        performUserAction { editor.deleteBackward(nil) }
        #expect(editor.string.isEmpty)
        undoManager.undo()
        #expect(editor.string == "☐\t")
        style = editor.requiredTextStorage.attribute(
            .paragraphStyle,
            at: 0,
            effectiveRange: nil
        ) as? NSParagraphStyle
        #expect(style?.firstLineHeadIndent == 0)
        undoManager.redo()
        #expect(editor.string.isEmpty)

        performUserAction { editor.insertNewline(nil) }
        performUserAction { editor.insertText("평문 입력", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        #expect(editor.string == "\n평문 입력")

        undoManager.undo()
        #expect(editor.string == "\n")
        undoManager.redo()
        #expect(editor.string == "\n평문 입력")
    }
}

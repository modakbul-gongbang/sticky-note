import AppKit
import Testing
@testable import StickyNotesApp
@testable import StickyNotesCore

@MainActor
@Suite struct RichTextViewTests {
    private func configuredEditor() -> RichTextView {
        let editor = RichTextView()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = 2
        editor.isEditable = true
        editor.isRichText = true
        editor.importsGraphics = true
        editor.allowsUndo = true
        editor.font = .systemFont(ofSize: 17)
        editor.textColor = NSColor(calibratedWhite: 0.91, alpha: 1)
        editor.defaultParagraphStyle = paragraph
        editor.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 17),
            .foregroundColor: NSColor(calibratedWhite: 0.91, alpha: 1),
            .paragraphStyle: paragraph,
        ]
        return editor
    }

    @Test func loadedForeignRichTextAdoptsEditorAppearanceAndKeepsSemantics() throws {
        let editor = configuredEditor()
        let foreignParagraph = NSMutableParagraphStyle()
        foreignParagraph.firstLineHeadIndent = 51
        foreignParagraph.headIndent = 77
        foreignParagraph.lineSpacing = 19
        let url = try #require(URL(string: "https://example.com/path"))
        let content = NSMutableAttributedString(
            string: "굵은 링크",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 28),
                .foregroundColor: NSColor.black,
                .backgroundColor: NSColor.yellow,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .paragraphStyle: foreignParagraph,
                .link: url,
            ]
        )
        editor.requiredTextStorage.setAttributedString(content)

        #expect(editor.reloadListPresentation())

        let attributes = editor.requiredTextStorage.attributes(at: 0, effectiveRange: nil)
        let font = try #require(attributes[.font] as? NSFont)
        let paragraph = try #require(attributes[.paragraphStyle] as? NSParagraphStyle)
        #expect(editor.string == "굵은 링크")
        #expect(font.pointSize == 17)
        #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        #expect((attributes[.foregroundColor] as? NSColor) == editor.textColor)
        #expect(attributes[.backgroundColor] == nil)
        #expect(attributes[.underlineStyle] == nil)
        #expect(attributes[.link] as? URL == url)
        #expect(paragraph.firstLineHeadIndent == 0)
        #expect(paragraph.headIndent == 0)
        #expect(paragraph.lineSpacing == 4)
        #expect(paragraph.paragraphSpacing == 2)
        #expect(!editor.reloadListPresentation())
    }

    @Test func appearanceRepairPreservesSupportedListsHierarchyAndAttachments() throws {
        let editor = configuredEditor()
        let content = NSMutableAttributedString(
            string: "☑\t완료\n• 글머리\n1.\t부모\n2.\t자식\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 24),
                .foregroundColor: NSColor.black,
            ]
        )
        let childLocation = (content.string as NSString).range(of: "2.\t자식").location
        let childStyle = NSMutableParagraphStyle()
        childStyle.firstLineHeadIndent = 24
        childStyle.headIndent = 49
        content.addAttribute(
            .paragraphStyle,
            value: childStyle,
            range: (content.string as NSString).paragraphRange(for: NSRange(location: childLocation, length: 0))
        )
        let attachment = NSTextAttachment()
        let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        attachment.contents = png
        attachment.fileType = "public.png"
        attachment.image = try #require(NSImage(data: png))
        content.append(NSAttributedString(attachment: attachment))
        editor.requiredTextStorage.setAttributedString(content)

        #expect(editor.reloadListPresentation())

        let lines = editor.string.components(separatedBy: .newlines)
        #expect(ListItemSyntax.kind(of: lines[0]) == .checkedChecklist)
        #expect(ListItemSyntax.kind(of: lines[1]) == .bullet)
        #expect(ListItemSyntax.kind(of: lines[2]) == .ordered(1))
        #expect(ListItemSyntax.kind(of: lines[3]) == .ordered(1))
        let restoredChildLocation = (editor.string as NSString).range(of: "1.\t자식").location
        let restoredStyle = try #require(editor.requiredTextStorage.attribute(
            .paragraphStyle,
            at: restoredChildLocation,
            effectiveRange: nil
        ) as? NSParagraphStyle)
        #expect(restoredStyle.firstLineHeadIndent == 24)
        #expect(editor.requiredTextStorage.attribute(
            .attachment,
            at: editor.requiredTextStorage.length - 1,
            effectiveRange: nil
        ) is NSTextAttachment)
    }

    @Test func richTextPasteUsesEditorAppearanceInsteadOfSourceAppearance() throws {
        let editor = configuredEditor()
        let pasteboard = NSPasteboard(name: .init("StickyNotesTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        let foreign = NSAttributedString(
            string: "붙여넣은 문장",
            attributes: [
                .font: NSFont(name: "Times New Roman", size: 31)!,
                .foregroundColor: NSColor.black,
                .backgroundColor: NSColor.white,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
        )
        let data = try #require(foreign.rtf(from: NSRange(location: 0, length: foreign.length)))
        pasteboard.setData(data, forType: .rtf)

        #expect(editor.readSelection(from: pasteboard, type: .rtf))

        let attributes = editor.requiredTextStorage.attributes(at: 0, effectiveRange: nil)
        #expect(editor.string == "붙여넣은 문장")
        #expect((attributes[.font] as? NSFont)?.pointSize == 17)
        #expect((attributes[.foregroundColor] as? NSColor) == editor.textColor)
        #expect(attributes[.backgroundColor] == nil)
        #expect(attributes[.underlineStyle] == nil)
    }

    @Test func automaticURLDetectionIsEnabled() {
        let editor = configuredEditor()
        #expect(editor.isAutomaticLinkDetectionEnabled)
        #expect(editor.enabledTextCheckingTypes & NSTextCheckingResult.CheckingType.link.rawValue != 0)
    }

    @Test func typedURLBecomesALinkAndPlainClickOpensIt() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 160),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 160))
        window.contentView = scrollView
        let editor = configuredEditor()
        editor.textContainerInset = NSSize(width: 20, height: 18)
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        scrollView.documentView = editor
        editor.layoutForScrollableViewport()
        editor.insertText("https://example.com", replacementRange: NSRange(location: NSNotFound, length: 0))

        let url = try #require(editor.requiredTextStorage.attribute(
            .link,
            at: 4,
            effectiveRange: nil
        ) as? URL)
        var openedURL: URL?
        editor.onLinkClick = { openedURL = $0 }
        editor.requiredLayoutManager.ensureLayout(for: editor.requiredTextContainer)
        let glyphRange = editor.requiredLayoutManager.glyphRange(
            forCharacterRange: NSRange(location: 4, length: 1),
            actualCharacterRange: nil
        )
        var glyphRect = editor.requiredLayoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: editor.requiredTextContainer
        )
        glyphRect.origin.x += editor.textContainerOrigin.x
        glyphRect.origin.y += editor.textContainerOrigin.y
        let windowPoint = editor.convert(NSPoint(x: glyphRect.midX, y: glyphRect.midY), to: nil)
        let event = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: windowPoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))

        editor.mouseDown(with: event)

        #expect(url == URL(string: "https://example.com"))
        #expect(openedURL == url)
    }

    @Test func pastedPlainURLBecomesALink() throws {
        let editor = configuredEditor()
        let pasteboard = NSPasteboard(name: .init("StickyNotesTests.URL.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("https://openai.com/docs", forType: .string)

        #expect(editor.readSelection(from: pasteboard, type: .string))

        #expect(editor.requiredTextStorage.attribute(.link, at: 4, effectiveRange: nil) as? URL == URL(string: "https://openai.com/docs"))
    }

    @Test func editedDetectedURLRefreshesOrClearsWithoutRemovingExplicitLinks() throws {
        let editor = configuredEditor()
        editor.insertText("https://example.com", replacementRange: NSRange(location: NSNotFound, length: 0))
        let hostRange = (editor.string as NSString).range(of: "example")
        editor.insertText("openai", replacementRange: hostRange)
        #expect(editor.string == "https://openai.com")
        #expect(editor.requiredTextStorage.attribute(.link, at: 4, effectiveRange: nil) as? URL == URL(string: "https://openai.com"))

        editor.insertText("x", replacementRange: NSRange(location: 0, length: 1))
        #expect(editor.string == "xttps://openai.com")
        #expect(editor.requiredTextStorage.attribute(.link, at: 4, effectiveRange: nil) == nil)

        let explicitURL = try #require(URL(string: "https://example.com/reference"))
        let explicit = NSAttributedString(string: "문서 보기", attributes: [.link: explicitURL])
        editor.requiredTextStorage.setAttributedString(explicit)
        _ = editor.reloadListPresentation()
        #expect(editor.requiredTextStorage.attribute(.link, at: 1, effectiveRange: nil) as? URL == explicitURL)
    }

    @Test func orderedListConversionContinuationHierarchyAndDeletionUndoRoundTrip() {
        let editor = configuredEditor()
        let undoManager = editor.undoManager!
        undoManager.groupsByEvent = false
        func performUserAction(_ action: () -> Void) {
            undoManager.beginUndoGrouping()
            action()
            undoManager.endUndoGrouping()
        }

        performUserAction { editor.insertText("1", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        performUserAction { editor.insertText(".", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        performUserAction { editor.insertText(" ", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        #expect(editor.string == "1.\t")
        undoManager.undo()
        #expect(editor.string == "1.")
        undoManager.redo()
        #expect(editor.string == "1.\t")

        performUserAction { editor.insertText("부모", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        performUserAction { editor.insertNewline(nil) }
        #expect(editor.string == "1.\t부모\n2.\t")
        undoManager.undo()
        #expect(editor.string == "1.\t부모")
        undoManager.redo()
        #expect(editor.string == "1.\t부모\n2.\t")

        performUserAction { editor.insertNewline(nil) }
        #expect(editor.string == "1.\t부모\n")
        undoManager.undo()
        #expect(editor.string == "1.\t부모\n2.\t")
        undoManager.redo()
        #expect(editor.string == "1.\t부모\n")
        undoManager.undo()
        #expect(editor.string == "1.\t부모\n2.\t")

        performUserAction { editor.insertText("자식", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        performUserAction { editor.insertTab(nil) }
        #expect(editor.string == "1.\t부모\n1.\t자식")
        let style = editor.requiredTextStorage.attribute(.paragraphStyle, at: 7, effectiveRange: nil) as? NSParagraphStyle
        #expect(style?.firstLineHeadIndent == 24)
        undoManager.undo()
        #expect(editor.string == "1.\t부모\n2.\t자식")
        undoManager.redo()
        #expect(editor.string == "1.\t부모\n1.\t자식")

        performUserAction { editor.insertBacktab(nil) }
        #expect(editor.string == "1.\t부모\n2.\t자식")
        var rootStyle = editor.requiredTextStorage.attribute(.paragraphStyle, at: 7, effectiveRange: nil) as? NSParagraphStyle
        #expect(rootStyle?.firstLineHeadIndent == 0)
        undoManager.undo()
        #expect(editor.string == "1.\t부모\n1.\t자식")
        rootStyle = editor.requiredTextStorage.attribute(.paragraphStyle, at: 7, effectiveRange: nil) as? NSParagraphStyle
        #expect(rootStyle?.firstLineHeadIndent == 24)
        undoManager.redo()
        #expect(editor.string == "1.\t부모\n2.\t자식")
        rootStyle = editor.requiredTextStorage.attribute(.paragraphStyle, at: 7, effectiveRange: nil) as? NSParagraphStyle
        #expect(rootStyle?.firstLineHeadIndent == 0)

        let childMarker = (editor.string as NSString).range(of: "\n2.\t")
        editor.setSelectedRange(NSRange(location: NSMaxRange(childMarker), length: 0))
        performUserAction { editor.deleteBackward(nil) }
        #expect(editor.string == "1.\t부모\n자식")
        undoManager.undo()
        #expect(editor.string == "1.\t부모\n2.\t자식")
        undoManager.redo()
        #expect(editor.string == "1.\t부모\n자식")
    }

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

import AppKit
import StickyNotesCore

final class RichTextView: NSTextView {
    var onAttachmentDoubleClick: ((NSImage) -> Void)?
    private let editorUndoManager = UndoManager()
    private lazy var listItemEditor = ListItemEditor(textView: self)

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        disableSystemTextTransformations()
    }

    convenience init() {
        self.init(frame: .zero, textContainer: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        disableSystemTextTransformations()
    }

    var checklistAccentColor: NSColor {
        get { listItemEditor.accentColor }
        set { listItemEditor.accentColor = newValue }
    }

    override var undoManager: UndoManager? { editorUndoManager }

    func resetUndoHistory() {
        editorUndoManager.removeAllActions()
    }

    @discardableResult
    func reloadListPresentation() -> Bool {
        listItemEditor.reloadPresentation()
    }

    override func paste(_ sender: Any?) {
        if let image = NSImage(pasteboard: .general) {
            insertImage(image)
            return
        }
        super.paste(sender)
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        if listItemEditor.handleInsertText(insertString, replacementRange: replacementRange) {
            return
        }
        super.insertText(insertString, replacementRange: replacementRange)
    }

    override func insertNewline(_ sender: Any?) {
        guard listItemEditor.continueOrExitList() else {
            super.insertNewline(sender)
            return
        }
    }

    override func insertTab(_ sender: Any?) {
        guard listItemEditor.adjustHierarchy(by: 1) else {
            super.insertTab(sender)
            return
        }
    }

    override func insertBacktab(_ sender: Any?) {
        guard listItemEditor.adjustHierarchy(by: -1) else {
            super.insertBacktab(sender)
            return
        }
    }

    override func deleteBackward(_ sender: Any?) {
        guard listItemEditor.deleteBackwardFromListIfNeeded() else {
            super.deleteBackward(sender)
            return
        }
    }

    override func didChangeText() {
        listItemEditor.textDidChange()
        super.didChangeText()
    }

    override func draw(_ dirtyRect: NSRect) {
        listItemEditor.prepareForDrawing()
        super.draw(dirtyRect)
        listItemEditor.drawControls(in: dirtyRect)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        listItemEditor.installCursorRects()
    }

    override func mouseDown(with event: NSEvent) {
        if listItemEditor.handleMouseDown(event) {
            return
        }
        if let (index, attachment) = attachment(at: event) {
            setSelectedRange(NSRange(location: index, length: 1))
            if event.clickCount == 2, let image = attachment.image {
                onAttachmentDoubleClick?(image)
            }
            return
        }
        super.mouseDown(with: event)
    }

    func insertListItem(_ kind: ListItemKind) {
        listItemEditor.insert(kind)
    }

    func toggleChecklistOnCurrentLine() {
        listItemEditor.toggleChecklistOnCurrentLine()
    }

    func insertImage(_ image: NSImage) {
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = fittedBounds(for: image, fraction: 0.92)
        let attributed = NSMutableAttributedString(attachment: attachment)
        attributed.append(NSAttributedString(string: "\n"))
        insertText(attributed, replacementRange: selectedRange())
        didChangeText()
    }

    func resizeSelectedImage(fraction: CGFloat) -> Bool {
        guard let attachment = selectedAttachment(), let image = attachment.image else { return false }
        attachment.bounds = fittedBounds(for: image, fraction: fraction)
        didChangeText()
        needsDisplay = true
        return true
    }

    func deleteSelectedImage() -> Bool {
        guard selectedAttachment() != nil else { return false }
        textStorage?.deleteCharacters(in: selectedRange())
        didChangeText()
        return true
    }

    private func selectedAttachment() -> NSTextAttachment? {
        let range = selectedRange()
        guard range.location < (textStorage?.length ?? 0) else { return nil }
        if range.length == 0 {
            setSelectedRange(NSRange(location: range.location, length: 1))
        }
        return textStorage?.attribute(.attachment, at: range.location, effectiveRange: nil) as? NSTextAttachment
    }

    private func attachment(at event: NSEvent) -> (Int, NSTextAttachment)? {
        guard let layoutManager, let textContainer, let storage = textStorage else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        var result: (Int, NSTextAttachment)?
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, stop in
            guard let attachment = value as? NSTextAttachment else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var bounds = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            bounds.origin.x += textContainerOrigin.x
            bounds.origin.y += textContainerOrigin.y
            if bounds.contains(point) {
                result = (range.location, attachment)
                stop.pointee = true
            }
        }
        return result
    }

    private func fittedBounds(for image: NSImage, fraction: CGFloat) -> CGRect {
        let source = image.size
        let maximumWidth = max(120, (textContainer?.containerSize.width ?? 360) * fraction)
        let scale = min(1, maximumWidth / max(source.width, 1))
        return CGRect(origin: .zero, size: CGSize(width: source.width * scale, height: source.height * scale))
    }

    private func disableSystemTextTransformations() {
        isAutomaticTextCompletionEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        enabledTextCheckingTypes = 0
    }
}

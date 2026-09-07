import AppKit
import StickyNotesCore

final class RichTextView: NSTextView {
    var onAttachmentDoubleClick: ((NSImage) -> Void)?
    private let editorUndoManager = UndoManager()
    private let ownedTextStorage: NSTextStorage?
    private let ownedLayoutManager: NSLayoutManager?
    private let ownedTextContainer: NSTextContainer?
    private lazy var listItemEditor = ListItemEditor(textView: self)

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        if let container {
            ownedTextStorage = nil
            ownedLayoutManager = nil
            ownedTextContainer = nil
            super.init(frame: frameRect, textContainer: container)
        } else {
            let storage = NSTextStorage()
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(
                containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            )
            textContainer.widthTracksTextView = true
            storage.addLayoutManager(layoutManager)
            layoutManager.addTextContainer(textContainer)
            ownedTextStorage = storage
            ownedLayoutManager = layoutManager
            ownedTextContainer = textContainer
            super.init(frame: frameRect, textContainer: textContainer)
        }
        assertCompleteTextSystem()
        disableSystemTextTransformations()
    }

    convenience init() {
        self.init(frame: .zero, textContainer: nil)
    }

    required init?(coder: NSCoder) {
        ownedTextStorage = nil
        ownedLayoutManager = nil
        ownedTextContainer = nil
        super.init(coder: coder)
        assertCompleteTextSystem()
        disableSystemTextTransformations()
    }

    var requiredTextStorage: NSTextStorage {
        guard let textStorage else { preconditionFailure("RichTextView requires NSTextStorage") }
        return textStorage
    }

    var requiredLayoutManager: NSLayoutManager {
        guard let layoutManager else { preconditionFailure("RichTextView requires NSLayoutManager") }
        return layoutManager
    }

    var requiredTextContainer: NSTextContainer {
        guard let textContainer else { preconditionFailure("RichTextView requires NSTextContainer") }
        return textContainer
    }

    var checklistAccentColor: NSColor {
        get { listItemEditor.accentColor }
        set { listItemEditor.accentColor = newValue }
    }

    override var undoManager: UndoManager? { editorUndoManager }

    func resetUndoHistory() {
        editorUndoManager.removeAllActions()
    }

    func layoutForScrollableViewport(scrollToDocumentStart: Bool = false) {
        guard let scrollView = enclosingScrollView else {
            preconditionFailure("RichTextView must be installed in an NSScrollView")
        }
        scrollView.layoutSubtreeIfNeeded()
        let viewport = scrollView.contentSize
        let previousOrigin = scrollView.contentView.bounds.origin
        minSize = NSSize(width: 0, height: viewport.height)
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        requiredTextContainer.widthTracksTextView = true
        requiredTextContainer.containerSize = NSSize(
            width: max(viewport.width, 1),
            height: CGFloat.greatestFiniteMagnitude
        )
        setFrameSize(NSSize(
            width: max(viewport.width, 1),
            height: max(frame.height, max(viewport.height, 1))
        ))
        requiredLayoutManager.ensureLayout(for: requiredTextContainer)
        let usedHeight = requiredLayoutManager.usedRect(for: requiredTextContainer).height
            + textContainerInset.height * 2
        let documentHeight = max(max(viewport.height, 1), ceil(usedHeight))
        setFrameSize(NSSize(width: max(viewport.width, 1), height: documentHeight))

        if scrollToDocumentStart {
            setSelectedRange(NSRange(location: 0, length: 0))
            scrollView.contentView.scroll(to: .zero)
        } else {
            let maximumY = max(0, documentHeight - viewport.height)
            scrollView.contentView.scroll(to: NSPoint(
                x: 0,
                y: min(max(0, previousOrigin.y), maximumY)
            ))
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
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
        requiredTextStorage.deleteCharacters(in: selectedRange())
        didChangeText()
        return true
    }

    private func selectedAttachment() -> NSTextAttachment? {
        let range = selectedRange()
        guard range.location < requiredTextStorage.length else { return nil }
        if range.length == 0 {
            setSelectedRange(NSRange(location: range.location, length: 1))
        }
        return requiredTextStorage.attribute(.attachment, at: range.location, effectiveRange: nil) as? NSTextAttachment
    }

    private func attachment(at event: NSEvent) -> (Int, NSTextAttachment)? {
        let layoutManager = requiredLayoutManager
        let textContainer = requiredTextContainer
        let storage = requiredTextStorage
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
        let maximumWidth = max(120, requiredTextContainer.containerSize.width * fraction)
        let scale = min(1, maximumWidth / max(source.width, 1))
        return CGRect(origin: .zero, size: CGSize(width: source.width * scale, height: source.height * scale))
    }

    private func assertCompleteTextSystem() {
        precondition(textStorage != nil, "RichTextView requires NSTextStorage")
        precondition(layoutManager != nil, "RichTextView requires NSLayoutManager")
        precondition(textContainer != nil, "RichTextView requires NSTextContainer")
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

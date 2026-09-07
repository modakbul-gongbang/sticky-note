import AppKit
import StickyNotesCore

final class ListItemEditor: NSObject {
    var accentColor = NSColor(calibratedRed: 0.88, green: 0.27, blue: 0.23, alpha: 1) {
        didSet { textView?.needsDisplay = true }
    }

    private weak var textView: RichTextView?
    private let hierarchyIndent: CGFloat = 24
    private let textIndent: CGFloat = 25
    private let controlSize: CGFloat = 15
    private let controlCornerRadius: CGFloat = 4
    private let controlStrokeWidth: CGFloat = 1.5
    private let hitTargetInset: CGFloat = 5
    private var presentationIsDirty = true

    init(textView: RichTextView) {
        self.textView = textView
    }

    func handleInsertText(_ value: Any, replacementRange: NSRange) -> Bool {
        guard let textView,
              let insertedText = (value as? NSAttributedString)?.string ?? (value as? String) else {
            return false
        }
        let selection = replacementRange.location == NSNotFound ? textView.selectedRange() : replacementRange
        guard selection.length == 0,
              let conversion = ListItemSyntax.conversion(
                  linePrefix: linePrefix(endingAt: selection.location),
                  insertedText: insertedText
              ) else {
            return false
        }

        let sourceRange = NSRange(
            location: selection.location - conversion.sourceLength,
            length: conversion.sourceLength
        )
        transaction(named: conversion.kind == .bullet ? "목록 생성" : "체크리스트 생성") {
            let attributes = attributesForListItem(level: 0)
            textView.requiredTextStorage.replaceCharacters(
                in: sourceRange,
                with: NSAttributedString(string: conversion.kind.prefix, attributes: attributes)
            )
            textView.setSelectedRange(NSRange(
                location: sourceRange.location + conversion.kind.prefix.utf16.count,
                length: 0
            ))
            applyTypingAttributes(level: 0)
        }
        return true
    }

    func insert(_ itemKind: ListItemKind) {
        guard let textView else { return }
        let selection = textView.selectedRange()
        let paragraph = paragraphRange(at: selection.location)
        transaction(named: itemKind == .bullet ? "목록 생성" : "체크리스트 생성") {
            let attributes = attributesForListItem(level: 0)
            textView.requiredTextStorage.insert(
                NSAttributedString(string: itemKind.prefix, attributes: attributes),
                at: paragraph.location
            )
            let styledRange = NSRange(
                location: paragraph.location,
                length: paragraph.length + itemKind.prefix.utf16.count
            )
            applyParagraphStyle(level: 0, to: styledRange)
            textView.setSelectedRange(NSRange(
                location: selection.location + itemKind.prefix.utf16.count,
                length: selection.length
            ))
            applyTypingAttributes(level: 0)
        }
    }

    func toggleChecklistOnCurrentLine() {
        guard let textView else { return }
        let selection = textView.selectedRange()
        let paragraph = paragraphRange(at: selection.location)
        let currentKind = kind(in: paragraph)
        let level = hierarchyLevel(at: paragraph.location)

        switch currentKind {
        case .uncheckedChecklist?, .checkedChecklist?:
            transaction(named: "체크리스트 해제") {
                textView.requiredTextStorage.deleteCharacters(in: NSRange(location: paragraph.location, length: 2))
                let remaining = NSRange(location: paragraph.location, length: max(0, paragraph.length - 2))
                applyPlainParagraphStyle(level: level, to: remaining)
                textView.setSelectedRange(NSRange(
                    location: max(paragraph.location, selection.location - 2),
                    length: selection.length
                ))
                applyPlainTypingAttributes(level: level)
            }
        case .bullet?:
            replacePrefix(in: paragraph, with: .uncheckedChecklist, actionName: "체크리스트 생성")
        case nil:
            insert(.uncheckedChecklist)
        }
    }

    func continueOrExitList() -> Bool {
        guard let textView else { return false }
        let selection = textView.selectedRange()
        let paragraph = paragraphRange(at: selection.location)
        guard let currentKind = kind(in: paragraph) else { return false }
        let content = contentText(in: paragraph)
        let level = hierarchyLevel(at: paragraph.location)

        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            transaction(named: "목록 종료") {
                textView.requiredTextStorage.deleteCharacters(in: NSRange(location: paragraph.location, length: 2))
                let remaining = NSRange(location: paragraph.location, length: max(0, paragraph.length - 2))
                applyPlainParagraphStyle(level: level, to: remaining)
                textView.setSelectedRange(NSRange(location: paragraph.location, length: 0))
                applyPlainTypingAttributes(level: level)
            }
            return true
        }

        let nextKind = currentKind.continuation
        transaction(named: "목록 이어쓰기") {
            let replacement = textView.selectedRange()
            let inserted = "\n\(nextKind.prefix)"
            textView.requiredTextStorage.replaceCharacters(
                in: replacement,
                with: NSAttributedString(string: inserted, attributes: attributesForListItem(level: level))
            )
            textView.setSelectedRange(NSRange(location: replacement.location + inserted.utf16.count, length: 0))
            applyParagraphStyle(level: level, to: paragraphRange(at: textView.selectedRange().location))
            applyTypingAttributes(level: level)
        }
        return true
    }

    func adjustHierarchy(by delta: Int) -> Bool {
        guard let textView else { return false }
        let paragraph = paragraphRange(at: textView.selectedRange().location)
        guard kind(in: paragraph) != nil else { return false }
        let current = hierarchyLevel(at: paragraph.location)
        let adjusted = ListItemSyntax.adjustedIndentLevel(current, by: delta)
        guard adjusted != current else { return true }

        transaction(named: delta > 0 ? "목록 들여쓰기" : "목록 내어쓰기") {
            applyParagraphStyle(level: adjusted, to: paragraph)
            applyTypingAttributes(level: adjusted)
        }
        return true
    }

    func deleteBackwardFromListIfNeeded() -> Bool {
        guard let textView else { return false }
        let selection = textView.selectedRange()
        guard selection.length == 0 else { return false }
        let paragraph = paragraphRange(at: selection.location)
        let line = (textView.string as NSString).substring(with: paragraph)
        let caretOffset = selection.location - paragraph.location
        guard ListItemSyntax.plainTextAfterRemovingPrefix(from: line, caretOffset: caretOffset) != nil else {
            return false
        }
        let level = hierarchyLevel(at: paragraph.location)
        transaction(named: "목록 해제") {
            textView.requiredTextStorage.deleteCharacters(in: NSRange(location: paragraph.location, length: 2))
            let remaining = NSRange(location: paragraph.location, length: max(0, paragraph.length - 2))
            applyPlainParagraphStyle(level: level, to: remaining)
            textView.setSelectedRange(NSRange(location: paragraph.location, length: 0))
            applyPlainTypingAttributes(level: level)
        }
        return true
    }

    func handleMouseDown(_ event: NSEvent) -> Bool {
        guard let textView else { return false }
        prepareForDrawing()
        let point = textView.convert(event.locationInWindow, from: nil)
        guard let paragraph = checklistParagraphs().first(where: {
            guard let rect = controlRect(forParagraphAt: $0.location) else { return false }
            return rect.insetBy(dx: -hitTargetInset, dy: -hitTargetInset).contains(point)
        }) else {
            return false
        }
        toggleChecklist(in: paragraph)
        return true
    }

    func textDidChange() {
        presentationIsDirty = true
        refreshTemporaryAttributes()
        invalidatePresentation()
    }

    @discardableResult
    func reloadPresentation() -> Bool {
        let migrated = migrateLegacyContentIfNeeded()
        presentationIsDirty = true
        refreshTemporaryAttributes()
        invalidatePresentation()
        updateTypingAttributesForSelection()
        return migrated
    }

    func prepareForDrawing() {
        refreshTemporaryAttributes()
    }

    func drawControls(in dirtyRect: NSRect) {
        guard let textView else { return }
        for paragraph in checklistParagraphs() {
            guard let box = controlRect(forParagraphAt: paragraph.location),
                  dirtyRect.intersects(box.insetBy(dx: -2, dy: -2)),
                  let itemKind = kind(in: paragraph) else {
                continue
            }

            textView.backgroundColor.setFill()
            box.insetBy(dx: -2, dy: -2).fill()

            let shape = NSBezierPath(roundedRect: box, xRadius: controlCornerRadius, yRadius: controlCornerRadius)
            shape.lineWidth = controlStrokeWidth
            accentColor.setStroke()
            if itemKind == .checkedChecklist {
                accentColor.setFill()
                shape.fill()
                NSColor(calibratedRed: 0.10, green: 0.06, blue: 0.06, alpha: 1).setStroke()
                let mark = NSBezierPath()
                mark.lineWidth = 1.8
                mark.lineCapStyle = .round
                mark.move(to: NSPoint(x: box.minX + 3.5, y: box.midY))
                mark.line(to: NSPoint(x: box.minX + 6.5, y: box.maxY - 3.8))
                mark.line(to: NSPoint(x: box.maxX - 3, y: box.minY + 3.8))
                mark.stroke()
            } else {
                shape.stroke()
            }
        }
    }

    func installCursorRects() {
        guard let textView else { return }
        prepareForDrawing()
        for paragraph in checklistParagraphs() {
            guard let rect = controlRect(forParagraphAt: paragraph.location) else { continue }
            textView.addCursorRect(
                rect.insetBy(dx: -hitTargetInset, dy: -hitTargetInset),
                cursor: .pointingHand
            )
        }
    }

    private func replacePrefix(in paragraph: NSRange, with itemKind: ListItemKind, actionName: String) {
        guard let textView else { return }
        let level = hierarchyLevel(at: paragraph.location)
        transaction(named: actionName) {
            textView.requiredTextStorage.replaceCharacters(
                in: NSRange(location: paragraph.location, length: 2),
                with: NSAttributedString(string: itemKind.prefix, attributes: attributesForListItem(level: level))
            )
            applyParagraphStyle(level: level, to: paragraph)
            applyTypingAttributes(level: level)
        }
    }

    private func toggleChecklist(in paragraph: NSRange) {
        guard let current = kind(in: paragraph), current.isChecklist else { return }
        let replacement: ListItemKind = current == .uncheckedChecklist ? .checkedChecklist : .uncheckedChecklist
        replacePrefix(
            in: paragraph,
            with: replacement,
            actionName: replacement == .checkedChecklist ? "항목 완료" : "항목 미완료"
        )
    }

    private func paragraphStyle(level: Int, isList: Bool) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let leadingIndent = CGFloat(level) * hierarchyIndent
        style.firstLineHeadIndent = leadingIndent
        style.headIndent = leadingIndent + (isList ? textIndent : 0)
        style.tabStops = isList
            ? [NSTextTab(textAlignment: .left, location: leadingIndent + textIndent)]
            : []
        style.lineSpacing = 4
        style.paragraphSpacing = isList ? 8 : 2
        return style
    }

    private func applyParagraphStyle(level: Int, to range: NSRange) {
        guard range.length > 0 else { return }
        guard let textView else { return }
        textView.requiredTextStorage.addAttribute(.paragraphStyle, value: paragraphStyle(level: level, isList: true), range: range)
    }

    private func applyPlainParagraphStyle(level: Int, to range: NSRange) {
        guard range.length > 0 else { return }
        guard let textView else { return }
        textView.requiredTextStorage.addAttribute(.paragraphStyle, value: paragraphStyle(level: level, isList: false), range: range)
    }

    private func attributesForListItem(level: Int) -> [NSAttributedString.Key: Any] {
        guard let textView else { return [.paragraphStyle: paragraphStyle(level: level, isList: true)] }
        var attributes = textView.typingAttributes
        attributes.removeValue(forKey: .link)
        attributes.removeValue(forKey: .toolTip)
        attributes.removeValue(forKey: .kern)
        attributes.removeValue(forKey: .strikethroughStyle)
        attributes.removeValue(forKey: .strikethroughColor)
        attributes[.foregroundColor] = textView.textColor ?? NSColor(calibratedWhite: 0.91, alpha: 1)
        attributes[.paragraphStyle] = paragraphStyle(level: level, isList: true)
        return attributes
    }

    private func applyTypingAttributes(level: Int) {
        textView?.typingAttributes = attributesForListItem(level: level)
    }

    private func applyPlainTypingAttributes(level: Int = 0) {
        guard let textView else { return }
        var attributes = attributesForListItem(level: 0)
        attributes[.paragraphStyle] = paragraphStyle(level: level, isList: false)
        textView.typingAttributes = attributes
    }

    private func updateTypingAttributesForSelection() {
        guard let textView else { return }
        let paragraph = paragraphRange(at: textView.selectedRange().location)
        if kind(in: paragraph) != nil {
            applyTypingAttributes(level: hierarchyLevel(at: paragraph.location))
        } else {
            applyPlainTypingAttributes(level: hierarchyLevel(at: paragraph.location))
        }
    }

    private func linePrefix(endingAt location: Int) -> String {
        guard let textView else { return "" }
        let source = textView.string as NSString
        let bounded = min(max(0, location), source.length)
        let line = source.lineRange(for: NSRange(location: bounded, length: 0))
        return source.substring(with: NSRange(location: line.location, length: bounded - line.location))
    }

    private func paragraphRange(at location: Int) -> NSRange {
        guard let textView else { return NSRange(location: 0, length: 0) }
        let source = textView.string as NSString
        let bounded = min(max(0, location), source.length)
        return source.paragraphRange(for: NSRange(location: bounded, length: 0))
    }

    private func kind(in paragraph: NSRange) -> ListItemKind? {
        guard let textView else { return nil }
        return ListItemSyntax.kind(of: (textView.string as NSString).substring(with: paragraph))
    }

    private func contentText(in paragraph: NSRange) -> String {
        guard let textView, paragraph.length >= 2 else { return "" }
        let source = textView.string as NSString
        let range = NSRange(location: paragraph.location + 2, length: paragraph.length - 2)
        return source.substring(with: range)
    }

    private func hierarchyLevel(at location: Int) -> Int {
        guard let textView else { return 0 }
        let storage = textView.requiredTextStorage
        guard storage.length > 0, location < storage.length else { return 0 }
        let style = storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
        let raw = Int(round((style?.firstLineHeadIndent ?? 0) / hierarchyIndent))
        return ListItemSyntax.adjustedIndentLevel(0, by: raw)
    }

    private func checklistParagraphs() -> [NSRange] {
        guard let textView, !textView.string.isEmpty else { return [] }
        let source = textView.string as NSString
        var result: [NSRange] = []
        var location = 0
        while location < source.length {
            let paragraph = source.paragraphRange(for: NSRange(location: location, length: 0))
            if kind(in: paragraph)?.isChecklist == true {
                result.append(paragraph)
            }
            location = NSMaxRange(paragraph)
        }
        return result
    }

    private func visibleContentRange(in paragraph: NSRange) -> NSRange? {
        guard let textView, paragraph.length > 2 else { return nil }
        let source = textView.string as NSString
        var end = NSMaxRange(paragraph)
        while end > paragraph.location {
            let value = source.character(at: end - 1)
            guard value == 10 || value == 13 else { break }
            end -= 1
        }
        let start = paragraph.location + 2
        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private func migrateLegacyContentIfNeeded() -> Bool {
        guard requiresLegacyMigration() else { return false }
        transaction(named: "체크리스트 데이터 정리") {
            migrateLegacyContent()
        }
        return true
    }

    private func requiresLegacyMigration() -> Bool {
        guard let textView else { return false }
        let storage = textView.requiredTextStorage
        guard storage.length > 0 else { return false }
        let source = storage.string as NSString
        var location = 0
        while location < source.length {
            let paragraph = source.paragraphRange(for: NSRange(location: location, length: 0))
            let line = source.substring(with: paragraph)
            guard line.hasPrefix("☐") || line.hasPrefix("☑") else {
                location = NSMaxRange(paragraph)
                continue
            }
            if ListItemSyntax.kind(of: line)?.isChecklist != true { return true }
            if !hasCanonicalParagraphStyle(at: paragraph.location) { return true }
            var foundLegacyAttribute = false
            storage.enumerateAttributes(in: paragraph) { attributes, _, stop in
                if let link = attributes[.link] as? URL, link.scheme == "sticky-notes-checklist" {
                    foundLegacyAttribute = true
                }
                if attributes[.toolTip] != nil || attributes[.kern] != nil || attributes[.strikethroughStyle] != nil || attributes[.strikethroughColor] != nil {
                    foundLegacyAttribute = true
                }
                if let color = attributes[.foregroundColor] as? NSColor,
                   color.alphaComponent < 0.01 || isLegacyCompletedColor(color) {
                    foundLegacyAttribute = true
                }
                if foundLegacyAttribute { stop.pointee = true }
            }
            if foundLegacyAttribute { return true }
            location = NSMaxRange(paragraph)
        }
        return false
    }

    private func migrateLegacyContent() {
        guard let textView else { return }
        let storage = textView.requiredTextStorage
        var location = 0
        while location < storage.length {
            var source = storage.string as NSString
            var paragraph = source.paragraphRange(for: NSRange(location: location, length: 0))
            var line = source.substring(with: paragraph)
            guard line.hasPrefix("☐") || line.hasPrefix("☑") else {
                location = NSMaxRange(paragraph)
                continue
            }

            if ListItemSyntax.kind(of: line)?.isChecklist != true {
                let separator = paragraph.location + 1
                let attributes = storage.attributes(at: paragraph.location, effectiveRange: nil)
                if paragraph.length > 1, source.character(at: separator) == 32 {
                    storage.replaceCharacters(
                        in: NSRange(location: separator, length: 1),
                        with: NSAttributedString(string: "\t", attributes: attributes)
                    )
                } else {
                    storage.insert(NSAttributedString(string: "\t", attributes: attributes), at: separator)
                }
                source = storage.string as NSString
                paragraph = source.paragraphRange(for: NSRange(location: paragraph.location, length: 0))
                line = source.substring(with: paragraph)
            }

            let level = hierarchyLevel(at: paragraph.location)
            applyParagraphStyle(level: level, to: paragraph)
            storage.removeAttribute(.toolTip, range: paragraph)
            storage.removeAttribute(.kern, range: paragraph)
            storage.removeAttribute(.strikethroughStyle, range: paragraph)
            storage.removeAttribute(.strikethroughColor, range: paragraph)

            var stickyLinks: [NSRange] = []
            storage.enumerateAttribute(.link, in: paragraph) { value, range, _ in
                if let url = value as? URL, url.scheme == "sticky-notes-checklist" {
                    stickyLinks.append(range)
                }
            }
            for range in stickyLinks {
                storage.removeAttribute(.link, range: range)
            }

            var legacyColorRanges: [NSRange] = []
            storage.enumerateAttribute(.foregroundColor, in: paragraph) { value, range, _ in
                guard let color = value as? NSColor else { return }
                if color.alphaComponent < 0.01 || isLegacyCompletedColor(color) {
                    legacyColorRanges.append(range)
                }
            }
            let normalColor = textView.textColor ?? NSColor(calibratedWhite: 0.91, alpha: 1)
            for range in legacyColorRanges {
                storage.addAttribute(.foregroundColor, value: normalColor, range: range)
            }

            let controlLength = min(2, paragraph.length)
            if controlLength > 0 {
                let font = textView.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 17)
                storage.addAttribute(
                    .font,
                    value: font,
                    range: NSRange(location: paragraph.location, length: controlLength)
                )
            }
            location = NSMaxRange(paragraph)
        }
    }

    private func hasCanonicalParagraphStyle(at location: Int) -> Bool {
        guard let textView else { return false }
        let storage = textView.requiredTextStorage
        guard location < storage.length,
              let style = storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle else {
            return false
        }
        let level = ListItemSyntax.adjustedIndentLevel(0, by: Int(round(style.firstLineHeadIndent / hierarchyIndent)))
        let expected = paragraphStyle(level: level, isList: true)
        return abs(style.firstLineHeadIndent - expected.firstLineHeadIndent) < 0.01
            && abs(style.headIndent - expected.headIndent) < 0.01
            && abs(style.lineSpacing - expected.lineSpacing) < 0.01
            && abs(style.paragraphSpacing - expected.paragraphSpacing) < 0.01
    }

    private func isLegacyCompletedColor(_ color: NSColor) -> Bool {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return false }
        return abs(rgb.redComponent - 0.56) < 0.02
            && abs(rgb.greenComponent - 0.56) < 0.02
            && abs(rgb.blueComponent - 0.56) < 0.02
            && rgb.alphaComponent > 0.98
    }

    private func refreshTemporaryAttributes() {
        guard presentationIsDirty, let textView else { return }
        let layoutManager = textView.requiredLayoutManager
        let fullRange = NSRange(location: 0, length: textView.requiredTextStorage.length)
        if fullRange.length > 0 {
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.strikethroughStyle, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.strikethroughColor, forCharacterRange: fullRange)
        }
        for paragraph in checklistParagraphs() {
            layoutManager.addTemporaryAttribute(
                .foregroundColor,
                value: NSColor.clear,
                forCharacterRange: NSRange(location: paragraph.location, length: 1)
            )
            if kind(in: paragraph) == .checkedChecklist,
               let contentRange = visibleContentRange(in: paragraph) {
                layoutManager.addTemporaryAttributes([
                    .foregroundColor: NSColor(calibratedWhite: 0.56, alpha: 1),
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: accentColor.withAlphaComponent(0.7),
                ], forCharacterRange: contentRange)
            }
        }
        presentationIsDirty = false
    }

    private func controlRect(forParagraphAt location: Int) -> NSRect? {
        guard let textView, location < textView.requiredTextStorage.length else { return nil }
        let layoutManager = textView.requiredLayoutManager
        let textContainer = textView.requiredTextContainer
        layoutManager.ensureLayout(for: textContainer)
        let glyph = layoutManager.glyphIndexForCharacter(at: location)
        var glyphBounds = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyph, length: 1),
            in: textContainer
        )
        glyphBounds.origin.x += textView.textContainerOrigin.x
        let line = layoutManager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
        let lineMidY = line.midY + textView.textContainerOrigin.y
        return NSRect(
            x: glyphBounds.minX + 1,
            y: lineMidY - controlSize / 2,
            width: controlSize,
            height: controlSize
        )
    }

    private func invalidatePresentation() {
        guard let textView else { return }
        let layoutManager = textView.requiredLayoutManager
        let fullRange = NSRange(location: 0, length: textView.requiredTextStorage.length)
        if fullRange.length > 0 {
            layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
            layoutManager.invalidateDisplay(forCharacterRange: fullRange)
        }
        layoutManager.ensureLayout(for: textView.requiredTextContainer)
        textView.needsDisplay = true
        textView.window?.invalidateCursorRects(for: textView)
    }

    private struct Snapshot {
        let content: NSAttributedString
        let selection: NSRange
    }

    private func snapshot() -> Snapshot? {
        guard let textView else { return nil }
        return Snapshot(
            content: NSAttributedString(attributedString: textView.attributedString()),
            selection: textView.selectedRange()
        )
    }

    private func transaction(named actionName: String, mutation: () -> Void) {
        guard let textView, let before = snapshot() else { return }
        textView.breakUndoCoalescing()
        mutation()
        textView.undoManager?.registerUndo(withTarget: self) { editor in
            editor.restore(before, actionName: actionName)
        }
        textView.undoManager?.setActionName(actionName)
        textView.didChangeText()
        updateTypingAttributesForSelection()
    }

    private func restore(_ state: Snapshot, actionName: String) {
        guard let textView, let inverse = snapshot() else { return }
        textView.undoManager?.registerUndo(withTarget: self) { editor in
            editor.restore(inverse, actionName: actionName)
        }
        textView.undoManager?.setActionName(actionName)
        textView.requiredTextStorage.setAttributedString(state.content)
        let storageLength = textView.requiredTextStorage.length
        let location = min(state.selection.location, storageLength)
        let length = min(state.selection.length, max(0, storageLength - location))
        textView.setSelectedRange(NSRange(location: location, length: length))
        textView.didChangeText()
        updateTypingAttributesForSelection()
    }
}

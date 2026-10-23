import Foundation

/// One line of pasted Markdown, already mapped onto the editor's own list kinds.
public struct PastedLine: Equatable, Sendable {
    public let text: String
    public let kind: ListItemKind?
    public let level: Int
    public let isHeading: Bool

    public init(text: String, kind: ListItemKind?, level: Int, isHeading: Bool) {
        self.text = text
        self.kind = kind
        self.level = level
        self.isHeading = isHeading
    }
}

/// Reads the task lists people keep in Markdown editors such as Obsidian
/// (`- [ ]`, `- [x]`, `-`, `1.`, `#### Heading`) so a paste lands as checkboxes and bold
/// section names instead of raw syntax.
public enum MarkdownPaste {
    /// Nil when the text carries no list or heading syntax, so ordinary text pastes unchanged.
    /// Blank lines and empty list items - the unfilled `- [ ]` rows a template leaves - are dropped.
    public static func lines(from text: String) -> [PastedLine]? {
        var result: [PastedLine] = []
        var sawMarkdown = false
        var levelAbove: Int?

        for rawLine in text.components(separatedBy: .newlines) {
            let indentation = rawLine.prefix { $0 == "\t" || $0 == " " }
            let body = rawLine.dropFirst(indentation.count).trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty else { continue }

            if let heading = heading(in: body) {
                sawMarkdown = true
                levelAbove = nil
                guard !heading.isEmpty else { continue }
                result.append(PastedLine(text: heading, kind: nil, level: 0, isHeading: true))
                continue
            }
            guard let (kind, content) = listItem(in: body) else {
                levelAbove = nil
                result.append(PastedLine(text: body, kind: nil, level: 0, isHeading: false))
                continue
            }
            sawMarkdown = true
            guard !content.isEmpty else { continue }
            let tabs = indentation.filter { $0 == "\t" }.count
            let spaces = indentation.count - tabs
            let level = ListItemSyntax.indentLevel(0, adjustedBy: tabs + spaces / 2, levelAbove: levelAbove)
            levelAbove = level
            result.append(PastedLine(text: content, kind: kind, level: level, isHeading: false))
        }
        return sawMarkdown ? result : nil
    }

    private static func heading(in body: String) -> String? {
        let hashes = body.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = body.dropFirst(hashes.count)
        guard rest.isEmpty || rest.first == " " else { return nil }
        return rest.trimmingCharacters(in: .whitespaces)
    }

    private static func listItem(in body: String) -> (ListItemKind, String)? {
        if let marker = body.first, "-*+".contains(marker), body.dropFirst().first == " " {
            let rest = body.dropFirst(2)
            for (box, kind) in [("[ ]", ListItemKind.uncheckedChecklist), ("[x]", .checkedChecklist), ("[X]", .checkedChecklist)]
            where rest.hasPrefix(box) && (rest.count == box.count || rest.dropFirst(box.count).first == " ") {
                return (kind, rest.dropFirst(box.count).trimmingCharacters(in: .whitespaces))
            }
            return (.bullet, rest.trimmingCharacters(in: .whitespaces))
        }
        let digits = body.prefix { $0.isASCII && $0.isNumber }
        if !digits.isEmpty, let number = Int(digits), number > 0 {
            let rest = body.dropFirst(digits.count)
            if rest.hasPrefix(". ") {
                return (.ordered(number), rest.dropFirst(2).trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }
}

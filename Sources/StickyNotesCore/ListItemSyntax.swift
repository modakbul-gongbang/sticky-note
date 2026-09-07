import Foundation

public enum ListItemKind: Equatable, Sendable {
    case uncheckedChecklist
    case checkedChecklist
    case bullet

    public var prefix: String {
        switch self {
        case .uncheckedChecklist: "☐\t"
        case .checkedChecklist: "☑\t"
        case .bullet: "• "
        }
    }

    public var continuation: ListItemKind {
        switch self {
        case .uncheckedChecklist, .checkedChecklist: .uncheckedChecklist
        case .bullet: .bullet
        }
    }

    public var isChecklist: Bool {
        self != .bullet
    }
}

public struct ListItemConversion: Equatable, Sendable {
    public let kind: ListItemKind
    public let sourceLength: Int

    public init(kind: ListItemKind, sourceLength: Int) {
        self.kind = kind
        self.sourceLength = sourceLength
    }
}

public enum ListItemSyntax {
    public static let maximumIndentLevel = 8

    public static func conversion(linePrefix: String, insertedText: String) -> ListItemConversion? {
        guard insertedText == " " else { return nil }
        switch linePrefix {
        case "[]": return ListItemConversion(kind: .uncheckedChecklist, sourceLength: 2)
        case "-": return ListItemConversion(kind: .bullet, sourceLength: 1)
        default: return nil
        }
    }

    public static func kind(of line: String) -> ListItemKind? {
        if line.hasPrefix(ListItemKind.uncheckedChecklist.prefix) { return .uncheckedChecklist }
        if line.hasPrefix(ListItemKind.checkedChecklist.prefix) { return .checkedChecklist }
        if line.hasPrefix(ListItemKind.bullet.prefix) { return .bullet }
        return nil
    }

    public static func plainTextAfterRemovingPrefix(from line: String, caretOffset: Int) -> String? {
        guard kind(of: line) != nil, caretOffset == 2 else { return nil }
        return String(line.dropFirst(2))
    }

    public static func adjustedIndentLevel(_ current: Int, by delta: Int) -> Int {
        min(maximumIndentLevel, max(0, current + delta))
    }
}

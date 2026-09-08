import Foundation

public enum ListItemKind: Equatable, Sendable {
    case uncheckedChecklist
    case checkedChecklist
    case bullet
    case ordered(Int)

    public var prefix: String {
        switch self {
        case .uncheckedChecklist: "☐\t"
        case .checkedChecklist: "☑\t"
        case .bullet: "• "
        case let .ordered(number): "\(number).\t"
        }
    }

    public var continuation: ListItemKind {
        switch self {
        case .uncheckedChecklist, .checkedChecklist: .uncheckedChecklist
        case .bullet: .bullet
        case let .ordered(number): .ordered(number + 1)
        }
    }

    public var isChecklist: Bool {
        switch self {
        case .uncheckedChecklist, .checkedChecklist: true
        case .bullet, .ordered: false
        }
    }

}

public struct ListItemMatch: Equatable, Sendable {
    public let kind: ListItemKind
    public let prefixLength: Int

    public init(kind: ListItemKind, prefixLength: Int) {
        self.kind = kind
        self.prefixLength = prefixLength
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
    public static let maximumIndentLevel = 1

    public static func conversion(linePrefix: String, insertedText: String) -> ListItemConversion? {
        guard insertedText == " " else { return nil }
        switch linePrefix {
        case "[]": return ListItemConversion(kind: .uncheckedChecklist, sourceLength: 2)
        case "-": return ListItemConversion(kind: .bullet, sourceLength: 1)
        default:
            guard linePrefix.last == ".",
                  let number = Int(linePrefix.dropLast()),
                  number > 0 else {
                return nil
            }
            return ListItemConversion(kind: .ordered(number), sourceLength: linePrefix.utf16.count)
        }
    }

    public static func kind(of line: String) -> ListItemKind? {
        match(in: line)?.kind
    }

    public static func match(in line: String) -> ListItemMatch? {
        if line.hasPrefix(ListItemKind.uncheckedChecklist.prefix) {
            return ListItemMatch(kind: .uncheckedChecklist, prefixLength: 2)
        }
        if line.hasPrefix(ListItemKind.checkedChecklist.prefix) {
            return ListItemMatch(kind: .checkedChecklist, prefixLength: 2)
        }
        if line.hasPrefix(ListItemKind.bullet.prefix) {
            return ListItemMatch(kind: .bullet, prefixLength: 2)
        }

        let utf16 = Array(line.utf16)
        var index = 0
        while index < utf16.count, utf16[index] >= 48, utf16[index] <= 57 {
            index += 1
        }
        guard index > 0,
              index + 1 < utf16.count,
              utf16[index] == 46,
              utf16[index + 1] == 9,
              let number = Int(String(line.prefix(index))),
              number > 0 else {
            return nil
        }
        return ListItemMatch(kind: .ordered(number), prefixLength: index + 2)
    }

    public static func plainTextAfterRemovingPrefix(from line: String, caretOffset: Int) -> String? {
        guard let match = match(in: line), caretOffset == match.prefixLength else { return nil }
        return String(decoding: line.utf16.dropFirst(match.prefixLength), as: UTF16.self)
    }

    public static func adjustedIndentLevel(_ current: Int, by delta: Int) -> Int {
        min(maximumIndentLevel, max(0, current + delta))
    }
}

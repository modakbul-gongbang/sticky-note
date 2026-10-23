import AppKit
import Foundation

public struct NoteMetadata: Codable, Equatable, Identifiable {
    public let id: UUID
    public var title: String
    public var searchText: String
    public var modifiedAt: Date
    public var isTrashed: Bool
    public var storageName: String
    /// The local day (`yyyy-MM-dd`) whose to-do page this note is; nil for an ordinary note.
    /// Optional so an index written before daily pages existed still decodes.
    public var dailyDay: String?

    public init(
        id: UUID,
        title: String,
        searchText: String,
        modifiedAt: Date,
        isTrashed: Bool,
        storageName: String,
        dailyDay: String? = nil
    ) {
        self.id = id
        self.title = title
        self.searchText = searchText
        self.modifiedAt = modifiedAt
        self.isTrashed = isTrashed
        self.storageName = storageName
        self.dailyDay = dailyDay
    }
}

public struct StoredNote {
    public let metadata: NoteMetadata
    public let content: NSAttributedString

    public init(metadata: NoteMetadata, content: NSAttributedString) {
        self.metadata = metadata
        self.content = content
    }
}

public enum NoteRepositoryError: LocalizedError {
    case invalidPackage(UUID)
    case saveFailed(String)
    case permanentDeleteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPackage(let id):
            return "노트 \(id.uuidString)의 저장 파일을 열 수 없습니다."
        case .saveFailed(let reason):
            return "저장하지 못했습니다. 이전 저장본은 유지됩니다. (\(reason))"
        case .permanentDeleteFailed(let reason):
            return "휴지통을 비우지 못했습니다. 삭제 전 상태로 복원했습니다. (\(reason))"
        }
    }
}

public enum NoteContent {
    public static func isEmpty(_ content: NSAttributedString) -> Bool {
        let hasText = !content.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        var hasAttachment = false
        content.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: content.length)
        ) { value, _, stop in
            if value != nil {
                hasAttachment = true
                stop.pointee = true
            }
        }
        return !hasText && !hasAttachment
    }

    /// True when every line is blank or a list marker with nothing after it - a page that
    /// holds only the empty checkbox it was opened with.
    public static func isBlankList(_ content: NSAttributedString, ignoring headings: Set<String> = []) -> Bool {
        guard isEmpty(content) == false else { return true }
        var hasAttachment = false
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length)) { value, _, stop in
            if value != nil { hasAttachment = true; stop.pointee = true }
        }
        guard !hasAttachment else { return false }
        return content.string.components(separatedBy: .newlines).allSatisfy { line in
            let body = ListItemSyntax.match(in: line).map { String(line.utf16.dropFirst($0.prefixLength)) ?? "" } ?? line
            let trimmed = body.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || headings.contains(trimmed)
        }
    }

    public static func title(from content: NSAttributedString) -> String {
        let firstLine = content.string
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "제목 없음" : String(firstLine.prefix(80))
    }
}

public struct TaskCount: Equatable, Sendable {
    public let total: Int
    public let done: Int

    public init(total: Int, done: Int) {
        self.total = total
        self.done = done
    }

    /// Counts checklist rows that carry text; an empty checkbox is a slot, not a task.
    public init(text: String) {
        var total = 0
        var done = 0
        for line in text.components(separatedBy: .newlines) {
            guard let match = ListItemSyntax.match(in: line), match.kind.isChecklist,
                  !String(decoding: line.utf16.dropFirst(match.prefixLength), as: UTF16.self)
                      .trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            total += 1
            if match.kind == .checkedChecklist { done += 1 }
        }
        self.init(total: total, done: done)
    }
}

/// A daily to-do page is an ordinary note keyed by its local day; the key, not the editable
/// first line, is what finds today's page again.
public enum DailyNote {
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            preconditionFailure("Gregorian date components are always present")
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// The Monday-to-Sunday week holding `date`, the same span as an ISO weekly note.
    public static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offsetFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -offsetFromMonday, to: day) else {
            preconditionFailure("Gregorian day arithmetic always succeeds")
        }
        return (0..<7).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: monday) else {
                preconditionFailure("Gregorian day arithmetic always succeeds")
            }
            return date
        }
    }

    /// Six Monday-first weeks covering the month of `date`, padded with the neighbouring
    /// months' days so every month draws as the same grid.
    public static func monthGrid(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            preconditionFailure("Gregorian month components are always present")
        }
        let monday = week(containing: first, calendar: calendar)[0]
        return (0..<42).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else {
                preconditionFailure("Gregorian day arithmetic always succeeds")
            }
            return day
        }
    }

    /// A fresh day page: a tasks heading with one empty checkbox, then a memo heading with an
    /// empty line under it. The headings are ordinary text the user may rename or delete.
    public static let templateHeadings: Set<String> = ["할 일", "메모"]
    public static let template: [PastedLine] = [
        PastedLine(text: "할 일", kind: nil, level: 0, isHeading: true),
        PastedLine(text: "", kind: .uncheckedChecklist, level: 0, isHeading: false),
        PastedLine(text: "메모", kind: nil, level: 0, isHeading: true),
        PastedLine(text: "", kind: nil, level: 0, isHeading: false),
    ]

    public static func title(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }
}

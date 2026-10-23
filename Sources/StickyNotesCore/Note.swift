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

    public static func title(from content: NSAttributedString) -> String {
        let firstLine = content.string
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "제목 없음" : String(firstLine.prefix(80))
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

    public static func title(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }
}

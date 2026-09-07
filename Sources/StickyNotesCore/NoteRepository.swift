import AppKit
import Foundation

public final class NoteRepository {
    public typealias BeforeIndexCommit = () throws -> Void

    public let rootURL: URL
    private let notesURL: URL
    private let indexURL: URL
    private let fileManager: FileManager
    private let beforeIndexCommit: BeforeIndexCommit
    private var metadata: [NoteMetadata] = []

    public init(
        rootURL: URL? = nil,
        fileManager: FileManager = .default,
        beforeIndexCommit: @escaping BeforeIndexCommit = {}
    ) throws {
        self.fileManager = fileManager
        self.beforeIndexCommit = beforeIndexCommit
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.rootURL = support.appendingPathComponent("Sticky Notes", isDirectory: true)
        }
        notesURL = self.rootURL.appendingPathComponent("Notes", isDirectory: true)
        indexURL = self.rootURL.appendingPathComponent("index.json")
        try fileManager.createDirectory(at: notesURL, withIntermediateDirectories: true)
        try loadIndex()
    }

    public func list(includeTrashed: Bool = false, query: String = "") -> [NoteMetadata] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return metadata
            .filter { $0.isTrashed == includeTrashed }
            .filter { note in
                guard !normalizedQuery.isEmpty else { return true }
                let haystack = "\(note.title)\n\(note.searchText)"
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                return haystack.contains(normalizedQuery)
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public func load(id: UUID) throws -> StoredNote {
        guard let item = metadata.first(where: { $0.id == id }) else {
            throw NoteRepositoryError.invalidPackage(id)
        }
        let packageURL = notesURL.appendingPathComponent(item.storageName, isDirectory: true)
        guard fileManager.fileExists(atPath: packageURL.path) else {
            throw NoteRepositoryError.invalidPackage(id)
        }
        let content = try NSAttributedString(
            url: packageURL,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        )
        return StoredNote(metadata: item, content: content)
    }

    @discardableResult
    public func save(
        id: UUID,
        content: NSAttributedString,
        modifiedAt: Date = Date()
    ) throws -> NoteMetadata? {
        if NoteContent.isEmpty(content) {
            try removeEmptyDraft(id: id)
            return nil
        }

        let previousMetadata = metadata
        let previousItem = metadata.first(where: { $0.id == id })
        let newStorageName = "\(id.uuidString)-\(UUID().uuidString).rtfd"
        let destination = notesURL.appendingPathComponent(newStorageName, isDirectory: true)

        do {
            let wrapper = try content.fileWrapper(
                from: NSRange(location: 0, length: content.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            try wrapper.write(to: destination, options: [.atomic, .withNameUpdating], originalContentsURL: nil)

            let item = NoteMetadata(
                id: id,
                title: NoteContent.title(from: content),
                searchText: content.string,
                modifiedAt: modifiedAt,
                isTrashed: previousItem?.isTrashed ?? false,
                storageName: newStorageName
            )
            metadata.removeAll { $0.id == id }
            metadata.append(item)
            try beforeIndexCommit()
            try writeIndex()

            if let previousItem, previousItem.storageName != newStorageName {
                try? fileManager.removeItem(at: notesURL.appendingPathComponent(previousItem.storageName))
            }
            return item
        } catch {
            metadata = previousMetadata
            try? fileManager.removeItem(at: destination)
            throw NoteRepositoryError.saveFailed(error.localizedDescription)
        }
    }

    public func moveToTrash(id: UUID, modifiedAt: Date = Date()) throws {
        try update(id: id) {
            $0.isTrashed = true
            $0.modifiedAt = modifiedAt
        }
    }

    public func restore(id: UUID, modifiedAt: Date = Date()) throws {
        try update(id: id) {
            $0.isTrashed = false
            $0.modifiedAt = modifiedAt
        }
    }

    @discardableResult
    public func emptyTrash(confirmed: Bool) throws -> Int {
        guard confirmed else { return 0 }
        let doomed = metadata.filter(\.isTrashed)
        guard !doomed.isEmpty else { return 0 }

        let previousMetadata = metadata
        let staging = rootURL.appendingPathComponent(".EmptyTrash-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            for item in doomed {
                let source = notesURL.appendingPathComponent(item.storageName)
                if fileManager.fileExists(atPath: source.path) {
                    try fileManager.moveItem(at: source, to: staging.appendingPathComponent(item.storageName))
                }
            }
            metadata.removeAll( where: \.isTrashed)
            try beforeIndexCommit()
            try writeIndex()
            try fileManager.removeItem(at: staging)
            return doomed.count
        } catch {
            metadata = previousMetadata
            if let staged = try? fileManager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) {
                for file in staged {
                    let destination = notesURL.appendingPathComponent(file.lastPathComponent)
                    if !fileManager.fileExists(atPath: destination.path) {
                        try? fileManager.moveItem(at: file, to: destination)
                    }
                }
            }
            try? fileManager.removeItem(at: staging)
            throw NoteRepositoryError.permanentDeleteFailed(error.localizedDescription)
        }
    }

    private func removeEmptyDraft(id: UUID) throws {
        guard let item = metadata.first(where: { $0.id == id }) else { return }
        let previousMetadata = metadata
        metadata.removeAll { $0.id == id }
        do {
            try beforeIndexCommit()
            try writeIndex()
            try? fileManager.removeItem(at: notesURL.appendingPathComponent(item.storageName))
        } catch {
            metadata = previousMetadata
            throw NoteRepositoryError.saveFailed(error.localizedDescription)
        }
    }

    private func update(id: UUID, mutation: (inout NoteMetadata) -> Void) throws {
        guard let index = metadata.firstIndex(where: { $0.id == id }) else {
            throw NoteRepositoryError.invalidPackage(id)
        }
        let previous = metadata
        mutation(&metadata[index])
        do {
            try beforeIndexCommit()
            try writeIndex()
        } catch {
            metadata = previous
            throw NoteRepositoryError.saveFailed(error.localizedDescription)
        }
    }

    private func loadIndex() throws {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            metadata = []
            return
        }
        let data = try Data(contentsOf: indexURL)
        metadata = try JSONDecoder.stickyNotes.decode([NoteMetadata].self, from: data)
    }

    private func writeIndex() throws {
        let data = try JSONEncoder.stickyNotes.encode(metadata)
        try data.write(to: indexURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var stickyNotes: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var stickyNotes: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

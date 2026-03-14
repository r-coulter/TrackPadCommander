import Foundation

enum LogEntryKind: String, Codable, CaseIterable {
    case system
    case gesture
    case action
}

struct LogEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var timestamp: Date
    var kind: LogEntryKind
    var title: String
    var details: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: LogEntryKind,
        title: String,
        details: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.title = title
        self.details = details
    }
}

final class LogStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let maxEntries: Int

    let logURL: URL

    init(fileManager: FileManager = .default, maxEntries: Int = 250, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.maxEntries = maxEntries
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        let baseURL = (baseDirectoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!)
            .appendingPathComponent("TrackpadCommander/logs", isDirectory: true)
        logURL = baseURL.appendingPathComponent("recent-log.json")
    }

    func loadEntries() -> [LogEntry] {
        guard fileManager.fileExists(atPath: logURL.path),
              let data = try? Data(contentsOf: logURL),
              let entries = try? decoder.decode([LogEntry].self, from: data) else {
            return []
        }

        return entries
    }

    @discardableResult
    func append(_ entry: LogEntry, currentEntries: [LogEntry]) -> [LogEntry] {
        var updated = currentEntries
        updated.insert(entry, at: 0)
        if updated.count > maxEntries {
            updated.removeLast(updated.count - maxEntries)
        }

        do {
            try ensureParentDirectory()
            let data = try encoder.encode(updated)
            try data.write(to: logURL, options: .atomic)
        } catch {
            // Logging failures should not break gesture execution.
        }

        return updated
    }

    func exportLogs(to destinationURL: URL, entries: [LogEntry]) throws {
        try ensureParentDirectory()
        let data = try encoder.encode(entries)
        try data.write(to: destinationURL, options: .atomic)
    }

    private func ensureParentDirectory() throws {
        try fileManager.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}

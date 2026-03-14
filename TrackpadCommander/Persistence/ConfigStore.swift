import Foundation

final class ConfigStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    let configURL: URL

    init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        let baseURL = (baseDirectoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!)
            .appendingPathComponent("TrackpadCommander", isDirectory: true)
        configURL = baseURL.appendingPathComponent("config.json")
    }

    func load() throws -> AppConfig {
        if !fileManager.fileExists(atPath: configURL.path) {
            try save(AppConfig.default)
            return .default
        }

        let data = try Data(contentsOf: configURL)
        return try decoder.decode(AppConfig.self, from: data)
    }

    func save(_ config: AppConfig) throws {
        try ensureParentDirectory()
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    private func ensureParentDirectory() throws {
        try fileManager.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}

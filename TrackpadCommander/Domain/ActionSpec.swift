import Foundation

enum ActionKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case shell
    case openApp
    case openPath
    case openURL
    case appleScript

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shell: "Shell Command"
        case .openApp: "Open App"
        case .openPath: "Open File or Folder"
        case .openURL: "Open URL"
        case .appleScript: "AppleScript"
        }
    }
}

struct ActionSpec: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: ActionKind
    var payload: String
    var timeoutMs: Int
    var debounceMs: Int
    var notifyOnFailure: Bool

    init(
        id: UUID = UUID(),
        kind: ActionKind = .shell,
        payload: String = "",
        timeoutMs: Int = 3_000,
        debounceMs: Int = 250,
        notifyOnFailure: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.payload = payload
        self.timeoutMs = timeoutMs
        self.debounceMs = debounceMs
        self.notifyOnFailure = notifyOnFailure
    }
}

import Foundation

struct StoredConflictRestore: Codable, Identifiable, Hashable {
    var id: String { "\(domain)|\(key)" }
    var domain: String
    var key: String
    var value: Int?
}

struct AppConfig: Codable, Hashable {
    var bindings: [Binding]
    var storedConflictRestores: [StoredConflictRestore]
    var launchAtLogin: Bool
    var loggingEnabled: Bool
    var showNotifications: Bool

    static let `default` = AppConfig(
        bindings: [
            Binding(
                gesture: .threeFingerTap,
                action: ActionSpec(
                    kind: .shell,
                    payload: "open -a Terminal",
                    timeoutMs: 3_000,
                    debounceMs: 300,
                    notifyOnFailure: true
                )
            )
        ],
        storedConflictRestores: [],
        launchAtLogin: false,
        loggingEnabled: true,
        showNotifications: false
    )
}

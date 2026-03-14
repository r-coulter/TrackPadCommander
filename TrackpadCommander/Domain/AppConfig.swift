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
    var threeFingerTapSensitivity: Double
    var gestureDiagnosticsEnabled: Bool

    init(
        bindings: [Binding],
        storedConflictRestores: [StoredConflictRestore],
        launchAtLogin: Bool,
        loggingEnabled: Bool,
        showNotifications: Bool,
        threeFingerTapSensitivity: Double,
        gestureDiagnosticsEnabled: Bool
    ) {
        self.bindings = bindings
        self.storedConflictRestores = storedConflictRestores
        self.launchAtLogin = launchAtLogin
        self.loggingEnabled = loggingEnabled
        self.showNotifications = showNotifications
        self.threeFingerTapSensitivity = threeFingerTapSensitivity
        self.gestureDiagnosticsEnabled = gestureDiagnosticsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bindings = try container.decode([Binding].self, forKey: .bindings)
        storedConflictRestores = try container.decodeIfPresent([StoredConflictRestore].self, forKey: .storedConflictRestores) ?? []
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        loggingEnabled = try container.decodeIfPresent(Bool.self, forKey: .loggingEnabled) ?? true
        showNotifications = try container.decodeIfPresent(Bool.self, forKey: .showNotifications) ?? false
        threeFingerTapSensitivity = try container.decodeIfPresent(Double.self, forKey: .threeFingerTapSensitivity) ?? 1.0
        gestureDiagnosticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .gestureDiagnosticsEnabled) ?? false
    }

    static let `default` = AppConfig(
        bindings: [
            Binding(
                gesture: .threeFingerTap,
                action: ActionSpec(
                    kind: .middleClick,
                    payload: "",
                    timeoutMs: 500,
                    debounceMs: 300,
                    notifyOnFailure: true
                )
            )
        ],
        storedConflictRestores: [],
        launchAtLogin: false,
        loggingEnabled: true,
        showNotifications: false,
        threeFingerTapSensitivity: 1.0,
        gestureDiagnosticsEnabled: false
    )
}

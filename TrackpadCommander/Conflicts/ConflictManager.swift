import AppKit
import Foundation

struct ConflictRule: Codable, Hashable, Identifiable {
    var id: String { "\(gesture.rawValue)|\(defaultsDomain)|\(defaultsKey)" }
    var gesture: GestureID
    var defaultsDomain: String
    var defaultsKey: String
    var overrideValue: Int
    var restoreValue: Int?
}

struct ConflictStatus: Identifiable, Hashable {
    var id: String { "\(gesture.rawValue)|\(defaultsDomain)|\(defaultsKey)" }
    var gesture: GestureID
    var defaultsDomain: String
    var defaultsKey: String
    var currentValue: Int?
    var targetValue: Int
    var isRequired: Bool
    var isApplied: Bool
    var manualVerificationRequired: Bool
}

struct ConflictSyncResult {
    var statuses: [ConflictStatus]
    var changedKeys: [String]
    var message: String?
}

final class ConflictManager {
    static let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func sync(bindings: [Binding], storedRestores: inout [StoredConflictRestore]) -> ConflictSyncResult {
        let activeGestures = Set(bindings.filter(\.isEnabled).map(\.gesture))
        let requiredRules = Self.rules.filter { activeGestures.contains($0.gesture) }
        let requiredKeys = Set(requiredRules.map { Self.restoreKey(domain: $0.defaultsDomain, key: $0.defaultsKey) })
        var changedKeys: [String] = []

        for rule in requiredRules {
            let restoreKey = Self.restoreKey(domain: rule.defaultsDomain, key: rule.defaultsKey)
            if storedRestores.first(where: { $0.id == restoreKey }) == nil {
                storedRestores.append(StoredConflictRestore(
                    domain: rule.defaultsDomain,
                    key: rule.defaultsKey,
                    value: readValue(domain: rule.defaultsDomain, key: rule.defaultsKey)
                ))
            }

            let currentValue = readValue(domain: rule.defaultsDomain, key: rule.defaultsKey)
            if currentValue != rule.overrideValue {
                writeValue(rule.overrideValue, domain: rule.defaultsDomain, key: rule.defaultsKey)
                changedKeys.append(restoreKey)
            }
        }

        let obsolete = storedRestores.filter { !requiredKeys.contains($0.id) }
        for restore in obsolete {
            writeValue(restore.value, domain: restore.domain, key: restore.key)
            changedKeys.append(restore.id)
        }
        storedRestores.removeAll { !requiredKeys.contains($0.id) }

        let statuses = snapshot(bindings: bindings, storedRestores: storedRestores)
        let message: String?
        if changedKeys.isEmpty {
            message = nil
        } else {
            message = "Trackpad conflicts updated. Manual verification may still be required in System Settings."
        }

        return ConflictSyncResult(statuses: statuses, changedKeys: changedKeys, message: message)
    }

    func restoreAll(storedRestores: inout [StoredConflictRestore]) -> ConflictSyncResult {
        let keys = storedRestores.map(\.id)
        for restore in storedRestores {
            writeValue(restore.value, domain: restore.domain, key: restore.key)
        }
        storedRestores.removeAll()

        return ConflictSyncResult(
            statuses: [],
            changedKeys: keys,
            message: keys.isEmpty ? nil : "Restored overridden trackpad settings."
        )
    }

    func snapshot(bindings: [Binding], storedRestores: [StoredConflictRestore]) -> [ConflictStatus] {
        let activeGestures = Set(bindings.filter(\.isEnabled).map(\.gesture))
        return Self.rules
            .map { rule in
                let currentValue = readValue(domain: rule.defaultsDomain, key: rule.defaultsKey)
                let isRequired = activeGestures.contains(rule.gesture)
                return ConflictStatus(
                    gesture: rule.gesture,
                    defaultsDomain: rule.defaultsDomain,
                    defaultsKey: rule.defaultsKey,
                    currentValue: currentValue,
                    targetValue: rule.overrideValue,
                    isRequired: isRequired,
                    isApplied: isRequired ? currentValue == rule.overrideValue : !storedRestores.contains(where: { $0.id == Self.restoreKey(domain: rule.defaultsDomain, key: rule.defaultsKey) }),
                    manualVerificationRequired: isRequired
                )
            }
            .sorted { lhs, rhs in
                if lhs.gesture.displayName == rhs.gesture.displayName {
                    return lhs.defaultsKey < rhs.defaultsKey
                }
                return lhs.gesture.displayName < rhs.gesture.displayName
            }
    }

    func openTrackpadSettings() {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension"),
            URL(string: "x-apple.systempreferences:com.apple.preference.trackpad"),
        ]

        for candidate in urls.compactMap({ $0 }) where NSWorkspace.shared.open(candidate) {
            return
        }

        _ = NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    private func readValue(domain: String, key: String) -> Int? {
        let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString)
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func writeValue(_ value: Int?, domain: String, key: String) {
        let cfValue = value.map(NSNumber.init(value:)) as CFPropertyList?
        CFPreferencesSetAppValue(key as CFString, cfValue, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    private static func restoreKey(domain: String, key: String) -> String {
        "\(domain)|\(key)"
    }

    static let rules: [ConflictRule] = domains.flatMap { domain in
        [
            ConflictRule(gesture: .threeFingerTap, defaultsDomain: domain, defaultsKey: "TrackpadThreeFingerTapGesture", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .threeFingerSwipeLeft, defaultsDomain: domain, defaultsKey: "TrackpadThreeFingerHorizSwipeGesture", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .threeFingerSwipeRight, defaultsDomain: domain, defaultsKey: "TrackpadThreeFingerHorizSwipeGesture", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .threeFingerSwipeUp, defaultsDomain: domain, defaultsKey: "TrackpadThreeFingerVertSwipeGesture", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .threeFingerSwipeDown, defaultsDomain: domain, defaultsKey: "TrackpadThreeFingerVertSwipeGesture", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .threeFingerSwipeLeft, defaultsDomain: domain, defaultsKey: "TrackpadThreeFingerDrag", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .threeFingerSwipeRight, defaultsDomain: domain, defaultsKey: "TrackpadThreeFingerDrag", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .threeFingerSwipeUp, defaultsDomain: domain, defaultsKey: "TrackpadThreeFingerDrag", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .threeFingerSwipeDown, defaultsDomain: domain, defaultsKey: "TrackpadThreeFingerDrag", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .fourFingerSwipeLeft, defaultsDomain: domain, defaultsKey: "TrackpadFourFingerHorizSwipeGesture", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .fourFingerSwipeRight, defaultsDomain: domain, defaultsKey: "TrackpadFourFingerHorizSwipeGesture", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .fourFingerSwipeUp, defaultsDomain: domain, defaultsKey: "TrackpadFourFingerVertSwipeGesture", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .fourFingerSwipeDown, defaultsDomain: domain, defaultsKey: "TrackpadFourFingerVertSwipeGesture", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .twoFingerPinchIn, defaultsDomain: domain, defaultsKey: "TrackpadPinch", overrideValue: 0, restoreValue: nil),
            ConflictRule(gesture: .twoFingerPinchOut, defaultsDomain: domain, defaultsKey: "TrackpadPinch", overrideValue: 0, restoreValue: nil),
        ]
    }
}

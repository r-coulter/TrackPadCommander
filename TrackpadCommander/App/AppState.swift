@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import Foundation
import ServiceManagement
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var config: AppConfig
    @Published var logEntries: [LogEntry]
    @Published var conflictStatuses: [ConflictStatus] = []
    @Published var lastGestureEvent: GestureEvent?
    @Published var statusMessage: String?
    @Published var recognizerAvailable = false
    @Published var accessibilityAccessGranted = AXIsProcessTrusted()

    private let configStore: ConfigStore
    private let logStore: LogStore
    private let actionRunner: ActionRunner
    private let recognizer: GestureRecognizerEngine
    private let bridge: MultitouchBridge
    private let conflictManager: ConflictManager

    private var lastExecutionByBinding: [UUID: Date] = [:]
    private var lastRawGestureByDevice: [String: GestureEvent] = [:]
    private var reconnectTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var didActivateObserver: NSObjectProtocol?
    private var hasPromptedForAccessibilityThisSession = false

    init(
        configStore: ConfigStore = ConfigStore(),
        logStore: LogStore = LogStore(),
        actionRunner: ActionRunner = ActionRunner(),
        recognizer: GestureRecognizerEngine = GestureRecognizerEngine(),
        bridge: MultitouchBridge = MultitouchBridge(),
        conflictManager: ConflictManager = ConflictManager()
    ) {
        self.configStore = configStore
        self.logStore = logStore
        self.actionRunner = actionRunner
        self.recognizer = recognizer
        self.bridge = bridge
        self.conflictManager = conflictManager

        logEntries = logStore.loadEntries()
        do {
            config = try configStore.load()
        } catch {
            config = .default
            logEntries = logStore.append(
                LogEntry(kind: .system, title: "Config load failed", details: error.localizedDescription),
                currentEntries: logEntries
            )
        }

        recognizerAvailable = bridge.isAvailable
        recognizer.threeFingerTapSensitivity = config.threeFingerTapSensitivity
        refreshAccessibilityPermissionStatus()
        promptForAccessibilityIfNeeded()
        applyLaunchAtLogin()
        syncConflicts()
        startGestureCapture()
        setUpSystemObservers()
    }

    var lastGestureLabel: String {
        guard let lastGestureEvent else { return "No gesture detected yet" }
        return "\(lastGestureEvent.gesture.displayName) at \(Self.timeFormatter.string(from: lastGestureEvent.timestamp))"
    }

    func addBinding(_ binding: Binding) {
        config.bindings.append(binding)
        persistConfigurationAndRuntime()
    }

    func updateBinding(_ binding: Binding) {
        guard let index = config.bindings.firstIndex(where: { $0.id == binding.id }) else { return }
        config.bindings[index] = binding
        persistConfigurationAndRuntime()
    }

    func duplicateBinding(_ binding: Binding) {
        var duplicate = binding
        duplicate.id = UUID()
        duplicate.action.id = UUID()
        config.bindings.append(duplicate)
        persistConfigurationAndRuntime()
    }

    func deleteBinding(_ binding: Binding) {
        config.bindings.removeAll { $0.id == binding.id }
        lastExecutionByBinding.removeValue(forKey: binding.id)
        persistConfigurationAndRuntime()
    }

    func trigger(binding: Binding) {
        Task {
            let result = await actionRunner.run(action: binding.action)
            handleExecutionResult(result, for: binding, source: "Manual Test")
        }
    }

    func setBindingEnabled(_ bindingID: UUID, isEnabled: Bool) {
        guard let index = config.bindings.firstIndex(where: { $0.id == bindingID }) else { return }
        config.bindings[index].isEnabled = isEnabled
        persistConfigurationAndRuntime()
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        config.launchAtLogin = enabled
        applyLaunchAtLogin()
        persistConfiguration()
    }

    func updateLoggingEnabled(_ enabled: Bool) {
        config.loggingEnabled = enabled
        persistConfiguration()
    }

    func updateNotificationsEnabled(_ enabled: Bool) {
        config.showNotifications = enabled
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        persistConfiguration()
    }

    func updateThreeFingerTapSensitivity(_ value: Double) {
        let clamped = min(max(value, 0.75), 1.5)
        config.threeFingerTapSensitivity = clamped
        recognizer.threeFingerTapSensitivity = clamped
        persistConfiguration()
    }

    func updateGestureDiagnosticsEnabled(_ enabled: Bool) {
        config.gestureDiagnosticsEnabled = enabled
        persistConfiguration()
    }

    func requestAccessibilityPermission() {
        if accessibilityAccessGranted {
            refreshAccessibilityPermissionStatus()
            statusMessage = "Accessibility access is already granted."
        } else {
            hasPromptedForAccessibilityThisSession = true
            refreshAccessibilityPermissionStatus(prompt: true)
        }
    }

    func restoreAllConflicts() {
        var restores = config.storedConflictRestores
        let result = conflictManager.restoreAll(storedRestores: &restores)
        config.storedConflictRestores = restores
        conflictStatuses = conflictManager.snapshot(bindings: config.bindings, storedRestores: restores)
        statusMessage = result.message
        appendSystemLog(title: "Conflicts restored", details: result.message ?? "Restored overridden trackpad settings.")
        persistConfiguration()
    }

    func openTrackpadSettings() {
        conflictManager.openTrackpadSettings()
    }

    func revealAppSupportFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([configStore.configURL.deletingLastPathComponent()])
    }

    func exportLogs() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "TrackpadCommander-logs.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try logStore.exportLogs(to: url, entries: logEntries)
            statusMessage = "Exported logs to \(url.lastPathComponent)."
        } catch {
            statusMessage = "Failed to export logs: \(error.localizedDescription)"
        }
    }

    private func setUpSystemObservers() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bridge.reconnectDevices()
            }
        }

        didActivateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAccessibilityPermissionStatus()
            }
        }

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bridge.reconnectDevices()
                self?.refreshAccessibilityPermissionStatus()
            }
        }
    }

    private func startGestureCapture() {
        bridge.start { [weak self] frame in
            self?.handleTouchFrame(frame)
        }

        if !bridge.isAvailable {
            appendSystemLog(
                title: "Gesture bridge unavailable",
                details: "MultitouchSupport.framework could not be loaded. The app UI still works, but global gesture capture is disabled."
            )
        }
    }

    private func handleTouchFrame(_ frame: TouchFrame) {
        guard let rawEvent = recognizer.process(frame: frame) else { return }
        let enabledGestures = Set(config.bindings.lazy.filter(\.isEnabled).map(\.gesture))
        let previousRawEvent = lastRawGestureByDevice[rawEvent.deviceID]
        lastRawGestureByDevice[rawEvent.deviceID] = rawEvent

        let event = Self.resolveGestureFallback(
            rawEvent: rawEvent,
            previousEvent: previousRawEvent,
            enabledGestures: enabledGestures,
            tapSensitivity: config.threeFingerTapSensitivity
        )
        lastGestureEvent = event
        let recognitionSource = Self.recognitionSource(rawEvent: rawEvent, resolvedEvent: event)

        if event.gesture != rawEvent.gesture, config.gestureDiagnosticsEnabled {
            appendSystemLog(
                title: "Gesture fallback applied",
                details: "Reinterpreted \(rawEvent.gesture.displayName) as \(event.gesture.displayName) after a short three-finger gesture sequence."
            )
        }

        appendLog(LogEntry(
            kind: .gesture,
            title: event.gesture.displayName,
            details: gestureLogDetails(for: event, recognitionSource: recognitionSource)
        ))

        guard let binding = config.bindings.first(where: { $0.gesture == event.gesture && $0.isEnabled }) else {
            return
        }

        if binding.action.kind == .middleClick && !accessibilityAccessGranted {
            refreshAccessibilityPermissionStatus()
            appendLog(LogEntry(
                kind: .system,
                title: "Middle click blocked",
                details: "Three-finger tap was recognized, but Accessibility access is still required to post a middle click. Use the Permissions tab to request access."
            ))
            return
        }

        let now = Date()
        if let lastExecution = lastExecutionByBinding[binding.id],
           now.timeIntervalSince(lastExecution) * 1_000 < Double(binding.action.debounceMs) {
            return
        }
        lastExecutionByBinding[binding.id] = now

        Task {
            let result = await actionRunner.run(action: binding.action)
            handleExecutionResult(result, for: binding, source: "\(event.gesture.displayName) [\(recognitionSource)]")
        }
    }

    private func handleExecutionResult(_ result: ExecutionResult, for binding: Binding, source: String) {
        let statusText = result.succeeded ? "Succeeded" : "Failed"
        let detail = [
            "Source: \(source)",
            result.errorDescription.map { "Error: \($0)" },
            result.stdoutTail.isEmpty ? nil : "stdout: \(result.stdoutTail)",
            result.stderrTail.isEmpty ? nil : "stderr: \(result.stderrTail)",
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        appendLog(LogEntry(
            kind: .action,
            title: "\(statusText): \(binding.gesture.displayName)",
            details: detail
        ))

        if !result.succeeded {
            statusMessage = "Action failed for \(binding.gesture.displayName)."
            if config.showNotifications || binding.action.notifyOnFailure {
                notifyFailure(title: binding.gesture.displayName, message: result.errorDescription ?? "Action execution failed.")
            }
        }
    }

    private func notifyFailure(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func syncConflicts() {
        var restores = config.storedConflictRestores
        let result = conflictManager.sync(bindings: config.bindings, storedRestores: &restores)
        config.storedConflictRestores = restores
        conflictStatuses = result.statuses
        if let message = result.message {
            statusMessage = message
            appendSystemLog(title: "Conflicts updated", details: message)
        }
    }

    private func persistConfigurationAndRuntime() {
        syncConflicts()
        promptForAccessibilityIfNeeded()
        persistConfiguration()
    }

    private func persistConfiguration() {
        do {
            try configStore.save(config)
        } catch {
            statusMessage = "Failed to save configuration: \(error.localizedDescription)"
            appendSystemLog(title: "Config save failed", details: error.localizedDescription)
        }
    }

    private func appendSystemLog(title: String, details: String) {
        appendLog(LogEntry(kind: .system, title: title, details: details))
    }

    private func appendLog(_ entry: LogEntry) {
        guard config.loggingEnabled else { return }
        logEntries = logStore.append(entry, currentEntries: logEntries)
    }

    private func applyLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }

        do {
            if config.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        } catch {
            appendSystemLog(title: "Launch at login", details: error.localizedDescription)
        }
    }

    private func promptForAccessibilityIfNeeded() {
        guard config.bindings.contains(where: { $0.isEnabled && $0.action.kind == .middleClick }),
              !accessibilityAccessGranted,
              !hasPromptedForAccessibilityThisSession else {
            return
        }

        hasPromptedForAccessibilityThisSession = true
        refreshAccessibilityPermissionStatus(prompt: true)
    }

    static func resolveGestureFallback(
        rawEvent: GestureEvent,
        previousEvent: GestureEvent?,
        enabledGestures: Set<GestureID>,
        tapSensitivity: Double = 1.0
    ) -> GestureEvent {
        let hasOnlyThreeFingerTapBinding = hasExclusiveThreeFingerTapBinding(enabledGestures)
        let normalizedTapSensitivity = min(max(tapSensitivity, 0.75), 1.5)

        if hasOnlyThreeFingerTapBinding,
           isThreeFingerSwipe(rawEvent.gesture),
           rawEvent.metrics.durationMs <= GestureThresholds.threeFingerTapFallbackMaxDurationMs * normalizedTapSensitivity {
            return GestureEvent(
                gesture: .threeFingerTap,
                deviceID: rawEvent.deviceID,
                timestamp: rawEvent.timestamp,
                metrics: RecognitionMetrics(
                    fingerCount: 3,
                    durationMs: rawEvent.metrics.durationMs,
                    distance: min(rawEvent.metrics.distance, GestureThresholds.tapMaxTravel),
                    velocity: rawEvent.metrics.velocity,
                    confidence: 0.6
                )
            )
        }

        guard rawEvent.gesture == .twoFingerTap,
              hasOnlyThreeFingerTapBinding,
              let previousEvent,
              previousEvent.deviceID == rawEvent.deviceID,
              isThreeFingerSwipe(previousEvent.gesture),
              rawEvent.timestamp.timeIntervalSince(previousEvent.timestamp) * 1_000 <= GestureThresholds.threeFingerTapSequenceFallbackWindowMs else {
            return rawEvent
        }

        return GestureEvent(
            gesture: .threeFingerTap,
            deviceID: rawEvent.deviceID,
            timestamp: rawEvent.timestamp,
            metrics: RecognitionMetrics(
                fingerCount: 3,
                durationMs: previousEvent.metrics.durationMs,
                distance: min(previousEvent.metrics.distance, GestureThresholds.tapMaxTravel),
                velocity: previousEvent.metrics.velocity,
                confidence: previousEvent.metrics.durationMs <= GestureThresholds.tapMaxDurationMs ? 0.7 : 0.6
            )
        )
    }

    private static func hasExclusiveThreeFingerTapBinding(_ enabledGestures: Set<GestureID>) -> Bool {
        enabledGestures.contains(.threeFingerTap) &&
        !enabledGestures.contains(.twoFingerTap) &&
        !enabledGestures.contains(.threeFingerSwipeLeft) &&
        !enabledGestures.contains(.threeFingerSwipeRight) &&
        !enabledGestures.contains(.threeFingerSwipeUp) &&
        !enabledGestures.contains(.threeFingerSwipeDown)
    }

    private static func isThreeFingerSwipe(_ gesture: GestureID) -> Bool {
        switch gesture {
        case .threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp, .threeFingerSwipeDown:
            return true
        default:
            return false
        }
    }

    private static func recognitionSource(rawEvent: GestureEvent, resolvedEvent: GestureEvent) -> String {
        guard rawEvent.gesture != resolvedEvent.gesture else {
            return "direct"
        }

        switch rawEvent.gesture {
        case .twoFingerTap:
            return "fallback-sequence"
        case .threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp, .threeFingerSwipeDown:
            return "fallback-swipe"
        default:
            return "fallback"
        }
    }

    private func gestureLogDetails(for event: GestureEvent, recognitionSource: String) -> String {
        var details = "Device \(event.deviceID), duration \(Int(event.metrics.durationMs)) ms, confidence \(String(format: "%.2f", event.metrics.confidence))."
        if config.gestureDiagnosticsEnabled {
            details += " Source \(recognitionSource)."
        }
        return details
    }

    private func refreshAccessibilityPermissionStatus(prompt: Bool = false) {
        let trusted: Bool
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            trusted = AXIsProcessTrustedWithOptions(options)
        } else {
            trusted = AXIsProcessTrusted()
        }

        let previousValue = accessibilityAccessGranted
        accessibilityAccessGranted = trusted

        if !trusted && prompt {
            statusMessage = "Accessibility access is required for synthetic middle click. Approve Trackpad Commander in Privacy & Security > Accessibility."
            if !previousValue {
                appendSystemLog(
                    title: "Accessibility permission required",
                    details: "Middle click injection requires Accessibility access. macOS should show the consent flow."
                )
            }
            hasPromptedForAccessibilityThisSession = true
        } else if trusted && !previousValue {
            statusMessage = "Accessibility access granted."
            hasPromptedForAccessibilityThisSession = false
            appendSystemLog(
                title: "Accessibility permission granted",
                details: "Synthetic input actions are now allowed."
            )
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}

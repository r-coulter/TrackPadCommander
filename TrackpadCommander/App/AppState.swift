@preconcurrency import AppKit
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

    private let configStore: ConfigStore
    private let logStore: LogStore
    private let actionRunner: ActionRunner
    private let recognizer: GestureRecognizerEngine
    private let bridge: MultitouchBridge
    private let conflictManager: ConflictManager

    private var lastExecutionByBinding: [UUID: Date] = [:]
    private var reconnectTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

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

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bridge.reconnectDevices()
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
        guard let event = recognizer.process(frame: frame) else { return }
        lastGestureEvent = event

        appendLog(LogEntry(
            kind: .gesture,
            title: event.gesture.displayName,
            details: "Device \(event.deviceID), duration \(Int(event.metrics.durationMs)) ms, confidence \(String(format: "%.2f", event.metrics.confidence))."
        ))

        guard let binding = config.bindings.first(where: { $0.gesture == event.gesture && $0.isEnabled }) else {
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
            handleExecutionResult(result, for: binding, source: event.gesture.displayName)
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

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}

import AppKit
import ApplicationServices
import Foundation

actor ActionRunner {
    func run(action: ActionSpec) async -> ExecutionResult {
        let startedAt = Date()

        switch action.kind {
        case .shell:
            return await runShell(action: action, startedAt: startedAt)
        case .openApp:
            return await runOpenApp(action: action, startedAt: startedAt)
        case .openPath:
            return await runOpenPath(action: action, startedAt: startedAt)
        case .openURL:
            return await runOpenURL(action: action, startedAt: startedAt)
        case .appleScript:
            return await runAppleScript(action: action, startedAt: startedAt)
        case .middleClick:
            return await runMiddleClick(startedAt: startedAt)
        }
    }

    private func runShell(action: ActionSpec, startedAt: Date) async -> ExecutionResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                var didTimeout = false

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", action.payload]
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
                timer.schedule(deadline: .now() + .milliseconds(max(action.timeoutMs, 100)))
                timer.setEventHandler {
                    guard process.isRunning else { return }
                    didTimeout = true
                    process.terminate()
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                        if process.isRunning {
                            kill(process.processIdentifier, SIGKILL)
                        }
                    }
                }

                do {
                    try process.run()
                    timer.resume()
                    process.waitUntilExit()
                    timer.cancel()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let finishedAt = Date()
                    continuation.resume(returning: ExecutionResult(
                        startedAt: startedAt,
                        finishedAt: finishedAt,
                        exitStatus: didTimeout ? nil : process.terminationStatus,
                        stdoutTail: Self.tailString(from: stdoutData),
                        stderrTail: Self.tailString(from: stderrData),
                        errorDescription: didTimeout ? "Shell command timed out after \(action.timeoutMs) ms." : nil
                    ))
                } catch {
                    timer.cancel()
                    continuation.resume(returning: ExecutionResult(
                        startedAt: startedAt,
                        finishedAt: Date(),
                        exitStatus: nil,
                        errorDescription: error.localizedDescription
                    ))
                }
            }
        }
    }

    private func runOpenApp(action: ActionSpec, startedAt: Date) async -> ExecutionResult {
        let appURL = await MainActor.run { () -> URL? in
            let workspace = NSWorkspace.shared
            if action.payload.hasPrefix("/") {
                return URL(fileURLWithPath: NSString(string: action.payload).expandingTildeInPath)
            }
            return workspace.urlForApplication(withBundleIdentifier: action.payload)
        }

        guard let appURL else {
            return ExecutionResult(
                startedAt: startedAt,
                finishedAt: Date(),
                exitStatus: 1,
                errorDescription: "Could not resolve app: \(action.payload)"
            )
        }

        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                NSWorkspace.shared.openApplication(at: appURL, configuration: .init()) { _, error in
                    continuation.resume(returning: ExecutionResult(
                        startedAt: startedAt,
                        finishedAt: Date(),
                        exitStatus: error == nil ? 0 : 1,
                        errorDescription: error?.localizedDescription
                    ))
                }
            }
        }
    }

    private func runOpenPath(action: ActionSpec, startedAt: Date) async -> ExecutionResult {
        await MainActor.run {
            let url = URL(fileURLWithPath: NSString(string: action.payload).expandingTildeInPath)
            let success = NSWorkspace.shared.open(url)

            return ExecutionResult(
                startedAt: startedAt,
                finishedAt: Date(),
                exitStatus: success ? 0 : 1,
                errorDescription: success ? nil : "Could not open path: \(action.payload)"
            )
        }
    }

    private func runOpenURL(action: ActionSpec, startedAt: Date) async -> ExecutionResult {
        await MainActor.run {
            guard let url = URL(string: action.payload) else {
                return ExecutionResult(
                    startedAt: startedAt,
                    finishedAt: Date(),
                    exitStatus: nil,
                    errorDescription: "Invalid URL: \(action.payload)"
                )
            }

            let success = NSWorkspace.shared.open(url)
            return ExecutionResult(
                startedAt: startedAt,
                finishedAt: Date(),
                exitStatus: success ? 0 : 1,
                errorDescription: success ? nil : "Could not open URL: \(action.payload)"
            )
        }
    }

    private func runAppleScript(action: ActionSpec, startedAt: Date) async -> ExecutionResult {
        await MainActor.run {
            var errorInfo: NSDictionary?
            let script = NSAppleScript(source: action.payload)
            _ = script?.executeAndReturnError(&errorInfo)

            return ExecutionResult(
                startedAt: startedAt,
                finishedAt: Date(),
                exitStatus: errorInfo == nil ? 0 : 1,
                stderrTail: errorInfo?.description ?? "",
                errorDescription: errorInfo?["NSAppleScriptErrorMessage"] as? String
            )
        }
    }

    private func runMiddleClick(startedAt: Date) async -> ExecutionResult {
        guard AXIsProcessTrusted() else {
            return ExecutionResult(
                startedAt: startedAt,
                finishedAt: Date(),
                exitStatus: 1,
                errorDescription: "Accessibility permission is required to post a middle click."
            )
        }

        return await MainActor.run {
            // Allow the trackpad gesture state to settle before injecting a mouse event.
            Thread.sleep(forTimeInterval: 0.035)

            guard let source = CGEventSource(stateID: .hidSystemState) else {
                return ExecutionResult(
                    startedAt: startedAt,
                    finishedAt: Date(),
                    exitStatus: 1,
                    errorDescription: "Could not create an event source for middle click."
                )
            }

            let desktopMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? 0
            let location = Self.quartzMouseLocation(from: NSEvent.mouseLocation, desktopMaxY: desktopMaxY)
            guard let down = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDown,
                mouseCursorPosition: location,
                mouseButton: .left
            ) else {
                return ExecutionResult(
                    startedAt: startedAt,
                    finishedAt: Date(),
                    exitStatus: 1,
                    errorDescription: "Could not create a middle-click down event."
                )
            }

            down.type = .otherMouseDown
            down.setIntegerValueField(.mouseEventButtonNumber, value: 2)
            down.setIntegerValueField(.mouseEventClickState, value: 1)
            down.setDoubleValueField(.mouseEventPressure, value: 1)
            down.post(tap: .cghidEventTap)

            Thread.sleep(forTimeInterval: 0.012)

            guard let up = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseUp,
                mouseCursorPosition: location,
                mouseButton: .left
            ) else {
                return ExecutionResult(
                    startedAt: startedAt,
                    finishedAt: Date(),
                    exitStatus: 1,
                    errorDescription: "Could not create a middle-click up event."
                )
            }

            up.type = .otherMouseUp
            up.setIntegerValueField(.mouseEventButtonNumber, value: 2)
            up.setIntegerValueField(.mouseEventClickState, value: 1)
            up.setDoubleValueField(.mouseEventPressure, value: 0)
            up.post(tap: .cghidEventTap)

            return ExecutionResult(
                startedAt: startedAt,
                finishedAt: Date(),
                exitStatus: 0
            )
        }
    }

    nonisolated static func quartzMouseLocation(from appKitLocation: CGPoint, desktopMaxY: CGFloat) -> CGPoint {
        CGPoint(x: appKitLocation.x, y: desktopMaxY - appKitLocation.y)
    }

    private static func tailString(from data: Data, limit: Int = 4_000) -> String {
        guard !data.isEmpty else { return "" }
        let string = String(decoding: data, as: UTF8.self)
        if string.count <= limit {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let tail = string.suffix(limit)
        return String(tail).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

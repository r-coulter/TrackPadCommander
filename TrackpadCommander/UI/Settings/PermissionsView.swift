import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Permissions and Runtime Notes")
                .font(.title2.weight(.semibold))

            GroupBox("Runtime") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.recognizerAvailable
                         ? "MultitouchSupport loaded successfully. Global gesture capture is available."
                         : "The private MultitouchSupport bridge is unavailable. Settings still work, but gesture capture is disabled until the framework can be loaded.")
                    Text("AppleScript actions can trigger Automation permission prompts from macOS.")
                    Text("Synthetic middle click actions can require Accessibility permission depending on the target app and OS policy.")
                    Text("Some overridden gesture settings may still require manual verification after OS updates.")
                    Text(appState.accessibilityAccessGranted
                         ? "Accessibility access is granted."
                         : "Accessibility access is not granted.")
                        .foregroundStyle(appState.accessibilityAccessGranted ? .green : .orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Preferences") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at login", isOn: SwiftUI.Binding(
                        get: { appState.config.launchAtLogin },
                        set: { appState.updateLaunchAtLogin($0) }
                    ))
                    Toggle("Write local logs", isOn: SwiftUI.Binding(
                        get: { appState.config.loggingEnabled },
                        set: { appState.updateLoggingEnabled($0) }
                    ))
                    Toggle("Show notifications on failures", isOn: SwiftUI.Binding(
                        get: { appState.config.showNotifications },
                        set: { appState.updateNotificationsEnabled($0) }
                    ))
                    Toggle("Include gesture diagnostics in logs", isOn: SwiftUI.Binding(
                        get: { appState.config.gestureDiagnosticsEnabled },
                        set: { appState.updateGestureDiagnosticsEnabled($0) }
                    ))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Three-Finger Tap Sensitivity")
                            Spacer()
                            Text(String(format: "%.2fx", appState.config.threeFingerTapSensitivity))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: SwiftUI.Binding(
                                get: { appState.config.threeFingerTapSensitivity },
                                set: { appState.updateThreeFingerTapSensitivity($0) }
                            ),
                            in: 0.75...1.5,
                            step: 0.05
                        )
                        Text("Higher values make three-finger tap more forgiving before the recognizer treats the motion as a swipe.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button(appState.accessibilityAccessGranted ? "Recheck Accessibility Access" : "Request Accessibility Access") {
                    appState.requestAccessibilityPermission()
                }
                Button("Reveal App Support Folder") {
                    appState.revealAppSupportFolder()
                }
                Button("Open Trackpad Settings") {
                    appState.openTrackpadSettings()
                }
            }

            Spacer()
        }
    }
}

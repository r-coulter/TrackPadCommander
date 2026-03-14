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
                    Text("Some overridden gesture settings may still require manual verification after OS updates.")
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
                }
            }

            HStack {
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

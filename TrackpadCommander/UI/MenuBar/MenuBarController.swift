import SwiftUI

struct MenuBarController: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trackpad Commander")
                .font(.headline)

            Text(appState.lastGestureLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            if let latest = appState.config.bindings.first(where: \.isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Test")
                        .font(.subheadline.weight(.medium))
                    Button("Run \(latest.gesture.displayName)") {
                        appState.trigger(binding: latest)
                    }
                    .buttonStyle(.link)
                }
            }

            Button("Open Settings") {
                openSettings()
            }

            Button("Open Trackpad Settings") {
                appState.openTrackpadSettings()
            }

            Divider()

            Text(appState.recognizerAvailable ? "Recognizer active" : "Recognizer unavailable")
                .font(.footnote)
                .foregroundStyle(appState.recognizerAvailable ? .green : .orange)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}

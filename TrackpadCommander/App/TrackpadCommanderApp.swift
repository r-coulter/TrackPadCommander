import SwiftUI

@main
struct TrackpadCommanderApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Trackpad Commander", systemImage: "hand.tap") {
            MenuBarController()
                .environmentObject(appState)
        }

        Settings {
            SettingsRootView()
                .environmentObject(appState)
                .frame(minWidth: 760, minHeight: 520)
        }
    }
}

private struct SettingsRootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let statusMessage = appState.statusMessage {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.12))
            }

            TabView {
                BindingsView()
                    .tabItem { Label("Bindings", systemImage: "command") }
                ConflictsView()
                    .tabItem { Label("Conflicts", systemImage: "exclamationmark.triangle") }
                PermissionsView()
                    .tabItem { Label("Permissions", systemImage: "lock.shield") }
                LogsView()
                    .tabItem { Label("Logs", systemImage: "text.append") }
            }
            .padding()
        }
    }
}

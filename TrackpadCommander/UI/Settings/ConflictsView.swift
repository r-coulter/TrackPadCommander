import SwiftUI

struct ConflictsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("macOS Gesture Conflicts")
                        .font(.title2.weight(.semibold))
                    Text("Enabled bindings can override built-in trackpad preferences. Verify the final behavior in System Settings.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Open Trackpad Settings") {
                    appState.openTrackpadSettings()
                }
                Button("Restore All") {
                    appState.restoreAllConflicts()
                }
            }

            List(appState.conflictStatuses) { status in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.gesture.displayName)
                            .font(.headline)
                        Text("\(status.defaultsDomain) / \(status.defaultsKey)")
                            .foregroundStyle(.secondary)
                            .font(.footnote.monospaced())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Current: \(status.currentValue.map(String.init) ?? "nil")")
                        Text("Target: \(status.targetValue)")
                            .foregroundStyle(.secondary)
                        Text(status.isApplied ? "Applied" : "Pending")
                            .foregroundStyle(status.isApplied ? .green : .orange)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }
}

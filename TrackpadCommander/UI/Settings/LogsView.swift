import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Logs")
                        .font(.title2.weight(.semibold))
                    Text("Gesture detection, command execution, and system notices are written locally.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Export Logs") {
                    appState.exportLogs()
                }
            }

            if appState.logEntries.isEmpty {
                ContentUnavailableView("No logs yet", systemImage: "text.append", description: Text("Logs will appear here after gestures are recognized or actions run."))
            } else {
                List(appState.logEntries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.title)
                                .font(.headline)
                            Spacer()
                            Text(entry.timestamp, style: .time)
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                        Text(entry.kind.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(entry.details)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
    }
}

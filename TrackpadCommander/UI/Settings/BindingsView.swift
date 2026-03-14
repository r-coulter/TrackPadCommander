import SwiftUI

struct BindingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft: BindingDraft?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gesture Bindings")
                        .font(.title2.weight(.semibold))
                    Text(appState.lastGestureLabel)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Add Binding") {
                    draft = .new
                }
            }

            if appState.config.bindings.isEmpty {
                ContentUnavailableView("No bindings yet", systemImage: "command", description: Text("Add a trackpad gesture and attach an action to it."))
            } else {
                List {
                    ForEach(appState.config.bindings) { binding in
                        BindingRow(
                            binding: binding,
                            onToggle: { appState.setBindingEnabled(binding.id, isEnabled: $0) },
                            onTest: { appState.trigger(binding: binding) },
                            onEdit: { draft = BindingDraft(binding: binding) },
                            onDuplicate: { appState.duplicateBinding(binding) },
                            onDelete: { appState.deleteBinding(binding) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: $draft) { draft in
            BindingEditorView(draft: draft) { updated in
                if appState.config.bindings.contains(where: { $0.id == updated.id }) {
                    appState.updateBinding(updated)
                } else {
                    appState.addBinding(updated)
                }
                self.draft = nil
            } onCancel: {
                self.draft = nil
            }
        }
    }
}

private struct BindingRow: View {
    let binding: Binding
    let onToggle: (Bool) -> Void
    let onTest: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: SwiftUI.Binding(
                get: { binding.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 6) {
                Text(binding.gesture.displayName)
                    .font(.headline)
                Text(binding.action.kind.displayName)
                    .font(.subheadline.weight(.medium))
                Text(binding.action.payload.isEmpty ? "No payload set" : binding.action.payload)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
                    .font(.footnote.monospaced())
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Test", action: onTest)
                Button("Edit", action: onEdit)
                Button("Duplicate", action: onDuplicate)
                Button("Delete", role: .destructive, action: onDelete)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

private struct BindingDraft: Identifiable {
    var id: UUID
    var actionID: UUID
    var gesture: GestureID
    var actionKind: ActionKind
    var payload: String
    var timeoutMs: String
    var debounceMs: String
    var notifyOnFailure: Bool
    var isEnabled: Bool

    init(binding: Binding) {
        id = binding.id
        actionID = binding.action.id
        gesture = binding.gesture
        actionKind = binding.action.kind
        payload = binding.action.payload
        timeoutMs = String(binding.action.timeoutMs)
        debounceMs = String(binding.action.debounceMs)
        notifyOnFailure = binding.action.notifyOnFailure
        isEnabled = binding.isEnabled
    }

    static let new = BindingDraft(binding: Binding())

    func buildBinding() -> Binding {
        Binding(
            id: id,
            gesture: gesture,
            action: ActionSpec(
                id: actionID,
                kind: actionKind,
                payload: payload,
                timeoutMs: Int(timeoutMs) ?? 3_000,
                debounceMs: Int(debounceMs) ?? 250,
                notifyOnFailure: notifyOnFailure
            ),
            isEnabled: isEnabled
        )
    }
}

private struct BindingEditorView: View {
    @State var draft: BindingDraft
    let onSave: (Binding) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Binding Editor")
                .font(.title2.weight(.semibold))

            Form {
                Picker("Gesture", selection: $draft.gesture) {
                    ForEach(GestureID.allCases) { gesture in
                        Text(gesture.displayName).tag(gesture)
                    }
                }

                Picker("Action", selection: $draft.actionKind) {
                    ForEach(ActionKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }

                Toggle("Binding enabled", isOn: $draft.isEnabled)
                Toggle("Notify on failure", isOn: $draft.notifyOnFailure)

                TextField("Timeout (ms)", text: $draft.timeoutMs)
                TextField("Debounce (ms)", text: $draft.debounceMs)

                if draft.actionKind == .shell || draft.actionKind == .appleScript {
                    TextEditor(text: $draft.payload)
                        .font(.body.monospaced())
                        .frame(minHeight: 160)
                } else {
                    TextField(payloadLabel, text: $draft.payload)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    onSave(draft.buildBinding())
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520, height: 520)
    }

    private var payloadLabel: String {
        switch draft.actionKind {
        case .shell: "Shell command"
        case .openApp: "Bundle identifier or app path"
        case .openPath: "File or folder path"
        case .openURL: "https://example.com"
        case .appleScript: "AppleScript source"
        }
    }
}

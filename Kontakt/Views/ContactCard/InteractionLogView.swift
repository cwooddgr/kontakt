import SwiftUI

/// Timestamped micro-notes for a contact, displayed as an interaction log.
///
/// Replaces the old notes "Append" concept. Each entry is a short note with
/// a timestamp, answering "when did I last interact with this person?"
struct InteractionLogView: View {
    let contactIdentifier: String
    @Environment(InteractionLogStore.self) private var logStore
    @State private var newEntryText = ""
    @State private var isAddingEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: KSpacing.m) {
            // Header: "LOG" in labelCaps + "Log" button
            HStack {
                Text("LOG")
                    .font(.labelCaps)
                    .tracking(0.5)
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                Button {
                    isAddingEntry = true
                } label: {
                    HStack(spacing: KSpacing.xs) {
                        Image(systemName: "plus")
                        Text("Log")
                    }
                    .font(.action)
                    .foregroundStyle(Color.accentSlateBlue)
                }
            }

            // Add entry field (when tapped)
            if isAddingEntry {
                HStack {
                    TextField("What happened?", text: $newEntryText)
                        .font(.kBody)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        guard !newEntryText.isEmpty else { return }
                        logStore.addEntry(text: newEntryText, to: contactIdentifier)
                        newEntryText = ""
                        isAddingEntry = false
                        HapticManager.success()
                    }
                    .font(.action)
                    .foregroundStyle(Color.accentSlateBlue)
                }
            }

            // Log entries (newest first)
            let entries = logStore.entries(for: contactIdentifier)
            if entries.isEmpty && !isAddingEntry {
                Text("No interactions logged yet.")
                    .font(.label)
                    .foregroundStyle(Color.textTertiary)
            } else {
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: KSpacing.s) {
                        Text(entry.timestamp, style: .date)
                            .font(.label)
                            .foregroundStyle(Color.textTertiary)
                            .frame(width: 80, alignment: .leading)
                        Text(entry.text)
                            .font(.kBody)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    InteractionLogView(contactIdentifier: "preview-id")
        .padding(.horizontal, KSpacing.xl)
        .environment(InteractionLogStore())
}

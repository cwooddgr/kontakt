import SwiftUI

/// Displays contact notes with a quick-append feature.
///
/// Shows the notes content below a separator line (the only separator in the card).
/// An "Append" button adds a timestamped entry. If no notes exist, a tappable
/// placeholder invites the user to add one.
struct NotesView: View {
    let notes: String
    let onSave: (String) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: KSpacing.m) {
            // Separator -- the ONLY one in the contact card
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)

            Text("NOTES")
                .font(.labelCaps)
                .foregroundStyle(Color.textTertiary)

            if isEditing {
                editor
            } else {
                content
            }
        }
    }

    // MARK: - Display Content

    @ViewBuilder
    private var content: some View {
        if notes.isEmpty {
            Text("Add a note...")
                .font(.kBody)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    beginEditing(withPrefix: false)
                }
        } else {
            Text(notes)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button {
                    beginEditing(withPrefix: true)
                } label: {
                    Text("+ Append")
                        .font(.action)
                        .foregroundStyle(Color.accentSlateBlue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Inline Editor

    private var editor: some View {
        VStack(alignment: .trailing, spacing: KSpacing.s) {
            TextEditor(text: $editText)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($editorFocused)
                .frame(minHeight: 80)

            HStack(spacing: KSpacing.m) {
                Button("Cancel") {
                    cancelEditing()
                }
                .font(.action)
                .foregroundStyle(Color.textSecondary)

                Button("Save") {
                    saveEditing()
                }
                .font(.action)
                .foregroundStyle(Color.accentSlateBlue)
            }
        }
    }

    // MARK: - Actions

    private func beginEditing(withPrefix: Bool) {
        if withPrefix {
            let dateString = Self.todayString()
            editText = notes + "\n[\(dateString)] "
        } else {
            let dateString = Self.todayString()
            editText = "[\(dateString)] "
        }
        isEditing = true
        // Delay focus so the TextEditor is in the view hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            editorFocused = true
        }
    }

    private func cancelEditing() {
        isEditing = false
        editText = ""
        editorFocused = false
    }

    private func saveEditing() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelEditing()
            return
        }
        onSave(trimmed)
        isEditing = false
        editText = ""
        editorFocused = false
        HapticManager.success()
    }

    // MARK: - Date Formatting

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Preview

#Preview("With notes") {
    NotesView(
        notes: "Met at WWDC 2025. Interested in our API platform.",
        onSave: { _ in }
    )
    .padding(.horizontal, KSpacing.xl)
}

#Preview("Empty notes") {
    NotesView(
        notes: "",
        onSave: { _ in }
    )
    .padding(.horizontal, KSpacing.xl)
}

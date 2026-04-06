import SwiftUI

/// Displays the contact's notes field with tap-to-edit inline editing.
///
/// Simplified from the original version: the "Append" flow has been removed in
/// favor of the InteractionLogView. This is now a straightforward display + edit
/// component for CNContact.note.
struct NotesView: View {
    let notes: String
    let onSave: (String) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: KSpacing.m) {
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
                    beginEditing()
                }
        } else {
            Text(notes)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    beginEditing()
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

    private func beginEditing() {
        editText = notes
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
        onSave(trimmed)
        isEditing = false
        editText = ""
        editorFocused = false
        HapticManager.success()
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

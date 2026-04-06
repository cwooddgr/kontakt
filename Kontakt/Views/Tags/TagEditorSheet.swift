import SwiftUI

/// Sheet for assigning and removing tags on a single contact.
///
/// Shows the contact's current tags as removable pills, a text field
/// for adding new tags, and a suggestion row of recent/frequent tags.
struct TagEditorSheet: View {
    let contactIdentifier: String

    @Environment(TagStore.self) private var tagStore
    @Environment(\.dismiss) private var dismiss

    @State private var newTagText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: KSpacing.l) {
                // Current tags
                currentTagsSection

                // Add tag text field
                addTagField

                // Suggestions
                suggestionsSection

                Spacer()
            }
            .padding(.horizontal, KSpacing.l)
            .padding(.top, KSpacing.m)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Current Tags

    private var currentTagsSection: some View {
        VStack(alignment: .leading, spacing: KSpacing.s) {
            Text("CURRENT TAGS")
                .font(.labelCaps)
                .tracking(0.5)
                .foregroundStyle(Color.textTertiary)

            let currentTags = tagStore.tags(for: contactIdentifier)

            if currentTags.isEmpty {
                Text("No tags")
                    .font(.kBody)
                    .foregroundStyle(Color.textTertiary)
            } else {
                TagBarView(
                    tags: currentTags,
                    isEditable: true,
                    onRemoveTag: { tag in
                        tagStore.removeTag(tag, from: contactIdentifier)
                    }
                )
            }
        }
    }

    // MARK: - Add Tag Field

    private var addTagField: some View {
        HStack(spacing: KSpacing.s) {
            TextField("Add tag...", text: $newTagText)
                .font(.kBody)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isTextFieldFocused)
                .onSubmit {
                    addCurrentTag()
                }

            if !newTagText.isEmpty {
                Button {
                    addCurrentTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentSlateBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, KSpacing.s)
        .padding(.vertical, KSpacing.s)
        .background(Color.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        let suggestions = availableSuggestions

        return Group {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: KSpacing.s) {
                    Text("SUGGESTIONS")
                        .font(.labelCaps)
                        .tracking(0.5)
                        .foregroundStyle(Color.textTertiary)

                    TagBarView(
                        tags: suggestions,
                        onTapTag: { tag in
                            tagStore.addTag(tag, to: contactIdentifier)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    /// Returns suggested tags that the contact does not already have.
    /// Combines recent tags with frequently used tags, deduped.
    private var availableSuggestions: [String] {
        let currentTags = Set(tagStore.tags(for: contactIdentifier))

        // Merge recent tags with top-count tags.
        var seen = Set<String>()
        var suggestions: [String] = []

        for tag in tagStore.recentTags where !currentTags.contains(tag) {
            if seen.insert(tag).inserted {
                suggestions.append(tag)
            }
        }

        // Add the most frequently used tags (top 10 by count).
        let topTags = tagStore.allTags
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map(\.name)

        for tag in topTags where !currentTags.contains(tag) {
            if seen.insert(tag).inserted {
                suggestions.append(tag)
            }
        }

        return suggestions
    }

    /// Adds the text field content as a new tag.
    private func addCurrentTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tagStore.addTag(trimmed, to: contactIdentifier)
        newTagText = ""
    }
}

// MARK: - Preview

#Preview {
    TagEditorSheet(contactIdentifier: "preview-id")
        .environment(TagStore())
}

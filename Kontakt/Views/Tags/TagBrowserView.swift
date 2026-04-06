import SwiftUI

/// Full-screen sheet listing all tags with their usage counts.
///
/// Tapping a tag dismisses the sheet and feeds the tag name back through
/// `onSelectTag` so the caller can populate the search field.
struct TagBrowserView: View {
    @Environment(TagStore.self) private var tagStore
    @Environment(\.dismiss) private var dismiss

    var onSelectTag: ((String) -> Void)?

    @State private var filterText = ""

    var body: some View {
        NavigationStack {
            Group {
                if tagStore.allTags.isEmpty {
                    emptyState
                } else if filteredTags.isEmpty {
                    noMatchState
                } else {
                    tagList
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filterText, prompt: "Filter tags...")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Tag List

    private var tagList: some View {
        List(filteredTags, id: \.name) { tag in
            Button {
                onSelectTag?(tag.name)
                dismiss()
            } label: {
                HStack {
                    Text(tag.name)
                        .font(.kBody)
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Text("\(tag.count)")
                        .font(.label)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty States

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Tags Yet", systemImage: "tag")
        } description: {
            Text("Add tags to people to organize them.")
        }
    }

    private var noMatchState: some View {
        ContentUnavailableView.search(text: filterText)
    }

    // MARK: - Filtering

    private var filteredTags: [(name: String, count: Int)] {
        let all = tagStore.allTags
        guard !filterText.isEmpty else { return all }
        let query = filterText.lowercased()
        return all.filter { $0.name.lowercased().contains(query) }
    }
}

// MARK: - Preview

#Preview {
    TagBrowserView()
        .environment(TagStore())
}

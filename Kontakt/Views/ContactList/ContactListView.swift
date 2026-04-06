import SwiftUI
import Contacts

/// The primary screen of Kontakt. "The list IS the app."
///
/// Displays all contacts grouped into a PINNED section and A-Z letter sections.
/// Supports search, section index scrubbing, and toolbar actions for cleanup,
/// new contact creation, and settings.
struct ContactListView: View {
    @Environment(ContactStore.self) private var contactStore
    @Environment(AppState.self) private var appState

    @State private var searchText = ""
    @State private var searchEngine = SearchEngine()
    @State private var searchIndex: [SearchEngine.SearchableContact] = []
    @State private var searchResults: [SearchResult] = []

    var body: some View {
        Group {
            if contactStore.contacts.isEmpty {
                emptyState
            } else if !searchText.isEmpty {
                searchResultsView
            } else {
                contactList
            }
        }
        .navigationTitle("People")
        .searchable(
            text: $searchText,
            isPresented: Bindable(appState).isSearchActive,
            prompt: "Search contacts..."
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appState.activeSheet = .cleanup
                } label: {
                    Text("Cleanup")
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    appState.activeSheet = .settings
                } label: {
                    Image(systemName: "gearshape")
                }
                Button {
                    appState.activeSheet = .newContact
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: String.self) { identifier in
            ContactCardView(contactIdentifier: identifier)
        }
        .sheet(item: Bindable(appState).activeSheet) { sheet in
            switch sheet {
            case .newContact:
                NewContactView()
            case .settings:
                SettingsView()
            case .cleanup:
                // Phase 2 — placeholder for now
                NavigationStack {
                    Text("Cleanup coming in Phase 2")
                        .navigationTitle("Cleanup")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { appState.activeSheet = nil }
                            }
                        }
                }
            }
        }
        .onChange(of: searchText) { _, _ in
            performSearch()
        }
        .onChange(of: contactStore.contacts) { _, _ in
            rebuildSearchIndex()
        }
        .task {
            contactStore.fetchAllContacts()
            rebuildSearchIndex()
        }
    }

    // MARK: - Contact List

    private var contactList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // PINNED section
                    if !pinnedContacts.isEmpty {
                        sectionHeader("PINNED")
                            .id("section_PINNED")

                        ForEach(pinnedContacts) { contact in
                            ContactRowView(contact: contact, isPinned: true)
                        }

                        Spacer()
                            .frame(height: KSpacing.xxl)
                    }

                    // A-Z sections
                    ForEach(letterGroups, id: \.letter) { group in
                        sectionHeader(group.letter)
                            .id("section_\(group.letter)")

                        ForEach(group.contacts) { contact in
                            ContactRowView(
                                contact: contact,
                                isPinned: contactStore.isPinned(identifier: contact.identifier)
                            )
                        }

                        Spacer()
                            .frame(height: KSpacing.l)
                    }
                }
                .padding(.trailing, 28) // Reserve space for section index
            }
            .overlay(alignment: .trailing) {
                SectionIndexView(
                    letters: availableLetters,
                    onSelectLetter: { letter in
                        withAnimation {
                            proxy.scrollTo("section_\(letter)", anchor: .top)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(searchResults) { result in
                    ContactRowView(
                        contact: result.contact,
                        isPinned: contactStore.isPinned(identifier: result.contact.identifier)
                    )
                }

                if !searchResults.isEmpty {
                    Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                        .font(.label)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, KSpacing.xl)
                        .padding(.top, KSpacing.m)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: searchResults.map(\.contact.identifier))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: KSpacing.m) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Color.textTertiary)

            Text("No Contacts")
                .font(.titlePrimary)
                .foregroundStyle(Color.textPrimary)

            Text("Your contacts will appear here.")
                .font(.titleSecondary)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.labelCaps)
            .tracking(0.5)
            .foregroundStyle(Color.textTertiary)
            .padding(.leading, KSpacing.l)
            .padding(.bottom, KSpacing.s)
    }

    // MARK: - Data Helpers

    /// Contacts whose identifiers are in the pinned set, preserving the list's sort order.
    private var pinnedContacts: [ContactWrapper] {
        contactStore.contacts.filter { contactStore.isPinned(identifier: $0.identifier) }
    }

    /// All contacts grouped by the first character of their display name, sorted alphabetically.
    private var letterGroups: [LetterGroup] {
        let allContacts = contactStore.contacts
        var grouped: [String: [ContactWrapper]] = [:]

        for contact in allContacts {
            let firstChar = contact.fullName.first
                .map { $0.isLetter ? String($0).uppercased() : "#" }
                ?? "#"
            grouped[firstChar, default: []].append(contact)
        }

        return grouped.keys
            .sorted { lhs, rhs in
                // Put "#" at the end
                if lhs == "#" { return false }
                if rhs == "#" { return true }
                return lhs < rhs
            }
            .map { LetterGroup(letter: $0, contacts: grouped[$0]!) }
    }

    /// The set of available first letters for the section index.
    private var availableLetters: [String] {
        letterGroups.map(\.letter)
    }

    /// Rebuilds the search index on a background thread whenever contacts change.
    private func rebuildSearchIndex() {
        let keys = SearchEngine.indexFetchKeys
        let store = CNContactStore()
        let engine = searchEngine
        Task.detached {
            var cnContacts: [CNContact] = []
            let request = CNContactFetchRequest(keysToFetch: keys)
            try? store.enumerateContacts(with: request) { contact, _ in
                cnContacts.append(contact)
            }
            let newIndex = engine.buildIndex(from: cnContacts)
            await MainActor.run {
                searchIndex = newIndex
            }
        }
    }

    /// Performs a search using the SearchEngine.
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        searchResults = searchEngine.search(
            query: searchText,
            in: searchIndex,
            contacts: contactStore.contacts
        )
    }
}

// MARK: - Letter Group

private struct LetterGroup: Equatable {
    let letter: String
    let contacts: [ContactWrapper]
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ContactListView()
    }
    .environment(ContactStore())
    .environment(AppState())
}

import SwiftUI
import Contacts

/// The primary screen of People. Three states: Ready, Searching, and Browse All.
///
/// **Ready** (default): search field focused with keyboard up, stars grid below.
/// **Searching**: live results as user types.
/// **Browse All**: full A-Z list with section index scrubber.
struct ContactListView: View {
    @Environment(ContactStore.self) private var contactStore
    @Environment(AppState.self) private var appState
    @Environment(RecentlyDeletedStore.self) private var recentlyDeletedStore
    @Environment(TagStore.self) private var tagStore
    @Environment(InteractionLogStore.self) private var interactionLogStore

    @State private var searchText = ""
    @State private var searchEngine = SearchEngine()
    @State private var searchIndex: [SearchEngine.SearchableContact] = []
    @State private var searchResults: [SearchResult] = []
    @FocusState private var isSearchFieldFocused: Bool

    @State private var contactToDelete: ContactWrapper?
    @State private var showDeleteConfirmation = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search field persists across all states to maintain focus
            if !contactStore.contacts.isEmpty && !appState.isBrowsingAll {
                searchField
                    .padding(.top, KSpacing.m)
            }

            if contactStore.contacts.isEmpty {
                emptyState
            } else if appState.isBrowsingAll {
                browseAllView
            } else if !searchText.isEmpty {
                searchResultsContent
            } else {
                starsContent
            }
        }
        .navigationTitle("People")
        .toolbar {
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
            sheetContent(for: sheet)
        }
        .alert("Delete Contact", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let contact = contactToDelete {
                    deleteContact(contact)
                }
            }
            Button("Cancel", role: .cancel) {
                contactToDelete = nil
            }
        } message: {
            if let contact = contactToDelete {
                Text("Are you sure you want to delete \(contact.fullName)? This contact will be recoverable for 30 days.")
            }
        }
        .onChange(of: searchText) { _, _ in
            performSearch()
        }
        .onChange(of: appState.pendingSearchTag) { _, newValue in
            if let tag = newValue {
                searchText = tag
                appState.pendingSearchTag = nil
            }
        }
        .onChange(of: contactStore.contacts) { _, _ in
            rebuildSearchIndex()
        }
        .onChange(of: tagStore.contactTags) { _, _ in
            rebuildSearchIndex()
        }
        .task {
            contactStore.fetchAllContacts()
            rebuildSearchIndex()
        }
    }

    // MARK: - State 1: Ready State

    private var starsContent: some View {
        ScrollView {
            StarsGridView(onBrowseAll: {
                withAnimation {
                    appState.isBrowsingAll = true
                }
            })
            .padding(.top, KSpacing.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: KSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)
                .font(.system(size: 16))

            TextField("Search people...", text: $searchText)
                .font(.search)
                .foregroundStyle(Color.textPrimary)
                .focused($isSearchFieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textTertiary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, KSpacing.m)
        .padding(.vertical, KSpacing.s + 2)
        .background(Color.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
        .padding(.horizontal, KSpacing.xl)
    }

    // MARK: - State 2: Search Results

    private var searchResultsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(searchResults) { result in
                    SearchResultRowView(
                        result: result,
                        isStarred: contactStore.isStarred(identifier: result.contact.identifier),
                        onDelete: {
                            contactToDelete = result.contact
                            showDeleteConfirmation = true
                        }
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
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - State 3: Browse All

    private var browseAllView: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.top, KSpacing.m)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Back button
                        Button {
                            withAnimation {
                                appState.isBrowsingAll = false
                                searchText = ""
                            }
                        } label: {
                            HStack(spacing: KSpacing.xs) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Back")
                                    .font(.kBody)
                            }
                            .foregroundStyle(Color.accentSlateBlue)
                            .padding(.horizontal, KSpacing.xl)
                            .padding(.vertical, KSpacing.m)
                        }

                        if !searchText.isEmpty {
                            // Show filtered results in browse mode
                            ForEach(searchResults) { result in
                                ContactRowView(
                                    contact: result.contact,
                                    isStarred: contactStore.isStarred(identifier: result.contact.identifier),
                                    onDelete: {
                                        contactToDelete = result.contact
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        } else {
                            // Full A-Z list
                            ForEach(letterGroups, id: \.letter) { group in
                                sectionHeader(group.letter)
                                    .id("section_\(group.letter)")

                                ForEach(group.contacts) { contact in
                                    ContactRowView(
                                        contact: contact,
                                        isStarred: contactStore.isStarred(identifier: contact.identifier),
                                        onDelete: {
                                            contactToDelete = contact
                                            showDeleteConfirmation = true
                                        }
                                    )
                                }

                                Spacer()
                                    .frame(height: KSpacing.l)
                            }
                        }
                    }
                    .padding(.trailing, searchText.isEmpty ? 28 : 0)
                }
                .overlay(alignment: .trailing) {
                    if searchText.isEmpty {
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
            .scrollDismissesKeyboard(.interactively)
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

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: AppState.ActiveSheet) -> some View {
        switch sheet {
        case .newContact:
            NewContactView()
        case .settings:
            SettingsView()
        case .cleanup:
            NavigationStack {
                Text("Cleanup coming in Phase 2")
                    .navigationTitle("Cleanup")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { appState.activeSheet = nil }
                        }
                    }
            }
        case .tagBrowser:
            TagBrowserView(onSelectTag: { tag in
                searchText = tag
                appState.activeSheet = nil
            })
        case .recentlyDeleted:
            RecentlyDeletedView()
        }
    }

    // MARK: - Data Helpers

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

    // MARK: - Search

    /// Rebuilds the search index on a background thread whenever contacts change.
    private func rebuildSearchIndex() {
        let keys = SearchEngine.indexFetchKeys
        let store = CNContactStore()
        let engine = searchEngine
        let currentTags = tagStore.contactTags
        Task.detached {
            var cnContacts: [CNContact] = []
            let request = CNContactFetchRequest(keysToFetch: keys)
            try? store.enumerateContacts(with: request) { contact, _ in
                cnContacts.append(contact)
            }
            let newIndex = engine.buildIndex(from: cnContacts, tags: currentTags)
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

    // MARK: - Deletion

    private func deleteContact(_ contact: ContactWrapper) {
        do {
            try contactStore.softDeleteContact(
                identifier: contact.identifier,
                recentlyDeletedStore: recentlyDeletedStore,
                tagStore: tagStore,
                interactionLogStore: interactionLogStore
            )
            contactToDelete = nil
        } catch {
            // In a future iteration, surface an error alert.
            contactToDelete = nil
        }
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
    .environment(RecentlyDeletedStore())
    .environment(TagStore())
    .environment(InteractionLogStore())
}

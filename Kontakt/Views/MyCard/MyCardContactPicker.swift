import SwiftUI

/// A contact picker for selecting the user's My Card contact.
///
/// Presents a searchable list of all contacts from the ContactStore.
/// Tapping a contact calls the `onSelect` closure with its identifier
/// and dismisses the picker.
struct MyCardContactPicker: View {
    @Environment(ContactStore.self) private var contactStore
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Called when the user selects a contact. Receives the contact identifier.
    let onSelect: (String) -> Void

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredContacts) { contact in
                    Button {
                        onSelect(contact.identifier)
                        dismiss()
                    } label: {
                        HStack(spacing: KSpacing.m) {
                            ContactPhoto(
                                imageData: contact.thumbnailImageData,
                                givenName: contact.givenName,
                                familyName: contact.familyName,
                                size: 40
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.fullName)
                                    .font(.listPrimary)
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)

                                if !contact.organizationName.isEmpty {
                                    Text(contact.organizationName)
                                        .font(.listSecondary)
                                        .foregroundStyle(Color.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, KSpacing.xs)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Select My Card")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search contacts...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Filtering

    /// Contacts filtered by the search text, matching against name and organization.
    private var filteredContacts: [ContactWrapper] {
        guard !searchText.isEmpty else {
            return contactStore.contacts
        }

        let query = searchText.lowercased()
        return contactStore.contacts.filter { contact in
            contact.fullName.lowercased().contains(query)
                || contact.organizationName.lowercased().contains(query)
        }
    }
}

// MARK: - Preview

#Preview {
    MyCardContactPicker { identifier in
        print("Selected: \(identifier)")
    }
    .environment(ContactStore())
    .environment(AppState())
}

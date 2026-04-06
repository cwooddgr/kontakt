import SwiftUI
import Contacts

/// Detail view for a single contact.
///
/// Loads the full contact using `ContactStore.fetchContactDetail(identifier:)` and
/// displays all available fields in a scrollable layout. Follows the design-spec
/// principle of "content over chrome" -- no lines between fields, whitespace separates,
/// separator only before notes.
struct ContactCardView: View {
    let contactIdentifier: String

    @Environment(ContactStore.self) private var contactStore
    @Environment(\.openURL) private var openURL

    @State private var contact: CNContact?
    @State private var showCopyConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let contact {
                cardContent(contact)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") {
                    FullEditView(contactIdentifier: contactIdentifier, contactStore: contactStore)
                }
            }
        }
        .copyConfirmation(isPresented: $showCopyConfirmation)
        .onAppear {
            contact = contactStore.fetchContactDetail(identifier: contactIdentifier)
        }
    }

    // MARK: - Card Content

    private func cardContent(_ contact: CNContact) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KSpacing.xl) {
                headerSection(contact)
                actionBarSection(contact)
                phoneSection(contact)
                emailSection(contact)
                addressSection(contact)
                urlSection(contact)
                dateSection(contact)
                socialProfileSection(contact)
                notesSection(contact)
                pinToggle(contact)
            }
            .padding(.horizontal, KSpacing.xl)
            .padding(.vertical, KSpacing.l)
        }
    }

    // MARK: - Header

    private func headerSection(_ contact: CNContact) -> some View {
        HStack(alignment: .top, spacing: KSpacing.m) {
            ContactPhoto(
                imageData: contact.thumbnailImageData,
                givenName: contact.givenName,
                familyName: contact.familyName,
                size: 56
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.titlePrimary)
                    .foregroundStyle(Color.textPrimary)

                if !contact.jobTitle.isEmpty {
                    Text(contact.jobTitle)
                        .font(.titleSecondary)
                        .foregroundStyle(Color.textSecondary)
                }

                if !contact.organizationName.isEmpty {
                    Text(contact.organizationName)
                        .font(.titleSecondary)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Action Bar

    @ViewBuilder
    private func actionBarSection(_ contact: CNContact) -> some View {
        if ActionBarView.hasActions(for: contact) {
            ActionBarView(contact: contact)
        }
    }

    // MARK: - Phone Numbers

    @ViewBuilder
    private func phoneSection(_ contact: CNContact) -> some View {
        if contact.hasPhoneNumbers {
            VStack(alignment: .leading, spacing: KSpacing.l) {
                ForEach(Array(contact.formattedPhoneNumbers.enumerated()), id: \.offset) { _, phone in
                    FieldView(
                        label: phone.label,
                        value: phone.value,
                        action: { callPhone(phone.value) },
                        copyValue: phone.value,
                        showCopyConfirmation: $showCopyConfirmation
                    )
                }
            }
        }
    }

    // MARK: - Email Addresses

    @ViewBuilder
    private func emailSection(_ contact: CNContact) -> some View {
        if contact.hasEmailAddresses {
            VStack(alignment: .leading, spacing: KSpacing.l) {
                ForEach(Array(contact.formattedEmailAddresses.enumerated()), id: \.offset) { _, email in
                    FieldView(
                        label: email.label,
                        value: email.value,
                        action: { composeEmail(email.value) },
                        copyValue: email.value,
                        showCopyConfirmation: $showCopyConfirmation
                    )
                }
            }
        }
    }

    // MARK: - Postal Addresses

    @ViewBuilder
    private func addressSection(_ contact: CNContact) -> some View {
        if contact.hasPostalAddresses {
            VStack(alignment: .leading, spacing: KSpacing.l) {
                ForEach(Array(contact.formattedAddresses.enumerated()), id: \.offset) { _, address in
                    FieldView(
                        label: address.label,
                        value: address.value,
                        action: { openDirections(address.value) },
                        copyValue: address.value,
                        showCopyConfirmation: $showCopyConfirmation
                    )
                }
            }
        }
    }

    // MARK: - URLs

    @ViewBuilder
    private func urlSection(_ contact: CNContact) -> some View {
        if !contact.urlAddresses.isEmpty {
            VStack(alignment: .leading, spacing: KSpacing.l) {
                ForEach(Array(contact.urlAddresses.enumerated()), id: \.offset) { _, labeled in
                    let label = CNLabelMapping.displayName(for: labeled.label)
                    let value = labeled.value as String
                    FieldView(
                        label: label,
                        value: value,
                        action: { openWebURL(value) },
                        copyValue: value,
                        showCopyConfirmation: $showCopyConfirmation
                    )
                }
            }
        }
    }

    // MARK: - Dates

    @ViewBuilder
    private func dateSection(_ contact: CNContact) -> some View {
        let dates = formattedDates(for: contact)
        if !dates.isEmpty {
            VStack(alignment: .leading, spacing: KSpacing.l) {
                ForEach(Array(dates.enumerated()), id: \.offset) { _, item in
                    FieldView(
                        label: item.label,
                        value: item.value,
                        copyValue: item.value,
                        showCopyConfirmation: $showCopyConfirmation
                    )
                }
            }
        }
    }

    // MARK: - Social Profiles

    @ViewBuilder
    private func socialProfileSection(_ contact: CNContact) -> some View {
        if !contact.socialProfiles.isEmpty {
            VStack(alignment: .leading, spacing: KSpacing.l) {
                ForEach(Array(contact.socialProfiles.enumerated()), id: \.offset) { _, labeled in
                    let profile = labeled.value
                    let label = profile.service.isEmpty
                        ? CNLabelMapping.displayName(for: labeled.label)
                        : profile.service.lowercased()
                    let value = profile.username.isEmpty ? profile.urlString : profile.username
                    FieldView(
                        label: label,
                        value: value,
                        action: profile.urlString.isEmpty ? nil : { openWebURL(profile.urlString) },
                        copyValue: value,
                        showCopyConfirmation: $showCopyConfirmation
                    )
                }
            }
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private func notesSection(_ contact: CNContact) -> some View {
        NotesView(notes: contact.note) { updatedNotes in
            saveNotes(updatedNotes)
        }
    }

    // MARK: - Pin Toggle

    private func pinToggle(_ contact: CNContact) -> some View {
        let isPinned = contactStore.isPinned(identifier: contact.identifier)

        return Button {
            HapticManager.mediumImpact()
            contactStore.togglePin(identifier: contact.identifier)
        } label: {
            HStack(spacing: KSpacing.xs) {
                if reduceMotion {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 14, weight: .regular))
                } else {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 14, weight: .regular))
                        .symbolEffect(.bounce, value: isPinned)
                }
                Text(isPinned ? "Pinned" : "Pin")
                    .font(.label)
            }
            .foregroundStyle(isPinned ? Color.accentSlateBlue : Color.textTertiary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, KSpacing.m)
    }

    // MARK: - Actions

    private func callPhone(_ number: String) {
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let url = URL(string: "tel:\(cleaned)") else { return }
        openURL(url)
    }

    private func composeEmail(_ email: String) {
        guard let url = URL(string: "mailto:\(email)") else { return }
        openURL(url)
    }

    private func openDirections(_ address: String) {
        // Replace newlines with commas for the Maps query
        let query = address
            .replacingOccurrences(of: "\n", with: ", ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "maps://?address=\(encoded)") else { return }
        openURL(url)
    }

    private func openWebURL(_ urlString: String) {
        var normalized = urlString
        if !normalized.contains("://") {
            normalized = "https://\(normalized)"
        }
        guard let url = URL(string: normalized) else { return }
        openURL(url)
    }

    private func saveNotes(_ updatedNotes: String) {
        guard let detail = contactStore.fetchContactDetail(identifier: contactIdentifier),
              let mutableContact = detail.mutableCopy() as? CNMutableContact else { return }
        mutableContact.note = updatedNotes
        do {
            try contactStore.saveContact(mutableContact)
            // Refresh the contact to reflect saved changes
            contact = contactStore.fetchContactDetail(identifier: contactIdentifier)
        } catch {
            HapticManager.error()
        }
    }

    // MARK: - Date Formatting

    private func formattedDates(for contact: CNContact) -> [(label: String, value: String)] {
        var results: [(label: String, value: String)] = []

        // Birthday
        if let birthday = contact.birthday {
            let dateString = Self.formatDateComponents(birthday)
            results.append((label: "birthday", value: dateString))
        }

        // Other dates (anniversary, etc.)
        for labeled in contact.dates {
            let label = CNLabelMapping.displayName(for: labeled.label)
            let dateString = Self.formatDateComponents(labeled.value as DateComponents)
            results.append((label: label, value: dateString))
        }

        return results
    }

    private static func formatDateComponents(_ components: DateComponents) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none

        if let date = Calendar.current.date(from: components) {
            // If no year was provided, show just month and day
            if components.year == nil {
                formatter.dateFormat = "MMMM d"
            }
            return formatter.string(from: date)
        }

        // Fallback: build a string from the components
        var parts: [String] = []
        if let month = components.month {
            parts.append(DateFormatter().monthSymbols[month - 1])
        }
        if let day = components.day {
            parts.append(String(day))
        }
        if let year = components.year {
            parts.append(String(year))
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ContactCardView(contactIdentifier: "preview-id")
    }
    .environment(ContactStore())
}

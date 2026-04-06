import SwiftUI
import Contacts

/// Detail view for a single contact.
///
/// Redesigned layout per the April 2026 spec update:
/// - Large centered photo at top with star toggle in the top-right
/// - Name centered and prominent, job title + company below
/// - Tags as horizontal pills
/// - Action bar for quick actions
/// - Fields ordered by usefulness (phone, email, address, URL, dates, social, notes)
/// - Context menu on each field for edit/delete
/// - Delete button always visible at bottom
/// - Interaction log at the very bottom
struct ContactCardView: View {
    let contactIdentifier: String

    @Environment(ContactStore.self) private var contactStore
    @Environment(TagStore.self) private var tagStore
    @Environment(InteractionLogStore.self) private var interactionLogStore
    @Environment(RecentlyDeletedStore.self) private var recentlyDeletedStore
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    @State private var contact: CNContact?
    @State private var showCopyConfirmation = false
    @State private var showTagEditor = false
    @State private var showDeleteConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let contact {
                cardContent(contact)
            } else {
                Color.clear
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
        .sheet(isPresented: $showTagEditor) {
            TagEditorSheet(contactIdentifier: contactIdentifier)
        }
        .confirmationDialog(
            "Delete Contact",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteContact()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This contact will be moved to Recently Deleted and permanently removed after 30 days.")
        }
        .onAppear {
            contact = contactStore.fetchContactDetail(identifier: contactIdentifier)
        }
    }

    // MARK: - Card Content

    private func cardContent(_ contact: CNContact) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KSpacing.xl) {
                headerSection(contact)
                nameSection(contact)
                tagsSection(contact)
                actionBarSection(contact)
                phoneSection(contact)
                emailSection(contact)
                addressSection(contact)
                urlSection(contact)
                dateSection(contact)
                socialProfileSection(contact)
                notesSection(contact)
                deleteSection()
                interactionLogSection()
            }
            .padding(.horizontal, KSpacing.xl)
            .padding(.vertical, KSpacing.l)
        }
    }

    // MARK: - Header (Photo + Star)

    private func headerSection(_ contact: CNContact) -> some View {
        ZStack(alignment: .topTrailing) {
            // Centered photo
            HStack {
                Spacer()
                ContactPhoto(
                    imageData: contact.imageData ?? contact.thumbnailImageData,
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    size: 120
                )
                Spacer()
            }

            // Star toggle in top-right
            starButton(contact)
        }
    }

    // MARK: - Star Button

    private func starButton(_ contact: CNContact) -> some View {
        let isStarred = contactStore.isStarred(identifier: contact.identifier)

        return Button {
            HapticManager.mediumImpact()
            contactStore.toggleStar(identifier: contact.identifier)
        } label: {
            Group {
                if reduceMotion {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.system(size: 18, weight: .regular))
                } else {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.system(size: 18, weight: .regular))
                        .symbolEffect(.bounce, value: isStarred)
                }
            }
            .foregroundStyle(isStarred ? Color.accentSlateBlue : Color.textTertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isStarred ? "Remove star" : "Add star")
    }

    // MARK: - Name Section

    private func nameSection(_ contact: CNContact) -> some View {
        VStack(spacing: 2) {
            Text(contact.displayName)
                .font(.nameDisplay)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            if !contact.jobTitle.isEmpty || !contact.organizationName.isEmpty {
                let parts = [contact.jobTitle, contact.organizationName]
                    .filter { !$0.isEmpty }
                Text(parts.joined(separator: " at "))
                    .font(.titleSecondary)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tags Section

    @ViewBuilder
    private func tagsSection(_ contact: CNContact) -> some View {
        let tags = tagStore.tags(for: contact.identifier)
        // Always show tags section so user can add tags
        VStack(alignment: .leading, spacing: KSpacing.s) {
            if tags.isEmpty {
                Button {
                    showTagEditor = true
                } label: {
                    HStack(spacing: KSpacing.xs) {
                        Image(systemName: "tag")
                            .font(.system(size: 11, weight: .medium))
                        Text("Add tags")
                            .font(.action)
                    }
                    .foregroundStyle(Color.accentSlateBlue)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            } else {
                TagBarView(
                    tags: tags,
                    onTapTag: { tagName in
                        appState.pendingSearchTag = tagName
                        dismiss()
                    },
                    onAddTag: { showTagEditor = true }
                )
                .frame(maxWidth: .infinity)
            }
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
                ForEach(Array(contact.formattedPhoneNumbers.enumerated()), id: \.offset) { index, phone in
                    FieldView(
                        label: phone.label,
                        value: phone.value,
                        action: { callPhone(phone.value) },
                        copyValue: phone.value,
                        onDelete: { deletePhoneNumber(at: index) },
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
                ForEach(Array(contact.formattedEmailAddresses.enumerated()), id: \.offset) { index, email in
                    FieldView(
                        label: email.label,
                        value: email.value,
                        action: { composeEmail(email.value) },
                        copyValue: email.value,
                        onDelete: { deleteEmailAddress(at: index) },
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
                ForEach(Array(contact.formattedAddresses.enumerated()), id: \.offset) { index, address in
                    FieldView(
                        label: address.label,
                        value: address.value,
                        action: { openDirections(address.value) },
                        copyValue: address.value,
                        onDelete: { deletePostalAddress(at: index) },
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
                ForEach(Array(contact.urlAddresses.enumerated()), id: \.offset) { index, labeled in
                    let label = CNLabelMapping.displayName(for: labeled.label)
                    let value = labeled.value as String
                    FieldView(
                        label: label,
                        value: value,
                        action: { openWebURL(value) },
                        copyValue: value,
                        onDelete: { deleteURL(at: index) },
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
                ForEach(Array(contact.socialProfiles.enumerated()), id: \.offset) { index, labeled in
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
                        onDelete: { deleteSocialProfile(at: index) },
                        showCopyConfirmation: $showCopyConfirmation
                    )
                }
            }
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private func notesSection(_ contact: CNContact) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.m) {
            Text("NOTES")
                .font(.labelCaps)
                .tracking(0.5)
                .foregroundStyle(Color.textTertiary)

            NotesView(notes: contact.note) { updatedNotes in
                saveNotes(updatedNotes)
            }
        }
    }

    // MARK: - Delete Section

    private func deleteSection() -> some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Text("Delete Contact")
                .font(.action)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KSpacing.m)
        }
        .buttonStyle(.plain)
        .padding(.top, KSpacing.m)
    }

    // MARK: - Interaction Log

    private func interactionLogSection() -> some View {
        InteractionLogView(contactIdentifier: contactIdentifier)
            .padding(.top, KSpacing.s)
    }

    // MARK: - URL / Action Helpers

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

    // MARK: - Save Notes

    private func saveNotes(_ updatedNotes: String) {
        guard let detail = contactStore.fetchContactDetail(identifier: contactIdentifier),
              let mutableContact = detail.mutableCopy() as? CNMutableContact else { return }
        mutableContact.note = updatedNotes
        do {
            try contactStore.saveContact(mutableContact)
            contact = contactStore.fetchContactDetail(identifier: contactIdentifier)
        } catch {
            HapticManager.error()
        }
    }

    // MARK: - Field Deletion Helpers

    private func deletePhoneNumber(at index: Int) {
        guard let detail = contactStore.fetchContactDetail(identifier: contactIdentifier),
              let mutableContact = detail.mutableCopy() as? CNMutableContact else { return }
        guard index < mutableContact.phoneNumbers.count else { return }
        mutableContact.phoneNumbers.remove(at: index)
        saveAndRefresh(mutableContact)
    }

    private func deleteEmailAddress(at index: Int) {
        guard let detail = contactStore.fetchContactDetail(identifier: contactIdentifier),
              let mutableContact = detail.mutableCopy() as? CNMutableContact else { return }
        guard index < mutableContact.emailAddresses.count else { return }
        mutableContact.emailAddresses.remove(at: index)
        saveAndRefresh(mutableContact)
    }

    private func deletePostalAddress(at index: Int) {
        guard let detail = contactStore.fetchContactDetail(identifier: contactIdentifier),
              let mutableContact = detail.mutableCopy() as? CNMutableContact else { return }
        guard index < mutableContact.postalAddresses.count else { return }
        mutableContact.postalAddresses.remove(at: index)
        saveAndRefresh(mutableContact)
    }

    private func deleteURL(at index: Int) {
        guard let detail = contactStore.fetchContactDetail(identifier: contactIdentifier),
              let mutableContact = detail.mutableCopy() as? CNMutableContact else { return }
        guard index < mutableContact.urlAddresses.count else { return }
        mutableContact.urlAddresses.remove(at: index)
        saveAndRefresh(mutableContact)
    }

    private func deleteSocialProfile(at index: Int) {
        guard let detail = contactStore.fetchContactDetail(identifier: contactIdentifier),
              let mutableContact = detail.mutableCopy() as? CNMutableContact else { return }
        guard index < mutableContact.socialProfiles.count else { return }
        mutableContact.socialProfiles.remove(at: index)
        saveAndRefresh(mutableContact)
    }

    private func saveAndRefresh(_ mutableContact: CNMutableContact) {
        do {
            try contactStore.saveContact(mutableContact)
            contact = contactStore.fetchContactDetail(identifier: contactIdentifier)
            HapticManager.success()
        } catch {
            HapticManager.error()
        }
    }

    // MARK: - Delete Contact

    private func deleteContact() {
        do {
            try contactStore.softDeleteContact(
                identifier: contactIdentifier,
                recentlyDeletedStore: recentlyDeletedStore,
                tagStore: tagStore,
                interactionLogStore: interactionLogStore
            )
            HapticManager.warning()
            dismiss()
        } catch {
            HapticManager.error()
        }
    }

    // MARK: - Date Formatting

    private func formattedDates(for contact: CNContact) -> [(label: String, value: String)] {
        var results: [(label: String, value: String)] = []

        if let birthday = contact.birthday {
            let dateString = Self.formatDateComponents(birthday)
            results.append((label: "birthday", value: dateString))
        }

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
            if components.year == nil {
                formatter.dateFormat = "MMMM d"
            }
            return formatter.string(from: date)
        }

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
    .environment(TagStore())
    .environment(InteractionLogStore())
    .environment(RecentlyDeletedStore())
    .environment(AppState())
}

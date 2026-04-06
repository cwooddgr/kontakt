import SwiftUI
import Contacts

/// Smart capture flow: single text field that parses input and matches against
/// existing contacts. Handles three outcomes: no match (new person), high-confidence
/// match (update existing), and low-confidence match (ask user).
///
/// Presented when `appState.activeSheet == .newContact`.
struct NewContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContactStore.self) private var contactStore
    @Environment(TagStore.self) private var tagStore

    // MARK: - State Machine

    enum CaptureState {
        case input
        case parsing
        case noMatch(ParsedContact, Bool)
        case highMatch(CNContact, [ContactMatchingService.FieldDiff], ParsedContact)
        case lowMatch(CNContact, ParsedContact)
        case saving
    }

    @State private var captureState: CaptureState = .input
    @State private var freeformText: String = ""
    @State private var debounceTask: Task<Void, Never>?

    // MARK: - Tag State

    @State private var assignedTags: [String] = []
    @State private var isAddingTag: Bool = false
    @State private var newTagText: String = ""
    @FocusState private var isTagFieldFocused: Bool

    // MARK: - Parser

    private let contactParser = ContactParser()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KSpacing.xl) {
                    textInputSection

                    stateContent
                }
                .padding(.horizontal, KSpacing.xl)
                .padding(.top, KSpacing.l)
                .padding(.bottom, KSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        debounceTask?.cancel()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Text Input

    private var textInputSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $freeformText)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(KSpacing.m)
                .background(Color.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
                .onChange(of: freeformText) { _, newValue in
                    scheduleParse(for: newValue)
                }

            if freeformText.isEmpty {
                Text("Paste or dictate anything about anyone.")
                    .font(.kBody)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, KSpacing.m)
                    .padding(.vertical, KSpacing.m + 8)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private var stateContent: some View {
        switch captureState {
        case .input:
            EmptyView()

        case .parsing:
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, KSpacing.m)

        case .noMatch(let parsed, let usedAI):
            noMatchSection(parsed: parsed, usedAI: usedAI)

        case .highMatch(let contact, let diffs, _):
            highMatchSection(contact: contact, diffs: diffs)

        case .lowMatch(let contact, let parsed):
            lowMatchSection(contact: contact, parsed: parsed)

        case .saving:
            ProgressView("Saving...")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, KSpacing.m)
        }
    }

    // MARK: - No Match

    private func noMatchSection(parsed: ParsedContact, usedAI: Bool) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.l) {
            ParsePreviewView(
                parsedContact: parsed,
                usedAI: usedAI,
                onFieldCorrected: { field, newValue in
                    applyFieldCorrection(field: field, newValue: newValue)
                }
            )
            .transition(.opacity)

            tagSection(contactID: nil)

            Button {
                saveNewContact(from: parsed)
            } label: {
                Text("Save")
                    .font(.kBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KSpacing.m)
                    .background(Color.accentSlateBlue)
                    .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - High-Confidence Match

    private func highMatchSection(
        contact: CNContact,
        diffs: [ContactMatchingService.FieldDiff]
    ) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.l) {
            // Header
            Text("This looks like new info for \(contactDisplayName(contact)).")
                .font(.kBody)
                .foregroundStyle(Color.textSecondary)

            // Contact identity
            contactIdentityRow(contact: contact)

            // Diffs
            if !diffs.isEmpty {
                VStack(alignment: .leading, spacing: KSpacing.m) {
                    ForEach(diffs) { diff in
                        diffRow(diff)
                    }
                }
            }

            tagSection(contactID: contact.identifier)

            // Actions
            HStack(spacing: KSpacing.m) {
                Button {
                    updateExistingContact(contact)
                } label: {
                    Text("Update")
                        .font(.kBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KSpacing.m)
                        .background(Color.accentSlateBlue)
                        .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
                }
                .buttonStyle(.plain)

                Button {
                    createNewPersonInstead()
                } label: {
                    Text("New Person Instead")
                        .font(.kBody)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentSlateBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KSpacing.m)
                        .background(Color.surfaceBackground)
                        .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
                        .overlay(
                            RoundedRectangle(cornerRadius: KRadius.m)
                                .strokeBorder(Color.accentSlateBlue.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Low-Confidence Match

    private func lowMatchSection(
        contact: CNContact,
        parsed: ParsedContact
    ) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.l) {
            Text("Is this the same person?")
                .font(.kBody)
                .foregroundStyle(Color.textSecondary)

            // Side-by-side comparison
            HStack(spacing: KSpacing.l) {
                // Existing contact
                VStack(spacing: KSpacing.s) {
                    contactPhoto(contact: contact, size: 56)

                    Text(contactDisplayName(contact))
                        .font(.titlePrimary)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Existing")
                        .font(.label)
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Text("vs")
                    .font(.label)
                    .foregroundStyle(Color.textTertiary)

                // Parsed contact
                VStack(spacing: KSpacing.s) {
                    Circle()
                        .fill(Color.accentSubtle)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(parsedInitials(parsed))
                                .font(.titlePrimary)
                                .foregroundStyle(Color.accentSlateBlue)
                        )

                    Text(parsedFullName(parsed))
                        .font(.titlePrimary)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Parsed")
                        .font(.label)
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, KSpacing.m)

            tagSection(contactID: contact.identifier)

            // Actions
            HStack(spacing: KSpacing.m) {
                Button {
                    confirmLowMatch(contact)
                } label: {
                    Text("Yes, Update")
                        .font(.kBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KSpacing.m)
                        .background(Color.accentSlateBlue)
                        .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
                }
                .buttonStyle(.plain)

                Button {
                    createNewPersonInstead()
                } label: {
                    Text("No, New Person")
                        .font(.kBody)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentSlateBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KSpacing.m)
                        .background(Color.surfaceBackground)
                        .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
                        .overlay(
                            RoundedRectangle(cornerRadius: KRadius.m)
                                .strokeBorder(Color.accentSlateBlue.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tag Section

    private func tagSection(contactID: String?) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.s) {
            // Existing tags + add button
            TagBarView(
                tags: assignedTags,
                onTapTag: { _ in },
                onAddTag: {
                    isAddingTag = true
                    isTagFieldFocused = true
                },
                isEditable: true,
                onRemoveTag: { tag in
                    assignedTags.removeAll { $0 == tag }
                }
            )

            // Inline tag creation
            if isAddingTag {
                HStack(spacing: KSpacing.s) {
                    TextField("Tag name", text: $newTagText)
                        .font(.kBody)
                        .textFieldStyle(.plain)
                        .focused($isTagFieldFocused)
                        .onSubmit {
                            commitNewTag()
                        }

                    Button {
                        commitNewTag()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentSlateBlue)
                            .font(.system(size: 20, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        isAddingTag = false
                        newTagText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.textTertiary)
                            .font(.system(size: 20, weight: .medium))
                    }
                    .buttonStyle(.plain)
                }
                .padding(KSpacing.m)
                .background(Color.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
            }

            // Tag suggestions (recent + frequent)
            if !suggestedTags.isEmpty {
                VStack(alignment: .leading, spacing: KSpacing.xs) {
                    Text("Suggestions")
                        .font(.label)
                        .foregroundStyle(Color.textTertiary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: KSpacing.xs) {
                            ForEach(suggestedTags, id: \.self) { tag in
                                Button {
                                    if !assignedTags.contains(tag) {
                                        assignedTags.append(tag)
                                    }
                                } label: {
                                    Text(tag)
                                        .font(.label)
                                        .foregroundStyle(Color.accentSlateBlue)
                                        .padding(.horizontal, KSpacing.s)
                                        .padding(.vertical, KSpacing.xs)
                                        .background(Color.accentSubtle)
                                        .clipShape(RoundedRectangle(cornerRadius: KRadius.s))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Recent and frequently used tags that are not already assigned.
    private var suggestedTags: [String] {
        let recent = tagStore.recentTags
        let frequent = tagStore.allTags
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map(\.name)
        let merged = Array(Set(recent + frequent))
        return merged.filter { !assignedTags.contains($0) }.sorted()
    }

    // MARK: - Shared UI Components

    private func contactIdentityRow(contact: CNContact) -> some View {
        HStack(spacing: KSpacing.m) {
            contactPhoto(contact: contact, size: 48)

            VStack(alignment: .leading, spacing: KSpacing.xs) {
                Text(contactDisplayName(contact))
                    .font(.titlePrimary)
                    .foregroundStyle(Color.textPrimary)

                if !contact.organizationName.isEmpty {
                    Text(contact.organizationName)
                        .font(.titleSecondary)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func contactPhoto(contact: CNContact, size: CGFloat) -> some View {
        if contact.isKeyAvailable(CNContactThumbnailImageDataKey),
           let imageData = contact.thumbnailImageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.accentSubtle)
                .frame(width: size, height: size)
                .overlay(
                    Text(contactInitials(contact))
                        .font(size > 40 ? .titlePrimary : .label)
                        .foregroundStyle(Color.accentSlateBlue)
                )
        }
    }

    private func diffRow(_ diff: ContactMatchingService.FieldDiff) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.xs) {
            if let oldValue = diff.oldValue {
                Text("New \(diff.fieldName.lowercased()) (was: \(oldValue)):")
                    .font(.label)
                    .foregroundStyle(Color.textTertiary)
            } else {
                Text("New \(diff.fieldName.lowercased()):")
                    .font(.label)
                    .foregroundStyle(Color.textTertiary)
            }

            Text(diff.newValue)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, KSpacing.s)
        .padding(.vertical, KSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentSubtle)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.s))
    }

    // MARK: - Helpers

    private func contactDisplayName(_ contact: CNContact) -> String {
        let name = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? contact.organizationName : name
    }

    private func contactInitials(_ contact: CNContact) -> String {
        let parts = [contact.givenName, contact.familyName].filter { !$0.isEmpty }
        if parts.isEmpty {
            return contact.organizationName.isEmpty
                ? "?"
                : String(contact.organizationName.prefix(1)).uppercased()
        }
        return parts
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
    }

    private func parsedFullName(_ parsed: ParsedContact) -> String {
        [parsed.givenName.value, parsed.familyName.value]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func parsedInitials(_ parsed: ParsedContact) -> String {
        let parts = [parsed.givenName.value, parsed.familyName.value]
            .filter { !$0.isEmpty }
        if parts.isEmpty { return "?" }
        return parts
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
    }

    // MARK: - Parsing

    private func scheduleParse(for text: String) {
        debounceTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            captureState = .input
            return
        }

        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            captureState = .parsing

            let (parsed, usedAI) = await contactParser.parse(trimmed)
            guard !Task.isCancelled else { return }

            // Run matching
            let matchResult = ContactMatchingService.findMatch(
                for: parsed,
                in: contactStore
            )

            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.2)) {
                switch matchResult {
                case .highConfidence(let contact, let diffs):
                    // Load existing tags for the matched contact
                    assignedTags = tagStore.tags(for: contact.identifier)
                    captureState = .highMatch(contact, diffs, parsed)

                case .lowConfidence(let contact, _):
                    assignedTags = tagStore.tags(for: contact.identifier)
                    captureState = .lowMatch(contact, parsed)

                case .noMatch:
                    assignedTags = []
                    captureState = .noMatch(parsed, usedAI)
                }
            }
        }
    }

    // MARK: - Field Correction (for noMatch preview)

    private func applyFieldCorrection(field: EditableField, newValue: String) {
        guard case .noMatch(var parsed, let usedAI) = captureState else { return }

        switch field {
        case .namePrefix:
            parsed.namePrefix = .high(newValue)
        case .givenName:
            parsed.givenName = .high(newValue)
        case .familyName:
            parsed.familyName = .high(newValue)
        case .jobTitle:
            parsed.jobTitle = .high(newValue)
        case .organization:
            parsed.organization = .high(newValue)
        case .street:
            if parsed.address == nil {
                parsed.address = ParsedAddress(
                    street: .high(newValue), city: .low(""), state: .low(""),
                    postalCode: .low(""), countryCode: .low(""))
            } else {
                parsed.address?.street = .high(newValue)
            }
        case .city:
            if parsed.address == nil {
                parsed.address = ParsedAddress(
                    street: .low(""), city: .high(newValue), state: .low(""),
                    postalCode: .low(""), countryCode: .low(""))
            } else {
                parsed.address?.city = .high(newValue)
            }
        case .state:
            if parsed.address == nil {
                parsed.address = ParsedAddress(
                    street: .low(""), city: .low(""), state: .high(newValue),
                    postalCode: .low(""), countryCode: .low(""))
            } else {
                parsed.address?.state = .high(newValue)
            }
        case .postalCode:
            if parsed.address == nil {
                parsed.address = ParsedAddress(
                    street: .low(""), city: .low(""), state: .low(""),
                    postalCode: .high(newValue), countryCode: .low(""))
            } else {
                parsed.address?.postalCode = .high(newValue)
            }
        case .phone(let index):
            if index < parsed.phoneNumbers.count {
                parsed.phoneNumbers[index] = (value: newValue, confidence: .high)
            }
        case .email(let index):
            if index < parsed.emailAddresses.count {
                parsed.emailAddresses[index] = (value: newValue, confidence: .high)
            }
        }

        captureState = .noMatch(parsed, usedAI)
    }

    // MARK: - Tag Management

    private func commitNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !assignedTags.contains(trimmed) {
            assignedTags.append(trimmed)
        }
        newTagText = ""
        isAddingTag = false
    }

    // MARK: - Save Actions

    private func saveNewContact(from parsed: ParsedContact) {
        captureState = .saving
        let contact = parsed.toCNMutableContact()

        do {
            try contactStore.saveContact(contact)
            applyTagsToContact(identifier: contact.identifier)
            contactStore.fetchAllContacts()
            HapticManager.success()
            dismiss()
        } catch {
            HapticManager.error()
            captureState = .noMatch(parsed, false)
        }
    }

    private func updateExistingContact(_ existingContact: CNContact) {
        guard case .highMatch(_, let diffs, let parsed) = captureState else { return }
        captureState = .saving

        let mutableContact = existingContact.mutableCopy() as! CNMutableContact
        ContactMatchingService.mergeFields(from: parsed, into: mutableContact)

        do {
            try contactStore.saveContact(mutableContact)
            applyTagsToContact(identifier: existingContact.identifier)
            contactStore.fetchAllContacts()
            HapticManager.success()
            dismiss()
        } catch {
            HapticManager.error()
            captureState = .highMatch(existingContact, diffs, parsed)
        }
    }

    private func confirmLowMatch(_ existingContact: CNContact) {
        guard case .lowMatch(_, let parsed) = captureState else { return }
        captureState = .saving

        let mutableContact = existingContact.mutableCopy() as! CNMutableContact
        ContactMatchingService.mergeFields(from: parsed, into: mutableContact)

        do {
            try contactStore.saveContact(mutableContact)
            applyTagsToContact(identifier: existingContact.identifier)
            contactStore.fetchAllContacts()
            HapticManager.success()
            dismiss()
        } catch {
            HapticManager.error()
            captureState = .lowMatch(existingContact, parsed)
        }
    }

    private func createNewPersonInstead() {
        // Extract the parsed contact from whichever match state we're in
        let parsed: ParsedContact
        switch captureState {
        case .highMatch(_, _, let p):
            parsed = p
        case .lowMatch(_, let p):
            parsed = p
        default:
            return
        }

        assignedTags = []
        withAnimation(.easeOut(duration: 0.2)) {
            captureState = .noMatch(parsed, false)
        }
    }

    private func applyTagsToContact(identifier: String) {
        for tag in assignedTags {
            tagStore.addTag(tag, to: identifier)
        }
    }
}

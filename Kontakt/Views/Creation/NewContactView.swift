import SwiftUI
import Contacts

/// Sheet view for creating a new contact via freeform text or manual field entry.
///
/// Presented when `appState.activeSheet == .newContact`. Provides two input modes:
/// 1. **Freeform** (primary): A multiline text area where users type or paste contact info.
///    After a 0.3s debounce, `ContactParser` parses the text and shows a live preview.
/// 2. **Manual** (fallback): Traditional text fields for each contact property.
///    Tapping into manual fields collapses the freeform area.
struct NewContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContactStore.self) private var contactStore

    // MARK: - Freeform State

    @State private var freeformText: String = ""
    @State private var parsedContact: ParsedContact?
    @State private var usedAI: Bool = false
    @State private var isParsing: Bool = false
    @State private var debounceTask: Task<Void, Never>?

    // MARK: - Manual Fields State

    @State private var manualFirstName: String = ""
    @State private var manualLastName: String = ""
    @State private var manualPhones: [String] = [""]
    @State private var manualEmails: [String] = [""]
    @State private var manualCompany: String = ""
    @State private var manualJobTitle: String = ""

    // MARK: - Mode State

    @State private var isManualMode: Bool = false
    @State private var isSaving: Bool = false

    // MARK: - Parser

    private let contactParser = ContactParser()

    // MARK: - Computed Properties

    /// Save is enabled when at least one meaningful field is populated.
    private var canSave: Bool {
        if isManualMode {
            return !manualFirstName.trimmingCharacters(in: .whitespaces).isEmpty
                || !manualLastName.trimmingCharacters(in: .whitespaces).isEmpty
                || manualPhones.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
                || manualEmails.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        } else {
            guard let parsed = parsedContact else { return false }
            return !parsed.givenName.value.isEmpty
                || !parsed.familyName.value.isEmpty
                || parsed.phoneNumbers.contains(where: { !$0.value.isEmpty })
                || parsed.emailAddresses.contains(where: { !$0.value.isEmpty })
                || !(parsed.address?.street.value.isEmpty ?? true)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KSpacing.xl) {
                    if !isManualMode {
                        freeformSection
                    }

                    orDivider

                    manualFieldsSection
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
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveContact()
                    }
                    .disabled(!canSave || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Freeform Section

    private var freeformSection: some View {
        VStack(alignment: .leading, spacing: KSpacing.m) {
            freeformEditor

            if isParsing {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, KSpacing.s)
            }

            if let parsed = parsedContact {
                ParsePreviewView(
                    parsedContact: parsed,
                    usedAI: usedAI,
                    onFieldCorrected: { field, newValue in
                        applyFieldCorrection(field: field, newValue: newValue)
                    }
                )
                .transition(.opacity)
            }
        }
    }

    private var freeformEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $freeformText)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 72)
                .padding(KSpacing.m)
                .background(Color.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
                .onChange(of: freeformText) { _, newValue in
                    scheduleParse(for: newValue)
                }

            if freeformText.isEmpty {
                Text("Type or paste contact info...")
                    .font(.kBody)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, KSpacing.m)
                    .padding(.vertical, KSpacing.m + 8) // Offset for TextEditor internal padding
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Or Divider

    private var orDivider: some View {
        HStack(spacing: KSpacing.m) {
            dashedLine
            Text("or enter manually")
                .font(.label)
                .foregroundStyle(Color.textTertiary)
                .layoutPriority(1)
            dashedLine
        }
    }

    private var dashedLine: some View {
        Rectangle()
            .fill(Color(UIColor.separator))
            .frame(height: 1)
    }

    // MARK: - Manual Fields Section

    private var manualFieldsSection: some View {
        VStack(alignment: .leading, spacing: KSpacing.l) {
            if !isManualMode {
                // Collapsed state: show a prompt to expand
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isManualMode = true
                    }
                } label: {
                    Text("Enter fields manually")
                        .font(.label)
                        .foregroundStyle(Color.accentSlateBlue)
                }
            } else {
                // Expanded manual fields
                expandedManualFields
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var expandedManualFields: some View {
        VStack(alignment: .leading, spacing: KSpacing.l) {
            // Name fields
            manualTextField(label: "First name", text: $manualFirstName)
            manualTextField(label: "Last name", text: $manualLastName)

            // Phone fields
            fieldGroupWithAdd(
                label: "Phone",
                values: $manualPhones,
                keyboardType: .phonePad
            )

            // Email fields
            fieldGroupWithAdd(
                label: "Email",
                values: $manualEmails,
                keyboardType: .emailAddress
            )

            // Company and Job Title
            manualTextField(label: "Company", text: $manualCompany)
            manualTextField(label: "Job title", text: $manualJobTitle)
        }
    }

    // MARK: - Manual Field Components

    private func manualTextField(
        label: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.xs) {
            Text(label)
                .font(.label)
                .foregroundStyle(Color.textTertiary)

            TextField(label, text: text)
                .font(.kBody)
                .keyboardType(keyboardType)
                .textFieldStyle(.plain)
                .padding(KSpacing.m)
                .background(Color.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
        }
    }

    private func fieldGroupWithAdd(
        label: String,
        values: Binding<[String]>,
        keyboardType: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.s) {
            ForEach(values.wrappedValue.indices, id: \.self) { index in
                manualTextField(
                    label: "\(label) \(values.wrappedValue.count > 1 ? "\(index + 1)" : "")",
                    text: Binding(
                        get: { values.wrappedValue[index] },
                        set: { values.wrappedValue[index] = $0 }
                    ),
                    keyboardType: keyboardType
                )
            }

            Button {
                values.wrappedValue.append("")
            } label: {
                HStack(spacing: KSpacing.xs) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14, weight: .regular))
                    Text("Add \(label.lowercased())")
                        .font(.label)
                }
                .foregroundStyle(Color.accentSlateBlue)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Parsing

    private func scheduleParse(for text: String) {
        debounceTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parsedContact = nil
            usedAI = false
            isParsing = false
            return
        }

        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isParsing = true
            let (result, aiUsed) = await contactParser.parse(trimmed)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.2)) {
                parsedContact = result
                usedAI = aiUsed
                isParsing = false
            }
        }
    }

    // MARK: - Field Correction

    private func applyFieldCorrection(field: EditableField, newValue: String) {
        guard parsedContact != nil else { return }

        switch field {
        case .namePrefix:
            parsedContact?.namePrefix = .high(newValue)
        case .givenName:
            parsedContact?.givenName = .high(newValue)
        case .familyName:
            parsedContact?.familyName = .high(newValue)
        case .jobTitle:
            parsedContact?.jobTitle = .high(newValue)
        case .organization:
            parsedContact?.organization = .high(newValue)
        case .street:
            if parsedContact?.address == nil {
                parsedContact?.address = ParsedAddress(
                    street: .high(newValue), city: .low(""), state: .low(""), postalCode: .low(""), countryCode: .low(""))
            } else {
                parsedContact?.address?.street = .high(newValue)
            }
        case .city:
            parsedContact?.address?.city = .high(newValue)
        case .state:
            parsedContact?.address?.state = .high(newValue)
        case .postalCode:
            parsedContact?.address?.postalCode = .high(newValue)
        case .phone(let index):
            if index < (parsedContact?.phoneNumbers.count ?? 0) {
                parsedContact?.phoneNumbers[index] = (value: newValue, confidence: .high)
            }
        case .email(let index):
            if index < (parsedContact?.emailAddresses.count ?? 0) {
                parsedContact?.emailAddresses[index] = (value: newValue, confidence: .high)
            }
        }
    }

    // MARK: - Save

    private func saveContact() {
        isSaving = true
        let contact: CNMutableContact

        if isManualMode {
            contact = buildManualContact()
        } else if let parsed = parsedContact {
            contact = parsed.toCNMutableContact()
        } else {
            isSaving = false
            return
        }

        do {
            try contactStore.saveContact(contact)
            HapticManager.success()
            dismiss()
        } catch {
            HapticManager.error()
            isSaving = false
        }
    }

    private func buildManualContact() -> CNMutableContact {
        let contact = CNMutableContact()

        let firstName = manualFirstName.trimmingCharacters(in: .whitespaces)
        let lastName = manualLastName.trimmingCharacters(in: .whitespaces)
        let company = manualCompany.trimmingCharacters(in: .whitespaces)
        let jobTitle = manualJobTitle.trimmingCharacters(in: .whitespaces)

        if !firstName.isEmpty { contact.givenName = firstName }
        if !lastName.isEmpty { contact.familyName = lastName }
        if !company.isEmpty { contact.organizationName = company }
        if !jobTitle.isEmpty { contact.jobTitle = jobTitle }

        for phone in manualPhones {
            let trimmed = phone.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                contact.phoneNumbers.append(
                    CNLabeledValue(
                        label: CNLabelPhoneNumberMobile,
                        value: CNPhoneNumber(stringValue: trimmed)
                    )
                )
            }
        }

        for email in manualEmails {
            let trimmed = email.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                contact.emailAddresses.append(
                    CNLabeledValue(
                        label: CNLabelHome,
                        value: trimmed as NSString
                    )
                )
            }
        }

        return contact
    }
}

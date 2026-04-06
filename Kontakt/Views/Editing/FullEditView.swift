import SwiftUI
import Contacts

/// Full structural editing of a contact.
///
/// Loads a `CNContact` by identifier, presents all editable fields in a
/// sectioned list, and builds a `CNMutableContact` on save. Supports
/// adding/removing labeled values (phones, emails, addresses, URLs, dates,
/// social profiles) and editing name, company, and notes fields.
struct FullEditView: View {

    // MARK: - Configuration

    let contactIdentifier: String
    let contactStore: ContactStore

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State: Loading

    @State private var loadedContact: CNContact?
    @State private var loadError: Bool = false

    // MARK: - State: Name Fields

    @State private var namePrefix: String = ""
    @State private var givenName: String = ""
    @State private var familyName: String = ""
    @State private var nameSuffix: String = ""

    // MARK: - State: Company Fields

    @State private var organizationName: String = ""
    @State private var jobTitle: String = ""
    @State private var departmentName: String = ""

    // MARK: - State: Labeled Values

    @State private var phoneNumbers: [LabeledStringValue] = []
    @State private var emailAddresses: [LabeledStringValue] = []
    @State private var postalAddresses: [LabeledPostalAddress] = []
    @State private var urlAddresses: [LabeledStringValue] = []
    @State private var dates: [LabeledDateValue] = []
    @State private var socialProfiles: [LabeledSocialProfile] = []
    @State private var relatedNames: [LabeledStringValue] = []

    // MARK: - State: Notes

    @State private var notes: String = ""

    // MARK: - State: UI

    @State private var showAddFieldPicker: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showAddressEditor: AddressEditorState?
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    // MARK: - Types

    /// Editable phone/email/URL/related name row.
    struct LabeledStringValue: Identifiable {
        let id = UUID()
        var label: String
        var value: String
    }

    /// Editable postal address row.
    struct LabeledPostalAddress: Identifiable {
        let id = UUID()
        var label: String
        var street: String
        var city: String
        var state: String
        var postalCode: String
        var country: String
        var isoCountryCode: String
    }

    /// Editable date row.
    struct LabeledDateValue: Identifiable {
        let id = UUID()
        var label: String
        var date: Date
    }

    /// Editable social profile row.
    struct LabeledSocialProfile: Identifiable {
        let id = UUID()
        var label: String
        var service: String
        var username: String
        var urlString: String
    }

    /// State for presenting the address editor sheet.
    struct AddressEditorState: Identifiable {
        let id = UUID()
        let index: Int
        let initialText: String?
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if loadError {
                    errorContent
                } else if loadedContact == nil {
                    ProgressView()
                } else {
                    editForm
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .onAppear {
                loadContact()
            }
            .alert("Error", isPresented: .constant(saveError != nil)) {
                Button("OK") {
                    saveError = nil
                }
            } message: {
                if let error = saveError {
                    Text(error)
                }
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
                Text("This contact will be permanently deleted from all your devices.")
            }
            .sheet(item: $showAddressEditor) { editorState in
                FreeformAddressInput(
                    initialText: editorState.initialText,
                    onSave: { parsed in
                        applyParsedAddress(parsed, at: editorState.index)
                        showAddressEditor = nil
                    },
                    onCancel: {
                        showAddressEditor = nil
                    }
                )
            }
            .sheet(isPresented: $showAddFieldPicker) {
                addFieldSheet
            }
        }
    }

    // MARK: - Error State

    @ViewBuilder
    private var errorContent: some View {
        ContentUnavailableView {
            Label("Unable to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text("This contact could not be loaded for editing.")
        } actions: {
            Button("Dismiss") {
                dismiss()
            }
        }
    }

    // MARK: - Edit Form

    @ViewBuilder
    private var editForm: some View {
        List {
            nameSection
            companySection
            phoneSection
            emailSection
            postalAddressSection
            urlSection
            dateSection
            socialProfileSection
            relatedNameSection
            notesSection
            addFieldSection
            deleteSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Name Section

    @ViewBuilder
    private var nameSection: some View {
        Section {
            editableTextField("Prefix", text: $namePrefix)
            editableTextField("First name", text: $givenName)
            editableTextField("Last name", text: $familyName)
            editableTextField("Suffix", text: $nameSuffix)
        } header: {
            Text("Name")
        }
    }

    // MARK: - Company Section

    @ViewBuilder
    private var companySection: some View {
        Section {
            editableTextField("Organization", text: $organizationName)
            editableTextField("Job title", text: $jobTitle)
            editableTextField("Department", text: $departmentName)
        } header: {
            Text("Company")
        }
    }

    // MARK: - Phone Section

    @ViewBuilder
    private var phoneSection: some View {
        if !phoneNumbers.isEmpty {
            Section {
                ForEach($phoneNumbers) { $phone in
                    labeledValueRow(
                        label: $phone.label,
                        value: $phone.value,
                        labelOptions: phoneLabelOptions,
                        keyboardType: .phonePad
                    )
                }
                .onDelete { offsets in
                    phoneNumbers.remove(atOffsets: offsets)
                }
            } header: {
                Text("Phone")
            }
        }
    }

    // MARK: - Email Section

    @ViewBuilder
    private var emailSection: some View {
        if !emailAddresses.isEmpty {
            Section {
                ForEach($emailAddresses) { $email in
                    labeledValueRow(
                        label: $email.label,
                        value: $email.value,
                        labelOptions: genericLabelOptions,
                        keyboardType: .emailAddress
                    )
                }
                .onDelete { offsets in
                    emailAddresses.remove(atOffsets: offsets)
                }
            } header: {
                Text("Email")
            }
        }
    }

    // MARK: - Postal Address Section

    @ViewBuilder
    private var postalAddressSection: some View {
        if !postalAddresses.isEmpty {
            Section {
                ForEach(Array(postalAddresses.enumerated()), id: \.element.id) { index, address in
                    VStack(alignment: .leading, spacing: KSpacing.s) {
                        labelPicker(
                            selection: $postalAddresses[index].label,
                            options: genericLabelOptions
                        )

                        addressSummary(address)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let text = formatAddressForEditing(address)
                                showAddressEditor = AddressEditorState(
                                    index: index,
                                    initialText: text.isEmpty ? nil : text
                                )
                            }
                    }
                }
                .onDelete { offsets in
                    postalAddresses.remove(atOffsets: offsets)
                }
            } header: {
                Text("Address")
            }
        }
    }

    @ViewBuilder
    private func addressSummary(_ address: LabeledPostalAddress) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if !address.street.isEmpty {
                Text(address.street)
                    .font(.kBody)
                    .foregroundStyle(Color.textPrimary)
            }
            let cityStateZip = [address.city, address.state, address.postalCode]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            if !cityStateZip.isEmpty {
                Text(cityStateZip)
                    .font(.kBody)
                    .foregroundStyle(Color.textPrimary)
            }
            if address.street.isEmpty && cityStateZip.isEmpty {
                Text("Tap to edit address")
                    .font(.kBody)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    // MARK: - URL Section

    @ViewBuilder
    private var urlSection: some View {
        if !urlAddresses.isEmpty {
            Section {
                ForEach($urlAddresses) { $url in
                    labeledValueRow(
                        label: $url.label,
                        value: $url.value,
                        labelOptions: urlLabelOptions,
                        keyboardType: .URL
                    )
                }
                .onDelete { offsets in
                    urlAddresses.remove(atOffsets: offsets)
                }
            } header: {
                Text("URL")
            }
        }
    }

    // MARK: - Date Section

    @ViewBuilder
    private var dateSection: some View {
        if !dates.isEmpty {
            Section {
                ForEach($dates) { $dateValue in
                    VStack(alignment: .leading, spacing: KSpacing.xs) {
                        labelPicker(
                            selection: $dateValue.label,
                            options: dateLabelOptions
                        )

                        DatePicker(
                            "",
                            selection: $dateValue.date,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                }
                .onDelete { offsets in
                    dates.remove(atOffsets: offsets)
                }
            } header: {
                Text("Dates")
            }
        }
    }

    // MARK: - Social Profile Section

    @ViewBuilder
    private var socialProfileSection: some View {
        if !socialProfiles.isEmpty {
            Section {
                ForEach($socialProfiles) { $profile in
                    VStack(alignment: .leading, spacing: KSpacing.xs) {
                        editableTextField("Service", text: $profile.service)
                        editableTextField("Username", text: $profile.username)
                    }
                }
                .onDelete { offsets in
                    socialProfiles.remove(atOffsets: offsets)
                }
            } header: {
                Text("Social Profiles")
            }
        }
    }

    // MARK: - Related Names Section

    @ViewBuilder
    private var relatedNameSection: some View {
        if !relatedNames.isEmpty {
            Section {
                ForEach($relatedNames) { $related in
                    labeledValueRow(
                        label: $related.label,
                        value: $related.value,
                        labelOptions: relatedNameLabelOptions,
                        keyboardType: .default
                    )
                }
                .onDelete { offsets in
                    relatedNames.remove(atOffsets: offsets)
                }
            } header: {
                Text("Related Names")
            }
        }
    }

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
        } header: {
            Text("Notes")
        }
    }

    // MARK: - Add Field Section

    @ViewBuilder
    private var addFieldSection: some View {
        Section {
            Button {
                showAddFieldPicker = true
            } label: {
                Label("Add Field", systemImage: "plus.circle")
                    .font(.kBody)
                    .foregroundStyle(Color.accentSlateBlue)
            }
        }
    }

    // MARK: - Delete Section

    @ViewBuilder
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Contact")
                        .font(.kBody)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Reusable Row Components

    @ViewBuilder
    private func editableTextField(
        _ placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.kBody)
            .foregroundStyle(Color.textPrimary)
            .keyboardType(keyboardType)
    }

    @ViewBuilder
    private func labeledValueRow(
        label: Binding<String>,
        value: Binding<String>,
        labelOptions: [(String, String)],
        keyboardType: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.xs) {
            labelPicker(selection: label, options: labelOptions)

            TextField("", text: value)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)
                .keyboardType(keyboardType)
                .autocorrectionDisabled(keyboardType != .default)
                .textInputAutocapitalization(
                    keyboardType == .emailAddress || keyboardType == .URL
                        ? .never : .words
                )
        }
    }

    @ViewBuilder
    private func labelPicker(
        selection: Binding<String>,
        options: [(String, String)]
    ) -> some View {
        Menu {
            ForEach(options, id: \.0) { (value, display) in
                Button {
                    selection.wrappedValue = value
                } label: {
                    if selection.wrappedValue == value {
                        Label(display, systemImage: "checkmark")
                    } else {
                        Text(display)
                    }
                }
            }
        } label: {
            HStack(spacing: KSpacing.xs) {
                Text(displayNameForLabel(selection.wrappedValue, in: options))
                    .font(.label)
                    .foregroundStyle(Color.accentSlateBlue)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accentSlateBlue)
            }
        }
    }

    // MARK: - Add Field Sheet

    @ViewBuilder
    private var addFieldSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ContactFieldTypeInfo.modernFieldTypes) { fieldType in
                        Button {
                            addField(fieldType)
                            showAddFieldPicker = false
                        } label: {
                            Label(fieldType.label, systemImage: iconForFieldType(fieldType))
                                .font(.kBody)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                } header: {
                    Text("Fields")
                }

                Section {
                    DisclosureGroup("Legacy") {
                        ForEach(ContactFieldTypeInfo.legacyFieldTypes) { fieldType in
                            Button {
                                addField(fieldType)
                                showAddFieldPicker = false
                            } label: {
                                Text(fieldType.label)
                                    .font(.kBody)
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                    }
                    .font(.kBody)
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddFieldPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Label Options

    private var phoneLabelOptions: [(String, String)] {
        [
            (CNLabelPhoneNumberMobile, "Mobile"),
            (CNLabelHome, "Home"),
            (CNLabelWork, "Work"),
            (CNLabelPhoneNumberMain, "Main"),
            (CNLabelPhoneNumberiPhone, "iPhone"),
            (CNLabelOther, "Other"),
        ]
    }

    private var genericLabelOptions: [(String, String)] {
        [
            (CNLabelHome, "Home"),
            (CNLabelWork, "Work"),
            (CNLabelSchool, "School"),
            (CNLabelOther, "Other"),
        ]
    }

    private var urlLabelOptions: [(String, String)] {
        [
            (CNLabelURLAddressHomePage, "Homepage"),
            (CNLabelHome, "Home"),
            (CNLabelWork, "Work"),
            (CNLabelOther, "Other"),
        ]
    }

    private var dateLabelOptions: [(String, String)] {
        [
            (CNLabelDateAnniversary, "Anniversary"),
            (CNLabelOther, "Other"),
        ]
    }

    private var relatedNameLabelOptions: [(String, String)] {
        [
            (CNLabelContactRelationSpouse, "Spouse"),
            (CNLabelContactRelationPartner, "Partner"),
            (CNLabelContactRelationChild, "Child"),
            (CNLabelContactRelationParent, "Parent"),
            (CNLabelContactRelationFather, "Father"),
            (CNLabelContactRelationMother, "Mother"),
            (CNLabelContactRelationSister, "Sister"),
            (CNLabelContactRelationBrother, "Brother"),
            (CNLabelContactRelationFriend, "Friend"),
            (CNLabelContactRelationAssistant, "Assistant"),
            (CNLabelContactRelationManager, "Manager"),
            (CNLabelOther, "Other"),
        ]
    }

    // MARK: - Helpers

    private func displayNameForLabel(_ label: String, in options: [(String, String)]) -> String {
        options.first(where: { $0.0 == label })?.1
            ?? CNLabelMapping.displayName(for: label)
    }

    private func iconForFieldType(_ fieldType: ContactFieldTypeInfo) -> String {
        switch fieldType.category {
        case .phone: return "phone"
        case .email: return "envelope"
        case .address: return "mappin.and.ellipse"
        case .url: return "link"
        case .date: return "calendar"
        case .note: return "note.text"
        case .relatedName: return "person.2"
        case .socialProfile: return "at"
        case .instantMessage: return "message"
        }
    }

    private func formatAddressForEditing(_ address: LabeledPostalAddress) -> String {
        var parts: [String] = []
        if !address.street.isEmpty { parts.append(address.street) }
        var cityLine = [address.city, address.state].filter { !$0.isEmpty }.joined(separator: ", ")
        if !address.postalCode.isEmpty {
            cityLine += cityLine.isEmpty ? address.postalCode : " \(address.postalCode)"
        }
        if !cityLine.isEmpty { parts.append(cityLine) }
        return parts.joined(separator: "\n")
    }

    // MARK: - Data Loading

    private func loadContact() {
        guard let contact = contactStore.fetchContactDetail(identifier: contactIdentifier) else {
            loadError = true
            return
        }

        loadedContact = contact

        // Populate name fields
        namePrefix = contact.namePrefix
        givenName = contact.givenName
        familyName = contact.familyName
        nameSuffix = contact.nameSuffix

        // Populate company fields
        organizationName = contact.organizationName
        jobTitle = contact.jobTitle
        departmentName = contact.departmentName

        // Populate phone numbers
        phoneNumbers = contact.phoneNumbers.map { labeled in
            LabeledStringValue(
                label: labeled.label ?? CNLabelOther,
                value: labeled.value.stringValue
            )
        }

        // Populate emails
        emailAddresses = contact.emailAddresses.map { labeled in
            LabeledStringValue(
                label: labeled.label ?? CNLabelOther,
                value: labeled.value as String
            )
        }

        // Populate postal addresses
        postalAddresses = contact.postalAddresses.map { labeled in
            let addr = labeled.value
            return LabeledPostalAddress(
                label: labeled.label ?? CNLabelOther,
                street: addr.street,
                city: addr.city,
                state: addr.state,
                postalCode: addr.postalCode,
                country: addr.country,
                isoCountryCode: addr.isoCountryCode
            )
        }

        // Populate URLs
        urlAddresses = contact.urlAddresses.map { labeled in
            LabeledStringValue(
                label: labeled.label ?? CNLabelOther,
                value: labeled.value as String
            )
        }

        // Populate dates
        dates = contact.dates.compactMap { labeled in
            let dateComponents = labeled.value as DateComponents
            guard let date = Calendar.current.date(from: dateComponents) else {
                return nil
            }
            return LabeledDateValue(
                label: labeled.label ?? CNLabelOther,
                date: date
            )
        }

        // Populate birthday as a date entry
        if let birthday = contact.birthday,
           let date = Calendar.current.date(from: birthday) {
            dates.insert(
                LabeledDateValue(label: "birthday", date: date),
                at: 0
            )
        }

        // Populate social profiles
        socialProfiles = contact.socialProfiles.map { labeled in
            let profile = labeled.value
            return LabeledSocialProfile(
                label: labeled.label ?? CNLabelOther,
                service: profile.service,
                username: profile.username,
                urlString: profile.urlString
            )
        }

        // Populate related names
        relatedNames = contact.contactRelations.map { labeled in
            LabeledStringValue(
                label: labeled.label ?? CNLabelOther,
                value: labeled.value.name
            )
        }

        // Populate notes
        notes = contact.note
    }

    // MARK: - Add Field

    private func addField(_ fieldType: ContactFieldTypeInfo) {
        switch fieldType.category {
        case .phone:
            phoneNumbers.append(LabeledStringValue(label: CNLabelPhoneNumberMobile, value: ""))
        case .email:
            emailAddresses.append(LabeledStringValue(label: CNLabelHome, value: ""))
        case .address:
            postalAddresses.append(LabeledPostalAddress(
                label: CNLabelHome,
                street: "", city: "", state: "", postalCode: "", country: "", isoCountryCode: ""
            ))
        case .url:
            urlAddresses.append(LabeledStringValue(label: CNLabelURLAddressHomePage, value: ""))
        case .date:
            if fieldType.id == "birthday" {
                dates.insert(LabeledDateValue(label: "birthday", date: Date()), at: 0)
            } else {
                dates.append(LabeledDateValue(label: CNLabelDateAnniversary, date: Date()))
            }
        case .note:
            // Notes section is always visible; just focus it
            break
        case .relatedName:
            relatedNames.append(LabeledStringValue(label: CNLabelContactRelationFriend, value: ""))
        case .socialProfile:
            socialProfiles.append(LabeledSocialProfile(
                label: CNLabelOther, service: fieldType.label, username: "", urlString: ""
            ))
        case .instantMessage:
            socialProfiles.append(LabeledSocialProfile(
                label: CNLabelOther, service: fieldType.label, username: "", urlString: ""
            ))
        }
    }

    // MARK: - Address Parsing Result

    private func applyParsedAddress(_ parsed: ParsedAddress, at index: Int) {
        guard postalAddresses.indices.contains(index) else { return }
        postalAddresses[index].street = parsed.street.value
        postalAddresses[index].city = parsed.city.value
        postalAddresses[index].state = parsed.state.value
        postalAddresses[index].postalCode = parsed.postalCode.value
        if !parsed.countryCode.value.isEmpty {
            postalAddresses[index].isoCountryCode = parsed.countryCode.value
        }
    }

    // MARK: - Save

    private func save() {
        guard let original = loadedContact else { return }

        isSaving = true

        let mutable = original.mutableCopy() as! CNMutableContact

        // Name
        mutable.namePrefix = namePrefix
        mutable.givenName = givenName
        mutable.familyName = familyName
        mutable.nameSuffix = nameSuffix

        // Company
        mutable.organizationName = organizationName
        mutable.jobTitle = jobTitle
        mutable.departmentName = departmentName

        // Phone numbers
        mutable.phoneNumbers = phoneNumbers
            .filter { !$0.value.isEmpty }
            .map { phone in
                CNLabeledValue(
                    label: phone.label,
                    value: CNPhoneNumber(stringValue: phone.value)
                )
            }

        // Emails
        mutable.emailAddresses = emailAddresses
            .filter { !$0.value.isEmpty }
            .map { email in
                CNLabeledValue(label: email.label, value: email.value as NSString)
            }

        // Postal addresses
        mutable.postalAddresses = postalAddresses
            .filter { !$0.street.isEmpty || !$0.city.isEmpty || !$0.state.isEmpty || !$0.postalCode.isEmpty }
            .map { addr in
                let postal = CNMutablePostalAddress()
                postal.street = addr.street
                postal.city = addr.city
                postal.state = addr.state
                postal.postalCode = addr.postalCode
                postal.country = addr.country
                postal.isoCountryCode = addr.isoCountryCode
                return CNLabeledValue(label: addr.label, value: postal as CNPostalAddress)
            }

        // URLs
        mutable.urlAddresses = urlAddresses
            .filter { !$0.value.isEmpty }
            .map { url in
                CNLabeledValue(label: url.label, value: url.value as NSString)
            }

        // Dates — separate birthday from other dates
        var birthdaySet = false
        var otherDates: [CNLabeledValue<NSDateComponents>] = []

        for dateValue in dates {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: dateValue.date
            )
            let nsComponents = components as NSDateComponents

            if dateValue.label == "birthday" && !birthdaySet {
                mutable.birthday = components
                birthdaySet = true
            } else {
                otherDates.append(
                    CNLabeledValue(label: dateValue.label, value: nsComponents)
                )
            }
        }

        if !birthdaySet {
            mutable.birthday = nil
        }
        mutable.dates = otherDates

        // Social profiles
        mutable.socialProfiles = socialProfiles
            .filter { !$0.username.isEmpty || !$0.service.isEmpty }
            .map { profile in
                let value = CNSocialProfile(
                    urlString: profile.urlString,
                    username: profile.username,
                    userIdentifier: nil,
                    service: profile.service
                )
                return CNLabeledValue(label: profile.label, value: value)
            }

        // Related names
        mutable.contactRelations = relatedNames
            .filter { !$0.value.isEmpty }
            .map { related in
                CNLabeledValue(
                    label: related.label,
                    value: CNContactRelation(name: related.value)
                )
            }

        // Notes
        mutable.note = notes

        // Persist
        do {
            try contactStore.saveContact(mutable)
            HapticManager.success()
            dismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
            HapticManager.error()
        }
    }

    // MARK: - Delete

    private func deleteContact() {
        do {
            try contactStore.deleteContact(identifier: contactIdentifier)
            HapticManager.warning()
            dismiss()
        } catch {
            saveError = "Failed to delete contact: \(error.localizedDescription)"
            HapticManager.error()
        }
    }
}

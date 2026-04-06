import SwiftUI
import Contacts

/// The My Card screen, accessible from Settings.
///
/// Allows the user to designate their own contact as "My Card", select which
/// fields to include when sharing, and generates a QR code containing the
/// filtered vCard data. The QR code regenerates whenever the contact or
/// selected fields change.
struct MyCardView: View {
    @Environment(ContactStore.self) private var contactStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("myCardContactIdentifier") private var contactIdentifier: String = ""
    @AppStorage("myCardFields") private var fieldsStorage: String = "name,phone,email,company"

    @State private var showingContactPicker = false
    @State private var showingShareSheet = false
    @State private var qrImage: UIImage?
    @State private var contact: CNContact?
    @State private var vCardData: Data?

    private let qrSize: CGFloat = 200

    var body: some View {
        Group {
            if contactIdentifier.isEmpty {
                emptyState
            } else if let contact {
                cardContent(for: contact)
            } else {
                // Contact identifier is set but contact could not be loaded.
                VStack(spacing: KSpacing.m) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(Color.textTertiary)

                    Text("Contact Not Found")
                        .font(.titlePrimary)
                        .foregroundStyle(Color.textPrimary)

                    Text("The saved contact could not be loaded.")
                        .font(.titleSecondary)
                        .foregroundStyle(Color.textSecondary)

                    Button("Select a Different Contact") {
                        showingContactPicker = true
                    }
                    .font(.kBody)
                    .foregroundStyle(Color.accentSlateBlue)
                    .padding(.top, KSpacing.m)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("My Card")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingContactPicker) {
            MyCardContactPicker { identifier in
                contactIdentifier = identifier
                loadContact()
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let vCardData {
                ActivityViewController(activityItems: [vCardData])
            }
        }
        .onAppear {
            loadContact()
        }
        .onChange(of: contactIdentifier) { _, _ in
            loadContact()
        }
        .onChange(of: fieldsStorage) { _, _ in
            regenerateQRCode()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: KSpacing.l) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Color.textTertiary)

            Text("No My Card Set")
                .font(.titlePrimary)
                .foregroundStyle(Color.textPrimary)

            Text("Select a contact to use as your card for sharing via QR code.")
                .font(.titleSecondary)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KSpacing.xxl)

            Button {
                showingContactPicker = true
            } label: {
                Text("Set My Card")
                    .font(.action)
                    .foregroundStyle(.white)
                    .padding(.horizontal, KSpacing.xl)
                    .padding(.vertical, KSpacing.m)
                    .background(Color.accentSlateBlue)
                    .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
            }
            .padding(.top, KSpacing.s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Card Content

    private func cardContent(for contact: CNContact) -> some View {
        ScrollView {
            VStack(spacing: KSpacing.xl) {
                // Header: name and company
                headerSection(for: contact)

                // QR code
                qrCodeSection

                // Field toggles
                fieldTogglesSection(for: contact)

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, KSpacing.xl)
            .padding(.vertical, KSpacing.l)
        }
    }

    // MARK: - Header

    private func headerSection(for contact: CNContact) -> some View {
        VStack(spacing: KSpacing.s) {
            ContactPhoto(
                imageData: contact.imageData,
                givenName: contact.givenName,
                familyName: contact.familyName,
                size: 56
            )

            Text(contact.displayName)
                .font(.titlePrimary)
                .foregroundStyle(Color.textPrimary)

            if !contact.organizationName.isEmpty {
                Text(contact.organizationName)
                    .font(.titleSecondary)
                    .foregroundStyle(Color.textSecondary)
            }

            if !contact.jobTitle.isEmpty {
                Text(contact.jobTitle)
                    .font(.titleSecondary)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - QR Code

    private var qrCodeSection: some View {
        Group {
            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: qrSize, height: qrSize)
                    .clipShape(RoundedRectangle(cornerRadius: KRadius.l))
                    .accessibilityLabel("QR code for sharing your contact card")
            } else {
                RoundedRectangle(cornerRadius: KRadius.l)
                    .fill(Color.surfaceBackground)
                    .frame(width: qrSize, height: qrSize)
                    .overlay {
                        VStack(spacing: KSpacing.s) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 32, weight: .thin))
                                .foregroundStyle(Color.textTertiary)
                            Text("Select fields to generate")
                                .font(.label)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
            }
        }
    }

    // MARK: - Field Toggles

    private func fieldTogglesSection(for contact: CNContact) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INCLUDED FIELDS")
                .font(.labelCaps)
                .tracking(0.5)
                .foregroundStyle(Color.textTertiary)
                .padding(.bottom, KSpacing.s)

            ForEach(availableFields(for: contact)) { field in
                fieldToggleRow(field)
            }
        }
    }

    private func fieldToggleRow(_ field: VCardField) -> some View {
        HStack(spacing: KSpacing.m) {
            Image(systemName: field.iconName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 20)

            Text(field.displayName)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Toggle(field.displayName, isOn: fieldBinding(for: field))
                .labelsHidden()
                .tint(Color.accentSlateBlue)
                .accessibilityLabel("Include \(field.displayName)")
        }
        .padding(.vertical, KSpacing.s)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: KSpacing.m) {
            // Share button
            Button {
                generateShareData()
                if vCardData != nil {
                    showingShareSheet = true
                }
            } label: {
                HStack(spacing: KSpacing.s) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share vCard")
                }
                .font(.action)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KSpacing.m)
                .background(Color.accentSlateBlue)
                .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
            }

            // Change My Card button
            Button {
                showingContactPicker = true
            } label: {
                Text("Change My Card")
                    .font(.kBody)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.top, KSpacing.m)
    }

    // MARK: - Field Management

    /// The currently selected fields, derived from the comma-separated AppStorage string.
    private var selectedFields: Set<VCardField> {
        get {
            let rawValues = fieldsStorage.split(separator: ",").map(String.init)
            let fields = rawValues.compactMap { VCardField(rawValue: $0) }
            return Set(fields)
        }
    }

    /// Updates the stored fields string when a field is toggled.
    private func setSelectedFields(_ fields: Set<VCardField>) {
        fieldsStorage = fields.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// Creates a binding for an individual field toggle.
    private func fieldBinding(for field: VCardField) -> Binding<Bool> {
        Binding(
            get: { selectedFields.contains(field) },
            set: { isOn in
                var current = selectedFields
                if isOn {
                    current.insert(field)
                } else {
                    // Prevent deselecting all fields — at least one must remain.
                    if current.count > 1 {
                        current.remove(field)
                    }
                }
                setSelectedFields(current)
            }
        )
    }

    /// Returns only the VCardField cases that have data for this contact.
    /// Name is always available. Other fields are filtered by whether
    /// the contact actually has data for them.
    private func availableFields(for contact: CNContact) -> [VCardField] {
        VCardField.allCases.filter { field in
            switch field {
            case .name:
                return true
            case .phone:
                return !contact.phoneNumbers.isEmpty
            case .email:
                return !contact.emailAddresses.isEmpty
            case .address:
                return !contact.postalAddresses.isEmpty
            case .company:
                return !contact.organizationName.isEmpty
            case .jobTitle:
                return !contact.jobTitle.isEmpty
            case .birthday:
                return contact.birthday != nil
            case .url:
                return !contact.urlAddresses.isEmpty
            case .photo:
                return contact.imageData != nil
            case .note:
                return contact.isKeyAvailable(CNContactNoteKey) && !contact.note.isEmpty
            }
        }
    }

    // MARK: - Data Loading

    /// Loads the full CNContact for the stored identifier.
    private func loadContact() {
        guard !contactIdentifier.isEmpty else {
            contact = nil
            qrImage = nil
            return
        }

        contact = contactStore.fetchContactDetail(identifier: contactIdentifier)
        regenerateQRCode()
    }

    /// Regenerates the QR code from the current contact and selected fields.
    /// Photo is excluded from QR data (too large for QR capacity) but included in shared vCard.
    private func regenerateQRCode() {
        guard let contact else {
            qrImage = nil
            return
        }

        // Exclude photo from QR — photos easily exceed QR's ~2.9KB capacity.
        let qrFields = selectedFields.subtracting([.photo])
        guard let data = VCardService.generateVCard(for: contact, includingFields: qrFields) else {
            qrImage = nil
            return
        }

        // Generate QR code at higher resolution for crisp rendering.
        let scale = UITraitCollection.current.displayScale
        qrImage = VCardService.generateQRCode(from: data, size: qrSize * scale)
    }

    /// Generates fresh vCard data for sharing.
    private func generateShareData() {
        guard let contact else { return }
        vCardData = VCardService.generateVCard(for: contact, includingFields: selectedFields)
    }
}

// MARK: - Activity View Controller

/// UIKit wrapper for UIActivityViewController presented as a SwiftUI sheet.
private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MyCardView()
    }
    .environment(ContactStore())
    .environment(AppState())
}

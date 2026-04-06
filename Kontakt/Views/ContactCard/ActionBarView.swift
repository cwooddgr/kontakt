import SwiftUI
import Contacts

/// Horizontal row of action buttons for a contact card.
///
/// Only renders buttons for data that exists on the contact.
/// If the contact has no actionable data at all, the bar should not be shown.
/// When multiple phone numbers or emails exist, tapping the corresponding button
/// presents a picker sheet.
struct ActionBarView: View {
    let contact: CNContact

    @State private var showPhonePicker = false
    @State private var showEmailPicker = false
    @State private var phonePickerAction: PhoneAction = .call

    @Environment(\.openURL) private var openURL

    enum PhoneAction {
        case call
        case message
        case facetime
    }

    private enum ActionKind: String {
        case call, message, facetime, email, directions
    }

    private struct ActionItem: Identifiable {
        let kind: ActionKind
        let icon: String
        let label: String
        var id: String { kind.rawValue }
    }

    var body: some View {
        HStack {
            ForEach(availableActions) { item in
                actionButton(icon: item.icon, label: item.label) {
                    performAction(item.kind)
                }
            }
        }
        .sheet(isPresented: $showPhonePicker) {
            phonePicker
        }
        .sheet(isPresented: $showEmailPicker) {
            emailPicker
        }
    }

    // MARK: - Available Actions

    private var availableActions: [ActionItem] {
        var items: [ActionItem] = []
        if contact.hasPhoneNumbers {
            items.append(ActionItem(kind: .call, icon: "phone", label: "Call"))
            items.append(ActionItem(kind: .message, icon: "message", label: "Message"))
            items.append(ActionItem(kind: .facetime, icon: "video", label: "FaceTime"))
        }
        if contact.hasEmailAddresses {
            items.append(ActionItem(kind: .email, icon: "envelope", label: "Mail"))
        }
        if contact.hasPostalAddresses {
            items.append(ActionItem(kind: .directions, icon: "map", label: "Directions"))
        }
        return items
    }

    private func performAction(_ kind: ActionKind) {
        switch kind {
        case .call: handlePhoneAction(.call)
        case .message: handlePhoneAction(.message)
        case .facetime: handlePhoneAction(.facetime)
        case .email: handleEmailAction()
        case .directions: openDirections()
        }
    }

    // MARK: - Action Button

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: KSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .symbolRenderingMode(.hierarchical)

                Text(label)
                    .font(.action)
            }
            .foregroundStyle(Color.accentSlateBlue)
            .frame(width: 60)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: label))
    }

    private func accessibilityLabel(for label: String) -> String {
        let contactName = contact.displayName
        switch label {
        case "Call":
            if let phone = contact.formattedPhoneNumbers.first {
                return "Call \(contactName)'s \(phone.label)"
            }
            return "Call"
        case "Message":
            if let phone = contact.formattedPhoneNumbers.first {
                return "Message \(contactName)'s \(phone.label)"
            }
            return "Message"
        case "FaceTime":
            if let phone = contact.formattedPhoneNumbers.first {
                return "FaceTime \(contactName)'s \(phone.label)"
            }
            return "FaceTime"
        case "Mail":
            if let email = contact.formattedEmailAddresses.first {
                return "Mail \(contactName)'s \(email.label)"
            }
            return "Mail"
        case "Directions":
            return "Directions to \(contactName)"
        default:
            return label
        }
    }

    // MARK: - Phone Actions

    private func handlePhoneAction(_ action: PhoneAction) {
        let numbers = contact.formattedPhoneNumbers
        if numbers.count == 1 {
            openPhoneURL(number: numbers[0].value, action: action)
        } else {
            phonePickerAction = action
            showPhonePicker = true
        }
    }

    private func openPhoneURL(number: String, action: PhoneAction) {
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let scheme: String
        switch action {
        case .call: scheme = "tel"
        case .message: scheme = "sms"
        case .facetime: scheme = "facetime"
        }
        guard let url = URL(string: "\(scheme)://\(cleaned)") else { return }
        openURL(url)
    }

    // MARK: - Email Actions

    private func handleEmailAction() {
        let emails = contact.formattedEmailAddresses
        if emails.count == 1 {
            openEmailURL(email: emails[0].value)
        } else {
            showEmailPicker = true
        }
    }

    private func openEmailURL(email: String) {
        guard let url = URL(string: "mailto:\(email)") else { return }
        openURL(url)
    }

    // MARK: - Directions

    private func openDirections() {
        guard let firstAddress = contact.postalAddresses.first else { return }
        let address = firstAddress.value
        let components = [
            address.street,
            address.city,
            address.state,
            address.postalCode,
            address.country,
        ].filter { !$0.isEmpty }
        let query = components.joined(separator: ", ")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "maps://?address=\(encoded)") else { return }
        openURL(url)
    }

    // MARK: - Picker Sheets

    private var phonePicker: some View {
        NavigationStack {
            List {
                ForEach(Array(contact.formattedPhoneNumbers.enumerated()), id: \.offset) { _, phone in
                    Button {
                        showPhonePicker = false
                        openPhoneURL(number: phone.value, action: phonePickerAction)
                    } label: {
                        VStack(alignment: .leading, spacing: KSpacing.xs) {
                            Text(phone.label)
                                .font(.label)
                                .foregroundStyle(Color.textTertiary)
                            Text(phone.value)
                                .font(.kBody)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                }
            }
            .navigationTitle(pickerTitle(for: phonePickerAction))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPhonePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var emailPicker: some View {
        NavigationStack {
            List {
                ForEach(Array(contact.formattedEmailAddresses.enumerated()), id: \.offset) { _, email in
                    Button {
                        showEmailPicker = false
                        openEmailURL(email: email.value)
                    } label: {
                        VStack(alignment: .leading, spacing: KSpacing.xs) {
                            Text(email.label)
                                .font(.label)
                                .foregroundStyle(Color.textTertiary)
                            Text(email.value)
                                .font(.kBody)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                }
            }
            .navigationTitle("Choose Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEmailPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func pickerTitle(for action: PhoneAction) -> String {
        switch action {
        case .call: return "Choose Number"
        case .message: return "Choose Number"
        case .facetime: return "Choose Number"
        }
    }
}

// MARK: - Availability Check

extension ActionBarView {
    /// Whether the contact has any data that warrants showing the action bar.
    static func hasActions(for contact: CNContact) -> Bool {
        contact.hasPhoneNumbers || contact.hasEmailAddresses || contact.hasPostalAddresses
    }
}

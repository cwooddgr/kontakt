import Foundation
import Contacts

extension CNContact {

    // MARK: - Display Name

    /// Formatted display name with multiple fallbacks:
    /// "Given Family" -> organization -> first email -> first phone -> "No Name"
    var displayName: String {
        let name = [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if !name.isEmpty {
            return name
        }

        if !organizationName.isEmpty {
            return organizationName
        }

        if let firstEmail = emailAddresses.first {
            return firstEmail.value as String
        }

        if let firstPhone = phoneNumbers.first {
            return firstPhone.value.stringValue
        }

        return "No Name"
    }

    // MARK: - Initials

    /// First letters of given and family name (e.g., "JS" for "John Smith").
    /// Falls back to the first character of the display name.
    var initials: String {
        let parts = [givenName, familyName].filter { !$0.isEmpty }

        if parts.isEmpty {
            let fallback = displayName
            return fallback == "No Name"
                ? "?"
                : String(fallback.prefix(1)).uppercased()
        }

        return parts
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
    }

    // MARK: - Formatted Phone Numbers

    /// Returns phone numbers as label-value pairs with human-readable labels.
    var formattedPhoneNumbers: [(label: String, value: String)] {
        phoneNumbers.map { labeled in
            let label = CNLabelMapping.displayName(for: labeled.label)
            let value = labeled.value.stringValue
            return (label: label, value: value)
        }
    }

    // MARK: - Formatted Email Addresses

    /// Returns email addresses as label-value pairs with human-readable labels.
    var formattedEmailAddresses: [(label: String, value: String)] {
        emailAddresses.map { labeled in
            let label = CNLabelMapping.displayName(for: labeled.label)
            let value = labeled.value as String
            return (label: label, value: value)
        }
    }

    // MARK: - Formatted Addresses

    /// Returns postal addresses as label-value pairs with formatted address strings.
    var formattedAddresses: [(label: String, value: String)] {
        let formatter = CNPostalAddressFormatter()

        return postalAddresses.map { labeled in
            let label = CNLabelMapping.displayName(for: labeled.label)
            let value = formatter.string(from: labeled.value)
            return (label: label, value: value)
        }
    }

    // MARK: - Availability Checks

    /// Whether this contact has at least one phone number.
    var hasPhoneNumbers: Bool {
        !phoneNumbers.isEmpty
    }

    /// Whether this contact has at least one email address.
    var hasEmailAddresses: Bool {
        !emailAddresses.isEmpty
    }

    /// Whether this contact has at least one postal address.
    var hasPostalAddresses: Bool {
        !postalAddresses.isEmpty
    }
}

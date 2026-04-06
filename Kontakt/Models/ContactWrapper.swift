import Foundation
import Contacts

/// Lightweight value-type snapshot of a CNContact for list display.
/// Holds only the minimal keys fetched during a list-tier fetch.
struct ContactWrapper: Identifiable, Hashable, Equatable, Sendable {

    var id: String { identifier }
    let identifier: String
    let givenName: String
    let familyName: String
    let organizationName: String
    let thumbnailImageData: Data?
    let primaryPhone: String?
    let primaryEmail: String?

    // MARK: - Computed Properties

    /// Formatted full name: "Given Family", falling back to organization if both names are empty.
    var fullName: String {
        let name = [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? organizationName : name
    }

    /// First letters of given and family name (e.g. "JS" for "John Smith").
    /// Falls back to the first letter of the organization name, or "?" if nothing is available.
    var initials: String {
        let parts = [givenName, familyName].filter { !$0.isEmpty }
        if parts.isEmpty {
            return organizationName.isEmpty
                ? "?"
                : String(organizationName.prefix(1)).uppercased()
        }
        return parts
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
    }

    // MARK: - Factory

    /// Creates a ContactWrapper from a CNContact that was fetched with list-tier keys.
    static func from(_ contact: CNContact) -> ContactWrapper {
        let phone: String? = if contact.isKeyAvailable(CNContactPhoneNumbersKey),
                                let first = contact.phoneNumbers.first {
            first.value.stringValue
        } else {
            nil
        }

        let email: String? = if contact.isKeyAvailable(CNContactEmailAddressesKey),
                                let first = contact.emailAddresses.first {
            first.value as String
        } else {
            nil
        }

        return ContactWrapper(
            identifier: contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            organizationName: contact.organizationName,
            thumbnailImageData: contact.thumbnailImageData,
            primaryPhone: phone,
            primaryEmail: email
        )
    }
}

import Foundation
import Contacts

// MARK: - Parsed Contact Field

/// A single parsed contact text field with its associated confidence level.
struct ParsedContactField: Sendable {
    let value: String
    let confidence: FieldConfidence

    static func high(_ value: String) -> ParsedContactField {
        ParsedContactField(value: value, confidence: .high)
    }

    static func medium(_ value: String) -> ParsedContactField {
        ParsedContactField(value: value, confidence: .medium)
    }

    static func low(_ value: String) -> ParsedContactField {
        ParsedContactField(value: value, confidence: .low)
    }
}

// MARK: - Parsed Contact

/// Intermediate representation of a parsed contact with per-field confidence scores.
///
/// On iOS 26+ devices with Foundation Models support, this struct can be made
/// `@Generable` for on-device LLM structured output. That conformance is added
/// conditionally in `AIParsingService`.
struct ParsedContact: Sendable {
    var namePrefix: ParsedContactField
    var givenName: ParsedContactField
    var familyName: ParsedContactField
    var jobTitle: ParsedContactField
    var organization: ParsedContactField
    var phoneNumbers: [(value: String, confidence: FieldConfidence)]
    var emailAddresses: [(value: String, confidence: FieldConfidence)]
    var address: ParsedAddress?

    /// The lowest confidence among the name fields.
    var nameConfidence: FieldConfidence {
        [givenName, familyName]
            .map(\.confidence)
            .min() ?? .low
    }

    /// Converts the parsed contact into a `CNMutableContact` suitable for saving.
    func toCNMutableContact() -> CNMutableContact {
        let contact = CNMutableContact()

        if !namePrefix.value.isEmpty {
            contact.namePrefix = namePrefix.value
        }
        if !givenName.value.isEmpty {
            contact.givenName = givenName.value
        }
        if !familyName.value.isEmpty {
            contact.familyName = familyName.value
        }
        if !jobTitle.value.isEmpty {
            contact.jobTitle = jobTitle.value
        }
        if !organization.value.isEmpty {
            contact.organizationName = organization.value
        }

        for phone in phoneNumbers where !phone.value.isEmpty {
            contact.phoneNumbers.append(
                CNLabeledValue(
                    label: CNLabelPhoneNumberMobile,
                    value: CNPhoneNumber(stringValue: phone.value)
                )
            )
        }

        for email in emailAddresses where !email.value.isEmpty {
            contact.emailAddresses.append(
                CNLabeledValue(
                    label: CNLabelHome,
                    value: email.value as NSString
                )
            )
        }

        if let address, !address.street.value.isEmpty {
            let postalAddress = address.toCNPostalAddress()
            contact.postalAddresses.append(
                CNLabeledValue(label: CNLabelHome, value: postalAddress as CNPostalAddress)
            )
        }

        return contact
    }
}

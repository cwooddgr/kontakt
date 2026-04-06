import Foundation
import Contacts

// MARK: - Field Confidence

/// Confidence level for a parsed field value.
enum FieldConfidence: String, Sendable, Comparable {
    case high
    case medium
    case low

    private var sortOrder: Int {
        switch self {
        case .high: return 2
        case .medium: return 1
        case .low: return 0
        }
    }

    static func < (lhs: FieldConfidence, rhs: FieldConfidence) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Parsed Address Field

/// A single parsed field with its associated confidence level.
struct ParsedAddressField: Sendable {
    let value: String
    let confidence: FieldConfidence

    /// A convenience initializer for high-confidence values.
    static func high(_ value: String) -> ParsedAddressField {
        ParsedAddressField(value: value, confidence: .high)
    }

    /// A convenience initializer for medium-confidence values.
    static func medium(_ value: String) -> ParsedAddressField {
        ParsedAddressField(value: value, confidence: .medium)
    }

    /// A convenience initializer for low-confidence values.
    static func low(_ value: String) -> ParsedAddressField {
        ParsedAddressField(value: value, confidence: .low)
    }
}

// MARK: - Parsed Address

/// Intermediate representation of a parsed address with per-field confidence scores.
///
/// On iOS 26+ devices with Foundation Models support, this struct can be made
/// `@Generable` for on-device LLM structured output. That conformance is added
/// conditionally in `AIParsingService`.
struct ParsedAddress: Sendable {
    var street: ParsedAddressField
    var city: ParsedAddressField
    var state: ParsedAddressField
    var postalCode: ParsedAddressField
    var countryCode: ParsedAddressField

    /// The lowest confidence among all fields.
    var overallConfidence: FieldConfidence {
        [street, city, state, postalCode, countryCode]
            .map(\.confidence)
            .min() ?? .low
    }

    /// Converts the parsed address into a `CNPostalAddress` suitable for saving.
    func toCNPostalAddress() -> CNPostalAddress {
        let address = CNMutablePostalAddress()
        address.street = street.value
        address.city = city.value
        address.state = state.value
        address.postalCode = postalCode.value
        address.isoCountryCode = countryCode.value
        return address as CNPostalAddress
    }
}

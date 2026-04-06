import Foundation

// MARK: - Search Field

/// Identifies which contact field was matched during a search.
/// Cases are ordered by descending search weight — name matches rank highest.
enum SearchField: Int, Sendable, Comparable, CaseIterable {
    case givenName = 0
    case familyName = 1
    case organization = 2
    case jobTitle = 3
    case tag = 4
    case email = 5
    case phone = 6
    case address = 7
    case notes = 8

    static func < (lhs: SearchField, rhs: SearchField) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Display label for the matched field.
    var displayLabel: String {
        switch self {
        case .givenName: return "First Name"
        case .familyName: return "Last Name"
        case .organization: return "Company"
        case .jobTitle: return "Job Title"
        case .tag: return "Tag"
        case .email: return "Email"
        case .phone: return "Phone"
        case .address: return "Address"
        case .notes: return "Notes"
        }
    }

    /// Relative weight for scoring. Higher values mean stronger matches.
    var weight: Double {
        switch self {
        case .givenName: return 1.0
        case .familyName: return 1.0
        case .organization: return 0.7
        case .jobTitle: return 0.7
        case .tag: return 0.65
        case .email: return 0.6
        case .phone: return 0.6
        case .address: return 0.4
        case .notes: return 0.3
        }
    }
}

// MARK: - Search Result

/// A single search result with scoring metadata.
struct SearchResult: Identifiable, Sendable {
    let contact: ContactWrapper
    let score: Double
    let matchedField: SearchField
    let matchedSubstring: Range<String.Index>?

    /// The actual matched text (e.g. the tag name or field value that matched).
    let matchedValue: String?

    var id: String { contact.identifier }

    init(
        contact: ContactWrapper,
        score: Double,
        matchedField: SearchField,
        matchedSubstring: Range<String.Index>?,
        matchedValue: String? = nil
    ) {
        self.contact = contact
        self.score = score
        self.matchedField = matchedField
        self.matchedSubstring = matchedSubstring
        self.matchedValue = matchedValue
    }
}

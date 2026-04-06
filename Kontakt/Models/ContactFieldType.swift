import Foundation
import Contacts

// MARK: - Field Category

/// High-level category for a contact field.
enum ContactFieldCategory: String, Sendable, CaseIterable {
    case phone
    case email
    case address
    case url
    case date
    case socialProfile
    case instantMessage
    case relatedName
    case note
}

// MARK: - Field Modernity

/// Whether a field type is considered modern or legacy.
enum ContactFieldModernity: String, Sendable {
    /// Commonly used field types (phone, email, address, etc.)
    case modern
    /// Rarely used services from an earlier era (Jabber, ICQ, AIM, etc.)
    case legacy
}

// MARK: - Field Type Info

/// Metadata about a specific contact field type.
struct ContactFieldTypeInfo: Sendable, Identifiable {
    let id: String
    let label: String
    let category: ContactFieldCategory
    let modernity: ContactFieldModernity
}

// MARK: - Standard Field Collections

extension ContactFieldTypeInfo {

    /// Field types that are commonly used and should be prominently displayed.
    static let modernFieldTypes: [ContactFieldTypeInfo] = [
        ContactFieldTypeInfo(id: "phone", label: "Phone", category: .phone, modernity: .modern),
        ContactFieldTypeInfo(id: "email", label: "Email", category: .email, modernity: .modern),
        ContactFieldTypeInfo(id: "address", label: "Address", category: .address, modernity: .modern),
        ContactFieldTypeInfo(id: "url", label: "URL", category: .url, modernity: .modern),
        ContactFieldTypeInfo(id: "date", label: "Date", category: .date, modernity: .modern),
        ContactFieldTypeInfo(id: "birthday", label: "Birthday", category: .date, modernity: .modern),
        ContactFieldTypeInfo(id: "note", label: "Note", category: .note, modernity: .modern),
        ContactFieldTypeInfo(id: "relatedName", label: "Related Name", category: .relatedName, modernity: .modern),
    ]

    /// Legacy field types — supported for display but hidden behind a disclosure group when adding.
    static let legacyFieldTypes: [ContactFieldTypeInfo] = [
        ContactFieldTypeInfo(id: "twitter", label: "Twitter", category: .socialProfile, modernity: .legacy),
        ContactFieldTypeInfo(id: "facebook", label: "Facebook", category: .socialProfile, modernity: .legacy),
        ContactFieldTypeInfo(id: "flickr", label: "Flickr", category: .socialProfile, modernity: .legacy),
        ContactFieldTypeInfo(id: "linkedIn", label: "LinkedIn", category: .socialProfile, modernity: .legacy),
        ContactFieldTypeInfo(id: "myspace", label: "Myspace", category: .socialProfile, modernity: .legacy),
        ContactFieldTypeInfo(id: "sinaWeibo", label: "Sina Weibo", category: .socialProfile, modernity: .legacy),
        ContactFieldTypeInfo(id: "jabber", label: "Jabber", category: .instantMessage, modernity: .legacy),
        ContactFieldTypeInfo(id: "icq", label: "ICQ", category: .instantMessage, modernity: .legacy),
        ContactFieldTypeInfo(id: "aim", label: "AIM", category: .instantMessage, modernity: .legacy),
        ContactFieldTypeInfo(id: "yahoo", label: "Yahoo", category: .instantMessage, modernity: .legacy),
        ContactFieldTypeInfo(id: "msn", label: "MSN", category: .instantMessage, modernity: .legacy),
        ContactFieldTypeInfo(id: "qq", label: "QQ", category: .instantMessage, modernity: .legacy),
        ContactFieldTypeInfo(id: "googleTalk", label: "Google Talk", category: .instantMessage, modernity: .legacy),
        ContactFieldTypeInfo(id: "skype", label: "Skype", category: .instantMessage, modernity: .legacy),
    ]

    /// All field types combined.
    static let allFieldTypes: [ContactFieldTypeInfo] = modernFieldTypes + legacyFieldTypes
}

// MARK: - CNLabel Mapping

/// Maps CNLabel constants to human-readable strings.
enum CNLabelMapping {

    /// Returns a human-readable string for a CNLabel, or the raw value if unknown.
    static func displayName(for label: String?) -> String {
        guard let label else { return "other" }

        switch label {
        // Generic
        case CNLabelHome: return "home"
        case CNLabelWork: return "work"
        case CNLabelOther: return "other"
        case CNLabelSchool: return "school"

        // Phone-specific
        case CNLabelPhoneNumberiPhone: return "iPhone"
        case CNLabelPhoneNumberMobile: return "mobile"
        case CNLabelPhoneNumberMain: return "main"
        case CNLabelPhoneNumberHomeFax: return "home fax"
        case CNLabelPhoneNumberWorkFax: return "work fax"
        case CNLabelPhoneNumberPager: return "pager"

        // Email-specific
        case CNLabelEmailiCloud: return "iCloud"

        // URL-specific
        case CNLabelURLAddressHomePage: return "homepage"

        // Date-specific
        case CNLabelDateAnniversary: return "anniversary"

        // Relation-specific
        case CNLabelContactRelationAssistant: return "assistant"
        case CNLabelContactRelationManager: return "manager"
        case CNLabelContactRelationPartner: return "partner"
        case CNLabelContactRelationSpouse: return "spouse"
        case CNLabelContactRelationChild: return "child"
        case CNLabelContactRelationFather: return "father"
        case CNLabelContactRelationMother: return "mother"
        case CNLabelContactRelationSister: return "sister"
        case CNLabelContactRelationBrother: return "brother"
        case CNLabelContactRelationFriend: return "friend"
        case CNLabelContactRelationParent: return "parent"

        default:
            // CNLabel values are prefixed with "_$!<" and suffixed with ">!$_".
            // Strip those markers if present.
            let stripped = label
                .replacingOccurrences(of: "_$!<", with: "")
                .replacingOccurrences(of: ">!$_", with: "")
            return stripped.isEmpty ? "other" : stripped.lowercased()
        }
    }
}

import Foundation
import Contacts

/// Stateless service that builds a search index from contacts and performs
/// multi-field ranked search with fuzzy matching.
///
/// `SearchEngine` is fully `Sendable` — it holds no mutable state. Call
/// `buildIndex(from:)` on a background thread after each contact list refresh,
/// then call `search(query:in:contacts:)` on each keystroke.
///
/// Performance target: < 50ms for 10,000 contacts per keystroke.
final class SearchEngine: Sendable {

    // MARK: - SearchableContact

    /// Pre-computed search tokens for a single contact.
    struct SearchableContact: Sendable {
        let identifier: String
        let tokens: [Token]

        struct Token: Sendable {
            let field: SearchField
            let value: String
            let normalized: String
        }
    }

    // MARK: - Index Keys

    /// The `CNContact` keys required to build a full search index.
    nonisolated(unsafe) static let indexFetchKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactNoteKey as CNKeyDescriptor,
    ]

    // MARK: - Building the Index

    /// Builds the searchable index from a list of contacts fetched with `indexFetchKeys`.
    ///
    /// Call this on a background thread. The resulting array is `Sendable` and can
    /// be stored and reused across search calls until the contact list changes.
    ///
    /// - Parameters:
    ///   - contacts: The contacts fetched with `indexFetchKeys`.
    ///   - tags: Optional mapping of contact identifier to tag names. When provided,
    ///     each tag is indexed as a `.tag` field token.
    func buildIndex(from contacts: [CNContact], tags: [String: [String]] = [:]) -> [SearchableContact] {
        contacts.map { contact in
            var tokens: [SearchableContact.Token] = []

            // Name fields
            addToken(contact.givenName, field: .givenName, to: &tokens)
            addToken(contact.familyName, field: .familyName, to: &tokens)

            // Organization fields
            addToken(contact.organizationName, field: .organization, to: &tokens)
            addToken(contact.jobTitle, field: .jobTitle, to: &tokens)

            // Tags
            if let contactTags = tags[contact.identifier] {
                for tag in contactTags {
                    addToken(tag, field: .tag, to: &tokens)
                }
            }

            // Email addresses
            for email in contact.emailAddresses {
                addToken(email.value as String, field: .email, to: &tokens)
            }

            // Phone numbers — store the digit-only normalized form
            for phone in contact.phoneNumbers {
                let raw = phone.value.stringValue
                let digits = raw.phoneNormalized
                if !digits.isEmpty {
                    tokens.append(SearchableContact.Token(
                        field: .phone,
                        value: raw,
                        normalized: digits
                    ))
                }
            }

            // Postal addresses — index street, city, state, and zip
            for address in contact.postalAddresses {
                let postal = address.value
                addToken(postal.street, field: .address, to: &tokens)
                addToken(postal.city, field: .address, to: &tokens)
                addToken(postal.state, field: .address, to: &tokens)
                addToken(postal.postalCode, field: .address, to: &tokens)
            }

            // Notes
            if contact.isKeyAvailable(CNContactNoteKey) {
                addToken(contact.note, field: .notes, to: &tokens)
            }

            return SearchableContact(identifier: contact.identifier, tokens: tokens)
        }
    }

    // MARK: - Search

    /// Searches the index for contacts matching `query` and returns ranked results.
    ///
    /// - Parameters:
    ///   - query: The raw user input string.
    ///   - index: The searchable index built via `buildIndex(from:)`.
    ///   - contacts: The current `ContactWrapper` list, used to populate result objects.
    /// - Returns: An array of `SearchResult` sorted by score descending.
    func search(
        query: String,
        in index: [SearchableContact],
        contacts: [ContactWrapper]
    ) -> [SearchResult] {
        let normalizedQuery = normalizeQuery(query)
        guard !normalizedQuery.isEmpty else { return [] }

        // Build a lookup table for ContactWrapper by identifier.
        let contactsByID = Dictionary(
            contacts.map { ($0.identifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var results: [SearchResult] = []

        for searchable in index {
            var bestScore: Double = 0
            var bestField: SearchField = .notes
            var bestValue: String?

            for token in searchable.tokens {
                let matchScore = score(
                    query: normalizedQuery,
                    against: token.normalized,
                    field: token.field
                )
                if matchScore > bestScore {
                    bestScore = matchScore
                    bestField = token.field
                    bestValue = token.value
                }
            }

            if bestScore > 0, let wrapper = contactsByID[searchable.identifier] {
                results.append(SearchResult(
                    contact: wrapper,
                    score: bestScore,
                    matchedField: bestField,
                    matchedSubstring: nil,
                    matchedValue: bestValue
                ))
            }
        }

        results.sort { $0.score > $1.score }
        return results
    }

    // MARK: - Scoring

    /// Calculates a match score for a single token against the query.
    private func score(query: String, against token: String, field: SearchField) -> Double {
        guard !token.isEmpty else { return 0 }

        let matchMultiplier: Double

        if token.hasPrefix(query) {
            // Prefix match — strongest signal
            matchMultiplier = 3.0
        } else if token.contains(query) {
            // Contains match — moderate signal
            matchMultiplier = 1.5
        } else if query.count < 20 && token.count < 20 {
            // Fuzzy match — only attempt for short strings to stay within perf budget
            let distance = levenshteinDistance(query, token)
            if distance <= 2 {
                matchMultiplier = 0.5
            } else {
                return 0
            }
        } else {
            return 0
        }

        return matchMultiplier * field.weight
    }

    // MARK: - Normalization

    /// Normalizes a query string for comparison: lowercase, strip diacritics,
    /// and strip phone formatting if the query looks like a phone number.
    private func normalizeQuery(_ query: String) -> String {
        let folded = query
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)

        // If the query looks like a phone number (mostly digits plus formatting),
        // strip it down to digits only.
        if looksLikePhoneNumber(folded) {
            return folded.phoneNormalized
        }

        return folded
    }

    /// Normalizes a field value: lowercase and strip diacritics.
    private func normalizeValue(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
    }

    /// Returns true if the string appears to be a phone number query.
    /// Heuristic: more than half the characters are digits, after stripping whitespace.
    private func looksLikePhoneNumber(_ string: String) -> Bool {
        let stripped = string.filter { !$0.isWhitespace }
        guard !stripped.isEmpty else { return false }
        let digitCount = stripped.filter(\.isWholeNumber).count
        // Consider it phone-like if > 50% digits and at least 3 digits present
        return digitCount >= 3 && Double(digitCount) / Double(stripped.count) > 0.5
    }

    // MARK: - Token Helpers

    /// Adds a token to the array if the value is non-empty, with standard normalization.
    private func addToken(
        _ value: String,
        field: SearchField,
        to tokens: inout [SearchableContact.Token]
    ) {
        guard !value.isEmpty else { return }
        tokens.append(SearchableContact.Token(
            field: field,
            value: value,
            normalized: normalizeValue(value)
        ))
    }

    // MARK: - Levenshtein Distance

    /// Computes the Levenshtein edit distance between two strings.
    ///
    /// Uses the standard dynamic-programming algorithm with a single-row optimization
    /// for O(min(m,n)) space. Only call for short strings (< 20 characters).
    func levenshteinDistance(_ source: String, _ target: String) -> Int {
        let s = Array(source)
        let t = Array(target)

        let m = s.count
        let n = t.count

        // Early exits
        if m == 0 { return n }
        if n == 0 { return m }

        // Ensure we iterate over the shorter dimension in the inner loop.
        // We use a single previous-row buffer for space efficiency.
        var previousRow = Array(0...n)
        var currentRow = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            currentRow[0] = i

            for j in 1...n {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,          // deletion
                    currentRow[j - 1] + 1,       // insertion
                    previousRow[j - 1] + cost    // substitution
                )
            }

            swap(&previousRow, &currentRow)
        }

        return previousRow[n]
    }
}

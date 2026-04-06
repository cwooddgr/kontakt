import Foundation
import Contacts

/// Stateless service that matches a parsed contact against existing contacts
/// in the contact store. Returns high-confidence, low-confidence, or no match.
enum ContactMatchingService {

    // MARK: - Result Types

    enum MatchResult {
        /// Phone/email or exact name match with new fields to add.
        case highConfidence(contact: CNContact, newFields: [FieldDiff])
        /// Fuzzy name match — ask the user to confirm identity.
        case lowConfidence(contact: CNContact, score: Double)
        /// No existing contact matches.
        case noMatch
    }

    struct FieldDiff: Identifiable {
        let id = UUID()
        let fieldName: String
        let oldValue: String?
        let newValue: String
    }

    // MARK: - Public API

    /// Match a parsed contact against existing contacts.
    ///
    /// Algorithm priority:
    /// 1. Phone/email exact match (highest confidence)
    /// 2. Exact name match with at least one new field
    /// 3. Fuzzy name match (Levenshtein distance <= 2)
    /// 4. No match
    @MainActor
    static func findMatch(
        for parsed: ParsedContact,
        in contactStore: ContactStore
    ) -> MatchResult {
        let parsedPhones = parsed.phoneNumbers
            .map { $0.value.phoneNormalized }
            .filter { !$0.isEmpty }

        let parsedEmails = parsed.emailAddresses
            .map { $0.value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let parsedGiven = parsed.givenName.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let parsedFamily = parsed.familyName.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let parsedFullName = [parsedGiven, parsedFamily]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // MARK: Pass 1 — Scan ContactWrappers for phone/email/name candidates

        var phoneOrEmailMatchID: String?
        var exactNameMatchID: String?
        var fuzzyNameMatchID: String?
        var fuzzyNameScore: Double = 0

        let searchEngine = SearchEngine()

        for wrapper in contactStore.contacts {
            // Phone match: compare primary phone (wrapper only has primary)
            if let primaryPhone = wrapper.primaryPhone {
                let normalizedExisting = primaryPhone.phoneNormalized
                if !normalizedExisting.isEmpty, parsedPhones.contains(normalizedExisting) {
                    phoneOrEmailMatchID = wrapper.identifier
                    break
                }
            }

            // Email match: compare primary email
            if let primaryEmail = wrapper.primaryEmail {
                let normalizedExisting = primaryEmail.lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalizedExisting.isEmpty, parsedEmails.contains(normalizedExisting) {
                    phoneOrEmailMatchID = wrapper.identifier
                    break
                }
            }

            // Name matching
            let existingGiven = wrapper.givenName.lowercased()
            let existingFamily = wrapper.familyName.lowercased()
            let existingFullName = [existingGiven, existingFamily]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            guard !parsedFullName.isEmpty, !existingFullName.isEmpty else { continue }

            // Exact name match
            if parsedGiven == existingGiven, parsedFamily == existingFamily,
               !parsedGiven.isEmpty || !parsedFamily.isEmpty {
                exactNameMatchID = wrapper.identifier
            }

            // Fuzzy name match (Levenshtein distance <= 2)
            if fuzzyNameMatchID == nil,
               parsedFullName.count < 40, existingFullName.count < 40 {
                let distance = searchEngine.levenshteinDistance(parsedFullName, existingFullName)
                if distance > 0, distance <= 2 {
                    fuzzyNameMatchID = wrapper.identifier
                    fuzzyNameScore = Double(distance)
                }
            }
        }

        // MARK: Pass 2 — Fetch full contact detail and compute diffs

        // Priority 1: Phone/email exact match
        if let matchID = phoneOrEmailMatchID,
           let fullContact = contactStore.fetchContactDetail(identifier: matchID) {

            // Also check all phones/emails on the full contact (not just primary)
            let diffs = computeDiffs(parsed: parsed, existing: fullContact)
            return .highConfidence(contact: fullContact, newFields: diffs)
        }

        // For exact name matches, also do a full phone/email scan on the detail contact
        // to make sure we didn't miss a secondary phone/email match
        if let matchID = exactNameMatchID,
           let fullContact = contactStore.fetchContactDetail(identifier: matchID) {

            let diffs = computeDiffs(parsed: parsed, existing: fullContact)
            if !diffs.isEmpty {
                return .highConfidence(contact: fullContact, newFields: diffs)
            }
            // Exact name match but nothing new — treat as no match (duplicate entry)
            // so the user can decide
            return .lowConfidence(contact: fullContact, score: 0)
        }

        // Priority 3: Fuzzy name match
        if let matchID = fuzzyNameMatchID,
           let fullContact = contactStore.fetchContactDetail(identifier: matchID) {
            return .lowConfidence(contact: fullContact, score: fuzzyNameScore)
        }

        return .noMatch
    }

    // MARK: - Diff Computation

    /// Compares parsed fields against an existing CNContact and returns diffs
    /// for fields where the parsed value is non-empty and different from existing.
    private static func computeDiffs(
        parsed: ParsedContact,
        existing: CNContact
    ) -> [FieldDiff] {
        var diffs: [FieldDiff] = []

        // Phone numbers
        let existingPhoneDigits = Set(
            existing.phoneNumbers.map { $0.value.stringValue.phoneNormalized }
        )
        for phone in parsed.phoneNumbers where !phone.value.isEmpty {
            let normalizedNew = phone.value.phoneNormalized
            if !normalizedNew.isEmpty, !existingPhoneDigits.contains(normalizedNew) {
                diffs.append(FieldDiff(
                    fieldName: "Phone",
                    oldValue: nil,
                    newValue: phone.value
                ))
            }
        }

        // Email addresses
        let existingEmails = Set(
            existing.emailAddresses.map { ($0.value as String).lowercased() }
        )
        for email in parsed.emailAddresses where !email.value.isEmpty {
            let normalizedNew = email.value.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedNew.isEmpty, !existingEmails.contains(normalizedNew) {
                diffs.append(FieldDiff(
                    fieldName: "Email",
                    oldValue: nil,
                    newValue: email.value
                ))
            }
        }

        // Postal address
        if let parsedAddr = parsed.address {
            let newStreet = parsedAddr.street.value
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let newCity = parsedAddr.city.value
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let newState = parsedAddr.state.value
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let newZip = parsedAddr.postalCode.value
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let addressParts = [newStreet, newCity, newState, newZip]
                .filter { !$0.isEmpty }

            if !addressParts.isEmpty {
                let formattedNew = addressParts.joined(separator: ", ")

                // Check if this address already exists
                let existingAddressStrings = existing.postalAddresses.map { labeled -> String in
                    let addr = labeled.value
                    return [addr.street, addr.city, addr.state, addr.postalCode]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                }

                let alreadyExists = existingAddressStrings.contains { existing in
                    existing.lowercased() == formattedNew.lowercased()
                }

                if !alreadyExists {
                    let oldAddress = existingAddressStrings.first
                    diffs.append(FieldDiff(
                        fieldName: "Address",
                        oldValue: oldAddress?.isEmpty == true ? nil : oldAddress,
                        newValue: formattedNew
                    ))
                }
            }
        }

        // Job title
        let parsedJobTitle = parsed.jobTitle.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !parsedJobTitle.isEmpty,
           parsedJobTitle.lowercased() != existing.jobTitle.lowercased() {
            diffs.append(FieldDiff(
                fieldName: "Job title",
                oldValue: existing.jobTitle.isEmpty ? nil : existing.jobTitle,
                newValue: parsedJobTitle
            ))
        }

        // Organization
        let parsedOrg = parsed.organization.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !parsedOrg.isEmpty,
           parsedOrg.lowercased() != existing.organizationName.lowercased() {
            diffs.append(FieldDiff(
                fieldName: "Company",
                oldValue: existing.organizationName.isEmpty ? nil : existing.organizationName,
                newValue: parsedOrg
            ))
        }

        return diffs
    }

    // MARK: - Merge

    /// Merges new fields from a parsed contact into a mutable copy of an existing contact.
    /// Only adds fields that are genuinely new (not already present).
    static func mergeFields(
        from parsed: ParsedContact,
        into contact: CNMutableContact
    ) {
        // Merge phone numbers
        let existingPhoneDigits = Set(
            contact.phoneNumbers.map { $0.value.stringValue.phoneNormalized }
        )
        for phone in parsed.phoneNumbers where !phone.value.isEmpty {
            let normalizedNew = phone.value.phoneNormalized
            if !normalizedNew.isEmpty, !existingPhoneDigits.contains(normalizedNew) {
                contact.phoneNumbers.append(
                    CNLabeledValue(
                        label: CNLabelPhoneNumberMobile,
                        value: CNPhoneNumber(stringValue: phone.value)
                    )
                )
            }
        }

        // Merge email addresses
        let existingEmails = Set(
            contact.emailAddresses.map { ($0.value as String).lowercased() }
        )
        for email in parsed.emailAddresses where !email.value.isEmpty {
            let normalizedNew = email.value.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedNew.isEmpty, !existingEmails.contains(normalizedNew) {
                contact.emailAddresses.append(
                    CNLabeledValue(
                        label: CNLabelHome,
                        value: email.value as NSString
                    )
                )
            }
        }

        // Merge address
        if let parsedAddr = parsed.address {
            let newStreet = parsedAddr.street.value
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let newCity = parsedAddr.city.value
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !newStreet.isEmpty || !newCity.isEmpty {
                let formattedNew = [newStreet, newCity,
                                    parsedAddr.state.value.trimmingCharacters(in: .whitespacesAndNewlines),
                                    parsedAddr.postalCode.value.trimmingCharacters(in: .whitespacesAndNewlines)]
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                    .lowercased()

                let alreadyExists = contact.postalAddresses.contains { labeled in
                    let addr = labeled.value
                    let existing = [addr.street, addr.city, addr.state, addr.postalCode]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                        .lowercased()
                    return existing == formattedNew
                }

                if !alreadyExists {
                    let postalAddress = parsedAddr.toCNPostalAddress()
                    contact.postalAddresses.append(
                        CNLabeledValue(label: CNLabelHome, value: postalAddress as CNPostalAddress)
                    )
                }
            }
        }

        // Merge job title (only if currently empty)
        let parsedJobTitle = parsed.jobTitle.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !parsedJobTitle.isEmpty, contact.jobTitle.isEmpty {
            contact.jobTitle = parsedJobTitle
        }

        // Merge organization (only if currently empty)
        let parsedOrg = parsed.organization.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !parsedOrg.isEmpty, contact.organizationName.isEmpty {
            contact.organizationName = parsedOrg
        }
    }
}

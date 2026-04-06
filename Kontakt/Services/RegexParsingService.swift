import Foundation
import NaturalLanguage

// MARK: - Regex Parsing Service

/// Fallback parser for devices without Foundation Models support.
///
/// This is Tier 2 in the parsing hierarchy. It uses regex pattern matching,
/// heuristics, and the NaturalLanguage framework to extract structured data
/// from freeform text. Results include per-field confidence scores.
///
/// All methods are synchronous and safe to call from any context.
enum RegexParsingService: Sendable {

    // MARK: - Address Parsing

    /// Parses freeform address text into a structured `ParsedAddress` using regex heuristics.
    ///
    /// Handles common US address formats:
    /// - `123 Main St, Austin, TX 78701`
    /// - `123 Main St Apt 4B\nAustin, TX 78701`
    /// - `123 Main Austin Texas`  (no commas, no zip)
    ///
    /// - Parameter input: Freeform address text.
    /// - Returns: A `ParsedAddress` with confidence scores reflecting match quality.
    static func parseAddress(_ input: String) -> ParsedAddress {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return emptyAddress
        }

        // Normalize the input: collapse newlines and multiple spaces.
        let normalized = trimmed
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Try structured formats from most specific to least.
        if let result = parseFullUSAddress(normalized) {
            return result
        }

        if let result = parseMultilineAddress(normalized) {
            return result
        }

        if let result = parseLooseAddress(normalized) {
            return result
        }

        // Last resort: put everything in street with low confidence.
        return ParsedAddress(
            street: .low(trimmed),
            city: .low(""),
            state: .low(""),
            postalCode: .low(""),
            countryCode: .low("")
        )
    }

    // MARK: - Contact Parsing

    /// Parses freeform contact text into a structured `ParsedContact` using regex and heuristics.
    ///
    /// Extraction order (most unambiguous first):
    /// 1. Email addresses (regex: `*@*.*`)
    /// 2. Phone numbers (digit sequences with optional formatting)
    /// 3. Names (NaturalLanguage person name recognition on remaining text)
    /// 4. Company/title (comma-separated segments after name extraction)
    ///
    /// - Parameter input: Freeform contact text.
    /// - Returns: A `ParsedContact` with confidence scores.
    static func parseContact(_ input: String) -> ParsedContact {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return emptyContact
        }

        // Normalize line endings.
        let normalized = trimmed
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Phase 1: Extract emails and phones from ALL lines.
        var allEmails: [String] = []
        var allPhones: [String] = []
        var strippedLines: [String] = []

        for line in lines {
            var remaining = line

            let emails = extractEmails(from: remaining)
            allEmails.append(contentsOf: emails)
            for email in emails {
                remaining = remaining.replacingOccurrences(of: email, with: "")
            }

            let phones = extractPhoneNumbers(from: remaining)
            allPhones.append(contentsOf: phones)
            for phone in phones {
                remaining = remaining.replacingOccurrences(of: phone, with: "")
            }

            remaining = remaining
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ",;|"))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !remaining.isEmpty {
                strippedLines.append(remaining)
            }
        }

        // Phase 2: Classify stripped lines.
        var nameLines: [String] = []
        var addressLines: [String] = []
        var otherLines: [String] = []

        for line in strippedLines {
            if looksLikeAddress(line) {
                addressLines.append(line)
            } else if nameLines.isEmpty && looksLikeName(line) {
                nameLines.append(line)
            } else {
                otherLines.append(line)
            }
        }

        // Phase 3: Parse address from address lines.
        var parsedAddress: ParsedAddress?
        if !addressLines.isEmpty {
            let addressText = addressLines.joined(separator: "\n")
            let result = parseAddress(addressText)
            if !result.street.value.isEmpty || !result.city.value.isEmpty {
                if isAllCaps(addressText) {
                    parsedAddress = ParsedAddress(
                        street: ParsedAddressField(value: titleCased(result.street.value), confidence: result.street.confidence),
                        city: ParsedAddressField(value: titleCased(result.city.value), confidence: result.city.confidence),
                        state: result.state,
                        postalCode: result.postalCode,
                        countryCode: result.countryCode
                    )
                } else {
                    parsedAddress = result
                }
            }
        }

        // Phase 4: Parse name.
        let nameText: String
        if !nameLines.isEmpty {
            nameText = nameLines.joined(separator: " ")
        } else if addressLines.isEmpty && otherLines.isEmpty && strippedLines.count == 1 {
            // Single line, no address -- backward compatible path.
            nameText = strippedLines[0]
        } else if !otherLines.isEmpty {
            // Use the first "other" line as potential name+title+org.
            nameText = otherLines.removeFirst()
        } else {
            nameText = ""
        }

        let normalizedName = isAllCaps(nameText) ? titleCased(nameText) : nameText
        let (prefix, afterPrefix) = extractNamePrefix(from: normalizedName)
        let (givenName, familyName, nameRemaining) = extractName(from: afterPrefix)

        // Phase 5: Title and org from remaining.
        var orgParts = otherLines
        if !nameRemaining.isEmpty {
            orgParts.insert(nameRemaining, at: 0)
        }
        let orgText = orgParts.joined(separator: ", ")
        let normalizedOrgText = isAllCaps(orgText) ? titleCased(orgText) : orgText
        let (jobTitle, organization) = extractTitleAndOrganization(from: normalizedOrgText)

        // Determine name confidence.
        let nameConf: FieldConfidence
        if !givenName.isEmpty && !familyName.isEmpty {
            nameConf = .high
        } else if !givenName.isEmpty || !familyName.isEmpty {
            nameConf = .medium
        } else {
            nameConf = .low
        }

        return ParsedContact(
            namePrefix: prefix.isEmpty ? .low("") : .medium(prefix),
            givenName: ParsedContactField(value: givenName, confidence: nameConf),
            familyName: ParsedContactField(value: familyName, confidence: nameConf),
            jobTitle: jobTitle.isEmpty ? .low("") : .medium(jobTitle),
            organization: organization.isEmpty ? .low("") : .medium(organization),
            phoneNumbers: allPhones.map { (value: $0, confidence: FieldConfidence.high) },
            emailAddresses: allEmails.map { (value: $0, confidence: FieldConfidence.high) },
            address: parsedAddress
        )
    }
}

// MARK: - Address Parsing Helpers

private extension RegexParsingService {

    /// Matches: "123 Main St, Austin, TX 78701" or "123 Main St, Austin, TX 78701-1234"
    /// Also handles Apt/Suite/Unit on the same line.
    static func parseFullUSAddress(_ input: String) -> ParsedAddress? {
        // Split by commas to identify segments
        let segments = input.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        // We need at least 3 segments: street, city, state+zip
        // Or 4+ if there's an apt/suite segment
        guard segments.count >= 3 else { return nil }

        // The last segment should contain state + ZIP
        let lastSegment = segments.last!
        let stateZipPattern = #"^\s*([A-Za-z]{2,}\.?\s*[A-Za-z]*)\s+(\d{5}(?:-\d{4})?)\s*$"#
        guard let stateZipRegex = try? NSRegularExpression(pattern: stateZipPattern),
              let stateZipMatch = stateZipRegex.firstMatch(in: lastSegment, range: NSRange(lastSegment.startIndex..., in: lastSegment)),
              stateZipMatch.numberOfRanges >= 3 else {
            return nil
        }

        let rawState = extractGroup(stateZipMatch, group: 1, from: lastSegment)
        let zip = extractGroup(stateZipMatch, group: 2, from: lastSegment)
        let state = normalizeState(rawState)
        guard !state.isEmpty else { return nil }

        // City is the segment right before state+zip
        let city = segments[segments.count - 2]
        guard !city.isEmpty else { return nil }

        // Street is everything before the city (may include apt/suite segments)
        let streetParts = segments.prefix(segments.count - 2)
        let street = streetParts.joined(separator: ", ")
        guard !street.isEmpty else { return nil }

        return ParsedAddress(
            street: .high(cleanStreet(street)),
            city: .high(city),
            state: .high(state),
            postalCode: .high(zip),
            countryCode: .high("US")
        )
    }

    /// Matches multiline addresses:
    /// "123 Main St Apt 4B\nAustin, TX 78701"
    static func parseMultilineAddress(_ input: String) -> ParsedAddress? {
        let lines = input.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return nil }

        // The last line should contain city, state, and optionally ZIP.
        let lastLine = lines.last!
        let cityStateZipPattern = #"^(.+?)[,\s]+([A-Za-z]{2,}\.?\s*[A-Za-z]*)\s*(\d{5}(?:-\d{4})?)?$"#

        guard let regex = try? NSRegularExpression(pattern: cityStateZipPattern),
              let match = regex.firstMatch(in: lastLine, range: NSRange(lastLine.startIndex..., in: lastLine)),
              match.numberOfRanges >= 3 else {
            return nil
        }

        let city = extractGroup(match, group: 1, from: lastLine)
        let rawState = extractGroup(match, group: 2, from: lastLine)
        let zip = match.numberOfRanges > 3 ? extractGroup(match, group: 3, from: lastLine) : ""
        let state = normalizeState(rawState)

        guard !city.isEmpty, !state.isEmpty else {
            return nil
        }

        // Everything before the last line is the street.
        let streetLines = lines.dropLast()
        let street = streetLines.joined(separator: ", ")

        let zipConfidence: FieldConfidence = zip.isEmpty ? .low : .high

        return ParsedAddress(
            street: .high(cleanStreet(street)),
            city: .high(city.trimmingCharacters(in: .whitespaces)),
            state: .high(state),
            postalCode: ParsedAddressField(value: zip, confidence: zipConfidence),
            countryCode: .medium("US")
        )
    }

    /// Loose parsing for addresses without commas: "123 Main Austin Texas"
    /// Tries to match a street number + street name, then a known state name/abbreviation.
    static func parseLooseAddress(_ input: String) -> ParsedAddress? {
        // Look for a ZIP code anywhere in the string.
        let zipPattern = #"\b(\d{5}(?:-\d{4})?)\b"#
        var zip = ""
        var workingInput = input

        if let zipRegex = try? NSRegularExpression(pattern: zipPattern),
           let zipMatch = zipRegex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            zip = extractGroup(zipMatch, group: 1, from: input)
            workingInput = (input as NSString).replacingCharacters(in: zipMatch.range, with: "")
                .trimmingCharacters(in: .whitespaces)
        }

        // Look for a state name or abbreviation.
        let words = workingInput.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var stateMatch = ""
        var stateEndIndex = words.count

        // Check two-word state names first (e.g., "New York", "North Carolina").
        for i in 0..<(words.count - 1) {
            let twoWord = "\(words[i]) \(words[i + 1])"
            if let abbr = stateAbbreviation(for: twoWord) {
                stateMatch = abbr
                stateEndIndex = i
                break
            }
        }

        // Then check single-word state names/abbreviations.
        if stateMatch.isEmpty {
            for i in stride(from: words.count - 1, through: 0, by: -1) {
                if let abbr = stateAbbreviation(for: words[i]) {
                    stateMatch = abbr
                    stateEndIndex = i
                    break
                }
            }
        }

        guard !stateMatch.isEmpty else {
            return nil
        }

        // Try to separate street from city.
        // Heuristic: the street starts with a number; the city is the word(s) before the state.
        let beforeState = Array(words[0..<stateEndIndex])

        // Find where the street number + name ends and city begins.
        // If the first token is a number, assume street address format.
        var street = ""
        var city = ""

        if let firstWord = beforeState.first, firstWord.rangeOfCharacter(from: .decimalDigits) != nil {
            // Heuristic: assume last 1-2 words before state are the city.
            if beforeState.count >= 3 {
                // Check if the second-to-last word could be part of a city name.
                // Simple heuristic: take the last word as city, rest as street.
                let streetWords = beforeState.dropLast(1)
                city = beforeState.last ?? ""
                street = streetWords.joined(separator: " ")
            } else if beforeState.count == 2 {
                street = beforeState[0]
                city = beforeState[1]
            } else {
                street = beforeState.joined(separator: " ")
            }
        } else {
            // No number at the start; put everything in street.
            street = beforeState.joined(separator: " ")
        }

        return ParsedAddress(
            street: street.isEmpty ? .low("") : .medium(cleanStreet(street)),
            city: city.isEmpty ? .low("") : .medium(city),
            state: .medium(stateMatch),
            postalCode: zip.isEmpty ? .low("") : .high(zip),
            countryCode: .medium("US")
        )
    }

    // MARK: - Utilities

    static func extractGroup(_ match: NSTextCheckingResult, group: Int, from string: String) -> String {
        guard group < match.numberOfRanges else { return "" }
        let nsRange = match.range(at: group)
        guard nsRange.location != NSNotFound,
              let range = Range(nsRange, in: string) else { return "" }
        return String(string[range])
    }

    /// Cleans up a street string by removing trailing commas and normalizing whitespace.
    static func cleanStreet(_ street: String) -> String {
        street
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))
            .trimmingCharacters(in: .whitespaces)
    }

    /// Normalizes a state name or abbreviation to a 2-letter US state code.
    /// Returns the input unchanged if no match is found (may be a non-US state).
    static func normalizeState(_ input: String) -> String {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")

        // Already a valid abbreviation?
        let upper = cleaned.uppercased()
        if upper.count == 2, stateNames[upper] != nil {
            return upper
        }

        // Try full name lookup.
        if let abbr = stateAbbreviation(for: cleaned) {
            return abbr
        }

        // Return as-is (could be a non-US state/province).
        return cleaned
    }

    /// Looks up a state abbreviation from a full name or abbreviation.
    static func stateAbbreviation(for input: String) -> String? {
        let cleaned = input.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".", with: "")
        let upper = cleaned.uppercased()

        // Direct abbreviation match.
        if upper.count == 2, stateNames[upper] != nil {
            return upper
        }

        // Full name to abbreviation.
        let lowered = cleaned.lowercased()
        for (abbr, name) in stateNames {
            if name.lowercased() == lowered {
                return abbr
            }
        }

        return nil
    }

    /// All 50 US states + DC: abbreviation -> full name.
    static let stateNames: [String: String] = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
        "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
        "DC": "District of Columbia", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii",
        "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa",
        "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine",
        "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
        "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska",
        "NV": "Nevada", "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico",
        "NY": "New York", "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio",
        "OK": "Oklahoma", "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island",
        "SC": "South Carolina", "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas",
        "UT": "Utah", "VT": "Vermont", "VA": "Virginia", "WA": "Washington",
        "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming",
    ]

    static var emptyAddress: ParsedAddress {
        ParsedAddress(
            street: .low(""),
            city: .low(""),
            state: .low(""),
            postalCode: .low(""),
            countryCode: .low("")
        )
    }
}

// MARK: - Contact Parsing Helpers

private extension RegexParsingService {

    /// Extracts all email addresses from the input string.
    static func extractEmails(from input: String) -> [String] {
        let pattern = #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: input) else { return nil }
            return String(input[range])
        }
    }

    /// Extracts all phone numbers from the input string.
    /// Recognizes formats: (xxx) xxx-xxxx, xxx-xxx-xxxx, xxx.xxx.xxxx, +1xxxxxxxxxx, etc.
    static func extractPhoneNumbers(from input: String) -> [String] {
        let pattern = #"(?:\+?1[\s.-]?)?\(?\d{3}\)?[\s.\-]?\d{3}[\s.\-]?\d{4}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: input) else { return nil }
            return String(input[range]).trimmingCharacters(in: .whitespaces)
        }
    }

    /// Extracts a name prefix (Dr., Mr., Ms., Mrs., Miss, Prof., etc.) from the beginning of text.
    /// Case-insensitive matching with canonical form output.
    /// Returns the prefix and the remaining text.
    static func extractNamePrefix(from input: String) -> (prefix: String, remaining: String) {
        // Map lowercased prefix variants to their canonical display form.
        let canonicalPrefixes: [String: String] = [
            "dr.": "Dr.", "dr": "Dr.",
            "mr.": "Mr.", "mr": "Mr.",
            "mrs.": "Mrs.", "mrs": "Mrs.",
            "ms.": "Ms.", "ms": "Ms.",
            "miss.": "Miss", "miss": "Miss",
            "prof.": "Prof.", "prof": "Prof.",
            "rev.": "Rev.", "rev": "Rev.",
            "hon.": "Hon.", "hon": "Hon.",
            "sgt.": "Sgt.", "sgt": "Sgt.",
            "cpl.": "Cpl.", "cpl": "Cpl.",
            "lt.": "Lt.", "lt": "Lt.",
            "capt.": "Capt.", "capt": "Capt.",
        ]

        // Sort keys longest first so "mrs." matches before "mr".
        let sortedKeys = canonicalPrefixes.keys.sorted { $0.count > $1.count }

        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()

        for key in sortedKeys {
            if lowered.hasPrefix(key), trimmed.count > key.count {
                let afterPrefix = trimmed[trimmed.index(trimmed.startIndex, offsetBy: key.count)...]
                let next = afterPrefix.first
                // Ensure the prefix is followed by a space, period, or end of string.
                if next == " " || next == "." || next == nil {
                    let remaining = afterPrefix
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                        .trimmingCharacters(in: .whitespaces)
                    let canonical = canonicalPrefixes[key]!
                    return (canonical, remaining)
                }
            }
        }

        return ("", trimmed)
    }

    /// Extracts given and family names from text using NaturalLanguage person name recognition.
    /// Returns the extracted names and any remaining text that was not identified as a name.
    static func extractName(from input: String) -> (givenName: String, familyName: String, remaining: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return ("", "", "")
        }

        // Use NLTagger to identify person names.
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = trimmed

        var nameTokens: [String] = []
        var nameRanges: [Range<String.Index>] = []

        tagger.enumerateTags(
            in: trimmed.startIndex..<trimmed.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, range in
            if tag == .personalName {
                nameTokens.append(String(trimmed[range]))
                nameRanges.append(range)
            }
            return true
        }

        var givenName = ""
        var familyName = ""
        var remaining = trimmed

        if nameTokens.count >= 2 {
            givenName = nameTokens[0]
            familyName = nameTokens[1..<nameTokens.count].joined(separator: " ")
            // Remove name tokens from remaining text.
            for range in nameRanges.reversed() {
                remaining.removeSubrange(range)
            }
        } else if nameTokens.count == 1 {
            givenName = nameTokens[0]
            for range in nameRanges.reversed() {
                remaining.removeSubrange(range)
            }
        } else {
            // NLTagger did not find a name. Fall back to heuristic:
            // take the first two words as given + family name.
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if words.count >= 2 {
                // Only treat as names if they look like names (start with uppercase, no special chars).
                let looksLikeName = words[0].first?.isUppercase == true && words[1].first?.isUppercase == true
                if looksLikeName {
                    givenName = words[0].trimmingCharacters(in: CharacterSet(charactersIn: ","))
                    familyName = words[1].trimmingCharacters(in: CharacterSet(charactersIn: ","))
                    let nameString = words[0...1].joined(separator: " ")
                    if let range = remaining.range(of: nameString) {
                        remaining.removeSubrange(range)
                    }
                }
            } else if words.count == 1, words[0].first?.isUppercase == true {
                givenName = words[0].trimmingCharacters(in: CharacterSet(charactersIn: ","))
                remaining = ""
            }
        }

        // Clean up remaining text.
        remaining = remaining
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",;"))
            .trimmingCharacters(in: .whitespaces)

        return (givenName, familyName, remaining)
    }

    /// Extracts job title and organization from comma/newline-separated remaining text.
    ///
    /// Heuristic: if there are two segments, treat the first as job title and second as organization.
    /// If there is one segment, treat it as the organization.
    static func extractTitleAndOrganization(from input: String) -> (jobTitle: String, organization: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return ("", "")
        }

        // Split on comma, semicolon, or newline.
        let segments = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        switch segments.count {
        case 0:
            return ("", "")
        case 1:
            return ("", segments[0])
        default:
            // First segment = title, second = organization.
            return (segments[0], segments[1])
        }
    }

    /// Returns true if the string has 2+ letter characters and all of them are uppercase.
    static func isAllCaps(_ input: String) -> Bool {
        let letters = input.filter { $0.isLetter }
        return letters.count >= 2 && letters.allSatisfy { $0.isUppercase }
    }

    /// Title-cases a string: splits on whitespace, lowercases each word, capitalizes the first letter.
    /// Only intended to be called when `isAllCaps` is true; mixed-case input should be left unchanged.
    static func titleCased(_ input: String) -> String {
        input.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { word in
                let lowered = word.lowercased()
                return lowered.prefix(1).uppercased() + lowered.dropFirst()
            }
            .joined(separator: " ")
    }

    /// Returns true if the line looks like a mailing/street address.
    static func looksLikeAddress(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        // PO BOX patterns
        if trimmed.range(of: #"\bP\.?O\.?\s*BOX\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        // ZIP code pattern
        if trimmed.range(of: #"\b\d{5}(-\d{4})?\b"#, options: .regularExpression) != nil {
            return true
        }

        // Apt, Suite, Ste, Unit, # followed by alphanumeric
        if trimmed.range(of: #"\b(?:Apt|Suite|Ste|Unit)\b\.?\s*#?\s*\w+"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        if trimmed.range(of: #"#\s*\w+"#, options: .regularExpression) != nil {
            return true
        }

        // Street suffixes at word boundary
        let streetSuffixes = [
            "St", "Street", "Ave", "Avenue", "Blvd", "Boulevard",
            "Dr", "Drive", "Ln", "Lane", "Rd", "Road", "Ct", "Court",
            "Pl", "Place", "Way", "Cir", "Circle", "Pkwy", "Parkway",
            "Hwy", "Highway",
        ]
        let suffixPattern = "\\b(" + streetSuffixes.joined(separator: "|") + ")\\.?\\b"
        if trimmed.range(of: suffixPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            // Make sure it's not just a name prefix like "Dr." followed by a name.
            // If line starts with a digit, it's definitely an address.
            if trimmed.first?.isNumber == true {
                return true
            }
            // If the match is a suffix like "St" or "Dr" but the line has no digits,
            // be more cautious — only match multi-character suffixes or when preceded by text.
            let longSuffixes = streetSuffixes.filter { $0.count > 2 }
            let longPattern = "\\b(" + longSuffixes.joined(separator: "|") + ")\\.?\\b"
            if trimmed.range(of: longPattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }

        // Starts with a street number followed by a word (and is NOT just a phone number)
        if trimmed.range(of: #"^\d+\s+\w+"#, options: .regularExpression) != nil {
            // Exclude phone number patterns (e.g., "512 555 1234")
            if trimmed.range(of: #"^\d{3}\s+\d{3}\s+\d{4}$"#, options: .regularExpression) == nil {
                return true
            }
        }

        // City + state abbreviation + zip pattern
        if trimmed.range(of: #"[A-Za-z]+\s+[A-Z]{2}\s+\d{5}"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    /// Returns true if the line looks like a person's name.
    static func looksLikeName(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        // Must not look like an address.
        guard !looksLikeAddress(trimmed) else { return false }

        // Must have no digits.
        guard trimmed.rangeOfCharacter(from: .decimalDigits) == nil else { return false }

        // Split into words and check count (1-4 words).
        let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard (1...4).contains(words.count) else { return false }

        // All words must be primarily alphabetic (allow ., -, ').
        let allowedNonAlpha = CharacterSet(charactersIn: ".-'")
        for word in words {
            let stripped = word.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
            for scalar in stripped.unicodeScalars {
                if !CharacterSet.letters.contains(scalar) && !allowedNonAlpha.contains(scalar) {
                    return false
                }
            }
        }

        return true
    }

    static var emptyContact: ParsedContact {
        ParsedContact(
            namePrefix: .low(""),
            givenName: .low(""),
            familyName: .low(""),
            jobTitle: .low(""),
            organization: .low(""),
            phoneNumbers: [],
            emailAddresses: [],
            address: nil
        )
    }
}

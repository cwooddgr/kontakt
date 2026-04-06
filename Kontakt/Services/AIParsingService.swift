import Foundation

// MARK: - AI Parsing Errors

/// Errors specific to the AI parsing service.
enum AIParsingError: Error, LocalizedError {
    case unavailable
    case generationFailed(underlying: Error)
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Foundation Models is not available on this device."
        case .generationFailed(let underlying):
            return "AI parsing failed: \(underlying.localizedDescription)"
        case .emptyInput:
            return "Cannot parse empty input."
        }
    }
}

// MARK: - AI Parsing Service

/// Wraps the Foundation Models framework for on-device AI parsing.
///
/// On devices running iOS 26+ with Apple Intelligence support (iPhone 15 Pro+),
/// this service uses the on-device language model to parse freeform text into
/// structured address and contact data. On older devices or unsupported hardware,
/// `isAvailable` returns false and all parsing methods throw `AIParsingError.unavailable`.
///
/// This is Tier 1 in the parsing hierarchy. Tier 2 (regex-based) is in `RegexParsingService`.
enum AIParsingService: Sendable {

    /// Whether Foundation Models is available on this device.
    ///
    /// Returns true only on iOS 26+ with supported hardware. The check is
    /// performed at runtime so the app can be compiled against older SDKs.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return true
        }
        #endif
        return false
    }

    // MARK: - Address Parsing

    /// Parses freeform address text into a structured `ParsedAddress` using Foundation Models.
    ///
    /// - Parameter input: Freeform address text (e.g., pasted from an email or website).
    /// - Returns: A `ParsedAddress` with per-field confidence scores.
    /// - Throws: `AIParsingError.unavailable` if Foundation Models is not supported,
    ///           `AIParsingError.emptyInput` if the input is blank,
    ///           `AIParsingError.generationFailed` if the model fails to produce output.
    static func parseAddress(_ input: String) async throws -> ParsedAddress {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIParsingError.emptyInput
        }

        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return try await parseAddressWithFoundationModels(trimmed)
        }
        #endif

        throw AIParsingError.unavailable
    }

    // MARK: - Contact Parsing

    /// Parses freeform contact text into a structured `ParsedContact` using Foundation Models.
    ///
    /// - Parameter input: Freeform contact text (e.g., from a business card or email signature).
    /// - Returns: A `ParsedContact` with per-field confidence scores.
    /// - Throws: `AIParsingError.unavailable` if Foundation Models is not supported,
    ///           `AIParsingError.emptyInput` if the input is blank,
    ///           `AIParsingError.generationFailed` if the model fails to produce output.
    static func parseContact(_ input: String) async throws -> ParsedContact {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIParsingError.emptyInput
        }

        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return try await parseContactWithFoundationModels(trimmed)
        }
        #endif

        throw AIParsingError.unavailable
    }
}

// MARK: - Foundation Models Implementation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
extension AIParsingService {

    // MARK: - @Generable Types

    /// Internal @Generable struct for address parsing via Foundation Models.
    /// Maps to our public `ParsedAddress` model after generation.
    @Generable
    struct GenerableAddress {
        @Guide(description: "Street address including apartment, suite, or unit number")
        var street: String

        @Guide(description: "City name")
        var city: String

        @Guide(description: "State or province, abbreviated if US (e.g., TX)")
        var state: String

        @Guide(description: "ZIP or postal code")
        var postalCode: String

        @Guide(description: "ISO country code if identifiable, empty string if ambiguous")
        var countryCode: String
    }

    /// Internal @Generable struct for contact parsing via Foundation Models.
    /// Covers all fields a person might include in a business card, email signature,
    /// mailing label, or pasted text block. Maps to CNContact fields after generation.
    @Generable
    struct GenerableContact {
        // MARK: Name
        @Guide(description: "Name prefix or title such as Dr., Mr., Ms., Miss, or empty string if none")
        var namePrefix: String

        @Guide(description: "Given (first) name")
        var givenName: String

        @Guide(description: "Middle name, or empty string if not found")
        var middleName: String

        @Guide(description: "Family (last) name")
        var familyName: String

        @Guide(description: "Name suffix such as Jr., Sr., III, PhD, or empty string if none")
        var nameSuffix: String

        @Guide(description: "Nickname or preferred name, or empty string if not found")
        var nickname: String

        // MARK: Work
        @Guide(description: "Job title or role, or empty string if not found")
        var jobTitle: String

        @Guide(description: "Department within the organization, or empty string if not found")
        var department: String

        @Guide(description: "Company or organization name, or empty string if not found")
        var organization: String

        // MARK: Contact info
        @Guide(description: "Phone numbers found in the input, including mobile, work, home, fax")
        var phoneNumbers: [String]

        @Guide(description: "Email addresses found in the input")
        var emailAddresses: [String]

        @Guide(description: "Website URLs found in the input")
        var urls: [String]

        // MARK: Address
        @Guide(description: "Street address including apartment, suite, or unit number, or empty string if not found")
        var street: String

        @Guide(description: "City name, or empty string if not found")
        var city: String

        @Guide(description: "State or province abbreviated if US (e.g., TX), or empty string if not found")
        var addressState: String

        @Guide(description: "ZIP or postal code, or empty string if not found")
        var postalCode: String

        @Guide(description: "Country name or ISO code, or empty string if not found")
        var country: String

        // MARK: Social & online
        @Guide(description: "Social media profile URLs or handles found (e.g., linkedin.com/in/..., @handle), as an array of strings")
        var socialProfiles: [String]

        // MARK: Other
        @Guide(description: "Birthday or date of birth in ISO format (YYYY-MM-DD), or empty string if not found")
        var birthday: String

        @Guide(description: "Any additional notes or context that don't fit other fields, or empty string")
        var notes: String
    }

    // MARK: - Private Parsing Helpers

    private static func parseAddressWithFoundationModels(_ input: String) async throws -> ParsedAddress {
        do {
            let session = LanguageModelSession()
            let prompt = """
            Parse the following freeform address text into structured fields. \
            Extract the street (including any apartment, suite, or unit), city, \
            state (use 2-letter abbreviation for US states), postal/ZIP code, \
            and ISO country code. If a field is not present, use an empty string.

            Address text:
            \(input)
            """

            let response = try await session.respond(to: prompt, generating: GenerableAddress.self)
            let generated = response.content

            // All AI-parsed fields start at high confidence. The UI can downgrade
            // based on post-validation (e.g., CNPostalAddressFormatter round-trip).
            return ParsedAddress(
                street: .high(generated.street),
                city: .high(generated.city),
                state: .high(generated.state),
                postalCode: .high(generated.postalCode),
                countryCode: .high(generated.countryCode)
            )
        } catch {
            throw AIParsingError.generationFailed(underlying: error)
        }
    }

    private static func parseContactWithFoundationModels(_ input: String) async throws -> ParsedContact {
        do {
            let session = LanguageModelSession()
            let prompt = """
            Parse the following freeform text into structured contact fields. \
            Extract everything you can: name (prefix, first, middle, last, suffix, nickname), \
            job title, department, company/organization, phone numbers, email addresses, \
            website URLs, postal address (street, city, state, ZIP, country), \
            social media profiles, birthday, and any notes. \
            If a field is not present, use an empty string (or empty array for lists). \
            For birthday, use ISO format YYYY-MM-DD if found.

            Contact text:
            \(input)
            """

            let response = try await session.respond(to: prompt, generating: GenerableContact.self)
            let generated = response.content

            // Build address if any component was found
            let address: ParsedAddress?
            if !generated.street.isEmpty || !generated.city.isEmpty {
                address = ParsedAddress(
                    street: .high(generated.street),
                    city: .high(generated.city),
                    state: .high(generated.addressState),
                    postalCode: .high(generated.postalCode),
                    countryCode: .high(generated.country)
                )
            } else {
                address = nil
            }

            // Build the contact and apply extra fields directly to CNMutableContact
            var parsed = ParsedContact(
                namePrefix: .high(generated.namePrefix),
                givenName: .high(generated.givenName),
                familyName: .high(generated.familyName),
                jobTitle: .high(generated.jobTitle),
                organization: .high(generated.organization),
                phoneNumbers: generated.phoneNumbers.map { (value: $0, confidence: .high) },
                emailAddresses: generated.emailAddresses.map { (value: $0, confidence: .high) },
                address: address
            )

            // Store extra fields that ParsedContact doesn't model directly.
            // These get applied in toCNMutableContact() via the extraFields dictionary.
            var extras: [String: String] = [:]
            if !generated.middleName.isEmpty { extras["middleName"] = generated.middleName }
            if !generated.nameSuffix.isEmpty { extras["nameSuffix"] = generated.nameSuffix }
            if !generated.nickname.isEmpty { extras["nickname"] = generated.nickname }
            if !generated.department.isEmpty { extras["department"] = generated.department }
            if !generated.birthday.isEmpty { extras["birthday"] = generated.birthday }
            if !generated.notes.isEmpty { extras["notes"] = generated.notes }
            if !generated.urls.isEmpty { extras["urls"] = generated.urls.joined(separator: "\n") }
            if !generated.socialProfiles.isEmpty { extras["socialProfiles"] = generated.socialProfiles.joined(separator: "\n") }
            parsed.extraFields = extras

            return parsed
        } catch {
            throw AIParsingError.generationFailed(underlying: error)
        }
    }
}
#endif

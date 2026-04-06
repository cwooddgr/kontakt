import XCTest
import Contacts
@testable import Kontakt

final class ContactMatchingServiceTests: XCTestCase {

    // MARK: - Helper: Create Mock Data

    /// Creates a CNMutableContact with the given properties.
    private func makeMutableContact(
        givenName: String = "",
        familyName: String = "",
        organizationName: String = "",
        jobTitle: String = "",
        phoneNumbers: [String] = [],
        emailAddresses: [String] = [],
        postalAddresses: [(street: String, city: String, state: String, zip: String)] = []
    ) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = givenName
        contact.familyName = familyName
        contact.organizationName = organizationName
        contact.jobTitle = jobTitle
        contact.phoneNumbers = phoneNumbers.map {
            CNLabeledValue(
                label: CNLabelPhoneNumberMobile,
                value: CNPhoneNumber(stringValue: $0)
            )
        }
        contact.emailAddresses = emailAddresses.map {
            CNLabeledValue(label: CNLabelHome, value: $0 as NSString)
        }
        contact.postalAddresses = postalAddresses.map { addr in
            let postal = CNMutablePostalAddress()
            postal.street = addr.street
            postal.city = addr.city
            postal.state = addr.state
            postal.postalCode = addr.zip
            return CNLabeledValue(label: CNLabelHome, value: postal as CNPostalAddress)
        }
        return contact
    }

    /// Creates a minimal ParsedContact for matching tests.
    private func makeParsedContact(
        givenName: String = "",
        familyName: String = "",
        organization: String = "",
        jobTitle: String = "",
        phoneNumbers: [String] = [],
        emailAddresses: [String] = [],
        address: ParsedAddress? = nil
    ) -> ParsedContact {
        ParsedContact(
            namePrefix: .high(""),
            givenName: .high(givenName),
            familyName: .high(familyName),
            jobTitle: .high(jobTitle),
            organization: .high(organization),
            phoneNumbers: phoneNumbers.map { (value: $0, confidence: FieldConfidence.high) },
            emailAddresses: emailAddresses.map { (value: $0, confidence: FieldConfidence.high) },
            address: address
        )
    }

    // MARK: - Phone Normalization

    func testPhoneNormalization_stripsFormatting() {
        // This verifies the phoneNormalized extension used by ContactMatchingService.
        XCTAssertEqual("(512) 555-1234".phoneNormalized, "5125551234")
        XCTAssertEqual("+1-512-555-1234".phoneNormalized, "15125551234")
        XCTAssertEqual("512.555.1234".phoneNormalized, "5125551234")
    }

    func testPhoneNormalization_identicalDigitsMatch() {
        // Two differently formatted phone numbers with the same digits should normalize equally.
        let phone1 = "(512) 555-1234".phoneNormalized
        let phone2 = "512-555-1234".phoneNormalized
        let phone3 = "512.555.1234".phoneNormalized
        XCTAssertEqual(phone1, phone2)
        XCTAssertEqual(phone2, phone3)
    }

    // MARK: - FieldDiff

    func testFieldDiff_hasUniqueID() {
        let diff1 = ContactMatchingService.FieldDiff(
            fieldName: "Phone",
            oldValue: nil,
            newValue: "512-555-1234"
        )
        let diff2 = ContactMatchingService.FieldDiff(
            fieldName: "Phone",
            oldValue: nil,
            newValue: "512-555-1234"
        )
        // Each FieldDiff should have a unique UUID-based ID.
        XCTAssertNotEqual(diff1.id, diff2.id)
    }

    // MARK: - ParsedContact → CNMutableContact Conversion

    func testParsedContactToCNMutableContact_basicFields() {
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            organization: "Acme Corp",
            jobTitle: "Engineer",
            phoneNumbers: ["512-555-1234"],
            emailAddresses: ["jen@acme.com"]
        )

        let cnContact = parsed.toCNMutableContact()

        XCTAssertEqual(cnContact.givenName, "Jennifer")
        XCTAssertEqual(cnContact.familyName, "Smith")
        XCTAssertEqual(cnContact.organizationName, "Acme Corp")
        XCTAssertEqual(cnContact.jobTitle, "Engineer")
        XCTAssertEqual(cnContact.phoneNumbers.count, 1)
        XCTAssertEqual(cnContact.phoneNumbers.first?.value.stringValue, "512-555-1234")
        XCTAssertEqual(cnContact.emailAddresses.count, 1)
        XCTAssertEqual(cnContact.emailAddresses.first?.value as String?, "jen@acme.com")
    }

    func testParsedContactToCNMutableContact_withAddress() {
        let address = ParsedAddress(
            street: .high("123 Main St"),
            city: .high("Austin"),
            state: .high("TX"),
            postalCode: .high("78701"),
            countryCode: .high("US")
        )
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            address: address
        )

        let cnContact = parsed.toCNMutableContact()

        XCTAssertEqual(cnContact.postalAddresses.count, 1)
        let postalAddress = cnContact.postalAddresses.first?.value
        XCTAssertEqual(postalAddress?.street, "123 Main St")
        XCTAssertEqual(postalAddress?.city, "Austin")
        XCTAssertEqual(postalAddress?.state, "TX")
        XCTAssertEqual(postalAddress?.postalCode, "78701")
        XCTAssertEqual(postalAddress?.isoCountryCode, "US")
    }

    func testParsedContactToCNMutableContact_withExtraFields() {
        var parsed = makeParsedContact(givenName: "Jennifer", familyName: "Smith")
        parsed.extraFields = [
            "middleName": "Marie",
            "nameSuffix": "Jr.",
            "nickname": "Jen",
            "department": "Engineering",
            "notes": "Met at conference",
            "urls": "https://example.com\nhttps://blog.example.com"
        ]

        let cnContact = parsed.toCNMutableContact()

        XCTAssertEqual(cnContact.middleName, "Marie")
        XCTAssertEqual(cnContact.nameSuffix, "Jr.")
        XCTAssertEqual(cnContact.nickname, "Jen")
        XCTAssertEqual(cnContact.departmentName, "Engineering")
        XCTAssertEqual(cnContact.note, "Met at conference")
        XCTAssertEqual(cnContact.urlAddresses.count, 2)
        XCTAssertEqual(cnContact.urlAddresses[0].value as String, "https://example.com")
        XCTAssertEqual(cnContact.urlAddresses[1].value as String, "https://blog.example.com")
    }

    func testParsedContactToCNMutableContact_emptyFieldsNotSet() {
        let parsed = makeParsedContact() // All fields empty

        let cnContact = parsed.toCNMutableContact()

        XCTAssertEqual(cnContact.givenName, "")
        XCTAssertEqual(cnContact.familyName, "")
        XCTAssertEqual(cnContact.organizationName, "")
        XCTAssertEqual(cnContact.jobTitle, "")
        XCTAssertTrue(cnContact.phoneNumbers.isEmpty)
        XCTAssertTrue(cnContact.emailAddresses.isEmpty)
        XCTAssertTrue(cnContact.postalAddresses.isEmpty)
    }

    func testParsedContactToCNMutableContact_multiplePhones() {
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            phoneNumbers: ["512-555-1234", "512-555-5678"]
        )

        let cnContact = parsed.toCNMutableContact()

        XCTAssertEqual(cnContact.phoneNumbers.count, 2)
    }

    func testParsedContactToCNMutableContact_multipleEmails() {
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            emailAddresses: ["jen@home.com", "jen@work.com"]
        )

        let cnContact = parsed.toCNMutableContact()

        XCTAssertEqual(cnContact.emailAddresses.count, 2)
    }

    // MARK: - ParsedContact Confidence

    func testNameConfidence_returnsLowest() {
        let parsed = ParsedContact(
            namePrefix: .high(""),
            givenName: .high("Jennifer"),
            familyName: .low("Smith"),
            jobTitle: .high(""),
            organization: .high(""),
            phoneNumbers: [],
            emailAddresses: [],
            address: nil
        )

        XCTAssertEqual(parsed.nameConfidence, .low,
                        "Name confidence should be the minimum of given and family name confidence")
    }

    func testNameConfidence_bothHigh() {
        let parsed = makeParsedContact(givenName: "Jennifer", familyName: "Smith")

        XCTAssertEqual(parsed.nameConfidence, .high)
    }

    // MARK: - MergeFields

    func testMergeFields_addsNewPhone() {
        let existing = makeMutableContact(
            givenName: "Jennifer",
            familyName: "Smith",
            phoneNumbers: ["512-555-1234"]
        )
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            phoneNumbers: ["512-555-5678"]
        )

        ContactMatchingService.mergeFields(from: parsed, into: existing)

        XCTAssertEqual(existing.phoneNumbers.count, 2,
                        "Merge should add the new phone number")
    }

    func testMergeFields_doesNotDuplicateExistingPhone() {
        let existing = makeMutableContact(
            givenName: "Jennifer",
            familyName: "Smith",
            phoneNumbers: ["512-555-1234"]
        )
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            phoneNumbers: ["(512) 555-1234"] // same number, different format
        )

        ContactMatchingService.mergeFields(from: parsed, into: existing)

        XCTAssertEqual(existing.phoneNumbers.count, 1,
                        "Merge should not add a phone number that already exists (different formatting)")
    }

    func testMergeFields_addsNewEmail() {
        let existing = makeMutableContact(
            givenName: "Jennifer",
            familyName: "Smith",
            emailAddresses: ["jen@home.com"]
        )
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            emailAddresses: ["jen@work.com"]
        )

        ContactMatchingService.mergeFields(from: parsed, into: existing)

        XCTAssertEqual(existing.emailAddresses.count, 2,
                        "Merge should add the new email address")
    }

    func testMergeFields_doesNotDuplicateExistingEmail() {
        let existing = makeMutableContact(
            givenName: "Jennifer",
            familyName: "Smith",
            emailAddresses: ["JEN@home.com"]
        )
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            emailAddresses: ["jen@home.com"] // same email, different case
        )

        ContactMatchingService.mergeFields(from: parsed, into: existing)

        XCTAssertEqual(existing.emailAddresses.count, 1,
                        "Merge should not add an email that already exists (case-insensitive)")
    }

    func testMergeFields_addsJobTitleOnlyIfEmpty() {
        let existing = makeMutableContact(
            givenName: "Jennifer",
            familyName: "Smith",
            jobTitle: "Engineer"
        )
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            jobTitle: "Senior Engineer"
        )

        ContactMatchingService.mergeFields(from: parsed, into: existing)

        XCTAssertEqual(existing.jobTitle, "Engineer",
                        "Merge should not overwrite an existing job title")
    }

    func testMergeFields_addsJobTitleWhenEmpty() {
        let existing = makeMutableContact(
            givenName: "Jennifer",
            familyName: "Smith"
        )
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            jobTitle: "Engineer"
        )

        ContactMatchingService.mergeFields(from: parsed, into: existing)

        XCTAssertEqual(existing.jobTitle, "Engineer",
                        "Merge should add job title when existing is empty")
    }

    func testMergeFields_addsOrganizationOnlyIfEmpty() {
        let existing = makeMutableContact(
            givenName: "Jennifer",
            familyName: "Smith",
            organizationName: "Acme Corp"
        )
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            organization: "Widget Inc"
        )

        ContactMatchingService.mergeFields(from: parsed, into: existing)

        XCTAssertEqual(existing.organizationName, "Acme Corp",
                        "Merge should not overwrite an existing organization")
    }

    func testMergeFields_addsAddress() {
        let existing = makeMutableContact(
            givenName: "Jennifer",
            familyName: "Smith"
        )
        let address = ParsedAddress(
            street: .high("123 Main St"),
            city: .high("Austin"),
            state: .high("TX"),
            postalCode: .high("78701"),
            countryCode: .high("US")
        )
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            address: address
        )

        ContactMatchingService.mergeFields(from: parsed, into: existing)

        XCTAssertEqual(existing.postalAddresses.count, 1,
                        "Merge should add the address when none exists")
        XCTAssertEqual(existing.postalAddresses.first?.value.city, "Austin")
    }

    func testMergeFields_doesNotDuplicateExistingAddress() {
        let existing = makeMutableContact(
            givenName: "Jennifer",
            familyName: "Smith",
            postalAddresses: [(street: "123 Main St", city: "Austin", state: "TX", zip: "78701")]
        )
        let address = ParsedAddress(
            street: .high("123 Main St"),
            city: .high("Austin"),
            state: .high("TX"),
            postalCode: .high("78701"),
            countryCode: .high("US")
        )
        let parsed = makeParsedContact(
            givenName: "Jennifer",
            familyName: "Smith",
            address: address
        )

        ContactMatchingService.mergeFields(from: parsed, into: existing)

        XCTAssertEqual(existing.postalAddresses.count, 1,
                        "Merge should not add a duplicate address")
    }

    // MARK: - ContactMatchingService.findMatch

    // NOTE: findMatch requires a ContactStore with populated `contacts` and working
    // `fetchContactDetail`. Since ContactStore.contacts is `private(set)` and
    // fetchContactDetail calls CNContactStore.unifiedContact (which requires a real
    // contact store with persisted contacts), we cannot unit-test findMatch with
    // mock data in isolation.
    //
    // The matching logic is tested indirectly through:
    // 1. Phone normalization tests (above and in StringExtensionTests)
    // 2. Levenshtein distance tests (in SearchEngineTests)
    // 3. MergeFields tests (above) which exercise the same diff/merge code paths
    // 4. ParsedContact conversion tests (above)
    //
    // For full integration testing of findMatch, a test target with real CNContactStore
    // access or a protocol-based abstraction of ContactStore would be needed.
}

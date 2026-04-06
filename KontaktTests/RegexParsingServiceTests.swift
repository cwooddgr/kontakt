import XCTest
@testable import Kontakt

final class RegexParsingServiceTests: XCTestCase {

    // MARK: - Address Parsing Tests

    func testParseAddress_standardUSFormat() {
        let result = RegexParsingService.parseAddress("1234 Main St, Austin, TX 78704")

        XCTAssertEqual(result.street.value, "1234 Main St")
        XCTAssertEqual(result.city.value, "Austin")
        XCTAssertEqual(result.state.value, "TX")
        XCTAssertEqual(result.postalCode.value, "78704")
        XCTAssertEqual(result.countryCode.value, "US")

        XCTAssertEqual(result.street.confidence, .high)
        XCTAssertEqual(result.city.confidence, .high)
        XCTAssertEqual(result.state.confidence, .high)
        XCTAssertEqual(result.postalCode.confidence, .high)
    }

    func testParseAddress_withApartment() {
        let result = RegexParsingService.parseAddress("1234 Main St, Apt 2B, Austin, TX 78704")

        // The regex should capture street including the apartment segment,
        // or split across street and the second comma-separated piece.
        // The key assertion is that city, state, and ZIP are correctly parsed.
        XCTAssertEqual(result.city.value, "Austin")
        XCTAssertEqual(result.state.value, "TX")
        XCTAssertEqual(result.postalCode.value, "78704")
        XCTAssertFalse(result.street.value.isEmpty, "Street should not be empty")
    }

    func testParseAddress_multiline() {
        let result = RegexParsingService.parseAddress("1234 Main St\nAustin, TX 78704")

        XCTAssertEqual(result.city.value, "Austin")
        XCTAssertEqual(result.state.value, "TX")
        XCTAssertEqual(result.postalCode.value, "78704")
        XCTAssertFalse(result.street.value.isEmpty, "Street should contain the street address")
    }

    func testParseAddress_fullStateName() {
        let result = RegexParsingService.parseAddress("1234 Main Street, Austin, Texas 78704")

        XCTAssertEqual(result.city.value, "Austin")
        XCTAssertEqual(result.state.value, "TX")
        XCTAssertEqual(result.postalCode.value, "78704")
    }

    func testParseAddress_zipPlusFour() {
        let result = RegexParsingService.parseAddress("1234 Main St, Austin, TX 78704-1234")

        XCTAssertEqual(result.state.value, "TX")
        XCTAssertEqual(result.postalCode.value, "78704-1234")
        XCTAssertEqual(result.city.value, "Austin")
    }

    func testParseAddress_cityStateOnly() {
        let result = RegexParsingService.parseAddress("Austin, TX")

        // A partial parse should still extract the state at minimum.
        XCTAssertEqual(result.state.value, "TX")
        // City may or may not be extracted depending on parser path,
        // but the state should always be found.
    }

    func testParseAddress_garbageInput() {
        let result = RegexParsingService.parseAddress("hello world")

        // Should produce mostly empty fields with low confidence.
        XCTAssertTrue(
            result.overallConfidence == .low,
            "Garbage input should produce low overall confidence"
        )
    }

    func testParseAddress_emptyInput() {
        let result = RegexParsingService.parseAddress("")

        XCTAssertEqual(result.street.value, "")
        XCTAssertEqual(result.city.value, "")
        XCTAssertEqual(result.state.value, "")
        XCTAssertEqual(result.postalCode.value, "")
        XCTAssertEqual(result.overallConfidence, .low)
    }

    // MARK: - Contact Parsing Tests

    func testParseContact_fullInfo() {
        let result = RegexParsingService.parseContact("Jennifer Smith 512-555-1234 jen@example.com")

        XCTAssertEqual(result.emailAddresses.count, 1)
        XCTAssertEqual(result.emailAddresses.first?.value, "jen@example.com")
        XCTAssertEqual(result.emailAddresses.first?.confidence, .high)

        XCTAssertEqual(result.phoneNumbers.count, 1)
        XCTAssertEqual(result.phoneNumbers.first?.value, "512-555-1234")
        XCTAssertEqual(result.phoneNumbers.first?.confidence, .high)

        // Name extraction depends on NLTagger, but at minimum
        // the given name should be found.
        XCTAssertFalse(
            result.givenName.value.isEmpty && result.familyName.value.isEmpty,
            "At least one name component should be extracted"
        )
    }

    func testParseContact_nameAndCompany() {
        let result = RegexParsingService.parseContact(
            "Dr. Robert Jones, Cardiologist, Heart Health Associates"
        )

        XCTAssertEqual(result.namePrefix.value, "Dr.")
        XCTAssertEqual(result.namePrefix.confidence, .medium)

        // The parser should extract at least a given name.
        XCTAssertFalse(
            result.givenName.value.isEmpty,
            "Given name should be extracted"
        )

        // With comma-separated segments after the name, the parser extracts
        // job title and organization from the remaining text.
        // At least one of jobTitle or organization should be non-empty.
        let hasCompanyInfo = !result.jobTitle.value.isEmpty || !result.organization.value.isEmpty
        XCTAssertTrue(hasCompanyInfo, "Should extract company or title info")
    }

    func testParseContact_emailOnly() {
        let result = RegexParsingService.parseContact("jen@example.com")

        XCTAssertEqual(result.emailAddresses.count, 1)
        XCTAssertEqual(result.emailAddresses.first?.value, "jen@example.com")
        XCTAssertEqual(result.emailAddresses.first?.confidence, .high)

        XCTAssertTrue(result.phoneNumbers.isEmpty)
    }

    func testParseContact_phoneOnly() {
        let result = RegexParsingService.parseContact("(512) 555-1234")

        XCTAssertEqual(result.phoneNumbers.count, 1)
        XCTAssertEqual(result.phoneNumbers.first?.confidence, .high)

        XCTAssertTrue(result.emailAddresses.isEmpty)
    }

    func testParseContact_multiplePhonesAndEmails() {
        let result = RegexParsingService.parseContact(
            "Bob 512-555-1234 bob@a.com 512-555-5678 bob@b.com"
        )

        XCTAssertEqual(result.emailAddresses.count, 2)
        XCTAssertTrue(
            result.emailAddresses.contains { $0.value == "bob@a.com" },
            "Should contain bob@a.com"
        )
        XCTAssertTrue(
            result.emailAddresses.contains { $0.value == "bob@b.com" },
            "Should contain bob@b.com"
        )

        XCTAssertEqual(result.phoneNumbers.count, 2)
    }

    func testParseContact_emptyInput() {
        let result = RegexParsingService.parseContact("")

        XCTAssertEqual(result.givenName.value, "")
        XCTAssertEqual(result.familyName.value, "")
        XCTAssertTrue(result.phoneNumbers.isEmpty)
        XCTAssertTrue(result.emailAddresses.isEmpty)
        XCTAssertEqual(result.nameConfidence, .low)
    }
}

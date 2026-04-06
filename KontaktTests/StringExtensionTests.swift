import XCTest
@testable import Kontakt

final class StringExtensionTests: XCTestCase {

    // MARK: - phoneNormalized

    func testPhoneNormalized_parenthesesAndDash() {
        XCTAssertEqual("(512) 555-1234".phoneNormalized, "5125551234")
    }

    func testPhoneNormalized_countryCodeWithDashes() {
        XCTAssertEqual("+1-512-555-1234".phoneNormalized, "15125551234")
    }

    func testPhoneNormalized_dots() {
        XCTAssertEqual("512.555.1234".phoneNormalized, "5125551234")
    }

    func testPhoneNormalized_alreadyDigits() {
        XCTAssertEqual("5125551234".phoneNormalized, "5125551234")
    }

    func testPhoneNormalized_emptyString() {
        XCTAssertEqual("".phoneNormalized, "")
    }

    func testPhoneNormalized_noDigits() {
        XCTAssertEqual("no digits here".phoneNormalized, "")
    }

    func testPhoneNormalized_mixedFormatting() {
        XCTAssertEqual("+1 (512) 555-1234".phoneNormalized, "15125551234")
    }

    // MARK: - formattedAsPhoneNumber

    func testFormattedAsPhoneNumber_tenDigits() {
        XCTAssertEqual("5125551234".formattedAsPhoneNumber, "(512) 555-1234")
    }

    func testFormattedAsPhoneNumber_elevenDigitsWithLeadingOne() {
        XCTAssertEqual("15125551234".formattedAsPhoneNumber, "+1 (512) 555-1234")
    }

    func testFormattedAsPhoneNumber_sevenDigits() {
        XCTAssertEqual("5551234".formattedAsPhoneNumber, "555-1234")
    }

    func testFormattedAsPhoneNumber_alreadyFormatted() {
        // When given a non-digit string, the digit count won't match a known
        // length, so it returns the original string.
        let formatted = "(512) 555-1234"
        XCTAssertEqual(formatted.formattedAsPhoneNumber, formatted)
    }

    func testFormattedAsPhoneNumber_unknownLength() {
        // 6 digits -- not a recognized length, should return original string.
        let sixDigits = "123456"
        XCTAssertEqual(sixDigits.formattedAsPhoneNumber, sixDigits)
    }
}

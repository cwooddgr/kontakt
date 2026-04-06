import XCTest
import Contacts
@testable import Kontakt

final class ContactWrapperTests: XCTestCase {

    // MARK: - fullName

    func testFullName_bothNames() {
        let wrapper = ContactWrapper(
            identifier: "test-1",
            givenName: "John",
            familyName: "Smith",
            organizationName: "",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(wrapper.fullName, "John Smith")
    }

    func testFullName_givenNameOnly() {
        let wrapper = ContactWrapper(
            identifier: "test-2",
            givenName: "John",
            familyName: "",
            organizationName: "Acme Corp",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(wrapper.fullName, "John")
    }

    func testFullName_familyNameOnly() {
        let wrapper = ContactWrapper(
            identifier: "test-3",
            givenName: "",
            familyName: "Smith",
            organizationName: "Acme Corp",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(wrapper.fullName, "Smith")
    }

    func testFullName_organizationFallback() {
        let wrapper = ContactWrapper(
            identifier: "test-4",
            givenName: "",
            familyName: "",
            organizationName: "Acme Corp",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(
            wrapper.fullName, "Acme Corp",
            "When both names are empty, fullName should fall back to organization"
        )
    }

    func testFullName_allEmpty() {
        let wrapper = ContactWrapper(
            identifier: "test-5",
            givenName: "",
            familyName: "",
            organizationName: "",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(wrapper.fullName, "")
    }

    // MARK: - initials

    func testInitials_bothNames() {
        let wrapper = ContactWrapper(
            identifier: "test-6",
            givenName: "John",
            familyName: "Smith",
            organizationName: "",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(wrapper.initials, "JS")
    }

    func testInitials_givenNameOnly() {
        let wrapper = ContactWrapper(
            identifier: "test-7",
            givenName: "John",
            familyName: "",
            organizationName: "",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(wrapper.initials, "J")
    }

    func testInitials_lowercaseNames() {
        let wrapper = ContactWrapper(
            identifier: "test-8",
            givenName: "john",
            familyName: "smith",
            organizationName: "",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(
            wrapper.initials, "JS",
            "Initials should be uppercased regardless of input"
        )
    }

    func testInitials_organizationFallback() {
        let wrapper = ContactWrapper(
            identifier: "test-9",
            givenName: "",
            familyName: "",
            organizationName: "Acme Corp",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(
            wrapper.initials, "A",
            "When names are empty, initials should be the first letter of the organization"
        )
    }

    func testInitials_allEmpty() {
        let wrapper = ContactWrapper(
            identifier: "test-10",
            givenName: "",
            familyName: "",
            organizationName: "",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(
            wrapper.initials, "?",
            "When all fields are empty, initials should be '?'"
        )
    }

    // MARK: - Factory Method

    func testFromCNContact() {
        let mutableContact = CNMutableContact()
        mutableContact.givenName = "Jane"
        mutableContact.familyName = "Doe"
        mutableContact.organizationName = "Widget Inc"

        let cnContact = mutableContact as CNContact
        let wrapper = ContactWrapper.from(cnContact)

        XCTAssertEqual(wrapper.identifier, cnContact.identifier)
        XCTAssertEqual(wrapper.givenName, "Jane")
        XCTAssertEqual(wrapper.familyName, "Doe")
        XCTAssertEqual(wrapper.organizationName, "Widget Inc")
        XCTAssertNil(wrapper.thumbnailImageData)
    }

    func testFromCNContact_preservesIdentifier() {
        let contact1 = CNMutableContact()
        contact1.givenName = "A"
        let contact2 = CNMutableContact()
        contact2.givenName = "B"

        let wrapper1 = ContactWrapper.from(contact1 as CNContact)
        let wrapper2 = ContactWrapper.from(contact2 as CNContact)

        XCTAssertNotEqual(
            wrapper1.identifier, wrapper2.identifier,
            "Different CNContacts should produce different identifiers"
        )
    }

    // MARK: - Identifiable / Equatable

    func testId_matchesIdentifier() {
        let wrapper = ContactWrapper(
            identifier: "unique-id-123",
            givenName: "Test",
            familyName: "User",
            organizationName: "",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(wrapper.id, "unique-id-123")
        XCTAssertEqual(wrapper.id, wrapper.identifier)
    }

    func testEquatable() {
        let wrapper1 = ContactWrapper(
            identifier: "same-id",
            givenName: "John",
            familyName: "Smith",
            organizationName: "",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )
        let wrapper2 = ContactWrapper(
            identifier: "same-id",
            givenName: "John",
            familyName: "Smith",
            organizationName: "",
            thumbnailImageData: nil,
            primaryPhone: nil,
            primaryEmail: nil
        )

        XCTAssertEqual(wrapper1, wrapper2)
    }
}

import XCTest
import Contacts
@testable import Kontakt

final class SearchEngineTests: XCTestCase {

    private var engine: SearchEngine!

    override func setUp() {
        super.setUp()
        engine = SearchEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Helper: Create Mock Contacts

    /// Creates a CNContact with the given properties set.
    private func makeCNContact(
        givenName: String = "",
        familyName: String = "",
        organizationName: String = "",
        jobTitle: String = "",
        phoneNumbers: [String] = [],
        emailAddresses: [String] = []
    ) -> CNContact {
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
        return contact as CNContact
    }

    /// Creates a ContactWrapper from the same parameters.
    private func makeWrapper(from contact: CNContact) -> ContactWrapper {
        ContactWrapper.from(contact)
    }

    /// Builds a search index and wrapper list from a set of CNContacts,
    /// then performs a search.
    private func performSearch(
        query: String,
        contacts: [CNContact]
    ) -> [SearchResult] {
        let index = engine.buildIndex(from: contacts)
        let wrappers = contacts.map { ContactWrapper.from($0) }
        return engine.search(query: query, in: index, contacts: wrappers)
    }

    // MARK: - Prefix Matching

    func testPrefixMatch_givenName() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let bob = makeCNContact(givenName: "Bob", familyName: "Jones")

        let results = performSearch(query: "Jen", contacts: [jennifer, bob])

        XCTAssertFalse(results.isEmpty, "Should find at least one result for 'Jen'")
        XCTAssertEqual(
            results.first?.contact.identifier,
            jennifer.identifier,
            "Jennifer should be the top result for prefix 'Jen'"
        )
    }

    // MARK: - Contains Matching

    func testContainsMatch_familyName() {
        let smith = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let jones = makeCNContact(givenName: "Bob", familyName: "Jones")

        let results = performSearch(query: "mith", contacts: [smith, jones])

        XCTAssertFalse(results.isEmpty, "Should find at least one result for 'mith'")
        XCTAssertEqual(
            results.first?.contact.identifier,
            smith.identifier,
            "'mith' should match 'Smith'"
        )
    }

    // MARK: - Phone Search

    func testPhoneSearch() {
        let contact = makeCNContact(
            givenName: "Jennifer",
            familyName: "Smith",
            phoneNumbers: ["(512) 555-1234"]
        )
        let other = makeCNContact(givenName: "Bob", familyName: "Jones")

        let results = performSearch(query: "5125", contacts: [contact, other])

        XCTAssertFalse(results.isEmpty, "Should find a result when searching by phone digits")
        XCTAssertEqual(
            results.first?.contact.identifier,
            contact.identifier,
            "Phone search '5125' should match contact with (512) 555-1234"
        )
    }

    // MARK: - Organization Search

    func testOrganizationSearch() {
        let acmeContact = makeCNContact(
            givenName: "Jennifer",
            familyName: "Smith",
            organizationName: "Acme Corp"
        )
        let other = makeCNContact(givenName: "Bob", familyName: "Jones")

        let results = performSearch(query: "acme", contacts: [acmeContact, other])

        XCTAssertFalse(results.isEmpty, "Should find a result for organization search")
        XCTAssertEqual(
            results.first?.contact.identifier,
            acmeContact.identifier,
            "'acme' should match contact at 'Acme Corp'"
        )
    }

    // MARK: - Result Ranking

    func testResultRanking_prefixHigherThanContains() {
        // "Jen" is a prefix of "Jennifer" (given name) but only contained in "Bojenko" (family name).
        let prefixMatch = makeCNContact(givenName: "Jennifer", familyName: "Adams")
        let containsMatch = makeCNContact(givenName: "Alice", familyName: "Bojenko")

        let results = performSearch(
            query: "jen",
            contacts: [containsMatch, prefixMatch]
        )

        XCTAssertGreaterThanOrEqual(results.count, 2, "Both contacts should match")

        // Prefix match should score higher than contains match.
        let prefixResult = results.first { $0.contact.identifier == prefixMatch.identifier }
        let containsResult = results.first { $0.contact.identifier == containsMatch.identifier }

        XCTAssertNotNil(prefixResult)
        XCTAssertNotNil(containsResult)

        if let pScore = prefixResult?.score, let cScore = containsResult?.score {
            XCTAssertGreaterThan(
                pScore, cScore,
                "Prefix match should score higher than contains match"
            )
        }
    }

    // MARK: - Empty Query

    func testEmptyQuery_returnsEmptyResults() {
        let contact = makeCNContact(givenName: "Jennifer", familyName: "Smith")

        let results = performSearch(query: "", contacts: [contact])

        XCTAssertTrue(results.isEmpty, "Empty query should return no results")
    }

    func testWhitespaceQuery_returnsEmptyResults() {
        let contact = makeCNContact(givenName: "Jennifer", familyName: "Smith")

        let results = performSearch(query: "   ", contacts: [contact])

        XCTAssertTrue(results.isEmpty, "Whitespace-only query should return no results")
    }

    // MARK: - Diacritics

    func testDiacriticInsensitiveSearch() {
        let jose = makeCNContact(givenName: "Jos\u{00E9}", familyName: "Garcia")
        let bob = makeCNContact(givenName: "Bob", familyName: "Jones")

        let results = performSearch(query: "jose", contacts: [jose, bob])

        XCTAssertFalse(results.isEmpty, "'jose' should match 'Jos\u{00E9}'")
        XCTAssertEqual(
            results.first?.contact.identifier,
            jose.identifier,
            "'jose' (no accent) should match 'Jos\u{00E9}' (with accent)"
        )
    }

    // MARK: - Fuzzy / Levenshtein Matching

    func testFuzzyMatch_levenshtein() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let bob = makeCNContact(givenName: "Bob", familyName: "Jones")

        // "Jeniffer" is edit distance 1 from "Jennifer" (transposed f).
        let results = performSearch(query: "Jeniffer", contacts: [jennifer, bob])

        XCTAssertFalse(
            results.isEmpty,
            "'Jeniffer' (misspelling) should fuzzy-match 'Jennifer'"
        )
        XCTAssertEqual(
            results.first?.contact.identifier,
            jennifer.identifier
        )
    }

    // MARK: - Levenshtein Distance Unit Tests

    func testLevenshteinDistance_identical() {
        XCTAssertEqual(engine.levenshteinDistance("kitten", "kitten"), 0)
    }

    func testLevenshteinDistance_singleEdit() {
        XCTAssertEqual(engine.levenshteinDistance("kitten", "sitten"), 1)
    }

    func testLevenshteinDistance_classic() {
        XCTAssertEqual(engine.levenshteinDistance("kitten", "sitting"), 3)
    }

    func testLevenshteinDistance_emptySource() {
        XCTAssertEqual(engine.levenshteinDistance("", "abc"), 3)
    }

    func testLevenshteinDistance_emptyTarget() {
        XCTAssertEqual(engine.levenshteinDistance("abc", ""), 3)
    }

    func testLevenshteinDistance_bothEmpty() {
        XCTAssertEqual(engine.levenshteinDistance("", ""), 0)
    }

    // MARK: - Index Building

    func testBuildIndex_createsTokensForAllFields() {
        let contact = makeCNContact(
            givenName: "Jennifer",
            familyName: "Smith",
            organizationName: "Acme Corp",
            phoneNumbers: ["(512) 555-1234"],
            emailAddresses: ["jen@acme.com"]
        )

        let index = engine.buildIndex(from: [contact])

        XCTAssertEqual(index.count, 1, "One contact should produce one index entry")

        let tokens = index[0].tokens
        let fields = Set(tokens.map { $0.field })

        XCTAssertTrue(fields.contains(.givenName), "Index should contain given name token")
        XCTAssertTrue(fields.contains(.familyName), "Index should contain family name token")
        XCTAssertTrue(fields.contains(.organization), "Index should contain organization token")
        XCTAssertTrue(fields.contains(.phone), "Index should contain phone token")
        XCTAssertTrue(fields.contains(.email), "Index should contain email token")
    }

    func testBuildIndex_phoneTokenIsDigitsOnly() {
        let contact = makeCNContact(phoneNumbers: ["(512) 555-1234"])

        let index = engine.buildIndex(from: [contact])
        let phoneToken = index[0].tokens.first { $0.field == .phone }

        XCTAssertNotNil(phoneToken)
        XCTAssertEqual(
            phoneToken?.normalized, "5125551234",
            "Phone token normalized value should be digits only"
        )
    }
}

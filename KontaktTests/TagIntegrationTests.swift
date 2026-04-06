import XCTest
import Contacts
@testable import Kontakt

final class TagIntegrationTests: XCTestCase {

    private var engine: SearchEngine!

    override func setUp() {
        super.setUp()
        engine = SearchEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Helper

    /// Creates a CNContact with the given properties.
    private func makeCNContact(
        givenName: String = "",
        familyName: String = "",
        organizationName: String = "",
        phoneNumbers: [String] = [],
        emailAddresses: [String] = []
    ) -> CNContact {
        let contact = CNMutableContact()
        contact.givenName = givenName
        contact.familyName = familyName
        contact.organizationName = organizationName
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

    /// Builds a search index with optional tags, then performs a search.
    private func performSearch(
        query: String,
        contacts: [CNContact],
        tags: [String: [String]] = [:]
    ) -> [SearchResult] {
        let index = engine.buildIndex(from: contacts, tags: tags)
        let wrappers = contacts.map { ContactWrapper.from($0) }
        return engine.search(query: query, in: index, contacts: wrappers)
    }

    // MARK: - Tag Indexing

    func testSearchByTagName_findsTaggedContact() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let bob = makeCNContact(givenName: "Bob", familyName: "Jones")

        let tags = [jennifer.identifier: ["VIP", "coworker"]]

        let results = performSearch(
            query: "VIP",
            contacts: [jennifer, bob],
            tags: tags
        )

        XCTAssertFalse(results.isEmpty, "Searching for tag 'VIP' should return results")
        XCTAssertEqual(
            results.first?.contact.identifier,
            jennifer.identifier,
            "Jennifer should be found when searching for her tag 'VIP'"
        )
    }

    func testSearchByTagName_matchedFieldIsTag() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let tags = [jennifer.identifier: ["VIP"]]

        let results = performSearch(
            query: "VIP",
            contacts: [jennifer],
            tags: tags
        )

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(
            results.first?.matchedField, .tag,
            "When matching on a tag, matchedField should be .tag"
        )
    }

    func testSearchByTagName_matchedValuePopulated() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let tags = [jennifer.identifier: ["coworker"]]

        let results = performSearch(
            query: "coworker",
            contacts: [jennifer],
            tags: tags
        )

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(
            results.first?.matchedValue, "coworker",
            "matchedValue should contain the tag name that was matched"
        )
    }

    func testSearchByTagName_caseInsensitive() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let tags = [jennifer.identifier: ["VIP"]]

        let results = performSearch(
            query: "vip",
            contacts: [jennifer],
            tags: tags
        )

        XCTAssertFalse(results.isEmpty, "Tag search should be case-insensitive")
        XCTAssertEqual(results.first?.contact.identifier, jennifer.identifier)
    }

    func testSearchByTagName_prefixMatch() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let tags = [jennifer.identifier: ["coworker"]]

        let results = performSearch(
            query: "cow",
            contacts: [jennifer],
            tags: tags
        )

        XCTAssertFalse(results.isEmpty, "Tag search should support prefix matching")
        XCTAssertEqual(results.first?.contact.identifier, jennifer.identifier)
    }

    func testSearchByTagName_doesNotMatchUntaggedContacts() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let bob = makeCNContact(givenName: "Bob", familyName: "Jones")

        let tags = [jennifer.identifier: ["VIP"]]

        let results = performSearch(
            query: "VIP",
            contacts: [jennifer, bob],
            tags: tags
        )

        // Only Jennifer should match on the tag, not Bob.
        let bobResults = results.filter { $0.contact.identifier == bob.identifier }
        XCTAssertTrue(
            bobResults.isEmpty,
            "Bob should not appear in results for tag 'VIP' since he is not tagged"
        )
    }

    func testSearchByTagName_multipleTagsOnSameContact() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let tags = [jennifer.identifier: ["VIP", "coworker", "austin"]]

        // Search for a tag that is not the first one.
        let results = performSearch(
            query: "austin",
            contacts: [jennifer],
            tags: tags
        )

        XCTAssertFalse(results.isEmpty, "Should find contact by any of its tags")
        XCTAssertEqual(results.first?.matchedValue, "austin")
    }

    func testSearchByTagName_multipleContactsWithSameTag() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let bob = makeCNContact(givenName: "Bob", familyName: "Jones")

        let tags = [
            jennifer.identifier: ["VIP"],
            bob.identifier: ["VIP"]
        ]

        let results = performSearch(
            query: "VIP",
            contacts: [jennifer, bob],
            tags: tags
        )

        XCTAssertEqual(results.count, 2, "Both contacts tagged 'VIP' should appear in results")
    }

    // MARK: - Tag Weight Ranking

    func testTagWeight_lowerThanNameMatch() {
        // "VIP" is a tag on Jennifer, but Bob's name is "Viper" which starts with "VIP".
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")
        let viper = makeCNContact(givenName: "Viper", familyName: "Jones")

        let tags = [jennifer.identifier: ["VIP"]]

        let results = performSearch(
            query: "vip",
            contacts: [jennifer, viper],
            tags: tags
        )

        XCTAssertGreaterThanOrEqual(results.count, 2, "Both contacts should match")

        let jenniferResult = results.first { $0.contact.identifier == jennifer.identifier }
        let viperResult = results.first { $0.contact.identifier == viper.identifier }

        XCTAssertNotNil(jenniferResult)
        XCTAssertNotNil(viperResult)

        // Name match (givenName weight 1.0) should score higher than tag match (weight 0.65).
        if let nameScore = viperResult?.score, let tagScore = jenniferResult?.score {
            XCTAssertGreaterThan(
                nameScore, tagScore,
                "Name prefix match should rank higher than tag prefix match"
            )
        }
    }

    // MARK: - No Tags

    func testSearchWithNoTags_stillWorksNormally() {
        let jennifer = makeCNContact(givenName: "Jennifer", familyName: "Smith")

        // No tags provided (empty dictionary).
        let results = performSearch(
            query: "Jen",
            contacts: [jennifer],
            tags: [:]
        )

        XCTAssertFalse(results.isEmpty, "Search should work normally without tags")
        XCTAssertEqual(results.first?.contact.identifier, jennifer.identifier)
    }

    // MARK: - SearchField.tag Properties

    func testSearchFieldTag_hasCorrectDisplayLabel() {
        XCTAssertEqual(SearchField.tag.displayLabel, "Tag")
    }

    func testSearchFieldTag_hasCorrectWeight() {
        XCTAssertEqual(SearchField.tag.weight, 0.65)
    }

    func testSearchFieldTag_weighsLessThanName() {
        XCTAssertLessThan(SearchField.tag.weight, SearchField.givenName.weight)
        XCTAssertLessThan(SearchField.tag.weight, SearchField.familyName.weight)
    }

    func testSearchFieldTag_weighsMoreThanPhone() {
        XCTAssertGreaterThan(SearchField.tag.weight, SearchField.phone.weight)
    }
}

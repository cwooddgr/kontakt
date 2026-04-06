import Foundation
import Contacts
import Observation

/// Central data store for all contact operations.
///
/// This is the single source of truth for the contact list. It wraps `CNContactStore`
/// and provides observation-compatible properties for SwiftUI views to bind to.
/// All mutations go through this store — views never touch the Contacts framework directly.
@MainActor
@Observable
final class ContactStore {

    // MARK: - Published State

    /// The current list of contacts, fetched with list-tier keys.
    private(set) var contacts: [ContactWrapper] = []

    /// Whether the app has full contact access.
    private(set) var isAuthorized: Bool = false

    /// The current authorization status for contacts.
    private(set) var authorizationStatus: CNAuthorizationStatus = .notDetermined

    /// Identifiers of pinned contacts, persisted in UserDefaults.
    var pinnedContactIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(pinnedContactIDs), forKey: Self.pinnedContactsKey)
        }
    }

    // MARK: - Internal State

    @ObservationIgnored
    let cnContactStore = CNContactStore()

    @ObservationIgnored
    private var changeObserver: ContactChangeObserver?

    // MARK: - Constants

    private static let pinnedContactsKey = "pinnedContactIdentifiers"

    /// Minimal keys needed for list display.
    static let listFetchKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
    ]

    /// Full keys needed for detail / card view.
    static let detailFetchKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor,
        CNContactNamePrefixKey as CNKeyDescriptor,
        CNContactNameSuffixKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactDepartmentNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor,
        CNContactSocialProfilesKey as CNKeyDescriptor,
        CNContactInstantMessageAddressesKey as CNKeyDescriptor,
        CNContactDatesKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactRelationsKey as CNKeyDescriptor,
        CNContactNoteKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactTypeKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
    ]

    // MARK: - Initialization

    init() {
        // Restore pinned contacts from UserDefaults.
        let stored = UserDefaults.standard.stringArray(forKey: Self.pinnedContactsKey) ?? []
        self.pinnedContactIDs = Set(stored)
    }

    // MARK: - Authorization

    /// Checks the current authorization status without prompting the user.
    func checkAuthorizationStatus() async {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        authorizationStatus = status
        isAuthorized = (status == .authorized)

        if status == .authorized || status == .limited {
            fetchAllContacts()
            startObservingChanges()
        }
    }

    /// Requests contact access from the user. Throws if access is denied.
    func requestAccess() async throws {
        let granted = try await cnContactStore.requestAccess(for: .contacts)
        isAuthorized = granted
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)

        if granted {
            fetchAllContacts()
            startObservingChanges()
        }
    }

    // MARK: - Fetching

    /// Fetches all contacts using list-tier keys and populates the `contacts` array.
    /// Contacts are sorted according to the system sort order preference.
    func fetchAllContacts() {
        let request = CNContactFetchRequest(keysToFetch: Self.listFetchKeys)

        // Read the user's preferred sort order from system settings.
        let sortOrder = CNContactsUserDefaults.shared().sortOrder
        request.sortOrder = sortOrder

        var fetched: [ContactWrapper] = []

        do {
            try cnContactStore.enumerateContacts(with: request) { contact, _ in
                fetched.append(ContactWrapper.from(contact))
            }
        } catch {
            // On failure, keep the existing contacts rather than clearing them.
            // In a production app, this could surface an error state.
            return
        }

        contacts = fetched
    }

    /// Fetches a single contact with all detail keys.
    /// Returns nil if the contact cannot be found or the fetch fails.
    func fetchContactDetail(identifier: String) -> CNContact? {
        do {
            return try cnContactStore.unifiedContact(
                withIdentifier: identifier,
                keysToFetch: Self.detailFetchKeys
            )
        } catch {
            return nil
        }
    }

    // MARK: - Saving

    /// Saves a new or modified contact to the contact store.
    func saveContact(_ contact: CNMutableContact) throws {
        let request = CNSaveRequest()

        if contact.identifier.isEmpty {
            request.add(contact, toContainerWithIdentifier: nil)
        } else {
            request.update(contact)
        }

        try cnContactStore.execute(request)
    }

    // MARK: - Deleting

    /// Deletes a contact by identifier from the contact store.
    func deleteContact(identifier: String) throws {
        guard let contact = fetchContactDetail(identifier: identifier) else { return }
        let mutableContact = contact.mutableCopy() as! CNMutableContact
        let request = CNSaveRequest()
        request.delete(mutableContact)
        try cnContactStore.execute(request)

        // Remove from pinned if necessary.
        pinnedContactIDs.remove(identifier)
    }

    // MARK: - Pinning

    /// Toggles the pinned state of a contact.
    func togglePin(identifier: String) {
        if pinnedContactIDs.contains(identifier) {
            pinnedContactIDs.remove(identifier)
        } else {
            pinnedContactIDs.insert(identifier)
        }
    }

    /// Returns whether a contact is currently pinned.
    func isPinned(identifier: String) -> Bool {
        pinnedContactIDs.contains(identifier)
    }

    // MARK: - Container Info

    /// The name of the default contact container (e.g. "iCloud", "On My iPhone").
    var defaultContainerName: String {
        let identifier = cnContactStore.defaultContainerIdentifier()
        do {
            let containers = try cnContactStore.containers(
                matching: CNContainer.predicateForContainers(withIdentifiers: [identifier])
            )
            return containers.first?.name ?? "Unknown"
        } catch {
            return "Unknown"
        }
    }

    // MARK: - Change Observation

    private func startObservingChanges() {
        guard changeObserver == nil else { return }
        changeObserver = ContactChangeObserver(store: self)
    }
}

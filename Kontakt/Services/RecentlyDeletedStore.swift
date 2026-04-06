import Foundation
import Contacts
import Observation

/// Manages soft-deleted contacts with a 30-day recovery window.
///
/// When a contact is soft-deleted, it is serialized to vCard format and stored
/// in this store. After 30 days, expired entries are purged automatically.
/// Users can restore a contact (which re-creates it in the CNContactStore)
/// or permanently delete it before the 30-day window expires.
/// Data is persisted as JSON in Application Support/People/recently-deleted.json.
@MainActor
@Observable
final class RecentlyDeletedStore {

    // MARK: - Types

    struct DeletedContact: Codable, Identifiable, Sendable {
        let id: String // original contact identifier
        let displayName: String
        let deletedDate: Date
        let vCardData: Data // serialized via CNContactVCardSerialization

        /// Days remaining before permanent deletion (30-day window).
        var daysRemaining: Int {
            let calendar = Calendar.current
            let daysSince = calendar.dateComponents([.day], from: deletedDate, to: Date()).day ?? 0
            return max(30 - daysSince, 0)
        }

        /// Whether this entry has expired and should be purged.
        var isExpired: Bool {
            daysRemaining <= 0
        }
    }

    // MARK: - State

    /// All soft-deleted contacts currently in the recovery window.
    private(set) var deletedContacts: [DeletedContact] = []

    // MARK: - Initialization

    init() {
        load()
    }

    // MARK: - Public API

    /// Archives a contact for soft deletion. The contact should already have been
    /// fetched with full detail keys so that vCard serialization captures all data.
    func softDelete(contact: CNContact) {
        let displayName = CNContactFormatter.string(from: contact, style: .fullName)
            ?? [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

        guard let vCardData = try? CNContactVCardSerialization.data(with: [contact]) else {
            return
        }

        let entry = DeletedContact(
            id: contact.identifier,
            displayName: displayName.isEmpty ? "Unknown" : displayName,
            deletedDate: Date(),
            vCardData: vCardData
        )

        deletedContacts.append(entry)
        save()
    }

    /// Restores a soft-deleted contact back into the system contact store.
    func restore(id: String, using contactStore: ContactStore) throws {
        guard let index = deletedContacts.firstIndex(where: { $0.id == id }) else { return }
        let entry = deletedContacts[index]

        let contacts = try CNContactVCardSerialization.contacts(with: entry.vCardData)
        guard let restored = contacts.first else { return }

        let mutableContact = restored.mutableCopy() as! CNMutableContact
        // Clear the identifier so it is treated as a new contact.
        try contactStore.saveContact(mutableContact)

        deletedContacts.remove(at: index)
        save()
    }

    /// Permanently removes a soft-deleted contact from the recovery list.
    func permanentlyDelete(id: String) {
        deletedContacts.removeAll { $0.id == id }
        save()
    }

    /// Removes all entries that have exceeded the 30-day recovery window.
    func purgeExpired() {
        let before = deletedContacts.count
        deletedContacts.removeAll { $0.isExpired }
        if deletedContacts.count != before {
            save()
        }
    }

    // MARK: - Persistence

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directory = appSupport.appendingPathComponent("People", isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        return directory.appendingPathComponent("recently-deleted.json")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.fileURL)
            deletedContacts = try JSONDecoder().decode([DeletedContact].self, from: data)
        } catch {
            deletedContacts = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(deletedContacts)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            // Silently fail — in-memory state remains correct.
        }
    }
}

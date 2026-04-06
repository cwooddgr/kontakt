import Foundation
import Observation

/// Manages per-contact tags with persistence to disk.
///
/// Tags are freeform strings attached to contact identifiers. They replace rigid
/// groups with a fluid, stackable labeling system. Data is stored as JSON in
/// Application Support/People/tags.json.
@MainActor
@Observable
final class TagStore {

    // MARK: - State

    /// Mapping of contact identifier to the list of tag names for that contact.
    private(set) var contactTags: [String: [String]] = [:]

    /// The last 5 unique tags added, most recent first. Used for suggestions.
    private(set) var recentTags: [String] = []

    // MARK: - Computed Properties

    /// All tags across all contacts, sorted alphabetically, with their usage count.
    var allTags: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for tags in contactTags.values {
            for tag in tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Initialization

    init() {
        load()
    }

    // MARK: - Public API

    /// Adds a tag to a contact. No-op if the contact already has this tag.
    func addTag(_ tag: String, to contactID: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var tags = contactTags[contactID] ?? []
        guard !tags.contains(trimmed) else { return }

        tags.append(trimmed)
        contactTags[contactID] = tags

        // Track in recent tags (most recent first, max 5, unique).
        recentTags.removeAll { $0 == trimmed }
        recentTags.insert(trimmed, at: 0)
        if recentTags.count > 5 {
            recentTags = Array(recentTags.prefix(5))
        }

        save()
    }

    /// Removes a specific tag from a contact.
    func removeTag(_ tag: String, from contactID: String) {
        guard var tags = contactTags[contactID] else { return }
        tags.removeAll { $0 == tag }
        if tags.isEmpty {
            contactTags.removeValue(forKey: contactID)
        } else {
            contactTags[contactID] = tags
        }
        save()
    }

    /// Returns all tags for a given contact, or an empty array.
    func tags(for contactID: String) -> [String] {
        contactTags[contactID] ?? []
    }

    /// Returns the identifiers of all contacts that have the given tag.
    func contactIDs(with tag: String) -> [String] {
        contactTags.compactMap { key, tags in
            tags.contains(tag) ? key : nil
        }
    }

    /// Removes all tags for a contact. Called when a contact is deleted.
    func removeAllTags(for contactID: String) {
        guard contactTags.removeValue(forKey: contactID) != nil else { return }
        save()
    }

    // MARK: - Persistence

    private struct Storage: Codable {
        var contactTags: [String: [String]]
        var recentTags: [String]
    }

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

        return directory.appendingPathComponent("tags.json")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.fileURL)
            let storage = try JSONDecoder().decode(Storage.self, from: data)
            contactTags = storage.contactTags
            recentTags = storage.recentTags
        } catch {
            // If the file is corrupt, start fresh.
            contactTags = [:]
            recentTags = []
        }
    }

    private func save() {
        let storage = Storage(contactTags: contactTags, recentTags: recentTags)
        do {
            let data = try JSONEncoder().encode(storage)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            // Silently fail — data will be lost if disk is full, but the in-memory
            // state remains correct for the current session.
        }
    }
}

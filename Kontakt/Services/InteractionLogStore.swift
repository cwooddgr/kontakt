import Foundation
import Observation

/// Stores timestamped interaction notes per contact.
///
/// Each contact can have a list of micro-notes ("plumber came 3/15", "lunch 2/20")
/// that answer "when did I last interact with this person?" without needing system-level
/// access to Messages or Calendar. Data is persisted as JSON in
/// Application Support/People/interaction-log.json.
@MainActor
@Observable
final class InteractionLogStore {

    // MARK: - Types

    struct Entry: Codable, Identifiable, Sendable {
        let id: UUID
        let timestamp: Date
        let text: String
    }

    // MARK: - State

    /// Mapping of contact identifier to the list of interaction log entries.
    private(set) var logs: [String: [Entry]] = [:]

    // MARK: - Initialization

    init() {
        load()
    }

    // MARK: - Public API

    /// Adds a new timestamped entry for a contact.
    func addEntry(text: String, to contactID: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = Entry(id: UUID(), timestamp: Date(), text: trimmed)
        var entries = logs[contactID] ?? []
        entries.insert(entry, at: 0) // newest first
        logs[contactID] = entries
        save()
    }

    /// Returns all entries for a contact, sorted newest-first.
    func entries(for contactID: String) -> [Entry] {
        (logs[contactID] ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    /// Deletes a specific entry by ID from a contact's log.
    func deleteEntry(id: UUID, from contactID: String) {
        guard var entries = logs[contactID] else { return }
        entries.removeAll { $0.id == id }
        if entries.isEmpty {
            logs.removeValue(forKey: contactID)
        } else {
            logs[contactID] = entries
        }
        save()
    }

    /// Removes all entries for a contact. Called when a contact is deleted.
    func removeAllEntries(for contactID: String) {
        guard logs.removeValue(forKey: contactID) != nil else { return }
        save()
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

        return directory.appendingPathComponent("interaction-log.json")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.fileURL)
            logs = try JSONDecoder().decode([String: [Entry]].self, from: data)
        } catch {
            logs = [:]
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(logs)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            // Silently fail — in-memory state remains correct.
        }
    }
}

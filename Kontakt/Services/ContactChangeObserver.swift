import Foundation
import Contacts

/// Observes CNContactStore change notifications and triggers a debounced refresh
/// of the contact list. Uses modern async/await notification observation.
@MainActor
final class ContactChangeObserver {

    private weak var store: ContactStore?
    private var observationTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    /// Debounce interval in seconds. Prevents rapid-fire refreshes during
    /// bulk sync or iCloud updates.
    private let debounceInterval: Duration = .milliseconds(500)

    init(store: ContactStore) {
        self.store = store
        startObserving()
    }

    deinit {
        observationTask?.cancel()
        debounceTask?.cancel()
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .CNContactStoreDidChange
            )

            for await _ in notifications {
                guard !Task.isCancelled else { break }
                self?.scheduleRefresh()
            }
        }
    }

    private func scheduleRefresh() {
        // Cancel any pending debounce to restart the timer.
        debounceTask?.cancel()

        debounceTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: debounceInterval)
            } catch {
                // Task was cancelled — a newer notification superseded this one.
                return
            }

            guard !Task.isCancelled else { return }
            self.store?.fetchAllContacts()
        }
    }
}

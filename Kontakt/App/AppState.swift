import SwiftUI

@Observable
final class AppState {

    // MARK: - Active Sheet

    enum ActiveSheet: Identifiable {
        case newContact
        case settings
        case cleanup

        var id: Self { self }
    }

    // MARK: - Density Mode

    enum DensityMode: String, CaseIterable, Sendable {
        case compact
        case standard
    }

    // MARK: - State

    /// The identifier of the currently selected contact, if any.
    var selectedContactID: String?

    /// The sheet currently presented over the main content.
    var activeSheet: ActiveSheet?

    /// Whether the search field is currently active.
    var isSearchActive: Bool = false

    /// Display density for the contact list. Defaults to compact. Persisted in UserDefaults.
    var densityMode: DensityMode {
        didSet {
            UserDefaults.standard.set(densityMode.rawValue, forKey: "densityMode")
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "densityMode") ?? DensityMode.compact.rawValue
        self.densityMode = DensityMode(rawValue: stored) ?? .compact
    }
}

import SwiftUI

/// Settings screen presented as a sheet.
///
/// Provides controls for display preferences, contact defaults, and app info.
/// Presented when `appState.activeSheet == .settings`.
struct SettingsView: View {
    @Environment(ContactStore.self) private var contactStore
    @Environment(AppState.self) private var appState
    @Environment(RecentlyDeletedStore.self) private var recentlyDeletedStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("myCardContactIdentifier") private var myCardContactIdentifier: String = ""

    var body: some View {
        NavigationStack {
            List {
                displaySection
                myCardSection
                contactsSection
                dataSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        Section("Display") {
            // Density mode
            Picker("Density", selection: Bindable(appState).densityMode) {
                ForEach(AppState.DensityMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Sort order info
            Text("Sort order follows your system Contacts setting.")
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - My Card Section

    private var myCardSection: some View {
        Section("My Card") {
            NavigationLink {
                MyCardView()
            } label: {
                HStack {
                    Text("My Card")
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if let name = myCardContactName {
                        Text(name)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("Not Set")
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
    }

    /// Looks up the display name for the stored My Card contact from the in-memory list.
    private var myCardContactName: String? {
        guard !myCardContactIdentifier.isEmpty else { return nil }
        return contactStore.contacts.first { $0.identifier == myCardContactIdentifier }?.fullName
    }

    // MARK: - Contacts Section

    private var contactsSection: some View {
        Section("Contacts") {
            HStack {
                Text("Default Account")
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(contactStore.defaultContainerName)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section("Data") {
            Button {
                dismiss()
                // Delay sheet presentation to avoid dismiss conflict
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    appState.activeSheet = .tagBrowser
                }
            } label: {
                HStack {
                    Text("Tags")
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    appState.activeSheet = .recentlyDeleted
                }
            } label: {
                HStack {
                    Text("Recently Deleted")
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if recentlyDeletedStore.deletedContacts.count > 0 {
                        Text("\(recentlyDeletedStore.deletedContacts.count)")
                            .font(.label)
                            .foregroundStyle(.white)
                            .padding(.horizontal, KSpacing.s)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(appVersion)
                    .foregroundStyle(Color.textSecondary)
            }

            Text("Made by DGR Labs")
                .foregroundStyle(Color.textPrimary)

            Text("A gift to the community.")
                .font(.titleSecondary)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Helpers

    /// The app version string from the main bundle (e.g. "1.0 (1)").
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Density Mode Display Name

extension AppState.DensityMode {
    var displayName: String {
        switch self {
        case .compact: "Compact"
        case .standard: "Standard"
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(ContactStore())
        .environment(AppState())
        .environment(RecentlyDeletedStore())
}

import SwiftUI

/// Displays soft-deleted contacts with a 30-day recovery window.
///
/// Presented as a sheet from `appState.activeSheet == .recentlyDeleted`.
/// Each row shows the contact's display name and days remaining before permanent deletion.
/// Swipe-to-restore (leading, green) and swipe-to-permanently-delete (trailing, red).
struct RecentlyDeletedView: View {
    @Environment(RecentlyDeletedStore.self) private var store
    @Environment(ContactStore.self) private var contactStore
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteAllConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if store.deletedContacts.isEmpty {
                    emptyState
                } else {
                    deletedContactsList
                }
            }
            .navigationTitle("Recently Deleted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.deletedContacts.isEmpty {
                        Button("Delete All", role: .destructive) {
                            showDeleteAllConfirmation = true
                        }
                        .foregroundStyle(Color.red)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete All", isPresented: $showDeleteAllConfirmation) {
                Button("Delete All Permanently", role: .destructive) {
                    deleteAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(store.deletedContacts.count) contacts. This cannot be undone.")
            }
        }
    }

    // MARK: - List

    private var deletedContactsList: some View {
        List {
            ForEach(store.deletedContacts) { entry in
                DeletedContactRow(
                    entry: entry,
                    onRestore: { restoreContact(id: entry.id) },
                    onPermanentlyDelete: { permanentlyDelete(id: entry.id) }
                )
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: KSpacing.m) {
            Image(systemName: "trash.slash")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Color.textTertiary)

            Text("No Recently Deleted Contacts")
                .font(.titlePrimary)
                .foregroundStyle(Color.textPrimary)

            Text("Deleted contacts appear here for 30 days before being permanently removed.")
                .font(.titleSecondary)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func restoreContact(id: String) {
        do {
            try store.restore(id: id, using: contactStore)
            HapticManager.mediumImpact()
        } catch {
            // Future: surface error alert
        }
    }

    private func permanentlyDelete(id: String) {
        store.permanentlyDelete(id: id)
        HapticManager.mediumImpact()
    }

    private func deleteAll() {
        let ids = store.deletedContacts.map(\.id)
        for id in ids {
            store.permanentlyDelete(id: id)
        }
        HapticManager.mediumImpact()
    }
}

// MARK: - Deleted Contact Row

/// A single row in the recently deleted list with swipe actions.
private struct DeletedContactRow: View {
    let entry: RecentlyDeletedStore.DeletedContact
    let onRestore: () -> Void
    let onPermanentlyDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.listPrimary)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(daysRemainingText)
                    .font(.label)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, KSpacing.xs)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onRestore()
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onPermanentlyDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var daysRemainingText: String {
        let days = entry.daysRemaining
        if days == 0 {
            return "Expiring today"
        } else if days == 1 {
            return "1 day remaining"
        } else {
            return "\(days) days remaining"
        }
    }
}

// MARK: - Preview

#Preview {
    RecentlyDeletedView()
        .environment(RecentlyDeletedStore())
        .environment(ContactStore())
}

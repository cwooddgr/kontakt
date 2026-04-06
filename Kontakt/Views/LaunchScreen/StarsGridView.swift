import SwiftUI

/// A compact grid of starred contacts shown on the launch screen.
///
/// Displays face photos (or initials fallback) in a flexible grid. Each cell
/// is tappable via NavigationLink to navigate to the contact's card.
/// When no contacts are starred, shows a subtle empty-state hint.
struct StarsGridView: View {
    @Environment(ContactStore.self) private var contactStore

    var onBrowseAll: () -> Void

    private let gridColumns = [
        GridItem(.adaptive(minimum: 64, maximum: 80))
    ]

    var body: some View {
        VStack(spacing: KSpacing.l) {
            if starredContacts.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: gridColumns, spacing: KSpacing.m) {
                    ForEach(starredContacts) { contact in
                        NavigationLink(value: contact.identifier) {
                            starCell(contact: contact)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: onBrowseAll) {
                Text("Browse All")
                    .font(.kBody)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, KSpacing.xl)
    }

    // MARK: - Star Cell

    private func starCell(contact: ContactWrapper) -> some View {
        VStack(spacing: KSpacing.xs) {
            ContactPhoto(
                imageData: contact.thumbnailImageData,
                givenName: contact.givenName,
                familyName: contact.familyName,
                size: 56
            )

            Text(contact.fullName)
                .font(.label)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("Star people to see them here")
            .font(.label)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, KSpacing.xl)
    }

    // MARK: - Data

    private var starredContacts: [ContactWrapper] {
        contactStore.contacts.filter { contactStore.isStarred(identifier: $0.identifier) }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StarsGridView(onBrowseAll: {})
    }
    .environment(ContactStore())
}

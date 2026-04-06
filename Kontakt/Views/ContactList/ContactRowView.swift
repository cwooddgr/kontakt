import SwiftUI

/// A single row in the contact list.
///
/// Adapts between compact mode (no photo, ~52pt) and standard mode (40x40 photo, ~60pt)
/// based on the current density setting in AppState. The entire row is tappable via
/// NavigationLink. A horizontal swipe gesture reveals a star/unstar action (leading)
/// and a delete action (trailing).
struct ContactRowView: View {
    let contact: ContactWrapper
    let isStarred: Bool
    var onDelete: (() -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(ContactStore.self) private var contactStore

    @State private var swipeOffset: CGFloat = 0
    @State private var activeSwipe: SwipeDirection = .none

    private let actionButtonWidth: CGFloat = 72

    private enum SwipeDirection {
        case none, leading, trailing
    }

    var body: some View {
        ZStack {
            // Leading action (star/unstar) -- revealed when swiping right
            HStack(spacing: 0) {
                Button {
                    toggleStar()
                    resetSwipe()
                } label: {
                    VStack(spacing: KSpacing.xs) {
                        Image(systemName: isStarred ? "star.fill" : "star")
                            .font(.system(size: 17, weight: .medium))
                        Text(isStarred ? "Unstar" : "Star")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: actionButtonWidth, maxHeight: .infinity)
                    .background(Color.accentSlateBlue)
                }
                .accessibilityLabel(isStarred ? "Unstar \(contact.fullName)" : "Star \(contact.fullName)")
                Spacer()
            }
            .opacity(activeSwipe == .leading ? 1 : 0)

            // Trailing action (delete) -- revealed when swiping left
            HStack(spacing: 0) {
                Spacer()
                Button {
                    resetSwipe()
                    onDelete?()
                } label: {
                    VStack(spacing: KSpacing.xs) {
                        Image(systemName: "trash")
                            .font(.system(size: 17, weight: .medium))
                        Text("Delete")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: actionButtonWidth, maxHeight: .infinity)
                    .background(Color.red)
                }
                .accessibilityLabel("Delete \(contact.fullName)")
            }
            .opacity(activeSwipe == .trailing ? 1 : 0)

            // Main row content
            NavigationLink(value: contact.identifier) {
                rowContent
            }
            .buttonStyle(.plain)
            .offset(x: swipeOffset)
            .gesture(swipeGesture)
        }
        .clipped()
    }

    // MARK: - Row Content

    private var rowContent: some View {
        HStack(spacing: KSpacing.m) {
            if appState.densityMode == .standard {
                ContactPhoto(
                    imageData: contact.thumbnailImageData,
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    size: 40
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.listPrimary)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                if !contact.organizationName.isEmpty {
                    Text(contact.organizationName)
                        .font(.listSecondary)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, KSpacing.xl)
        .padding(.vertical, KSpacing.m)
        .frame(
            minHeight: appState.densityMode == .compact ? 52 : 60,
            alignment: .leading
        )
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width

                // Determine direction on first movement
                if activeSwipe == .none {
                    if horizontal > 0 {
                        activeSwipe = .leading
                    } else if horizontal < 0 && onDelete != nil {
                        activeSwipe = .trailing
                    }
                }

                // Clamp the offset within bounds
                switch activeSwipe {
                case .leading:
                    swipeOffset = min(max(horizontal, 0), actionButtonWidth)
                case .trailing:
                    swipeOffset = max(min(horizontal, 0), -actionButtonWidth)
                case .none:
                    break
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let threshold = actionButtonWidth * 0.5

                withAnimation(.easeOut(duration: 0.2)) {
                    switch activeSwipe {
                    case .leading:
                        if horizontal > threshold {
                            swipeOffset = actionButtonWidth
                        } else {
                            resetSwipe()
                        }
                    case .trailing:
                        if horizontal < -threshold {
                            swipeOffset = -actionButtonWidth
                        } else {
                            resetSwipe()
                        }
                    case .none:
                        resetSwipe()
                    }
                }
            }
    }

    // MARK: - Actions

    private func resetSwipe() {
        withAnimation(.easeOut(duration: 0.2)) {
            swipeOffset = 0
            activeSwipe = .none
        }
    }

    private func toggleStar() {
        HapticManager.mediumImpact()
        contactStore.toggleStar(identifier: contact.identifier)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VStack(spacing: 0) {
            ContactRowView(
                contact: ContactWrapper(
                    identifier: "1",
                    givenName: "Alice",
                    familyName: "Johnson",
                    organizationName: "Acme Corp",
                    thumbnailImageData: nil,
                    primaryPhone: nil,
                    primaryEmail: nil
                ),
                isStarred: false,
                onDelete: { print("Delete Alice") }
            )
            ContactRowView(
                contact: ContactWrapper(
                    identifier: "2",
                    givenName: "Bob",
                    familyName: "Williams",
                    organizationName: "",
                    thumbnailImageData: nil,
                    primaryPhone: nil,
                    primaryEmail: nil
                ),
                isStarred: true,
                onDelete: { print("Delete Bob") }
            )
        }
    }
    .environment(ContactStore())
    .environment(AppState())
}

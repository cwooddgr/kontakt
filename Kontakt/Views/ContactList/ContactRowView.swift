import SwiftUI

/// A single row in the contact list.
///
/// Adapts between compact mode (no photo, ~52pt) and standard mode (40x40 photo, ~60pt)
/// based on the current density setting in AppState. The entire row is tappable via
/// NavigationLink. Horizontal swipe gestures reveal pin/unpin (leading) and delete
/// (trailing) action buttons.
struct ContactRowView: View {
    let contact: ContactWrapper
    let isPinned: Bool

    @Environment(AppState.self) private var appState
    @Environment(ContactStore.self) private var contactStore

    @State private var swipeOffset: CGFloat = 0
    @State private var activeSwipe: SwipeDirection = .none

    private let actionButtonWidth: CGFloat = 72

    private enum SwipeDirection {
        case none, leading, trailing
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Leading action (pin/unpin) — revealed when swiping right
            HStack(spacing: 0) {
                Button {
                    togglePin()
                    resetSwipe()
                } label: {
                    VStack(spacing: KSpacing.xs) {
                        Image(systemName: isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 17, weight: .medium))
                        Text(isPinned ? "Unpin" : "Pin")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: actionButtonWidth, maxHeight: .infinity)
                    .background(Color.accentSlateBlue)
                }
                .accessibilityLabel(isPinned ? "Unpin \(contact.fullName)" : "Pin \(contact.fullName)")
                Spacer()
            }
            .opacity(activeSwipe == .leading ? 1 : 0)

            // Trailing action (delete) — revealed when swiping left
            HStack(spacing: 0) {
                Spacer()
                Button {
                    deleteContact()
                    resetSwipe()
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

                // Determine the swipe direction once at the start
                if activeSwipe == .none {
                    activeSwipe = horizontal > 0 ? .leading : .trailing
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

    private func togglePin() {
        HapticManager.mediumImpact()
        contactStore.togglePin(identifier: contact.identifier)
    }

    private func deleteContact() {
        do {
            try contactStore.deleteContact(identifier: contact.identifier)
        } catch {
            HapticManager.error()
        }
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
                    thumbnailImageData: nil
                ),
                isPinned: false
            )
            ContactRowView(
                contact: ContactWrapper(
                    identifier: "2",
                    givenName: "Bob",
                    familyName: "Williams",
                    organizationName: "",
                    thumbnailImageData: nil
                ),
                isPinned: true
            )
        }
    }
    .environment(ContactStore())
    .environment(AppState())
}

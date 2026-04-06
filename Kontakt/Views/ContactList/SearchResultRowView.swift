import SwiftUI

/// A richer row for search results that shows matched field context.
///
/// Displays: contact photo, name, matched field with highlighted value,
/// primary phone/email, and star indicator. Supports swipe-to-star (leading)
/// and swipe-to-delete (trailing), matching `ContactRowView`'s gesture pattern.
struct SearchResultRowView: View {
    let result: SearchResult
    let isStarred: Bool
    var onDelete: (() -> Void)?

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
                .accessibilityLabel(isStarred ? "Unstar \(result.contact.fullName)" : "Star \(result.contact.fullName)")
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
                .accessibilityLabel("Delete \(result.contact.fullName)")
            }
            .opacity(activeSwipe == .trailing ? 1 : 0)

            // Main row content
            NavigationLink(value: result.contact.identifier) {
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
            ContactPhoto(
                imageData: result.contact.thumbnailImageData,
                givenName: result.contact.givenName,
                familyName: result.contact.familyName,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                // Name line with star indicator
                HStack(spacing: KSpacing.xs) {
                    Text(result.contact.fullName)
                        .font(.listPrimary)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if isStarred {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentSlateBlue)
                    }

                    Spacer(minLength: 0)
                }

                // Matched field context line (only if match is NOT in name)
                if let matchContext = matchedFieldText {
                    matchContext
                        .lineLimit(1)
                }

                // Primary phone / email line
                if let contactInfo = primaryContactInfo {
                    Text(contactInfo)
                        .font(.label)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, KSpacing.xl)
        .padding(.vertical, KSpacing.m)
        .frame(minHeight: 60, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
    }

    // MARK: - Matched Field Display

    /// Builds an attributed "Matched in [field]: [value]" text when the match
    /// is in a field other than given/family name. Returns nil for name matches.
    private var matchedFieldText: Text? {
        let field = result.matchedField
        guard field != .givenName && field != .familyName,
              let value = result.matchedValue else {
            return nil
        }
        return (
            Text("Matched in \(field.displayLabel): ")
                .font(.listSecondary)
                .foregroundStyle(Color.textSecondary)
            + Text(value)
                .font(.listSecondary)
                .foregroundStyle(Color.accentSlateBlue)
        )
    }

    /// Formats primary phone and/or email separated by " \u{00B7} ".
    private var primaryContactInfo: String? {
        let parts = [result.contact.primaryPhone, result.contact.primaryEmail]
            .compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " \u{00B7} ")
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width

                if activeSwipe == .none {
                    if horizontal > 0 {
                        activeSwipe = .leading
                    } else if horizontal < 0 && onDelete != nil {
                        activeSwipe = .trailing
                    }
                }

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
        contactStore.toggleStar(identifier: result.contact.identifier)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VStack(spacing: 0) {
            SearchResultRowView(
                result: SearchResult(
                    contact: ContactWrapper(
                        identifier: "1",
                        givenName: "Jennifer",
                        familyName: "Adams",
                        organizationName: "Acme Corp",
                        thumbnailImageData: nil,
                        primaryPhone: "512-555-1234",
                        primaryEmail: "jen@example.com"
                    ),
                    score: 0.8,
                    matchedField: .notes,
                    matchedSubstring: nil,
                    matchedValue: "plumber"
                ),
                isStarred: true,
                onDelete: { print("Delete") }
            )
            SearchResultRowView(
                result: SearchResult(
                    contact: ContactWrapper(
                        identifier: "2",
                        givenName: "Bob",
                        familyName: "Williams",
                        organizationName: "",
                        thumbnailImageData: nil,
                        primaryPhone: "303-555-9876",
                        primaryEmail: nil
                    ),
                    score: 0.9,
                    matchedField: .givenName,
                    matchedSubstring: nil,
                    matchedValue: "Bob"
                ),
                isStarred: false,
                onDelete: { print("Delete") }
            )
            SearchResultRowView(
                result: SearchResult(
                    contact: ContactWrapper(
                        identifier: "3",
                        givenName: "Maria",
                        familyName: "Garcia",
                        organizationName: "Garcia Plumbing",
                        thumbnailImageData: nil,
                        primaryPhone: nil,
                        primaryEmail: "maria@garciaplumbing.com"
                    ),
                    score: 0.7,
                    matchedField: .organization,
                    matchedSubstring: nil,
                    matchedValue: "Garcia Plumbing"
                ),
                isStarred: false,
                onDelete: { print("Delete") }
            )
        }
    }
    .environment(ContactStore())
    .environment(AppState())
}

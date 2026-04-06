import SwiftUI
import UIKit
import Contacts

/// First launch and permission-denied screen.
///
/// A single, focused screen that handles all three non-authorized states:
/// - `.notDetermined` — the user hasn't been asked yet.
/// - `.denied` / `.restricted` — permission was refused or blocked.
/// - `.limited` — iOS 18+ partial access granted.
///
/// No carousel, no multi-step flow. One screen, one ask.
struct OnboardingView: View {
    @Environment(ContactStore.self) private var contactStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: KSpacing.xxl) {
            Spacer()

            // App identity
            VStack(spacing: KSpacing.s) {
                Text("People")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Your contacts, simplified.")
                    .font(.titleSecondary)
                    .foregroundStyle(Color.textSecondary)
            }

            // Icon
            Image(systemName: "person.2")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(Color.accentSlateBlue)

            // State-specific content
            stateContent

            Spacer()
        }
        .padding(.horizontal, KSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - State Content

    @ViewBuilder
    private var stateContent: some View {
        switch contactStore.authorizationStatus {
        case .notDetermined:
            notDeterminedContent
        case .limited:
            limitedContent
        default:
            deniedContent
        }
    }

    // MARK: - Not Determined

    private var notDeterminedContent: some View {
        VStack(spacing: KSpacing.xl) {
            Text("People needs access to your contacts to work. All data stays on your device \u{2014} no accounts, no cloud sync, no tracking.")
                .font(.kBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    try? await contactStore.requestAccess()
                }
            } label: {
                Text("Get Started")
                    .font(.titlePrimary)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KSpacing.m)
                    .background(Color.accentSlateBlue)
                    .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Denied / Restricted

    private var deniedContent: some View {
        VStack(spacing: KSpacing.xl) {
            Text("People needs full contact access to function. Please enable it in Settings.")
                .font(.kBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                openSettings()
            } label: {
                Text("Open Settings")
                    .font(.titlePrimary)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KSpacing.m)
                    .background(Color.accentSlateBlue)
                    .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Limited (iOS 18+)

    private var limitedContent: some View {
        VStack(spacing: KSpacing.xl) {
            // Banner
            HStack(spacing: KSpacing.s) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.kBody)
                    .foregroundStyle(Color.accentSlateBlue)

                Text("People is running with limited contact access. Some contacts may not be visible.")
                    .font(.kBody)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(KSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentSubtle)
            .clipShape(RoundedRectangle(cornerRadius: KRadius.m))

            Button {
                openSettings()
            } label: {
                Text("Grant Full Access")
                    .font(.titlePrimary)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KSpacing.m)
                    .background(Color.accentSlateBlue)
                    .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Preview

#Preview("Not Determined") {
    OnboardingView()
        .environment(ContactStore())
        .environment(AppState())
}

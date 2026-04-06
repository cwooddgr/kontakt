import SwiftUI
import Contacts

@main
struct PeopleApp: App {
    @State private var contactStore = ContactStore()
    @State private var appState = AppState()
    @State private var tagStore = TagStore()
    @State private var interactionLogStore = InteractionLogStore()
    @State private var recentlyDeletedStore = RecentlyDeletedStore()

    var body: some Scene {
        WindowGroup {
            Group {
                switch contactStore.authorizationStatus {
                case .authorized:
                    NavigationStack {
                        ContactListView()
                    }
                case .limited:
                    NavigationStack {
                        VStack(spacing: 0) {
                            LimitedAccessBanner()
                                .padding(.horizontal, KSpacing.l)
                                .padding(.top, KSpacing.s)
                            ContactListView()
                        }
                    }
                case .notDetermined:
                    // Still waiting for the user to respond or for the check to complete.
                    // Show onboarding which will trigger the permission request.
                    OnboardingView()
                default:
                    // Denied or restricted — show onboarding with guidance.
                    OnboardingView()
                }
            }
            .environment(contactStore)
            .environment(appState)
            .environment(tagStore)
            .environment(interactionLogStore)
            .environment(recentlyDeletedStore)
            .task {
                await contactStore.checkAuthorizationStatus()
                recentlyDeletedStore.purgeExpired()
            }
        }
    }
}

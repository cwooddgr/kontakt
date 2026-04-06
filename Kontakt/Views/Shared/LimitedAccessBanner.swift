import SwiftUI
import UIKit

/// Banner shown at the top of the contact list when the app has limited contact access.
///
/// Tapping the banner opens the system Settings so the user can grant full access.
/// The banner can be dismissed via its close button; the dismissed state is persisted
/// in `@AppStorage` so it stays hidden across launches.
struct LimitedAccessBanner: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("limitedAccessBannerDismissed") private var isDismissed = false

    var body: some View {
        if !isDismissed {
            HStack(spacing: KSpacing.s) {
                Image(systemName: "info.circle")
                    .font(.kBody)
                    .foregroundStyle(Color.accentSlateBlue)

                Text("People works best with full contact access")
                    .font(.kBody)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation {
                        isDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.label)
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(KSpacing.l)
            .background(Color.accentSubtle)
            .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
            .contentShape(Rectangle())
            .onTapGesture {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        LimitedAccessBanner()
        Spacer()
    }
    .padding(KSpacing.l)
}

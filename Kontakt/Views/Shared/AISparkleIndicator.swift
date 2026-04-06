import SwiftUI

/// Indicates that on-device Foundation Models intelligence is active.
/// Only renders on devices running iOS 26+ that support the FoundationModels framework.
struct AISparkleIndicator: View {
    @State private var isVisible = false

    var body: some View {
        if AIParsingService.isAvailable {
            HStack(spacing: KSpacing.xs) {
                Text("\u{2726}")
                    .foregroundStyle(Color.accentSlateBlue)
                Text("On-device")
                    .font(.labelCaps)
                    .tracking(0.5)
                    .foregroundStyle(Color.textTertiary)
            }
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) {
                    isVisible = true
                }
            }
        }
    }
}

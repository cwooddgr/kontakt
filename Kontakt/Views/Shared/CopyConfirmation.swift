import SwiftUI

/// A small floating "Copied" label that appears briefly to confirm a clipboard copy.
struct CopyConfirmationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("Copied")
            .font(.labelCaps)
            .foregroundStyle(Color.textTertiary)
            .padding(.horizontal, KSpacing.m)
            .padding(.vertical, KSpacing.s)
            .background(Color.surfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: KRadius.s))
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

/// ViewModifier that overlays a "Copied" confirmation when triggered.
struct CopyConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if visible {
                    CopyConfirmationView()
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.95))
                        )
                        .zIndex(1)
                        .padding(.top, KSpacing.s)
                }
            }
            .onChange(of: isPresented) { _, newValue in
                guard newValue else { return }
                show()
            }
    }

    private func show() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.2, bounce: 0.3)) {
            visible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                visible = false
            }
            // Reset binding after dismiss so it can be triggered again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isPresented = false
            }
        }
    }
}

extension View {
    /// Attaches a floating "Copied" confirmation that appears when `isPresented` becomes true.
    /// Automatically dismisses after 1.5 seconds.
    func copyConfirmation(isPresented: Binding<Bool>) -> some View {
        modifier(CopyConfirmationModifier(isPresented: isPresented))
    }
}

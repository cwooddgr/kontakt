import SwiftUI

/// A single contact field row showing a label above its value.
///
/// Tapping executes the primary action (call, compose, open Maps, etc.).
/// Long-pressing copies the value to the clipboard and shows a confirmation.
struct FieldView: View {
    let label: String
    let value: String
    var action: (() -> Void)?
    var copyValue: String?

    @Binding var showCopyConfirmation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: KSpacing.xs) {
            Text(label)
                .font(.label)
                .foregroundStyle(Color.textTertiary)

            Text(value)
                .font(.kBody)
                .foregroundStyle(action != nil ? Color.accentSlateBlue : Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            action?()
        }
        .onLongPressGesture {
            guard let copyValue else { return }
            UIPasteboard.general.string = copyValue
            HapticManager.lightImpact()
            showCopyConfirmation = true
        }
        .accessibilityHint(copyValue != nil ? "Long press to copy" : "")
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var copied = false

    VStack(alignment: .leading, spacing: KSpacing.l) {
        FieldView(
            label: "mobile",
            value: "(512) 555-1234",
            action: {},
            copyValue: "5125551234",
            showCopyConfirmation: $copied
        )

        FieldView(
            label: "work",
            value: "(512) 555-5678",
            action: {},
            copyValue: "5125555678",
            showCopyConfirmation: $copied
        )

        FieldView(
            label: "home",
            value: "1234 Main Street\nAustin, TX 78704",
            action: {},
            copyValue: "1234 Main Street, Austin, TX 78704",
            showCopyConfirmation: $copied
        )
    }
    .padding(.horizontal, KSpacing.xl)
    .copyConfirmation(isPresented: $copied)
}

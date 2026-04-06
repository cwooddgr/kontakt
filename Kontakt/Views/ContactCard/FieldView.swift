import SwiftUI

/// A single contact field row showing a label above its value.
///
/// Tapping executes the primary action (call, compose, open Maps, etc.).
/// Long-pressing copies the value to the clipboard and shows a confirmation.
/// When `onEdit` or `onDelete` callbacks are provided, a context menu offers
/// "Edit" and "Delete" options for inline field management.
struct FieldView: View {
    let label: String
    let value: String
    var action: (() -> Void)?
    var copyValue: String?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

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
        .if(hasContextMenu) { view in
            view.contextMenu {
                if let copyValue {
                    Button {
                        UIPasteboard.general.string = copyValue
                        HapticManager.lightImpact()
                        showCopyConfirmation = true
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }

                if let onEdit {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }

                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .if(!hasContextMenu) { view in
            view.onLongPressGesture {
                guard let copyValue else { return }
                UIPasteboard.general.string = copyValue
                HapticManager.lightImpact()
                showCopyConfirmation = true
            }
        }
        .accessibilityHint(accessibilityHintText)
    }

    // MARK: - Helpers

    private var hasContextMenu: Bool {
        onEdit != nil || onDelete != nil
    }

    private var accessibilityHintText: String {
        if hasContextMenu {
            return "Long press for options"
        }
        return copyValue != nil ? "Long press to copy" : ""
    }
}

// MARK: - Conditional Modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
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
            onEdit: {},
            onDelete: {},
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

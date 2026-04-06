import SwiftUI

/// A small horizontal pill displaying a tag name.
///
/// Tappable by default. When `isRemovable` is true, a trailing "x" button
/// is shown for removal.
struct TagPillView: View {
    let name: String
    var isRemovable: Bool = false
    var onTap: () -> Void = {}
    var onRemove: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: KSpacing.xs) {
                Text(name)
                    .font(.label)
                    .foregroundStyle(Color.accentSlateBlue)

                if isRemovable {
                    Button {
                        onRemove?()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.accentSlateBlue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, KSpacing.s)
            .padding(.vertical, KSpacing.xs)
            .background(Color.accentSubtle)
            .clipShape(RoundedRectangle(cornerRadius: KRadius.s))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HStack {
        TagPillView(name: "estes")
        TagPillView(name: "vendor", isRemovable: true, onRemove: {})
    }
    .padding()
}

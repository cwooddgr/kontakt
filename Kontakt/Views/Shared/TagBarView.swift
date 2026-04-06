import SwiftUI

/// Horizontal scrolling row of tag pills.
///
/// Supports an optional trailing "+" pill for adding tags and optional
/// removable mode for editing tag assignments.
struct TagBarView: View {
    let tags: [String]
    var onTapTag: (String) -> Void = { _ in }
    var onAddTag: (() -> Void)?
    var isEditable: Bool = false
    var onRemoveTag: ((String) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KSpacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    TagPillView(
                        name: tag,
                        isRemovable: isEditable,
                        onTap: { onTapTag(tag) },
                        onRemove: { onRemoveTag?(tag) }
                    )
                }

                if let onAddTag {
                    Button(action: onAddTag) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentSlateBlue)
                            .padding(.horizontal, KSpacing.s)
                            .padding(.vertical, KSpacing.xs)
                            .overlay(
                                RoundedRectangle(cornerRadius: KRadius.s)
                                    .strokeBorder(
                                        Color.accentSlateBlue.opacity(0.5),
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TagBarView(
        tags: ["estes", "vendor", "plumber"],
        onTapTag: { _ in },
        onAddTag: {},
        isEditable: true,
        onRemoveTag: { _ in }
    )
    .padding()
}

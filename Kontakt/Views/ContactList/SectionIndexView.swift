import SwiftUI

/// A-Z section index scrubber displayed on the trailing edge of the contact list.
///
/// Users can tap or drag through the letters to quickly jump to a section.
/// Provides haptic selection feedback on each letter change during a drag.
struct SectionIndexView: View {
    let letters: [String]
    let onSelectLetter: (String) -> Void

    @State private var currentLetter: String?

    var body: some View {
        VStack(spacing: 1) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.accentSlateBlue)
                    .frame(width: 16, height: letterHeight)
            }
        }
        .padding(.vertical, KSpacing.xs)
        .padding(.horizontal, KSpacing.xs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    let index = letterIndex(for: value.location.y)
                    guard index >= 0, index < letters.count else { return }
                    let letter = letters[index]
                    if letter != currentLetter {
                        currentLetter = letter
                        HapticManager.selection()
                        onSelectLetter(letter)
                    }
                }
                .onEnded { _ in
                    currentLetter = nil
                }
        )
        .padding(.trailing, KSpacing.xs)
        .accessibilityLabel("Section index")
        .accessibilityHint("Drag to quickly scroll through contact sections")
    }

    // MARK: - Layout Helpers

    /// Height of each letter label. Kept small to fit the full alphabet.
    private var letterHeight: CGFloat {
        14
    }

    /// Total height of the letter stack (letters + 1pt spacing between each).
    private var totalHeight: CGFloat {
        let lettersHeight = CGFloat(letters.count) * letterHeight
        let spacingHeight = CGFloat(max(0, letters.count - 1)) * 1
        let paddingHeight = KSpacing.xs * 2
        return lettersHeight + spacingHeight + paddingHeight
    }

    /// Determines the letter index for a given y position within the gesture area.
    private func letterIndex(for y: CGFloat) -> Int {
        let adjustedY = y - KSpacing.xs
        let perLetterHeight = letterHeight + 1
        return Int(adjustedY / perLetterHeight)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(UIColor.systemBackground)
        HStack {
            Spacer()
            SectionIndexView(
                letters: ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
                           "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X",
                           "Y", "Z"],
                onSelectLetter: { letter in
                    print("Selected: \(letter)")
                }
            )
        }
    }
}

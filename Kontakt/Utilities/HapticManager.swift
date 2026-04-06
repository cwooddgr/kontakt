import SwiftUI

enum HapticManager {
    /// Light impact - used for copy to clipboard
    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact - used for pin/unpin toggle, triage swipe threshold
    static func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Selection feedback - used for section scrubber letter change
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Success notification - used for save confirmation
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Error notification - used for save failure
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Warning notification - used for triage delete confirmation
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

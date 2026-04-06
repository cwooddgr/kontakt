import SwiftUI
import UIKit

// MARK: - Spacing

enum KSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Typography

extension Font {
    /// SF Pro Medium 17pt - Contact name in card view. Scales with Dynamic Type (relative to .headline).
    static var titlePrimary: Font {
        .system(.headline, weight: .medium)
    }

    /// SF Pro Regular 15pt - Company name, subtitle. Scales with Dynamic Type (relative to .subheadline).
    static var titleSecondary: Font {
        .system(.subheadline, weight: .regular)
    }

    /// SF Pro Regular 15pt - Field values, notes content. Scales with Dynamic Type (relative to .subheadline).
    static var kBody: Font {
        .system(.subheadline, weight: .regular)
    }

    /// SF Pro Regular 13pt - Field labels ("mobile", "work", "home"). Scales with Dynamic Type (relative to .footnote).
    static var label: Font {
        .system(.footnote, weight: .regular)
    }

    /// SF Pro Regular 11pt, small caps - Section headers, metadata. Scales with Dynamic Type (relative to .caption2).
    static var labelCaps: Font {
        .system(.caption2, weight: .regular).uppercaseSmallCaps()
    }

    /// SF Pro Regular 16pt - Contact name in list row. Scales with Dynamic Type (relative to .callout).
    static var listPrimary: Font {
        .system(.callout, weight: .regular)
    }

    /// SF Pro Regular 13pt - Company/label in list row. Scales with Dynamic Type (relative to .footnote).
    static var listSecondary: Font {
        .system(.footnote, weight: .regular)
    }

    /// SF Pro Medium 13pt - Action bar button labels. Scales with Dynamic Type (relative to .footnote).
    static var action: Font {
        .system(.footnote, weight: .medium)
    }

    /// SF Pro Regular 16pt - Search field input. Scales with Dynamic Type (relative to .callout).
    static var search: Font {
        .system(.callout, weight: .regular)
    }

    /// Large name display for person view header
    static var nameDisplay: Font {
        .system(.title2, weight: .semibold)
    }
}

// MARK: - Corner Radii

enum KRadius {
    /// Small elements (tags, badges)
    static let s: CGFloat = 6
    /// Contact photos, field editor
    static let m: CGFloat = 10
    /// Cards, modal sheets
    static let l: CGFloat = 14
}

// MARK: - Semantic Colors

extension Color {
    /// Custom Slate Blue accent - light #5B7B9A / dark #7B9BB8
    static var accentSlateBlue: Color {
        Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0x7B / 255.0, green: 0x9B / 255.0, blue: 0xB8 / 255.0, alpha: 1)
                    : UIColor(red: 0x5B / 255.0, green: 0x7B / 255.0, blue: 0x9A / 255.0, alpha: 1)
            }
        )
    }

    /// Accent color at 12% opacity (light) / 15% opacity (dark) - highlights, selected states
    static var accentSubtle: Color {
        Color(
            UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    UIColor(red: 0x7B / 255.0, green: 0x9B / 255.0, blue: 0xB8 / 255.0, alpha: 0.15)
                } else {
                    UIColor(red: 0x5B / 255.0, green: 0x7B / 255.0, blue: 0x9A / 255.0, alpha: 0.12)
                }
            }
        )
    }

    /// Maps to UIColor.label - fully adaptive primary text
    static var textPrimary: Color {
        Color(UIColor.label)
    }

    /// Maps to UIColor.secondaryLabel - subtitles, secondary info
    static var textSecondary: Color {
        Color(UIColor.secondaryLabel)
    }

    /// Maps to UIColor.tertiaryLabel - field labels, metadata
    static var textTertiary: Color {
        Color(UIColor.tertiaryLabel)
    }

    /// Maps to UIColor.secondarySystemBackground - cards, grouped sections
    static var surfaceBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
}

import SwiftUI

/// Reusable contact photo view that shows the contact's image or initials fallback.
struct ContactPhoto: View {
    /// Raw image data (e.g. from CNContact.thumbnailImageData).
    let imageData: Data?
    /// The contact's given (first) name.
    let givenName: String
    /// The contact's family (last) name.
    let familyName: String
    /// Display size. Common values: 40 (list), 56 (card).
    var size: CGFloat = 40

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.m))
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: KRadius.m)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var initialsView: some View {
        ZStack {
            Color.accentSubtle
            Text(initials)
                .font(.system(size: initialsFontSize, weight: .medium))
                .foregroundStyle(Color.accentSlateBlue)
        }
    }

    /// Computes initials from the first character of given name and family name.
    private var initials: String {
        let first = givenName.first.map(String.init) ?? ""
        let last = familyName.first.map(String.init) ?? ""
        let result = first + last
        return result.isEmpty ? "?" : result
    }

    /// Scale the initials font relative to the photo size.
    private var initialsFontSize: CGFloat {
        size * 0.38
    }
}

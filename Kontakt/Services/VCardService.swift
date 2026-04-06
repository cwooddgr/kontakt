import Foundation
import Contacts
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - VCardField

/// Represents a selectable field for vCard generation.
/// Each case maps to one or more CNContact properties that can be
/// included or excluded when sharing a contact via QR code or vCard.
enum VCardField: String, CaseIterable, Identifiable, Sendable {
    case name
    case phone
    case email
    case address
    case company
    case jobTitle
    case birthday
    case url
    case photo
    case note

    var id: String { rawValue }

    /// Human-readable label for display in the field toggle list.
    var displayName: String {
        switch self {
        case .name: "Name"
        case .phone: "Phone"
        case .email: "Email"
        case .address: "Address"
        case .company: "Company"
        case .jobTitle: "Job Title"
        case .birthday: "Birthday"
        case .url: "URL"
        case .photo: "Photo"
        case .note: "Notes"
        }
    }

    /// SF Symbol name for the field's icon.
    var iconName: String {
        switch self {
        case .name: "person"
        case .phone: "phone"
        case .email: "envelope"
        case .address: "mappin.and.ellipse"
        case .company: "building.2"
        case .jobTitle: "briefcase"
        case .birthday: "gift"
        case .url: "link"
        case .photo: "photo"
        case .note: "note.text"
        }
    }
}

// MARK: - VCardService

/// Generates vCard data and QR code images from contacts with selectable fields.
enum VCardService {

    /// Generate vCard data for a contact, including only the specified fields.
    ///
    /// Creates a mutable copy of the contact and clears all properties
    /// that are NOT in the selected field set, then serializes to vCard format.
    static func generateVCard(for contact: CNContact, includingFields fields: Set<VCardField>) -> Data? {
        let mutable = contact.mutableCopy() as! CNMutableContact

        // Clear name fields if not selected.
        if !fields.contains(.name) {
            mutable.givenName = ""
            mutable.familyName = ""
            mutable.middleName = ""
            mutable.namePrefix = ""
            mutable.nameSuffix = ""
            mutable.nickname = ""
        }

        if !fields.contains(.phone) {
            mutable.phoneNumbers = []
        }

        if !fields.contains(.email) {
            mutable.emailAddresses = []
        }

        if !fields.contains(.address) {
            mutable.postalAddresses = []
        }

        if !fields.contains(.company) {
            mutable.organizationName = ""
            mutable.departmentName = ""
        }

        if !fields.contains(.jobTitle) {
            mutable.jobTitle = ""
        }

        if !fields.contains(.birthday) {
            mutable.birthday = nil
        }

        if !fields.contains(.url) {
            mutable.urlAddresses = []
        }

        if !fields.contains(.photo) {
            mutable.imageData = nil
        }

        if !fields.contains(.note) {
            mutable.note = ""
        }

        do {
            return try CNContactVCardSerialization.data(with: [mutable])
        } catch {
            return nil
        }
    }

    /// Generate a QR code image from vCard data.
    ///
    /// Uses CoreImage's QR code generator to create a black-on-white QR code
    /// scaled to the requested point size.
    static func generateQRCode(from data: Data, size: CGFloat) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale the QR code to the requested size.
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Render to a CGImage for crisp pixel-perfect output.
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

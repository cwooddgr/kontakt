import Foundation

extension String {

    // MARK: - Phone Normalization

    /// Strips all non-digit characters for phone number comparison during search.
    /// For example, "(512) 555-1234" becomes "5125551234".
    var phoneNormalized: String {
        filter(\.isWholeNumber)
    }

    // MARK: - Phone Formatting

    /// Attempts to format a digit string as a US phone number.
    /// Returns the original string if it doesn't match a standard length.
    ///
    /// - 10 digits: "(XXX) XXX-XXXX"
    /// - 11 digits starting with 1: "+1 (XXX) XXX-XXXX"
    /// - 7 digits: "XXX-XXXX"
    var formattedAsPhoneNumber: String {
        let digits = phoneNormalized

        switch digits.count {
        case 7:
            let idx3 = digits.index(digits.startIndex, offsetBy: 3)
            let prefix = digits[digits.startIndex..<idx3]
            let suffix = digits[idx3...]
            return "\(prefix)-\(suffix)"

        case 10:
            let idx0 = digits.startIndex
            let idx3 = digits.index(idx0, offsetBy: 3)
            let idx6 = digits.index(idx0, offsetBy: 6)
            let area = digits[idx0..<idx3]
            let exchange = digits[idx3..<idx6]
            let number = digits[idx6...]
            return "(\(area)) \(exchange)-\(number)"

        case 11 where digits.hasPrefix("1"):
            let idx1 = digits.index(after: digits.startIndex)
            let idx4 = digits.index(idx1, offsetBy: 3)
            let idx7 = digits.index(idx1, offsetBy: 6)
            let area = digits[idx1..<idx4]
            let exchange = digits[idx4..<idx7]
            let number = digits[idx7...]
            return "+1 (\(area)) \(exchange)-\(number)"

        default:
            return self
        }
    }
}

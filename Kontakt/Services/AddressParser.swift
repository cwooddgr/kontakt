import Foundation

// MARK: - Address Parser

/// Delegates freeform address parsing to the appropriate tier.
///
/// - **Tier 1** (iOS 26+, iPhone 15 Pro+): Foundation Models on-device AI via `AIParsingService`.
/// - **Tier 2** (all devices): Regex heuristics via `RegexParsingService`.
///
/// The parser tries Tier 1 first when available. If the AI call fails for any reason,
/// it falls back transparently to Tier 2. The `usedAI` flag in the result tuple
/// lets the UI show the sparkle indicator when AI was used.
struct AddressParser: Sendable {

    /// Parses freeform address text into a structured `ParsedAddress`.
    ///
    /// - Parameter input: Freeform address text (e.g., pasted from an email).
    /// - Returns: A tuple containing the parsed result and whether AI (Tier 1) was used.
    ///   The `usedAI` flag is true only when Foundation Models successfully produced the result.
    func parse(_ input: String) async -> (result: ParsedAddress, usedAI: Bool) {
        // Tier 1: Try Foundation Models if available.
        if AIParsingService.isAvailable {
            do {
                let result = try await AIParsingService.parseAddress(input)
                return (result: result, usedAI: true)
            } catch {
                // AI failed — fall through to Tier 2 silently.
                // In debug builds, log the failure for diagnostics.
                #if DEBUG
                print("[AddressParser] AI parsing failed, falling back to regex: \(error.localizedDescription)")
                #endif
            }
        }

        // Tier 2: Regex-based fallback.
        let result = RegexParsingService.parseAddress(input)
        return (result: result, usedAI: false)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BCP47LanguageTag — ISO 639-2 ↔ BCP 47 bridge
//
// Reference: ISO 639-2 (alpha-3 Bibliographic /B vs Terminologic /T)
// + RFC 5646 §4.5 (canonicalisation, shortest valid form preferred)
// + ISO/IEC 14496-12 §8.4.2.3 (Media Header Box `mdhd` language
// storage).

import Foundation

extension BCP47LanguageTag {

    /// Bridge from an ISO 639-2 3-character code (as carried in
    /// ISOBMFF `mdhd` boxes) to a typed BCP 47 language tag.
    ///
    /// Handles both the Bibliographic (/B) and Terminologic (/T) ISO
    /// 639-2 variants, normalising to /T per RFC 5646 §2.2.1, then
    /// preferring the ISO 639-1 (2-char) form when one exists per
    /// RFC 5646 §4.5 canonicalisation (shortest valid form preferred).
    ///
    /// Examples:
    /// - `fra` → `iso639_1("fr")`
    /// - `fre` → /T `fra` → `iso639_1("fr")`
    /// - `yue` → `iso639_3("yue")` (no ISO 639-1 — keep 3-char)
    /// - `und` → `iso639_3("und")` (undetermined)
    ///
    /// - Throws: ``BCP47Error/unknownISO6392Code(_:)`` when the input
    ///   is not a syntactically valid 3-letter code.
    ///
    /// References:
    /// - ISO 639-2 — Codes for the representation of names of
    ///   languages, Part 2: Alpha-3 code
    /// - IETF RFC 5646 §4.5 — Canonicalization (prefer shortest)
    /// - ISO/IEC 14496-12 §8.4.2.3 — Media Header Box `mdhd` language
    public static func fromISO6392T(_ code: String) throws -> BCP47LanguageTag {
        let lowered = code.lowercased()
        guard IANALanguageSubtagRegistry.isWellFormedISO639_3(lowered) else {
            throw BCP47Error.unknownISO6392Code(code)
        }
        // /B → /T normalisation.
        let terminologic =
            IANALanguageSubtagRegistry.iso639_2BToTMapping[lowered] ?? lowered
        // /T → /1 shortest-form preference (RFC 5646 §4.5).
        if let iso1 = IANALanguageSubtagRegistry.iso639_3To1Mapping[terminologic] {
            return BCP47LanguageTag(primaryLanguage: .iso639_1(iso1))
        }
        return BCP47LanguageTag(primaryLanguage: .iso639_3(terminologic))
    }

    /// Reverse bridge: convert this BCP 47 tag to an ISO 639-2/T
    /// 3-character code suitable for `mdhd` box encoding.
    ///
    /// Returns `nil` when the language has no ISO 639-2 representation
    /// (private-use or grandfathered without an ISO 639-2 equivalent).
    ///
    /// References:
    /// - ISO 639-2 — Alpha-3 code
    /// - ISO/IEC 14496-12 §8.4.2.3 — Media Header Box
    public func toISO6392T() -> String? {
        switch primaryLanguage {
        case .iso639_1(let code):
            let lowered = code.lowercased()
            for (terminologic, alpha2) in IANALanguageSubtagRegistry
                .iso639_3To1Mapping where alpha2 == lowered
            {
                return terminologic
            }
            return nil
        case .iso639_3(let code):
            let lowered = code.lowercased()
            guard IANALanguageSubtagRegistry.isWellFormedISO639_3(lowered) else {
                return nil
            }
            // If the caller put a /B form in `.iso639_3(_)`, normalise.
            return IANALanguageSubtagRegistry.iso639_2BToTMapping[lowered]
                ?? lowered
        case .grandfathered, .privateUse:
            return nil
        }
    }
}

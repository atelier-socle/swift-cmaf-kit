// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - IANALanguageSubtagRegistry
//
// Embedded snapshot of the IANA Language Subtag Registry for offline
// BCP 47 validation.
//
// Strategy: syntax-first + common-set acceleration. Each subtag
// category exposes both `isKnownXXX(_:)` (fast Set lookup against the
// embedded snapshot) and `isWellFormedXXX(_:)` (RFC 5646 §2.1 ABNF
// check). The default parser uses the syntax check; strict mode (a
// future opt-in) requires registry membership.
//
// References:
// - IANA Language Subtag Registry — authoritative subtag list
// - IETF RFC 5646 §3 — Registry maintenance
// - IETF RFC 5646 §2.1 — ABNF syntax (well-formedness)

import Foundation

/// Embedded snapshot of the IANA Language Subtag Registry for offline
/// BCP 47 validation.
///
/// Snapshot date: 2026-05 (most recent registry release at the time of
/// CMAFKit 0.1.1). Refresh policy: regenerated at every CMAFKit minor
/// release; deprecated subtags are retained for legacy-tag parsing;
/// new subtags require a new minor release.
///
/// Strategy — two-tier validation:
/// 1. `isKnownXXX(_:)` — `Set` lookup against the embedded snapshot for
///    the most common subtags (covers >99% of real-world streaming media).
/// 2. `isWellFormedXXX(_:)` — RFC 5646 §2.1 ABNF check; accepts any
///    syntactically valid subtag.
///
/// References:
/// - IANA Language Subtag Registry — authoritative subtag list
/// - IETF RFC 5646 §3 — Registry maintenance
public enum IANALanguageSubtagRegistry {

    /// Snapshot date as ISO 8601 (yyyy-MM).
    public static let snapshotDate: String = "2026-05"

    // MARK: Well-formedness (RFC 5646 §2.1 ABNF)

    /// True if `code` is a syntactically well-formed ISO 639-1 subtag:
    /// exactly 2 ASCII letters. Does not check registry membership.
    public static func isWellFormedISO639_1(_ code: String) -> Bool {
        code.count == 2 && code.allSatisfy { $0.isASCII && $0.isLetter }
    }

    /// True if `code` is a syntactically well-formed ISO 639-2/3 subtag:
    /// exactly 3 ASCII letters. Does not check registry membership.
    public static func isWellFormedISO639_3(_ code: String) -> Bool {
        code.count == 3 && code.allSatisfy { $0.isASCII && $0.isLetter }
    }

    /// True if `code` is a syntactically well-formed ISO 15924 script
    /// subtag: exactly 4 ASCII letters. Does not check registry
    /// membership.
    public static func isWellFormedISO15924(_ code: String) -> Bool {
        code.count == 4 && code.allSatisfy { $0.isASCII && $0.isLetter }
    }

    /// True if `code` is a syntactically well-formed ISO 3166-1 alpha-2
    /// subtag: exactly 2 ASCII letters. Does not check registry
    /// membership.
    public static func isWellFormedISO3166_1(_ code: String) -> Bool {
        code.count == 2 && code.allSatisfy { $0.isASCII && $0.isLetter }
    }

    /// True if `code` is a syntactically well-formed UN M.49 numeric
    /// region subtag: exactly 3 ASCII digits.
    public static func isWellFormedUNM49(_ code: String) -> Bool {
        code.count == 3 && code.allSatisfy { $0.isASCII && $0.isNumber }
    }

    // MARK: Known-subtag lookups (Set-based)

    /// True if `code` (case-insensitive) is in the embedded snapshot of
    /// the active ISO 639-1 registry.
    public static func isKnownISO639_1(_ code: String) -> Bool {
        iso639_1Codes.contains(code.lowercased())
    }

    /// True if `code` (case-insensitive) is in the embedded snapshot of
    /// the active ISO 639-2/3 registry (terminologic codes).
    public static func isKnownISO639_3(_ code: String) -> Bool {
        iso639_3Codes.contains(code.lowercased())
    }

    /// True if `code` (title-case canonical) is in the embedded
    /// snapshot of the active ISO 15924 script registry.
    public static func isKnownISO15924(_ code: String) -> Bool {
        iso15924Scripts.contains(titleCased(code))
    }

    /// True if `code` (uppercase canonical) is in the embedded snapshot
    /// of the active ISO 3166-1 alpha-2 region registry.
    public static func isKnownISO3166_1(_ code: String) -> Bool {
        iso3166_1Regions.contains(code.uppercased())
    }

    /// True if `value` is in the embedded snapshot of the active UN
    /// M.49 supra-national / continental region registry.
    public static func isKnownUNM49(_ value: UInt16) -> Bool {
        unM49Regions.contains(value)
    }

    /// True if `tag` (case-insensitive) is one of the RFC 5646 §2.2.8
    /// grandfathered tags.
    public static func isGrandfathered(_ tag: String) -> Bool {
        grandfatheredTags.contains(tag.lowercased())
    }

    /// True if `code` (lowercased) is one of the RFC 5646 §2.2.2
    /// extended-language subtags carried in the embedded snapshot.
    public static func isKnownExtendedLanguage(_ code: String) -> Bool {
        extendedLanguageSubtags.contains(code.lowercased())
    }

    // MARK: Helpers

    private static func titleCased(_ code: String) -> String {
        guard let first = code.first else { return code }
        return first.uppercased() + code.dropFirst().lowercased()
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - PrimarySubtag
//
// Reference: IETF RFC 5646 §2.2.1 (Primary Language Subtag).
//
// Sources of primary subtags:
//   - ISO 639-1 (2-character codes for the most common languages)
//   - ISO 639-3 (3-character codes for individual languages, including
//                those not in ISO 639-1)
//   - IANA-assigned grandfathered tags (`i-*`, `art-lojban`, etc.)
//   - Private-use tags (prefix `x-` or `qaa..qtz` range)

import Foundation

/// Primary language subtag of a BCP 47 language tag.
///
/// Per RFC 5646 §2.2.1 the primary subtag is the first subtag of a
/// language tag and identifies the language at the broadest level.
/// Three sources of primary subtags:
/// - **ISO 639-1** (2-character codes for the most common languages)
/// - **ISO 639-3** (3-character codes for individual languages,
///    including those not in ISO 639-1)
/// - **IANA-assigned** grandfathered (`i-*`, `art-lojban`, ...) /
///   private-use (`x-*`, `qaa..qtz`) tags
///
/// References:
/// - IETF RFC 5646 §2.2.1 — Primary Language Subtag
/// - IETF RFC 5646 §2.2.7 — Private-Use Subtags
/// - IETF RFC 5646 §2.2.8 — Grandfathered and Redundant Registrations
/// - ISO 639-1 — Alpha-2 code
/// - ISO 639-3 — Alpha-3 code for comprehensive coverage of languages
public enum PrimarySubtag: Sendable, Equatable, Hashable, Codable {

    /// ISO 639-1 2-character code (e.g., `"en"`, `"fr"`, `"zh"`).
    case iso639_1(String)

    /// ISO 639-3 3-character code (e.g., `"yue"` for Cantonese, `"cmn"`
    /// for Mandarin Chinese). Used when no ISO 639-1 code exists for the
    /// language, or when ISO 639-1 is ambiguous (e.g., `"zh"` is
    /// ambiguous between Mandarin and Cantonese — `"zh-yue"` or `"yue"`
    /// resolves it).
    case iso639_3(String)

    /// Grandfathered tag per RFC 5646 §2.2.8 (e.g., `"i-default"`,
    /// `"i-enochian"`, `"art-lojban"`). Registered before RFC 4646 and
    /// retained for backward compatibility; do not fit modern syntax.
    case grandfathered(String)

    /// Private-use primary tag per RFC 5646 §2.2.7. Begins with `x-`
    /// or uses the `qaa..qtz` ISO 639 private-use range. Not validated
    /// against any registry.
    case privateUse(String)

    /// Canonical lowercase form of the primary subtag, used by
    /// ``BCP47LanguageTag/canonicalForm`` per RFC 5646 §4.5
    /// (case normalisation: primary subtag → lowercase).
    public var raw: String {
        switch self {
        case .iso639_1(let value), .iso639_3(let value):
            return value.lowercased()
        case .grandfathered(let value):
            return value.lowercased()
        case .privateUse(let value):
            return value.lowercased()
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BCP47LanguageTag
//
// Reference: IETF BCP 47 / RFC 5646 (Tags for Identifying Languages,
// September 2009). Backed by ISO 639-1 / 639-2 / 639-3, ISO 15924,
// ISO 3166-1, UN M.49, IANA Language Subtag Registry.
//
// This type is the typed primitive for language identification across
// the Atelier Socle streaming ecosystem: ISOBMFF `mdhd` boxes, HLS
// `EXT-X-MEDIA LANGUAGE`, DASH MPD `@lang`, subtitle / accessibility
// track selection.

import Foundation

/// IETF BCP 47 / RFC 5646 language tag, fully typed and round-trip safe.
///
/// A BCP 47 tag identifies a language with hierarchical subtags:
/// primary language, extended language, script, region, variants,
/// extensions, private-use. Examples:
/// - `en` — English (primary only)
/// - `en-US` — English as used in the United States
/// - `zh-Hant-TW` — Chinese in Traditional Han, as used in Taiwan
/// - `pt-BR` — Portuguese as used in Brazil
/// - `de-CH-1996` — German, Switzerland, traditional orthography
/// - `zh-yue` — Cantonese (primary + extended-language)
/// - `i-default` — grandfathered IANA default
/// - `qaa-Latn-DE` — private-use primary in Latin script in Germany
///
/// References:
/// - IETF RFC 5646 — Tags for Identifying Languages (BCP 47)
/// - IETF RFC 4647 — Matching of Language Tags
/// - ISO 639-1 / -2 / -3 — Language codes
/// - ISO 15924 — Script codes
/// - ISO 3166-1 — Country / region codes (alpha-2)
/// - UN M.49 — Numeric region codes
/// - IANA Language Subtag Registry (snapshot 2026-05)
public struct BCP47LanguageTag: Sendable, Equatable, Hashable, Codable,
    CustomStringConvertible
{

    /// Primary language subtag (mandatory per RFC 5646 §2.1).
    public let primaryLanguage: PrimarySubtag

    /// Extended language subtag per RFC 5646 §2.2.2 (e.g., `yue` in `zh-yue`).
    public let extendedLanguage: String?

    /// Script subtag per RFC 5646 §2.2.3 (e.g., `Hant`).
    public let script: ISO15924Script?

    /// Region subtag per RFC 5646 §2.2.4.
    public let region: Region?

    /// Variant subtags per RFC 5646 §2.2.5 (e.g., `1996` in `de-CH-1996`).
    public let variants: [String]

    /// Extension subtags per RFC 5646 §2.2.6.
    public let extensions: [BCP47Extension]

    /// Private-use subtags per RFC 5646 §2.2.7 (after the `x-` prefix).
    public let privateUse: [String]

    /// Canonical RFC 5646 §4.5 string form: primary subtag lowercase,
    /// script title-case, region uppercase, all other subtags lowercase.
    public var canonicalForm: String {
        // Grandfathered: the primary subtag holds the full original tag
        // (lowercased) and the other fields are empty. Return as-is.
        if case .grandfathered(let value) = primaryLanguage,
            extendedLanguage == nil, script == nil, region == nil,
            variants.isEmpty, extensions.isEmpty, privateUse.isEmpty
        {
            return value.lowercased()
        }
        // Private-use primary entirely (e.g., `x-private-foo`).
        if case .privateUse(let value) = primaryLanguage,
            value.lowercased().hasPrefix("x-"), extendedLanguage == nil,
            script == nil, region == nil, variants.isEmpty,
            extensions.isEmpty, privateUse.isEmpty
        {
            return value.lowercased()
        }
        var parts: [String] = [primaryLanguage.raw]
        if let ext = extendedLanguage {
            parts.append(ext.lowercased())
        }
        if let scr = script {
            parts.append(scr.code)
        }
        if let reg = region {
            parts.append(reg.canonicalForm)
        }
        parts.append(contentsOf: variants.map { $0.lowercased() })
        for ext in extensions {
            parts.append(String(ext.singleton).lowercased())
            parts.append(contentsOf: ext.subtags.map { $0.lowercased() })
        }
        if !privateUse.isEmpty {
            parts.append("x")
            parts.append(contentsOf: privateUse.map { $0.lowercased() })
        }
        return parts.joined(separator: "-")
    }

    public var description: String { canonicalForm }

    /// Designated initializer — does not perform registry validation
    /// (the caller asserts validity).
    public init(
        primaryLanguage: PrimarySubtag,
        extendedLanguage: String? = nil,
        script: ISO15924Script? = nil,
        region: Region? = nil,
        variants: [String] = [],
        extensions: [BCP47Extension] = [],
        privateUse: [String] = []
    ) {
        self.primaryLanguage = primaryLanguage
        self.extendedLanguage = extendedLanguage
        self.script = script
        self.region = region
        self.variants = variants
        self.extensions = extensions
        self.privateUse = privateUse
    }
}

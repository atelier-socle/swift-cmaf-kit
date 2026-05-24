// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BCP47Extension
//
// Reference: IETF RFC 5646 §2.2.6 (Extension Subtags).
//
// A BCP 47 extension subtag is composed of a singleton character (a
// single ASCII letter `a..z`, distinct from `x` which marks private
// use) followed by one or more sub-subtags, each 2..8 alphanumeric
// characters. Example: `de-DE-u-co-phonebk` has extension `u` (Unicode
// extension) with sub-subtag `co-phonebk` (collation: phonebook order).

import Foundation

/// BCP 47 extension subtag per RFC 5646 §2.2.6 — a singleton letter
/// followed by one or more sub-subtags.
///
/// Example: in `de-DE-u-co-phonebk`, the extension is
/// `BCP47Extension(singleton: "u", subtags: ["co", "phonebk"])`. The
/// singleton `u` identifies the Unicode (CLDR) extension; the sub-subtags
/// carry collation, calendar, currency, or other locale options
/// (registered with IANA under the BCP 47 Extension U Registry).
///
/// References:
/// - IETF RFC 5646 §2.2.6 — Extension Subtags
/// - IETF RFC 6067 — BCP 47 Extension U (Unicode Locale Extension)
/// - IETF RFC 6497 — BCP 47 Extension T (Transformed Content)
public struct BCP47Extension: Sendable, Equatable, Hashable, Codable {

    /// The singleton character identifying the extension (e.g., `u` for
    /// Unicode CLDR, `t` for transformed content). Must be a single
    /// ASCII letter `a..z` other than `x` (private use); RFC 5646
    /// §2.2.6 reserves `x` for private-use subtags.
    public let singleton: Character

    /// Sub-subtags following the singleton. Each is 2..8 alphanumeric
    /// characters per RFC 5646 §2.2.6.
    public let subtags: [String]

    public init(singleton: Character, subtags: [String]) {
        self.singleton = singleton
        self.subtags = subtags
    }

    // Manual Codable: Character is not Codable out of the box.
    private enum CodingKeys: String, CodingKey {
        case singleton
        case subtags
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let singletonString = try container.decode(String.self, forKey: .singleton)
        guard singletonString.count == 1, let char = singletonString.first else {
            throw DecodingError.dataCorruptedError(
                forKey: .singleton,
                in: container,
                debugDescription: "BCP47Extension singleton must be exactly one character"
            )
        }
        self.singleton = char
        self.subtags = try container.decode([String].self, forKey: .subtags)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(singleton), forKey: .singleton)
        try container.encode(subtags, forKey: .subtags)
    }
}

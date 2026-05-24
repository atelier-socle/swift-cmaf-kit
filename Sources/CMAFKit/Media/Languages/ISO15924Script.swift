// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ISO15924Script
//
// Reference: ISO 15924 (Codes for the representation of names of
// scripts) + IETF RFC 5646 §2.2.3 (Script Subtag).
//
// 4-character title-case code identifying a writing system. Examples:
// `Latn` (Latin), `Hans` (Han Simplified), `Hant` (Han Traditional),
// `Cyrl` (Cyrillic), `Arab` (Arabic), `Hebr` (Hebrew), `Grek` (Greek),
// `Jpan` (Japanese alias for Han + Hiragana + Katakana).

import Foundation

/// ISO 15924 script code — a 4-character title-case code identifying a
/// writing system.
///
/// References:
/// - ISO 15924 — Codes for the representation of names of scripts
/// - IETF RFC 5646 §2.2.3 — Script Subtag (cites ISO 15924)
public struct ISO15924Script: Sendable, Equatable, Hashable, Codable,
    CustomStringConvertible
{

    /// The validated 4-character title-case code (e.g., `"Latn"`).
    public let code: String

    public var description: String { code }

    /// Parse and validate a 4-character ISO 15924 code.
    ///
    /// - Throws: ``BCP47Error/unknownScript(_:)`` when the input is not
    ///   exactly 4 ASCII letters, or when title-case canonicalisation
    ///   yields a code that is not in the embedded IANA snapshot.
    public init(_ code: String) throws {
        guard code.count == 4, code.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            throw BCP47Error.unknownScript(code)
        }
        // Title-case canonicalisation per RFC 5646 §2.2.3: first letter
        // uppercase, rest lowercase.
        let titleCased = Self.titleCased(code)
        guard IANALanguageSubtagRegistry.isKnownISO15924(titleCased) else {
            throw BCP47Error.unknownScript(code)
        }
        self.code = titleCased
    }

    /// Title-case canonicalisation: first letter uppercase, rest lowercase.
    private static func titleCased(_ code: String) -> String {
        guard let first = code.first else { return code }
        return first.uppercased() + code.dropFirst().lowercased()
    }
}

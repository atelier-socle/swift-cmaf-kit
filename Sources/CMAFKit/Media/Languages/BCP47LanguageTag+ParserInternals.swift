// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BCP47LanguageTag — parser internals
//
// Subtag-shape classifiers and the primary-subtag dispatcher used by
// the RFC 5646 §2.1 parser.

import Foundation

extension BCP47LanguageTag {

    internal enum SubtagShapeMode {
        case privateUseWhole
        case privateUseSubtag
    }

    internal static func validateHyphenBoundaries(
        input: String, lowered: String
    ) throws {
        guard !lowered.hasPrefix("-"), !lowered.hasSuffix("-") else {
            throw BCP47Error.malformedTag(
                input: input,
                reason: "tag must not begin or end with a hyphen")
        }
        guard !lowered.contains("--") else {
            throw BCP47Error.malformedTag(
                input: input, reason: "consecutive hyphens are not allowed")
        }
    }

    internal static func validateSubtagShape(
        _ subtag: String, mode: SubtagShapeMode, original: String
    ) throws {
        switch mode {
        case .privateUseWhole:
            // Whole tag starting with `x-`. Each downstream subtag must
            // be 1..8 alphanumeric per RFC 5646 §2.2.7.
            let parts = subtag.split(separator: "-").map(String.init)
            guard parts.count >= 2, parts[0] == "x" else {
                throw BCP47Error.malformedTag(
                    input: original,
                    reason: "private-use tag must start with `x-`")
            }
            for piece in parts.dropFirst() {
                try validateSubtagShape(
                    piece, mode: .privateUseSubtag, original: original)
            }
        case .privateUseSubtag:
            guard (1...8).contains(subtag.count),
                subtag.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) })
            else {
                throw BCP47Error.malformedTag(
                    input: original,
                    reason:
                        "private-use subtag '\(subtag)' must be 1..8 alphanumeric")
            }
        }
    }

    internal static func parsePrimaryLanguage(
        subtags: [String], cursor: inout Int, original: String
    ) throws -> PrimarySubtag {
        // `validateHyphenBoundaries` guarantees a non-empty `lower`
        // without leading/trailing hyphens, so `split(separator:)`
        // returns at least one subtag — cursor < subtags.count always
        // holds at the call site.
        let first = subtags[cursor]
        cursor += 1
        switch first.count {
        case 2:
            guard IANALanguageSubtagRegistry.isWellFormedISO639_1(first) else {
                throw BCP47Error.malformedTag(
                    input: original,
                    reason: "primary 2-char subtag '\(first)' must be ASCII letters")
            }
            // Private-use ISO 639 range `qa..qt` followed by `a..z` is
            // not a 2-letter situation (those are 3-letter codes
            // `qaa..qtz`). 2-letter passes through as ISO 639-1.
            return .iso639_1(first)
        case 3:
            guard IANALanguageSubtagRegistry.isWellFormedISO639_3(first) else {
                throw BCP47Error.malformedTag(
                    input: original,
                    reason: "primary 3-char subtag '\(first)' must be ASCII letters")
            }
            // ISO 639 private-use range qaa..qtz per RFC 5646 §2.2.1.
            if isPrivateUsePrimary3Letter(first) {
                return .privateUse(first)
            }
            return .iso639_3(first)
        case 4:
            // RFC 5646 §2.2.1 reserves 4-letter primary subtags for
            // future use; reject as malformed in the current registry
            // generation.
            throw BCP47Error.malformedTag(
                input: original,
                reason:
                    "primary 4-char subtags are reserved for future use (RFC 5646 §2.2.1)")
        case 5...8:
            // RFC 5646 §2.2.1 allows 5..8-letter registered language
            // subtags; permissive mode accepts them as ISO 639-3-ish.
            guard first.allSatisfy({ $0.isASCII && $0.isLetter }) else {
                throw BCP47Error.malformedTag(
                    input: original,
                    reason:
                        "primary 5..8-char subtag '\(first)' must be ASCII letters")
            }
            return .iso639_3(first)
        default:
            throw BCP47Error.malformedTag(
                input: original,
                reason:
                    "primary subtag '\(first)' length \(first.count) outside 2..8")
        }
    }

    /// True if `code` falls in the ISO 639 private-use range
    /// `qaa..qtz` reserved by RFC 5646 §2.2.1.
    private static func isPrivateUsePrimary3Letter(_ code: String) -> Bool {
        guard code.count == 3 else { return false }
        let scalars = Array(code.unicodeScalars)
        guard scalars[0].value == 0x71 else { return false }  // 'q'
        let second = scalars[1].value
        guard (0x61...0x74).contains(second) else { return false }  // a..t
        let third = scalars[2].value
        return (0x61...0x7A).contains(third)  // a..z
    }

    internal static func isExtendedLanguageCandidate(_ subtag: String) -> Bool {
        subtag.count == 3
            && subtag.allSatisfy({ $0.isASCII && $0.isLetter })
            && IANALanguageSubtagRegistry.isKnownExtendedLanguage(subtag)
    }

    internal static func isScriptCandidate(_ subtag: String) -> Bool {
        IANALanguageSubtagRegistry.isWellFormedISO15924(subtag)
    }

    internal static func tryParseRegion(_ subtag: String) -> Region? {
        if IANALanguageSubtagRegistry.isWellFormedISO3166_1(subtag) {
            return .iso3166_1(subtag.uppercased())
        }
        if IANALanguageSubtagRegistry.isWellFormedUNM49(subtag),
            let numeric = UInt16(subtag)
        {
            return .unM49(numeric)
        }
        return nil
    }

    internal static func isVariantCandidate(_ subtag: String) -> Bool {
        // RFC 5646 §2.2.5: variant subtags are 5..8 alphanumeric, OR
        // 4 characters starting with a digit followed by 3 alphanumeric.
        switch subtag.count {
        case 5...8:
            return subtag.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        case 4:
            let scalars = Array(subtag.unicodeScalars)
            guard let first = scalars.first,
                CharacterSet.decimalDigits.contains(first)
            else { return false }
            return scalars.dropFirst().allSatisfy {
                CharacterSet.alphanumerics.contains($0)
            }
        default:
            return false
        }
    }

    internal static func isExtensionSingleton(_ subtag: String) -> Bool {
        guard subtag.count == 1, let char = subtag.first else { return false }
        return char.isASCII && char.isLetter && char != "x"
    }

    internal static func isExtensionSubSubtag(_ subtag: String) -> Bool {
        (2...8).contains(subtag.count)
            && subtag.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }
}

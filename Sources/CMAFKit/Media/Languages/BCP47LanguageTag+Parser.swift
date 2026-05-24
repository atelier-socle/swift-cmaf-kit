// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BCP47LanguageTag — RFC 5646 §2.1 ABNF parser
//
// Permissive parser: validates RFC 5646 §2.1 ABNF syntax, recognises
// grandfathered tags as a whole, and accepts any well-formed subtag
// for unknown values. Strict-mode registry validation is reserved for
// a future opt-in.

import Foundation

extension BCP47LanguageTag {

    /// Parse a string into a `BCP47LanguageTag`. The parser:
    /// 1. Lowercases the input (BCP 47 is case-insensitive on input).
    /// 2. Matches grandfathered tags as a whole per RFC 5646 §2.2.8.
    /// 3. Walks the `-`-separated subtags applying the RFC 5646 §2.1
    ///    ABNF state machine.
    ///
    /// - Parameter tag: the BCP 47 string (case-insensitive on input,
    ///   canonicalised on output).
    /// - Throws:
    ///   - ``BCP47Error/malformedTag(input:reason:)`` on ABNF violation.
    ///   - ``BCP47Error/unknownScript(_:)`` when a 4-letter subtag in
    ///     script position is not in the IANA snapshot.
    public init(_ tag: String) throws {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BCP47Error.malformedTag(input: tag, reason: "empty input")
        }
        let lower = trimmed.lowercased()

        // Grandfathered short-circuit (RFC 5646 §2.2.8).
        if IANALanguageSubtagRegistry.isGrandfathered(lower) {
            self.init(primaryLanguage: .grandfathered(lower))
            return
        }

        // Whole-tag private-use (RFC 5646 §2.2.7) — entire tag starts
        // with `x-`.
        if lower.hasPrefix("x-") {
            try Self.validateSubtagShape(
                lower, mode: .privateUseWhole, original: tag)
            self.init(primaryLanguage: .privateUse(lower))
            return
        }

        try Self.validateHyphenBoundaries(input: tag, lowered: lower)
        let subtags = lower.split(separator: "-").map(String.init)

        var cursor = 0
        let primary = try Self.parsePrimaryLanguage(
            subtags: subtags, cursor: &cursor, original: tag)

        var extendedLanguage: String?
        var script: ISO15924Script?
        var region: Region?
        var variants: [String] = []
        var extensions: [BCP47Extension] = []
        var privateUse: [String] = []

        // Extended language (RFC 5646 §2.2.2) — only after a 2/3-letter
        // primary, never after grandfathered/privateUse.
        if cursor < subtags.count, Self.isExtendedLanguageCandidate(subtags[cursor]) {
            extendedLanguage = subtags[cursor]
            cursor += 1
        }

        // Script (RFC 5646 §2.2.3) — exactly 4 letters.
        if cursor < subtags.count, Self.isScriptCandidate(subtags[cursor]) {
            script = try ISO15924Script(subtags[cursor])
            cursor += 1
        }

        // Region (RFC 5646 §2.2.4) — 2 letters (ISO 3166-1 alpha-2) or
        // 3 digits (UN M.49).
        if cursor < subtags.count {
            if let parsedRegion = Self.tryParseRegion(subtags[cursor]) {
                region = parsedRegion
                cursor += 1
            }
        }

        // Variants (RFC 5646 §2.2.5).
        while cursor < subtags.count, Self.isVariantCandidate(subtags[cursor]) {
            variants.append(subtags[cursor])
            cursor += 1
        }

        // Extensions and trailing private-use (RFC 5646 §2.2.6 / §2.2.7).
        while cursor < subtags.count {
            let candidate = subtags[cursor]
            if candidate == "x" {
                cursor += 1
                let remaining = subtags[cursor...]
                guard !remaining.isEmpty else {
                    throw BCP47Error.malformedTag(
                        input: tag,
                        reason: "private-use prefix `x-` requires at least one subtag")
                }
                for sub in remaining {
                    try Self.validateSubtagShape(
                        sub, mode: .privateUseSubtag, original: tag)
                }
                privateUse = Array(remaining)
                cursor = subtags.count
                break
            }
            guard Self.isExtensionSingleton(candidate),
                let singleton = candidate.first
            else {
                throw BCP47Error.malformedTag(
                    input: tag,
                    reason: "unexpected subtag '\(candidate)' at position \(cursor)")
            }
            cursor += 1
            var collected: [String] = []
            while cursor < subtags.count,
                !Self.isExtensionSingleton(subtags[cursor]),
                subtags[cursor] != "x"
            {
                let sub = subtags[cursor]
                guard Self.isExtensionSubSubtag(sub) else {
                    throw BCP47Error.malformedTag(
                        input: tag,
                        reason:
                            "extension sub-subtag '\(sub)' must be 2..8 alphanumeric")
                }
                collected.append(sub)
                cursor += 1
            }
            guard !collected.isEmpty else {
                throw BCP47Error.malformedTag(
                    input: tag,
                    reason:
                        "extension singleton '\(singleton)' requires at least one sub-subtag")
            }
            extensions.append(
                BCP47Extension(singleton: singleton, subtags: collected))
        }

        self.init(
            primaryLanguage: primary,
            extendedLanguage: extendedLanguage,
            script: script,
            region: region,
            variants: variants,
            extensions: extensions,
            privateUse: privateUse)
    }
}

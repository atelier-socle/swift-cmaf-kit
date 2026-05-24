// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BCP47LanguageTag — RFC 4647 matching
//
// Reference: IETF RFC 4647 (Matching of Language Tags, September 2006).
// Implements the three matching schemes used by HLS / DASH players to
// resolve user language preferences against available rendition tags.

import Foundation

extension BCP47LanguageTag {

    /// RFC 4647 language tag matching scheme.
    public enum MatchingScheme: Sendable, Equatable, Hashable {

        /// Basic filtering per RFC 4647 §3.3.1 — the language range
        /// matches the tag iff the tag is identical to OR begins with
        /// the range followed by a `-`.
        case basic

        /// Extended filtering per RFC 4647 §3.3.2 — extends basic
        /// filtering: the range's subtags must appear in the tag in
        /// order, but intervening subtags are allowed. Subtag `*`
        /// matches any single subtag.
        case extended

        /// Lookup per RFC 4647 §3.4 — produces a single best match by
        /// progressively dropping subtags from the end of the range
        /// until a match is found.
        case lookup
    }

    /// Match this language tag against a language range per RFC 4647.
    ///
    /// - Parameters:
    ///   - languageRange: a RFC 4647 §2 language range; may be `*`
    ///     (wildcard) per §2.2, or contain `*` subtags under the
    ///     extended scheme.
    ///   - scheme: matching scheme (default `.lookup`).
    /// - Returns: `true` if the tag matches the range under the scheme.
    ///
    /// Reference: IETF RFC 4647 §3.
    public func matches(
        _ languageRange: String, scheme: MatchingScheme = .lookup
    ) -> Bool {
        let trimmed = languageRange.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed == "*" { return true }

        let lowerRange = trimmed.lowercased()
        let lowerTag = canonicalForm.lowercased()
        let rangeSubtags = lowerRange.split(separator: "-").map(String.init)
        let tagSubtags = lowerTag.split(separator: "-").map(String.init)

        switch scheme {
        case .basic:
            return Self.basicMatch(range: rangeSubtags, tag: tagSubtags)
        case .extended:
            return Self.extendedMatch(range: rangeSubtags, tag: tagSubtags)
        case .lookup:
            return Self.lookupMatch(range: rangeSubtags, tag: tagSubtags)
        }
    }

    // MARK: - Implementations

    /// RFC 4647 §3.3.1 — range matches tag iff tag begins with range
    /// (subtag-aligned).
    private static func basicMatch(
        range: [String], tag: [String]
    ) -> Bool {
        guard range.count <= tag.count else { return false }
        for index in 0..<range.count
        where !subtagEquals(range[index], tag[index]) {
            return false
        }
        return true
    }

    /// RFC 4647 §3.3.2 — extended filtering.
    ///
    /// Algorithm follows the spec's numbered rules (steps 2 and 4):
    /// - The first subtag of the range must match the first subtag of
    ///   the tag (rule 2; wildcard `*` matches anything).
    /// - For each remaining range subtag: rule 4A advances the range
    ///   only on `*`; rule 4B fails if the tag is exhausted; rule 4C
    ///   advances both lists on a subtag match; rule 4D fails if the
    ///   tag subtag is a singleton (length 1); rule 4E otherwise
    ///   advances the tag only.
    private static func extendedMatch(
        range: [String], tag: [String]
    ) -> Bool {
        guard !range.isEmpty, !tag.isEmpty else { return false }
        guard subtagEquals(range[0], tag[0]) else { return false }
        var rangeIdx = 1
        var tagIdx = 1
        while rangeIdx < range.count {
            let rangeSub = range[rangeIdx]
            if rangeSub == "*" {  // rule 4A
                rangeIdx += 1
                continue
            }
            if tagIdx >= tag.count {  // rule 4B
                return false
            }
            if subtagEquals(rangeSub, tag[tagIdx]) {  // rule 4C
                rangeIdx += 1
                tagIdx += 1
                continue
            }
            if tag[tagIdx].count == 1 {  // rule 4D
                return false
            }
            tagIdx += 1  // rule 4E
        }
        return true
    }

    /// RFC 4647 §3.4 — progressively drop trailing range subtags
    /// until a basic match succeeds.
    private static func lookupMatch(
        range: [String], tag: [String]
    ) -> Bool {
        var working = range
        while !working.isEmpty {
            // §3.4: never end on a singleton (single-character subtag).
            while let last = working.last, last.count == 1 {
                working.removeLast()
            }
            if working.isEmpty { return false }
            if basicMatch(range: working, tag: tag) { return true }
            working.removeLast()
        }
        return false
    }

    private static func subtagEquals(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == "*" || rhs == "*" { return true }
        return lhs == rhs
    }
}

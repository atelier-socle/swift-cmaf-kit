// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// RFC 4647 matching schemes — basic / extended / lookup. Examples
// taken from RFC 4647 §3.

import Foundation
import Testing

@testable import CMAFKit

@Suite("BCP47LanguageTag — RFC 4647 §3.3.1 basic filtering")
struct BCP47LanguageTagBasicMatchingTests {

    @Test func basicMatchExact() throws {
        let tag = try BCP47LanguageTag("en")
        #expect(tag.matches("en", scheme: .basic))
    }

    @Test func basicMatchPrefix() throws {
        let tag = try BCP47LanguageTag("en-US")
        #expect(tag.matches("en", scheme: .basic))
    }

    @Test func basicNoMatchSuperstringRange() throws {
        let tag = try BCP47LanguageTag("en")
        #expect(!tag.matches("en-US", scheme: .basic))
    }

    @Test func basicWildcardMatchesAnything() throws {
        let tag = try BCP47LanguageTag("zh-Hant-TW")
        #expect(tag.matches("*", scheme: .basic))
    }

    @Test func basicMatchCaseInsensitive() throws {
        let tag = try BCP47LanguageTag("en-US")
        #expect(tag.matches("EN-us", scheme: .basic))
    }

    @Test func basicNoMatchDifferentPrimary() throws {
        let tag = try BCP47LanguageTag("fr-CA")
        #expect(!tag.matches("en", scheme: .basic))
    }

    @Test func basicMatchEmptyRangeFails() throws {
        let tag = try BCP47LanguageTag("en")
        #expect(!tag.matches("", scheme: .basic))
    }
}

@Suite("BCP47LanguageTag — RFC 4647 §3.3.2 extended filtering")
struct BCP47LanguageTagExtendedMatchingTests {

    @Test func extendedMatchesWithInterveningSubtag() throws {
        // RFC 4647 §3.3.2 example: range "zh-Hant" matches
        // "zh-cmn-Hant" because cmn is an extended-language subtag.
        let tag = try BCP47LanguageTag("zh-cmn-Hant")
        #expect(tag.matches("zh-Hant", scheme: .extended))
    }

    @Test func extendedExactMatchStillSucceeds() throws {
        let tag = try BCP47LanguageTag("zh-Hant")
        #expect(tag.matches("zh-Hant", scheme: .extended))
    }

    @Test func extendedSubtagWildcardMatchesSubtree() throws {
        let tag = try BCP47LanguageTag("en-US")
        #expect(tag.matches("en-*", scheme: .extended))
    }

    @Test func extendedSubtagWildcardSkipsOver() throws {
        let tag = try BCP47LanguageTag("en-US")
        #expect(tag.matches("en-*-US", scheme: .extended))
    }

    @Test func extendedNoMatchDifferentPrimary() throws {
        let tag = try BCP47LanguageTag("en-US")
        #expect(!tag.matches("fr-FR", scheme: .extended))
    }

    @Test func extendedRangeLongerThanTagFails() throws {
        let tag = try BCP47LanguageTag("en")
        #expect(!tag.matches("en-US-NY", scheme: .extended))
    }
}

@Suite("BCP47LanguageTag — RFC 4647 §3.4 lookup")
struct BCP47LanguageTagLookupMatchingTests {

    @Test func lookupExactMatch() throws {
        let tag = try BCP47LanguageTag("en")
        #expect(tag.matches("en", scheme: .lookup))
    }

    @Test func lookupDropsTrailingSubtagsToMatchShorterTag() throws {
        // RFC 4647 §3.4 — range "en-US-x-twain" looked up against
        // tag "en" matches because the range progressively shortens.
        let tag = try BCP47LanguageTag("en")
        #expect(tag.matches("en-US-x-twain", scheme: .lookup))
    }

    @Test func lookupHonoursPrefixMatchOfTag() throws {
        let tag = try BCP47LanguageTag("pt-BR-1990")
        #expect(tag.matches("pt-BR", scheme: .lookup))
    }

    @Test func lookupNoMatchBelowPrimary() throws {
        let tag = try BCP47LanguageTag("fr-FR")
        #expect(!tag.matches("en", scheme: .lookup))
    }

    @Test func lookupDoesNotEndOnSingletonSubtag() throws {
        // RFC 4647 §3.4 — never end on a singleton; the singleton +
        // its singleton-subtags pair must be dropped together.
        let tag = try BCP47LanguageTag("de")
        #expect(tag.matches("de-u-co-phonebk", scheme: .lookup))
    }

    @Test func lookupAllSubtagsDroppedReturnsFalse() throws {
        let tag = try BCP47LanguageTag("fr")
        #expect(!tag.matches("en-US", scheme: .lookup))
    }

    @Test func lookupWildcardMatchesAnything() throws {
        let tag = try BCP47LanguageTag("zh-Hant-TW")
        #expect(tag.matches("*", scheme: .lookup))
    }

    @Test func lookupWhitespaceRangeFails() throws {
        let tag = try BCP47LanguageTag("en")
        #expect(!tag.matches("   ", scheme: .lookup))
    }
}

@Suite("BCP47LanguageTag — matching defaults")
struct BCP47LanguageTagMatchingDefaultsTests {

    @Test func defaultSchemeIsLookup() throws {
        let tag = try BCP47LanguageTag("en")
        #expect(tag.matches("en-US-x-twain"))
    }
}

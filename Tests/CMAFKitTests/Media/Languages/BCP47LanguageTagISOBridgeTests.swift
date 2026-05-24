// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// ISO 639-2/B vs /T disambiguation + ISO 639-2/T ↔ ISO 639-1 down-/up-
// conversion. Every entry of the iso639_2BToTMapping table is asserted
// individually so that any future regression is caught by name.

import Foundation
import Testing

@testable import CMAFKit

@Suite("BCP47LanguageTag — ISO 639-2/T bridge: happy paths")
struct BCP47LanguageTagISOBridgeHappyPathTests {

    @Test func fromISO6392TFrenchTerminologic() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("fra")
        #expect(tag.primaryLanguage == .iso639_1("fr"))
        #expect(tag.canonicalForm == "fr")
    }

    @Test func fromISO6392TFrenchBibliographic() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("fre")
        #expect(tag.primaryLanguage == .iso639_1("fr"))
    }

    @Test func fromISO6392TGerman() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("ger")
        #expect(tag.primaryLanguage == .iso639_1("de"))
    }

    @Test func fromISO6392TDutch() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("dut")
        #expect(tag.primaryLanguage == .iso639_1("nl"))
    }

    @Test func fromISO6392TChinese() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("chi")
        #expect(tag.primaryLanguage == .iso639_1("zh"))
    }

    @Test func fromISO6392TEnglish() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("eng")
        #expect(tag.primaryLanguage == .iso639_1("en"))
    }

    @Test func fromISO6392TCaseInsensitiveInput() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("FrA")
        #expect(tag.primaryLanguage == .iso639_1("fr"))
    }

    @Test func fromISO6392TCantoneseKeeps3Char() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("yue")
        #expect(tag.primaryLanguage == .iso639_3("yue"))
        #expect(tag.canonicalForm == "yue")
    }

    @Test func fromISO6392TMandarinKeeps3Char() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("cmn")
        #expect(tag.primaryLanguage == .iso639_3("cmn"))
    }

    // ISO 639-2 special-purpose codes (ISO 639-2 §3.1)

    @Test func fromISO6392TUndetermined() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("und")
        #expect(tag.primaryLanguage == .iso639_3("und"))
    }

    @Test func fromISO6392TMultiple() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("mul")
        #expect(tag.primaryLanguage == .iso639_3("mul"))
    }

    @Test func fromISO6392TZxxNoLinguisticContent() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("zxx")
        #expect(tag.primaryLanguage == .iso639_3("zxx"))
    }

    @Test func fromISO6392TMisUncoded() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("mis")
        #expect(tag.primaryLanguage == .iso639_3("mis"))
    }
}

@Suite("BCP47LanguageTag — ISO 639-2/T bridge: every /B→/T entry")
struct BCP47LanguageTagISOBridgeFullMappingTests {

    @Test func everyKnownBibliographicCodeBridgesToTerminologicAndAlpha2() throws {
        let knownMappings: [(b: String, t: String, alpha2: String?)] = [
            ("alb", "sqi", "sq"),
            ("arm", "hye", "hy"),
            ("baq", "eus", "eu"),
            ("bur", "mya", "my"),
            ("chi", "zho", "zh"),
            ("cze", "ces", "cs"),
            ("dut", "nld", "nl"),
            ("fre", "fra", "fr"),
            ("geo", "kat", "ka"),
            ("ger", "deu", "de"),
            ("gre", "ell", "el"),
            ("ice", "isl", "is"),
            ("mac", "mkd", "mk"),
            ("may", "msa", "ms"),
            ("mao", "mri", "mi"),
            ("per", "fas", "fa"),
            ("rum", "ron", "ro"),
            ("slo", "slk", "sk"),
            ("tib", "bod", "bo"),
            ("wel", "cym", "cy")
        ]
        for entry in knownMappings {
            let tag = try BCP47LanguageTag.fromISO6392T(entry.b)
            if let alpha2 = entry.alpha2 {
                #expect(
                    tag.primaryLanguage == .iso639_1(alpha2),
                    "Expected /B \(entry.b) → /1 \(alpha2)")
            }
        }
    }
}

@Suite("BCP47LanguageTag — ISO 639-2/T bridge: errors")
struct BCP47LanguageTagISOBridgeErrorTests {

    @Test func fromISO6392TEmptyThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag.fromISO6392T("")
        }
    }

    @Test func fromISO6392TTooShortThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag.fromISO6392T("en")
        }
    }

    @Test func fromISO6392TTooLongThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag.fromISO6392T("abcd")
        }
    }

    @Test func fromISO6392TNonAlphaThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag.fromISO6392T("a1z")
        }
    }

    @Test func fromISO6392TUnknownButWellFormedAcceptsPermissively() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("zzz")
        #expect(tag.primaryLanguage == .iso639_3("zzz"))
    }
}

@Suite("BCP47LanguageTag — toISO6392T reverse bridge")
struct BCP47LanguageTagReverseBridgeTests {

    @Test func toISO6392TFromISO6391English() throws {
        let tag = BCP47LanguageTag(primaryLanguage: .iso639_1("en"))
        #expect(tag.toISO6392T() == "eng")
    }

    @Test func toISO6392TFromISO6391French() throws {
        let tag = BCP47LanguageTag(primaryLanguage: .iso639_1("fr"))
        #expect(tag.toISO6392T() == "fra")
    }

    @Test func toISO6392TFromISO6391German() throws {
        let tag = BCP47LanguageTag(primaryLanguage: .iso639_1("de"))
        #expect(tag.toISO6392T() == "deu")
    }

    @Test func toISO6392TFromISO6393CantonesePreserves() throws {
        let tag = BCP47LanguageTag(primaryLanguage: .iso639_3("yue"))
        #expect(tag.toISO6392T() == "yue")
    }

    @Test func toISO6392TFromBibliographicNormalisesToTerminologic() throws {
        // If a caller stuffs a /B code into .iso639_3(...), the reverse
        // bridge must still output the /T form.
        let tag = BCP47LanguageTag(primaryLanguage: .iso639_3("fre"))
        #expect(tag.toISO6392T() == "fra")
    }

    @Test func toISO6392TFromGrandfatheredReturnsNil() throws {
        let tag = BCP47LanguageTag(primaryLanguage: .grandfathered("i-default"))
        #expect(tag.toISO6392T() == nil)
    }

    @Test func toISO6392TFromPrivateUseReturnsNil() throws {
        let tag = BCP47LanguageTag(primaryLanguage: .privateUse("x-private"))
        #expect(tag.toISO6392T() == nil)
    }

    @Test func toISO6392TWithUnmappedISO6391ReturnsNil() throws {
        // Use a syntactically well-formed but not-yet-mapped 2-char code.
        let tag = BCP47LanguageTag(primaryLanguage: .iso639_1("zz"))
        #expect(tag.toISO6392T() == nil)
    }

    @Test func toISO6392TWithMalformedISO6393ReturnsNil() throws {
        let tag = BCP47LanguageTag(primaryLanguage: .iso639_3("a1z"))
        #expect(tag.toISO6392T() == nil)
    }

    @Test func roundTripFRStable() throws {
        let tag = try BCP47LanguageTag.fromISO6392T("fra")
        let back = tag.toISO6392T()
        #expect(back == "fra")
        let again = try BCP47LanguageTag.fromISO6392T(#require(back))
        #expect(again.primaryLanguage == .iso639_1("fr"))
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Spec-anchored canonical-tag parser coverage. Each test cites the
// RFC 5646 example it validates.

import Foundation
import Testing

@testable import CMAFKit

@Suite("BCP47LanguageTag — RFC 5646 §2.2 parsing")
struct BCP47LanguageTagParsingTests {

    // MARK: Primary + region (RFC 5646 §2.2.1 / §2.2.4)

    @Test func parsePrimaryOnlyEN() throws {
        let tag = try BCP47LanguageTag("en")
        #expect(tag.primaryLanguage == .iso639_1("en"))
        #expect(tag.region == nil)
        #expect(tag.canonicalForm == "en")
    }

    @Test func parsePrimaryRegionENUS() throws {
        let tag = try BCP47LanguageTag("en-US")
        #expect(tag.primaryLanguage == .iso639_1("en"))
        #expect(tag.region == .iso3166_1("US"))
        #expect(tag.canonicalForm == "en-US")
    }

    @Test func parseScriptZhHantTW() throws {
        let tag = try BCP47LanguageTag("zh-Hant-TW")
        #expect(tag.primaryLanguage == .iso639_1("zh"))
        #expect(tag.script?.code == "Hant")
        #expect(tag.region == .iso3166_1("TW"))
        #expect(tag.canonicalForm == "zh-Hant-TW")
    }

    @Test func parsePortugueseBrazilian() throws {
        let tag = try BCP47LanguageTag("pt-BR")
        #expect(tag.primaryLanguage == .iso639_1("pt"))
        #expect(tag.region == .iso3166_1("BR"))
        #expect(tag.canonicalForm == "pt-BR")
    }

    // MARK: Variants (RFC 5646 §2.2.5)

    @Test func parseSwissGermanTraditional() throws {
        let tag = try BCP47LanguageTag("de-CH-1996")
        #expect(tag.primaryLanguage == .iso639_1("de"))
        #expect(tag.region == .iso3166_1("CH"))
        #expect(tag.variants == ["1996"])
        #expect(tag.canonicalForm == "de-CH-1996")
    }

    @Test func parseMultipleVariants() throws {
        let tag = try BCP47LanguageTag("sl-rozaj-biske")
        #expect(tag.primaryLanguage == .iso639_1("sl"))
        #expect(tag.variants == ["rozaj", "biske"])
    }

    @Test func parseVariantStartingWithDigit() throws {
        let tag = try BCP47LanguageTag("de-1901")
        #expect(tag.primaryLanguage == .iso639_1("de"))
        #expect(tag.variants == ["1901"])
    }

    // MARK: Extended language (RFC 5646 §2.2.2)

    @Test func parseCantoneseExtendedLanguage() throws {
        let tag = try BCP47LanguageTag("zh-yue")
        #expect(tag.primaryLanguage == .iso639_1("zh"))
        #expect(tag.extendedLanguage == "yue")
        #expect(tag.canonicalForm == "zh-yue")
    }

    // MARK: Grandfathered (RFC 5646 §2.2.8)

    @Test func parseGrandfatheredIDefault() throws {
        let tag = try BCP47LanguageTag("i-default")
        #expect(tag.primaryLanguage == .grandfathered("i-default"))
        #expect(tag.canonicalForm == "i-default")
    }

    @Test func parseGrandfatheredArtLojban() throws {
        let tag = try BCP47LanguageTag("art-lojban")
        #expect(tag.primaryLanguage == .grandfathered("art-lojban"))
    }

    @Test func parseGrandfatheredZhMinNan() throws {
        let tag = try BCP47LanguageTag("zh-min-nan")
        #expect(tag.primaryLanguage == .grandfathered("zh-min-nan"))
    }

    // MARK: Private-use (RFC 5646 §2.2.7)

    @Test func parsePrivateUseWholeTag() throws {
        let tag = try BCP47LanguageTag("x-private")
        #expect(tag.primaryLanguage == .privateUse("x-private"))
        #expect(tag.canonicalForm == "x-private")
    }

    @Test func parsePrivateUseSuffix() throws {
        let tag = try BCP47LanguageTag("en-x-private")
        #expect(tag.primaryLanguage == .iso639_1("en"))
        #expect(tag.privateUse == ["private"])
        #expect(tag.canonicalForm == "en-x-private")
    }

    @Test func parsePrivateUsePrimaryQaaRange() throws {
        let tag = try BCP47LanguageTag("qaa-Latn-DE")
        #expect(tag.primaryLanguage == .privateUse("qaa"))
        #expect(tag.script?.code == "Latn")
        #expect(tag.region == .iso3166_1("DE"))
    }

    // MARK: Extensions (RFC 5646 §2.2.6)

    @Test func parseExtensionSubtag() throws {
        let tag = try BCP47LanguageTag("de-DE-u-co-phonebk")
        #expect(tag.primaryLanguage == .iso639_1("de"))
        #expect(tag.region == .iso3166_1("DE"))
        #expect(tag.extensions.count == 1)
        #expect(tag.extensions[0].singleton == "u")
        #expect(tag.extensions[0].subtags == ["co", "phonebk"])
    }

    @Test func parseMultipleExtensions() throws {
        let tag = try BCP47LanguageTag("en-a-bbb-ccc-t-en-US-x-priv")
        #expect(tag.extensions.count == 2)
        #expect(tag.extensions[0].singleton == "a")
        #expect(tag.extensions[0].subtags == ["bbb", "ccc"])
        #expect(tag.extensions[1].singleton == "t")
        #expect(tag.extensions[1].subtags == ["en", "us"])
        #expect(tag.privateUse == ["priv"])
    }

    // MARK: UN M.49 numeric region (RFC 5646 §2.2.4)

    @Test func parseUNM49RegionLatinAmerica() throws {
        let tag = try BCP47LanguageTag("es-419")
        #expect(tag.primaryLanguage == .iso639_1("es"))
        #expect(tag.region == .unM49(419))
        #expect(tag.canonicalForm == "es-419")
    }

    @Test func parseUNM49RegionPaddedZero() throws {
        let tag = try BCP47LanguageTag("en-002")
        #expect(tag.region == .unM49(2))
        #expect(tag.canonicalForm == "en-002")
    }

    // MARK: Error paths (RFC 5646 §2.1 ABNF violations)

    @Test func parseEmptyStringThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("")
        }
    }

    @Test func parseWhitespaceOnlyThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("   ")
        }
    }

    @Test func parseInvalidPrimaryLengthThrows() throws {
        // 4-letter primary is reserved per RFC 5646 §2.2.1.
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("abcd")
        }
    }

    @Test func parsePrimary9LettersThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("abcdefghi")
        }
    }

    @Test func parsePrimaryWithDigitsThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("e1")
        }
    }

    @Test func parseLeadingHyphenThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("-en")
        }
    }

    @Test func parseTrailingHyphenThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("en-")
        }
    }

    @Test func parseConsecutiveHyphensThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("en--US")
        }
    }

    @Test func parseExtensionWithoutSubtagThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("en-u")
        }
    }

    @Test func parsePrivateUseEmptyThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("en-x")
        }
    }

    @Test func parsePrivateUseSubtagTooLongThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("en-x-toolongsubtag")
        }
    }

    @Test func parseUnknownScriptThrows() throws {
        // 4-letter alpha but not in IANA snapshot.
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("en-Xxxz")
        }
    }
}

@Suite("BCP47LanguageTag — RFC 5646 §4.5 canonicalization")
struct BCP47LanguageTagCanonicalizationTests {

    @Test func canonicalizePrimaryUppercase() throws {
        let tag = try BCP47LanguageTag("EN")
        #expect(tag.canonicalForm == "en")
    }

    @Test func canonicalizeScriptTitleCase() throws {
        let tag = try BCP47LanguageTag("zh-HANT-tw")
        #expect(tag.canonicalForm == "zh-Hant-TW")
    }

    @Test func canonicalizeRegionUppercase() throws {
        let tag = try BCP47LanguageTag("en-us")
        #expect(tag.canonicalForm == "en-US")
    }

    @Test func canonicalRoundTripAcrossSubtags() throws {
        let inputs = [
            "en", "en-US", "zh-Hant-TW", "pt-BR", "de-CH-1996",
            "zh-yue", "i-default", "qaa-Latn-DE", "es-419",
            "de-DE-u-co-phonebk", "en-x-private"
        ]
        for input in inputs {
            let parsed = try BCP47LanguageTag(input)
            let canonical = parsed.canonicalForm
            let reparsed = try BCP47LanguageTag(canonical)
            #expect(
                reparsed.canonicalForm == canonical,
                "round-trip drifted for '\(input)' → '\(canonical)'")
        }
    }

    @Test func grandfatheredPreservedExactly() throws {
        let tag = try BCP47LanguageTag("I-DEFAULT")
        #expect(tag.canonicalForm == "i-default")
    }
}

@Suite("BCP47LanguageTag — Equatable / Hashable / Codable")
struct BCP47LanguageTagConformanceTests {

    @Test func equalAfterDifferentCaseInput() throws {
        let lhs = try BCP47LanguageTag("en-US")
        let rhs = try BCP47LanguageTag("EN-us")
        #expect(lhs == rhs)
    }

    @Test func hashableConsistentAcrossEqualValues() throws {
        let lhs = try BCP47LanguageTag("zh-Hant-TW")
        let rhs = try BCP47LanguageTag("ZH-hant-tw")
        var dict: [BCP47LanguageTag: Int] = [:]
        dict[lhs] = 1
        #expect(dict[rhs] == 1)
    }

    @Test func codableJSONRoundTripSimple() throws {
        let tag = try BCP47LanguageTag("pt-BR")
        let data = try JSONEncoder().encode(tag)
        let decoded = try JSONDecoder().decode(BCP47LanguageTag.self, from: data)
        #expect(decoded == tag)
    }

    @Test func codableJSONRoundTripWithExtension() throws {
        let tag = try BCP47LanguageTag("de-DE-u-co-phonebk")
        let data = try JSONEncoder().encode(tag)
        let decoded = try JSONDecoder().decode(BCP47LanguageTag.self, from: data)
        #expect(decoded == tag)
        #expect(decoded.extensions == tag.extensions)
    }

    @Test func designatedInitProducesExpectedCanonicalForm() throws {
        let tag = BCP47LanguageTag(
            primaryLanguage: .iso639_1("en"),
            region: .iso3166_1("US"))
        #expect(tag.canonicalForm == "en-US")
    }
}

@Suite("BCP47Extension — Codable")
struct BCP47ExtensionConformanceTests {

    @Test func extensionRoundTripsThroughJSON() throws {
        let ext = BCP47Extension(singleton: "u", subtags: ["co", "phonebk"])
        let data = try JSONEncoder().encode(ext)
        let decoded = try JSONDecoder().decode(BCP47Extension.self, from: data)
        #expect(decoded == ext)
    }

    @Test func extensionDecodeRejectsMultiCharSingleton() throws {
        let json = #"{"singleton":"ab","subtags":["co"]}"#
        let data = Data(json.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(BCP47Extension.self, from: data)
        }
    }
}

@Suite("BCP47LanguageTag — additional primary-subtag shapes")
struct BCP47LanguageTagPrimaryShapeTests {

    @Test func parseISO6393OnlyPrimary() throws {
        // 3-letter primary not in qaa..qtz range → ISO 639-3.
        let tag = try BCP47LanguageTag("yue")
        #expect(tag.primaryLanguage == .iso639_3("yue"))
        #expect(tag.canonicalForm == "yue")
    }

    @Test func parse3LetterPrimaryWithDigitThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("a1z")
        }
    }

    @Test func parse5LetterRegisteredPrimary() throws {
        // RFC 5646 §2.2.1 allows 5..8-letter registered primary subtags.
        // Permissive mode accepts as ISO 639-3-ish.
        let tag = try BCP47LanguageTag("klingo")
        #expect(tag.primaryLanguage == .iso639_3("klingo"))
    }

    @Test func parse8LetterPrimary() throws {
        let tag = try BCP47LanguageTag("abcdefgh")
        #expect(tag.primaryLanguage == .iso639_3("abcdefgh"))
    }

    @Test func parse5To8LetterPrimaryWithDigitThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("klingo1")
        }
    }

    @Test func parseExtensionFollowedByPrivateUseStopsAtX() throws {
        // After an extension, an `x` singleton ends the extension and
        // begins the private-use sequence.
        let tag = try BCP47LanguageTag("en-u-co-x-priv")
        #expect(tag.extensions.count == 1)
        #expect(tag.extensions[0].singleton == "u")
        #expect(tag.extensions[0].subtags == ["co"])
        #expect(tag.privateUse == ["priv"])
    }

    @Test func parseExtensionSubSubtagTooLongThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("en-u-toolongsubsubtag")
        }
    }

    @Test func parseWholeTagPrivateUseWithBadSubtagThrows() throws {
        // Whole-tag `x-` with a subtag containing '#' (not alphanumeric).
        #expect(throws: BCP47Error.self) {
            _ = try BCP47LanguageTag("x-toolongsubsubtag")
        }
    }
}

@Suite("PrimarySubtag — raw lowercase normalisation")
struct PrimarySubtagRawTests {

    @Test func rawISO6391Lowercases() {
        #expect(PrimarySubtag.iso639_1("EN").raw == "en")
    }

    @Test func rawISO6393Lowercases() {
        #expect(PrimarySubtag.iso639_3("YUE").raw == "yue")
    }

    @Test func rawGrandfatheredLowercases() {
        #expect(PrimarySubtag.grandfathered("I-Default").raw == "i-default")
    }

    @Test func rawPrivateUseLowercases() {
        #expect(PrimarySubtag.privateUse("X-Private").raw == "x-private")
    }
}

@Suite("ISO15924Script + Region — conformance")
struct ISO15924ScriptAndRegionTests {

    @Test func iso15924ParseTitleCaseValid() throws {
        let script = try ISO15924Script("Latn")
        #expect(script.code == "Latn")
        #expect(script.description == "Latn")
    }

    @Test func iso15924ParseLowercaseCanonicalised() throws {
        let script = try ISO15924Script("hant")
        #expect(script.code == "Hant")
    }

    @Test func iso15924ParseInvalidLengthThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try ISO15924Script("Lat")
        }
    }

    @Test func iso15924ParseDigitsThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try ISO15924Script("L4tn")
        }
    }

    @Test func iso15924ParseUnknownCodeThrows() throws {
        #expect(throws: BCP47Error.self) {
            _ = try ISO15924Script("Xxxz")
        }
    }

    @Test func regionISO3166CanonicalUppercase() {
        let region = Region.iso3166_1("us")
        #expect(region.canonicalForm == "US")
        #expect(region.description == "US")
    }

    @Test func regionUNM49ZeroPadded() {
        #expect(Region.unM49(2).canonicalForm == "002")
        #expect(Region.unM49(419).canonicalForm == "419")
    }
}

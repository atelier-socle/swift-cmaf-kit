// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Direct coverage for the IANALanguageSubtagRegistry public surface —
// well-formedness predicates and known-subtag lookups across every
// category in the embedded 2026-05 snapshot.

import Foundation
import Testing

@testable import CMAFKit

@Suite("IANALanguageSubtagRegistry — snapshot metadata")
struct IANALanguageSubtagRegistrySnapshotTests {

    @Test func snapshotDateIsCurrent() {
        #expect(IANALanguageSubtagRegistry.snapshotDate == "2026-05")
    }
}

@Suite("IANALanguageSubtagRegistry — ISO 639-1 known + well-formed")
struct IANALanguageSubtagRegistryISO6391Tests {

    @Test func isKnownAcceptsCommonCode() {
        #expect(IANALanguageSubtagRegistry.isKnownISO639_1("en"))
        #expect(IANALanguageSubtagRegistry.isKnownISO639_1("FR"))  // case insensitive
    }

    @Test func isKnownRejectsUnknownCode() {
        #expect(!IANALanguageSubtagRegistry.isKnownISO639_1("zz"))
    }

    @Test func isWellFormedAcceptsAnyTwoLetters() {
        #expect(IANALanguageSubtagRegistry.isWellFormedISO639_1("xx"))
        #expect(IANALanguageSubtagRegistry.isWellFormedISO639_1("ZZ"))
    }

    @Test func isWellFormedRejectsWrongLength() {
        #expect(!IANALanguageSubtagRegistry.isWellFormedISO639_1("e"))
        #expect(!IANALanguageSubtagRegistry.isWellFormedISO639_1("eng"))
    }

    @Test func isWellFormedRejectsDigits() {
        #expect(!IANALanguageSubtagRegistry.isWellFormedISO639_1("e1"))
    }
}

@Suite("IANALanguageSubtagRegistry — ISO 639-3 known + well-formed")
struct IANALanguageSubtagRegistryISO6393Tests {

    @Test func isKnownAcceptsTerminologic() {
        #expect(IANALanguageSubtagRegistry.isKnownISO639_3("fra"))
        #expect(IANALanguageSubtagRegistry.isKnownISO639_3("YUE"))
    }

    @Test func isKnownRejectsArbitraryThreeLetterCode() {
        #expect(!IANALanguageSubtagRegistry.isKnownISO639_3("zzz"))
    }

    @Test func isWellFormedAcceptsAnyThreeLetters() {
        #expect(IANALanguageSubtagRegistry.isWellFormedISO639_3("zzz"))
    }

    @Test func isWellFormedRejectsDigits() {
        #expect(!IANALanguageSubtagRegistry.isWellFormedISO639_3("a1z"))
    }
}

@Suite("IANALanguageSubtagRegistry — ISO 15924 + ISO 3166-1 + UN M.49")
struct IANALanguageSubtagRegistryRegionAndScriptTests {

    @Test func iso15924KnownAcceptsLatn() {
        #expect(IANALanguageSubtagRegistry.isKnownISO15924("Latn"))
        #expect(IANALanguageSubtagRegistry.isKnownISO15924("latn"))
    }

    @Test func iso15924KnownRejectsUnknownCode() {
        #expect(!IANALanguageSubtagRegistry.isKnownISO15924("Xxxz"))
    }

    @Test func iso3166KnownAcceptsCommonRegion() {
        #expect(IANALanguageSubtagRegistry.isKnownISO3166_1("US"))
        #expect(IANALanguageSubtagRegistry.isKnownISO3166_1("fr"))
    }

    @Test func iso3166KnownRejectsUnknownRegion() {
        #expect(!IANALanguageSubtagRegistry.isKnownISO3166_1("XX"))
    }

    @Test func iso3166WellFormedAcceptsAnyTwoLetters() {
        #expect(IANALanguageSubtagRegistry.isWellFormedISO3166_1("ZZ"))
    }

    @Test func iso3166WellFormedRejectsDigits() {
        #expect(!IANALanguageSubtagRegistry.isWellFormedISO3166_1("U1"))
    }

    @Test func unM49KnownAcceptsCommonRegion() {
        #expect(IANALanguageSubtagRegistry.isKnownUNM49(419))
        #expect(IANALanguageSubtagRegistry.isKnownUNM49(150))
    }

    @Test func unM49KnownRejectsUnknown() {
        #expect(!IANALanguageSubtagRegistry.isKnownUNM49(999))
    }

    @Test func unM49WellFormedAccepts3Digits() {
        #expect(IANALanguageSubtagRegistry.isWellFormedUNM49("419"))
        #expect(IANALanguageSubtagRegistry.isWellFormedUNM49("002"))
    }

    @Test func unM49WellFormedRejectsLetters() {
        #expect(!IANALanguageSubtagRegistry.isWellFormedUNM49("ABC"))
    }

    @Test func unM49WellFormedRejectsWrongLength() {
        #expect(!IANALanguageSubtagRegistry.isWellFormedUNM49("42"))
        #expect(!IANALanguageSubtagRegistry.isWellFormedUNM49("1999"))
    }
}

@Suite("IANALanguageSubtagRegistry — grandfathered + extended-language")
struct IANALanguageSubtagRegistryGrandfatheredAndExtlangTests {

    @Test func grandfatheredAcceptsKnownTag() {
        #expect(IANALanguageSubtagRegistry.isGrandfathered("i-default"))
        #expect(IANALanguageSubtagRegistry.isGrandfathered("I-DEFAULT"))
        #expect(IANALanguageSubtagRegistry.isGrandfathered("art-lojban"))
    }

    @Test func grandfatheredRejectsRegularTag() {
        #expect(!IANALanguageSubtagRegistry.isGrandfathered("en-US"))
    }

    @Test func extlangAcceptsKnownCode() {
        #expect(IANALanguageSubtagRegistry.isKnownExtendedLanguage("yue"))
        #expect(IANALanguageSubtagRegistry.isKnownExtendedLanguage("CMN"))
    }

    @Test func extlangRejectsUnknownCode() {
        #expect(!IANALanguageSubtagRegistry.isKnownExtendedLanguage("xxx"))
    }
}

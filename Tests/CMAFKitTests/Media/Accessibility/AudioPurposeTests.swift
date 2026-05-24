// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// DVB-DASH TVA AudioPurpose round-trip per
// `urn:tva:metadata:cs:AudioPurposeCS:2007`.

import Foundation
import Testing

@testable import CMAFKit

@Suite("AudioPurpose — TVA round-trip")
struct AudioPurposeTests {

    @Test func allCasesCountMatchesTVAScheme() {
        // TVA AudioPurposeCS:2007 has exactly 8 codes (0-7).
        #expect(AudioPurpose.allCases.count == 8)
    }

    @Test func everyTVACodeRoundTripsViaRawValue() throws {
        let expected: [(UInt8, AudioPurpose)] = [
            (0, .main),
            (1, .audioDescription),
            (2, .hearingImpaired),
            (3, .translation),
            (4, .supplementary),
            (5, .emergency),
            (6, .voiceover),
            (7, .spokenSubtitle)
        ]
        for (code, expectedCase) in expected {
            let purpose = try #require(AudioPurpose(rawValue: code))
            #expect(purpose == expectedCase)
            #expect(purpose.rawValue == code)
        }
    }

    @Test func dashSchemeValueIsDecimalString() {
        #expect(AudioPurpose.main.dashSchemeValue == "0")
        #expect(AudioPurpose.audioDescription.dashSchemeValue == "1")
        #expect(AudioPurpose.spokenSubtitle.dashSchemeValue == "7")
    }

    @Test func dashAccessibilitySchemeIdUriIsCanonical() {
        #expect(
            AudioPurpose.dashAccessibilitySchemeIdUri
                == "urn:tva:metadata:cs:AudioPurposeCS:2007")
    }

    @Test func fromDASHSchemeValueRoundTripsEveryCode() throws {
        for purpose in AudioPurpose.allCases {
            let back = try #require(AudioPurpose.fromDASHSchemeValue(purpose.dashSchemeValue))
            #expect(back == purpose)
        }
    }

    @Test func fromDASHSchemeValueRejectsOutOfRange() {
        #expect(AudioPurpose.fromDASHSchemeValue("8") == nil)
        #expect(AudioPurpose.fromDASHSchemeValue("255") == nil)
        #expect(AudioPurpose.fromDASHSchemeValue("-1") == nil)
    }

    @Test func fromDASHSchemeValueRejectsNonNumeric() {
        #expect(AudioPurpose.fromDASHSchemeValue("audioDescription") == nil)
        #expect(AudioPurpose.fromDASHSchemeValue("") == nil)
    }

    @Test func codableJSONRoundTrip() throws {
        for purpose in AudioPurpose.allCases {
            let data = try JSONEncoder().encode(purpose)
            let decoded = try JSONDecoder().decode(AudioPurpose.self, from: data)
            #expect(decoded == purpose)
        }
    }

    @Test func hashableSetMembership() {
        let set: Set<AudioPurpose> = [.main, .audioDescription, .hearingImpaired]
        #expect(set.count == 3)
        #expect(set.contains(.audioDescription))
        #expect(!set.contains(.emergency))
    }
}

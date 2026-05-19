// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CommonEncryptionScheme")
struct CommonEncryptionSchemeTests {

    @Test
    func fourCCsMatchTheStandard() {
        #expect(CommonEncryptionScheme.cenc.fourCC == "cenc")
        #expect(CommonEncryptionScheme.cbc1.fourCC == "cbc1")
        #expect(CommonEncryptionScheme.cens.fourCC == "cens")
        #expect(CommonEncryptionScheme.cbcs.fourCC == "cbcs")
    }

    @Test
    func patternFlagDistinguishesFullSampleFromPattern() {
        #expect(CommonEncryptionScheme.cenc.usesPattern == false)
        #expect(CommonEncryptionScheme.cbc1.usesPattern == false)
        #expect(CommonEncryptionScheme.cens.usesPattern)
        #expect(CommonEncryptionScheme.cbcs.usesPattern)
    }

    @Test
    func cbcAndCtrModesAreMutuallyExclusive() {
        for scheme in CommonEncryptionScheme.allCases {
            #expect(scheme.usesCBCMode != scheme.usesCTRMode)
        }
    }

    @Test
    func cbcModeMatchesSchemeFamily() {
        #expect(CommonEncryptionScheme.cenc.usesCBCMode == false)
        #expect(CommonEncryptionScheme.cbc1.usesCBCMode)
        #expect(CommonEncryptionScheme.cens.usesCBCMode == false)
        #expect(CommonEncryptionScheme.cbcs.usesCBCMode)
    }

    @Test
    func ctrModeMatchesSchemeFamily() {
        #expect(CommonEncryptionScheme.cenc.usesCTRMode)
        #expect(CommonEncryptionScheme.cbc1.usesCTRMode == false)
        #expect(CommonEncryptionScheme.cens.usesCTRMode)
        #expect(CommonEncryptionScheme.cbcs.usesCTRMode == false)
    }

    @Test
    func codableRoundTripsByRawValue() throws {
        for scheme in CommonEncryptionScheme.allCases {
            let encoded = try JSONEncoder().encode(scheme)
            let decoded = try JSONDecoder().decode(CommonEncryptionScheme.self, from: encoded)
            #expect(decoded == scheme)
        }
    }

    @Test
    func rawValuesMatchFourCCBitPatterns() {
        // ASCII "cenc" = 0x63 65 6E 63
        #expect(CommonEncryptionScheme.cenc.rawValue == 0x6365_6E63)
        #expect(CommonEncryptionScheme.cbc1.rawValue == 0x6362_6331)
        #expect(CommonEncryptionScheme.cens.rawValue == 0x6365_6E73)
        #expect(CommonEncryptionScheme.cbcs.rawValue == 0x6362_6373)
    }
}

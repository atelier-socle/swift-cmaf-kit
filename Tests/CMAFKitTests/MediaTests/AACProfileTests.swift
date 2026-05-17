// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for AACProfile — ISO/IEC 14496-3 §1.6.2.1 Table 1.16.

import Foundation
import Testing

@testable import CMAFKit

@Suite("AACProfile")
struct AACProfileTests {

    @Test
    func rawValuesMatchISOTable() {
        #expect(AACProfile.main.rawValue == 1)
        #expect(AACProfile.lc.rawValue == 2)
        #expect(AACProfile.ssr.rawValue == 3)
        #expect(AACProfile.ltp.rawValue == 4)
        #expect(AACProfile.sbr.rawValue == 5)
        #expect(AACProfile.psSBR.rawValue == 29)
        #expect(AACProfile.eldV2.rawValue == 39)
        #expect(AACProfile.xHE.rawValue == 42)
    }

    @Test
    func caseIterableHasEightEntries() {
        #expect(AACProfile.allCases.count == 8)
    }

    @Test
    func hashableConsistency() {
        let a = AACProfile.lc
        let b = AACProfile.lc
        let c = AACProfile.sbr
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }
}

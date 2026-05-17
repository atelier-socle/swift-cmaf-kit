// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for ProResFlavor — Apple ProRes profile FourCC mapping.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ProResFlavor")
struct ProResFlavorTests {

    @Test
    func fourCCMappings() {
        #expect(ProResFlavor.proxy.fourCC.stringValue == "apco")
        #expect(ProResFlavor.lt.fourCC.stringValue == "apcs")
        #expect(ProResFlavor.standard.fourCC.stringValue == "apcn")
        #expect(ProResFlavor.hq.fourCC.stringValue == "apch")
        #expect(ProResFlavor.ap4h.fourCC.stringValue == "ap4h")
        #expect(ProResFlavor.ap4x.fourCC.stringValue == "ap4x")
    }

    @Test
    func rawValueIntegrity() {
        #expect(ProResFlavor.proxy.rawValue == 0x6170_636F)
        #expect(ProResFlavor.lt.rawValue == 0x6170_6373)
        #expect(ProResFlavor.standard.rawValue == 0x6170_636E)
        #expect(ProResFlavor.hq.rawValue == 0x6170_6368)
        #expect(ProResFlavor.ap4h.rawValue == 0x6170_3468)
        #expect(ProResFlavor.ap4x.rawValue == 0x6170_3478)
    }

    @Test
    func caseIterableCount() {
        #expect(ProResFlavor.allCases.count == 6)
    }
}

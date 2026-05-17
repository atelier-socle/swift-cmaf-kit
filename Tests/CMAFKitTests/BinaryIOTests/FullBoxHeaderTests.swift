// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for FullBoxHeader — ISO/IEC 14496-12 §4.2 full box version + flags.

import Foundation
import Testing

@testable import CMAFKit

@Suite("FullBoxHeader")
struct FullBoxHeaderTests {

    @Test
    func versionZero() {
        let box = ISOBoxHeader(type: "mvhd", size: 100, headerSize: 8)
        let full = FullBoxHeader(boxHeader: box, version: 0, flags: 0)
        #expect(full.version == 0)
        #expect(full.flags == 0)
        #expect(full.boxHeader == box)
    }

    @Test
    func versionOneWithFlags() {
        let box = ISOBoxHeader(type: "tfhd", size: 28, headerSize: 8)
        let full = FullBoxHeader(boxHeader: box, version: 1, flags: 0x0001_0023)
        #expect(full.version == 1)
        #expect(full.flags == 0x0001_0023)
    }

    @Test
    func twentyFourBitFlagsMaximum() {
        let box = ISOBoxHeader(type: "trun", size: 16, headerSize: 8)
        // Maximum value that fits in 24 bits.
        let full = FullBoxHeader(boxHeader: box, version: 0, flags: 0x00FF_FFFF)
        #expect(full.flags == 0x00FF_FFFF)
    }
}

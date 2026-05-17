// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for AudioChannelLayout — ISO/IEC 23001-8 §8.

import Foundation
import Testing

@testable import CMAFKit

@Suite("AudioChannelLayout")
struct AudioChannelLayoutTests {

    @Test
    func monoLayout() {
        let mono = AudioChannelLayout.mono
        #expect(mono.channelCount == 1)
        #expect(mono.mask == 0x4)
        #expect(mono.description == [.frontCenter])
    }

    @Test
    func stereoLayout() {
        let stereo = AudioChannelLayout.stereo
        #expect(stereo.channelCount == 2)
        #expect(stereo.mask == 0x3)
        #expect(stereo.description == [.frontLeft, .frontRight])
    }

    @Test
    func surround5_1Layout() {
        let layout = AudioChannelLayout.surround5_1
        #expect(layout.channelCount == 6)
        #expect(layout.description.count == 6)
        #expect(layout.description.contains(.lfe))
    }

    @Test
    func atmos7_1_4Layout() {
        let atmos = AudioChannelLayout.atmos7_1_4
        #expect(atmos.channelCount == 12)
        #expect(atmos.description.count == 12)
        // Four height channels present.
        #expect(atmos.description.contains(.topFrontLeft))
        #expect(atmos.description.contains(.topFrontRight))
        #expect(atmos.description.contains(.topBackLeft))
        #expect(atmos.description.contains(.topBackRight))
    }

    @Test
    func customLayoutRoundTrip() {
        let custom = AudioChannelLayout(
            channelCount: 4,
            mask: 0xFF00,
            description: [.frontLeft, .frontRight, .sideLeft, .sideRight]
        )
        #expect(custom.channelCount == 4)
        #expect(custom.mask == 0xFF00)
        #expect(custom.description == [.frontLeft, .frontRight, .sideLeft, .sideRight])
        // Hashable round-trip via Set.
        let set: Set<AudioChannelLayout> = [custom, custom, .stereo]
        #expect(set.count == 2)
    }
}

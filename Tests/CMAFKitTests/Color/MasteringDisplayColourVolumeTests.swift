// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("MasteringDisplayColourVolume")
struct MasteringDisplayColourVolumeTests {

    @Test
    func fieldsRoundTripWithUInt16Range() {
        let mdcv = MasteringDisplayColourVolume(
            displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
            displayPrimaryGreenX: 8500, displayPrimaryGreenY: 39850,
            displayPrimaryBlueX: 6550, displayPrimaryBlueY: 2300,
            whitePointX: 15635, whitePointY: 16450,
            maxDisplayMasteringLuminance: 10_000_000,
            minDisplayMasteringLuminance: 50
        )
        #expect(mdcv.displayPrimaryRedX == 35400)
        #expect(mdcv.maxDisplayMasteringLuminance == 10_000_000)
    }

    @Test
    func redNormalisedConversion() {
        let mdcv = MasteringDisplayColourVolume(
            displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
            displayPrimaryGreenX: 0, displayPrimaryGreenY: 0,
            displayPrimaryBlueX: 0, displayPrimaryBlueY: 0,
            whitePointX: 0, whitePointY: 0,
            maxDisplayMasteringLuminance: 0,
            minDisplayMasteringLuminance: 0
        )
        #expect((mdcv.redXNormalised - 0.708).magnitude < 0.001)
    }

    @Test
    func maxLuminanceCdM2Conversion() {
        let mdcv = MasteringDisplayColourVolume(
            displayPrimaryRedX: 0, displayPrimaryRedY: 0,
            displayPrimaryGreenX: 0, displayPrimaryGreenY: 0,
            displayPrimaryBlueX: 0, displayPrimaryBlueY: 0,
            whitePointX: 0, whitePointY: 0,
            maxDisplayMasteringLuminance: 10_000_000,
            minDisplayMasteringLuminance: 50
        )
        #expect(mdcv.maxLuminanceCdM2 == 1000.0)
        #expect((mdcv.minLuminanceCdM2 - 0.005).magnitude < 0.0001)
    }

    @Test
    func boxRoundTrip() async throws {
        let mdcv = MasteringDisplayColourVolume(
            displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
            displayPrimaryGreenX: 8500, displayPrimaryGreenY: 39850,
            displayPrimaryBlueX: 6550, displayPrimaryBlueY: 2300,
            whitePointX: 15635, whitePointY: 16450,
            maxDisplayMasteringLuminance: 10_000_000,
            minDisplayMasteringLuminance: 50
        )
        let box = MasteringDisplayColourVolumeBox(metadata: mdcv)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MasteringDisplayColourVolumeBox)
        #expect(parsed == box)
    }

    @Test
    func boxBodyIs24Bytes() {
        let mdcv = MasteringDisplayColourVolume(
            displayPrimaryRedX: 0, displayPrimaryRedY: 0,
            displayPrimaryGreenX: 0, displayPrimaryGreenY: 0,
            displayPrimaryBlueX: 0, displayPrimaryBlueY: 0,
            whitePointX: 0, whitePointY: 0,
            maxDisplayMasteringLuminance: 0,
            minDisplayMasteringLuminance: 0
        )
        let box = MasteringDisplayColourVolumeBox(metadata: mdcv)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // 8 header + 24 body = 32 bytes total
        #expect(writer.data.count == 32)
    }

    @Test
    func hashableConformance() {
        let mdcv1 = MasteringDisplayColourVolume(
            displayPrimaryRedX: 100, displayPrimaryRedY: 200,
            displayPrimaryGreenX: 300, displayPrimaryGreenY: 400,
            displayPrimaryBlueX: 500, displayPrimaryBlueY: 600,
            whitePointX: 700, whitePointY: 800,
            maxDisplayMasteringLuminance: 900,
            minDisplayMasteringLuminance: 10
        )
        let mdcv2 = mdcv1
        #expect(mdcv1.hashValue == mdcv2.hashValue)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("MasteringDisplayColourVolume normalisation accessors")
struct MasteringDisplayColourVolumeNormalisationTests {

    private let tolerance: Double = 1e-9

    private static func zeroed() -> MasteringDisplayColourVolume {
        MasteringDisplayColourVolume(
            displayPrimaryRedX: 0, displayPrimaryRedY: 0,
            displayPrimaryGreenX: 0, displayPrimaryGreenY: 0,
            displayPrimaryBlueX: 0, displayPrimaryBlueY: 0,
            whitePointX: 0, whitePointY: 0,
            maxDisplayMasteringLuminance: 0,
            minDisplayMasteringLuminance: 0
        )
    }

    @Test
    func canonicalBT2020Primaries() {
        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
            displayPrimaryGreenX: 8500, displayPrimaryGreenY: 39850,
            displayPrimaryBlueX: 6550, displayPrimaryBlueY: 2300,
            whitePointX: 15635, whitePointY: 16450,
            maxDisplayMasteringLuminance: 10_000_000,
            minDisplayMasteringLuminance: 50
        )
        #expect(abs(metadata.redXNormalised - 0.708) < tolerance)
        #expect(abs(metadata.redYNormalised - 0.292) < tolerance)
        #expect(abs(metadata.greenXNormalised - 0.170) < tolerance)
        #expect(abs(metadata.greenYNormalised - 0.797) < tolerance)
        #expect(abs(metadata.blueXNormalised - 0.131) < tolerance)
        #expect(abs(metadata.blueYNormalised - 0.046) < tolerance)
        #expect(abs(metadata.whitePointXNormalised - 0.3127) < tolerance)
        #expect(abs(metadata.whitePointYNormalised - 0.3290) < tolerance)
        #expect(abs(metadata.maxLuminanceCdM2 - 1000.0) < tolerance)
        #expect(abs(metadata.minLuminanceCdM2 - 0.005) < tolerance)
    }

    @Test
    func dciP3Primaries() {
        // DCI-P3 D65 primaries.
        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: 34000, displayPrimaryRedY: 16000,
            displayPrimaryGreenX: 13250, displayPrimaryGreenY: 34500,
            displayPrimaryBlueX: 7500, displayPrimaryBlueY: 3000,
            whitePointX: 15635, whitePointY: 16450,
            maxDisplayMasteringLuminance: 10_000_000,
            minDisplayMasteringLuminance: 1
        )
        #expect(abs(metadata.redXNormalised - 0.680) < tolerance)
        #expect(abs(metadata.redYNormalised - 0.320) < tolerance)
        #expect(abs(metadata.greenXNormalised - 0.265) < tolerance)
        #expect(abs(metadata.greenYNormalised - 0.690) < tolerance)
        #expect(abs(metadata.blueXNormalised - 0.150) < tolerance)
        #expect(abs(metadata.blueYNormalised - 0.060) < tolerance)
    }

    @Test
    func whitePointD65Normalisation() {
        let metadata = Self.zeroed()
        let withWhite = MasteringDisplayColourVolume(
            displayPrimaryRedX: metadata.displayPrimaryRedX,
            displayPrimaryRedY: metadata.displayPrimaryRedY,
            displayPrimaryGreenX: metadata.displayPrimaryGreenX,
            displayPrimaryGreenY: metadata.displayPrimaryGreenY,
            displayPrimaryBlueX: metadata.displayPrimaryBlueX,
            displayPrimaryBlueY: metadata.displayPrimaryBlueY,
            whitePointX: 15635, whitePointY: 16450,
            maxDisplayMasteringLuminance: 0,
            minDisplayMasteringLuminance: 0
        )
        #expect(abs(withWhite.whitePointXNormalised - 0.3127) < tolerance)
        #expect(abs(withWhite.whitePointYNormalised - 0.3290) < tolerance)
    }

    @Test
    func maxLuminanceConversion() {
        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: 0, displayPrimaryRedY: 0,
            displayPrimaryGreenX: 0, displayPrimaryGreenY: 0,
            displayPrimaryBlueX: 0, displayPrimaryBlueY: 0,
            whitePointX: 0, whitePointY: 0,
            maxDisplayMasteringLuminance: 10_000_000,
            minDisplayMasteringLuminance: 50
        )
        // 10_000_000 × 0.0001 = 1000.0 cd/m²
        #expect(abs(metadata.maxLuminanceCdM2 - 1000.0) < tolerance)
    }

    @Test
    func minLuminanceConversion() {
        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: 0, displayPrimaryRedY: 0,
            displayPrimaryGreenX: 0, displayPrimaryGreenY: 0,
            displayPrimaryBlueX: 0, displayPrimaryBlueY: 0,
            whitePointX: 0, whitePointY: 0,
            maxDisplayMasteringLuminance: 0,
            minDisplayMasteringLuminance: 50
        )
        // 50 × 0.0001 = 0.005 cd/m²
        #expect(abs(metadata.minLuminanceCdM2 - 0.005) < tolerance)
    }

    @Test
    func zeroValuesNormalisation() {
        let metadata = Self.zeroed()
        #expect(metadata.redXNormalised == 0.0)
        #expect(metadata.redYNormalised == 0.0)
        #expect(metadata.greenXNormalised == 0.0)
        #expect(metadata.greenYNormalised == 0.0)
        #expect(metadata.blueXNormalised == 0.0)
        #expect(metadata.blueYNormalised == 0.0)
        #expect(metadata.whitePointXNormalised == 0.0)
        #expect(metadata.whitePointYNormalised == 0.0)
        #expect(metadata.maxLuminanceCdM2 == 0.0)
        #expect(metadata.minLuminanceCdM2 == 0.0)
    }

    @Test
    func maxRawValuesNormalisation() {
        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: UInt16.max, displayPrimaryRedY: UInt16.max,
            displayPrimaryGreenX: UInt16.max, displayPrimaryGreenY: UInt16.max,
            displayPrimaryBlueX: UInt16.max, displayPrimaryBlueY: UInt16.max,
            whitePointX: UInt16.max, whitePointY: UInt16.max,
            maxDisplayMasteringLuminance: UInt32.max,
            minDisplayMasteringLuminance: UInt32.max
        )
        // 65535 × 0.00002 = 1.3107
        #expect(abs(metadata.redXNormalised - 1.3107) < tolerance)
        // UInt32.max × 0.0001 ≈ 429496.7295
        #expect(abs(metadata.maxLuminanceCdM2 - 429496.7295) < 1e-4)
    }

    @Test
    func redChromaticityIndependentOfOtherChannels() {
        // Verify red accessors don't read from green/blue/white storage.
        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
            displayPrimaryGreenX: 1, displayPrimaryGreenY: 2,
            displayPrimaryBlueX: 3, displayPrimaryBlueY: 4,
            whitePointX: 5, whitePointY: 6,
            maxDisplayMasteringLuminance: 7,
            minDisplayMasteringLuminance: 8
        )
        #expect(abs(metadata.redXNormalised - 0.708) < tolerance)
        #expect(abs(metadata.redYNormalised - 0.292) < tolerance)
    }

    @Test
    func greenChromaticityIndependent() {
        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: 1, displayPrimaryRedY: 2,
            displayPrimaryGreenX: 8500, displayPrimaryGreenY: 39850,
            displayPrimaryBlueX: 3, displayPrimaryBlueY: 4,
            whitePointX: 5, whitePointY: 6,
            maxDisplayMasteringLuminance: 7,
            minDisplayMasteringLuminance: 8
        )
        #expect(abs(metadata.greenXNormalised - 0.170) < tolerance)
        #expect(abs(metadata.greenYNormalised - 0.797) < tolerance)
    }

    @Test
    func blueChromaticityIndependent() {
        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: 1, displayPrimaryRedY: 2,
            displayPrimaryGreenX: 3, displayPrimaryGreenY: 4,
            displayPrimaryBlueX: 6550, displayPrimaryBlueY: 2300,
            whitePointX: 5, whitePointY: 6,
            maxDisplayMasteringLuminance: 7,
            minDisplayMasteringLuminance: 8
        )
        #expect(abs(metadata.blueXNormalised - 0.131) < tolerance)
        #expect(abs(metadata.blueYNormalised - 0.046) < tolerance)
    }

    @Test
    func luminanceUnitScale() {
        // 1 raw unit corresponds to 0.0001 cd/m².
        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: 0, displayPrimaryRedY: 0,
            displayPrimaryGreenX: 0, displayPrimaryGreenY: 0,
            displayPrimaryBlueX: 0, displayPrimaryBlueY: 0,
            whitePointX: 0, whitePointY: 0,
            maxDisplayMasteringLuminance: 1,
            minDisplayMasteringLuminance: 1
        )
        #expect(abs(metadata.maxLuminanceCdM2 - 0.0001) < tolerance)
        #expect(abs(metadata.minLuminanceCdM2 - 0.0001) < tolerance)
    }

    @Test
    func chromaticityUnitScale() {
        // 1 raw unit corresponds to 0.00002 (the 2e-5 ICC/SMPTE convention).
        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: 1, displayPrimaryRedY: 1,
            displayPrimaryGreenX: 1, displayPrimaryGreenY: 1,
            displayPrimaryBlueX: 1, displayPrimaryBlueY: 1,
            whitePointX: 1, whitePointY: 1,
            maxDisplayMasteringLuminance: 0,
            minDisplayMasteringLuminance: 0
        )
        #expect(abs(metadata.redXNormalised - 0.00002) < tolerance)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for HDRMetadata — exercises the typed Color and Dolby Vision
// surfaces against the HDR10 / HLG / Dolby Vision shapes.

import Foundation
import Testing

@testable import CMAFKit

@Suite("HDRMetadata")
struct HDRMetadataTests {

    @Test
    func hdr10MetadataConstruction() {
        let mdcv = MasteringDisplayColourVolume(
            displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
            displayPrimaryGreenX: 8500, displayPrimaryGreenY: 39850,
            displayPrimaryBlueX: 6550, displayPrimaryBlueY: 2300,
            whitePointX: 15635, whitePointY: 16450,
            maxDisplayMasteringLuminance: 10_000_000,
            minDisplayMasteringLuminance: 50
        )
        let clli = ContentLightLevel(
            maxContentLightLevel: 1000,
            maxPicAverageLightLevel: 400
        )
        let metadata = HDRMetadata(
            dynamicRange: .hdr10,
            colorPrimaries: .bt2020,
            transferCharacteristics: .smpteST2084_PQ,
            matrixCoefficients: .bt2020NCL,
            fullRange: false,
            masteringDisplay: mdcv,
            contentLightLevel: clli
        )
        #expect(metadata.dynamicRange == .hdr10)
        #expect(metadata.fullRange == false)
        #expect(metadata.masteringDisplay != nil)
        #expect(metadata.contentLightLevel != nil)
        #expect(metadata.dolbyVision == nil)
    }

    @Test
    func dolbyVisionProfile8_1StorageFidelity() {
        // 8.1 = profile 8 + bl_signal_compatibility_id = 1 (HDR10-compatible).
        let dv = DolbyVisionConfiguration(
            versionMajor: 1,
            versionMinor: 0,
            profile: .profile8(subProfile: .hdr10Compatible),
            level: .level09,
            rpuPresent: true,
            elPresent: false,
            blPresent: true,
            blSignalCompatibilityID: .hdr10Compatible
        )
        let metadata = HDRMetadata(
            dynamicRange: .dolbyVision(profile: .profile8(subProfile: .hdr10Compatible)),
            colorPrimaries: .bt2020,
            transferCharacteristics: .smpteST2084_PQ,
            matrixCoefficients: .bt2020NCL,
            fullRange: false,
            dolbyVision: dv
        )
        #expect(metadata.dolbyVision?.profile.wireProfileNumber == 8)
        #expect(metadata.dolbyVision?.blSignalCompatibilityID == .hdr10Compatible)
    }

    @Test
    func hlgMetadataConstruction() {
        let metadata = HDRMetadata(
            dynamicRange: .hlg,
            colorPrimaries: .bt2020,
            transferCharacteristics: .aribSTDB67_HLG,
            matrixCoefficients: .bt2020NCL,
            fullRange: false
        )
        #expect(metadata.dynamicRange == .hlg)
        #expect(metadata.masteringDisplay == nil)
        #expect(metadata.contentLightLevel == nil)
    }
}

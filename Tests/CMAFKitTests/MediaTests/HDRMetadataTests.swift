// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for HDRMetadata — uses Session-5 stub types (ColorPrimaries,
// TransferCharacteristics, etc.) from Sources/CMAFKit/Color/_ModulePlaceholder.swift.
// Tests cover only the bits available in Session 1 — Session 5 expands the
// underlying enums.

import Foundation
import Testing

@testable import CMAFKit

@Suite("HDRMetadata")
struct HDRMetadataTests {

    @Test
    func hdr10MetadataConstruction() {
        let metadata = HDRMetadata(
            dynamicRange: .hdr10,
            colorPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709,
            fullRange: false,
            masteringDisplay: MasteringDisplayMetadata(),
            contentLightLevel: ContentLightLevelMetadata()
        )
        #expect(metadata.dynamicRange == .hdr10)
        #expect(metadata.fullRange == false)
        #expect(metadata.masteringDisplay != nil)
        #expect(metadata.contentLightLevel != nil)
        #expect(metadata.dolbyVision == nil)
    }

    @Test
    func dolbyVisionProfile8Sub1StorageFidelity() {
        // Sub-flavor 8.1 is profile=8 + dvBLSignalCompatibilityID=1
        // (per the public Dolby Vision specification).
        let dv = DolbyVisionMetadata(
            profile: .profile8,
            level: 9,
            rpuPresent: true,
            elPresent: false,
            blPresent: true,
            dvBLSignalCompatibilityID: 1
        )
        let metadata = HDRMetadata(
            dynamicRange: .dolbyVision(profile: .profile8),
            colorPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709,
            fullRange: false,
            dolbyVision: dv
        )
        #expect(metadata.dolbyVision?.profile == .profile8)
        #expect(metadata.dolbyVision?.dvBLSignalCompatibilityID == 1)
        // Session 5 will add a .subFlavor accessor on DolbyVisionMetadata —
        // for Session 1 we only verify the underlying storage.
    }

    @Test
    func hlgMetadataConstruction() {
        let metadata = HDRMetadata(
            dynamicRange: .hlg,
            colorPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709,
            fullRange: false
        )
        #expect(metadata.dynamicRange == .hlg)
        #expect(metadata.masteringDisplay == nil)
        #expect(metadata.contentLightLevel == nil)
    }
}

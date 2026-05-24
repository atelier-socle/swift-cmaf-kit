// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCMultiLayerSPS")
struct HEVCMultiLayerSPSTests {

    // MARK: - Fixtures

    private static func defaultPTL() -> HEVCProfileTierLevel {
        HEVCProfileTierLevel(
            generalProfile: HEVCProfileTierLevel.ProfileBlock(
                profileSpace: .zero,
                tierFlag: .main,
                profileIDC: .main,
                compatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0x6000_0000),
                constraintFlags: HEVCConstraintIndicatorFlags(
                    progressiveSourceFlag: true,
                    interlacedSourceFlag: false,
                    nonPackedConstraintFlag: true,
                    frameOnlyConstraintFlag: true
                )
            ),
            generalLevel: .level4_1
        )
    }

    private static func minimalBaseSPS() -> HEVCSequenceParameterSet {
        HEVCSequenceParameterSet(
            vpsID: 0,
            maxSubLayersMinus1: 0,
            temporalIDNestingFlag: true,
            profileTierLevel: defaultPTL(),
            spsID: 0,
            chromaFormatIDC: .format420,
            picWidthInLumaSamples: 1920,
            picHeightInLumaSamples: 1080,
            conformanceWindow: nil,
            bitDepthYMinus8: 0,
            bitDepthCMinus8: 0,
            log2MaxPicOrderCntLsbMinus4: 4,
            subLayerOrderingInfoPresentFlag: true,
            subLayerOrderingInfo: [
                HEVCVideoParameterSet.SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: 4,
                    maxNumReorderPics: 2,
                    maxLatencyIncreasePlus1: 0
                )
            ],
            log2MinLumaCodingBlockSizeMinus3: 0,
            log2DiffMaxMinLumaCodingBlockSize: 3,
            log2MinLumaTransformBlockSizeMinus2: 0,
            log2DiffMaxMinLumaTransformBlockSize: 3,
            maxTransformHierarchyDepthInter: 0,
            maxTransformHierarchyDepthIntra: 0,
            amplificationEnabledFlag: false,
            sampleAdaptiveOffsetEnabledFlag: false,
            pcmInfo: nil,
            shortTermRefPicSets: [],
            longTermRefPicsInfo: nil,
            spsTemporalMVPEnabledFlag: true,
            strongIntraSmoothingEnabledFlag: false,
            vuiParameters: nil
        )
    }

    // MARK: - Round-trip

    @Test
    func roundTripMinimalStereoExtension() throws {
        let original = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: true,
            updateRepFormatFlag: false
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCMultiLayerSPS.parse(
            bitstream: &reader, baseSPS: Self.minimalBaseSPS(), layerID: 1
        )
        #expect(recovered == original)
    }

    @Test
    func roundTripWithBothFlagsSet() throws {
        let original = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: true,
            updateRepFormatFlag: true
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCMultiLayerSPS.parse(
            bitstream: &reader, baseSPS: Self.minimalBaseSPS(), layerID: 1
        )
        #expect(recovered.interLayerRefPicsPresentFlag == true)
        #expect(recovered.updateRepFormatFlag == true)
        #expect(recovered == original)
    }

    @Test
    func roundTripWithBothFlagsClear() throws {
        let original = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: false,
            updateRepFormatFlag: false
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCMultiLayerSPS.parse(
            bitstream: &reader, baseSPS: Self.minimalBaseSPS(), layerID: 1
        )
        #expect(recovered.interLayerRefPicsPresentFlag == false)
        #expect(recovered.updateRepFormatFlag == false)
    }

    @Test
    func opaqueExtensionDataPreserved() throws {
        let opaque = Data([0xCA, 0xFE, 0xBA, 0xBE])
        let original = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: true,
            updateRepFormatFlag: false,
            multiLayerExtensionData: opaque
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCMultiLayerSPS.parse(
            bitstream: &reader, baseSPS: Self.minimalBaseSPS(), layerID: 1
        )
        #expect(recovered.multiLayerExtensionData == opaque)
    }

    @Test
    func emptyOpaqueDataRoundTrip() throws {
        let original = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: true,
            updateRepFormatFlag: false
        )
        var writer = BitWriter()
        try original.encode(to: &writer)
        let encoded = writer.finish()
        var reader = BitReader(encoded)
        let recovered = try HEVCMultiLayerSPS.parse(
            bitstream: &reader, baseSPS: Self.minimalBaseSPS(), layerID: 1
        )
        #expect(recovered.multiLayerExtensionData.isEmpty)
    }

    // MARK: - Error paths

    @Test
    func layerIDAbove63Throws() throws {
        var reader = BitReader(Data([0xC0]))  // both flags set
        #expect(throws: HEVCMultiLayerSPSError.self) {
            _ = try HEVCMultiLayerSPS.parse(
                bitstream: &reader, baseSPS: Self.minimalBaseSPS(), layerID: 64
            )
        }
    }

    @Test
    func truncatedBitstreamThrows() throws {
        // Empty input — can't read the flags.
        var reader = BitReader(Data())
        #expect(throws: BitstreamError.self) {
            _ = try HEVCMultiLayerSPS.parse(
                bitstream: &reader, baseSPS: Self.minimalBaseSPS(), layerID: 1
            )
        }
    }

    // MARK: - Equatable / Hashable

    @Test
    func equatableSameInput() {
        let a = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: true,
            updateRepFormatFlag: false
        )
        let b = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: true,
            updateRepFormatFlag: false
        )
        #expect(a == b)
    }

    @Test
    func hashableSameInput() {
        let a = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: true,
            updateRepFormatFlag: false
        )
        let b = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: true,
            updateRepFormatFlag: false
        )
        var ha = Hasher()
        a.hash(into: &ha)
        var hb = Hasher()
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
    }

    @Test
    func equatableDifferentFlags() {
        let a = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: true,
            updateRepFormatFlag: false
        )
        let b = HEVCMultiLayerSPS(
            baseSPS: Self.minimalBaseSPS(),
            interLayerRefPicsPresentFlag: false,
            updateRepFormatFlag: true
        )
        #expect(a != b)
    }
}

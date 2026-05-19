// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCSequenceParameterSet")
struct HEVCSequenceParameterSetTests {

    private static func defaultPTL(level: HEVCLevelIDC = .level4_1) -> HEVCProfileTierLevel {
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
            generalLevel: level
        )
    }

    private static func main1080p() -> HEVCSequenceParameterSet {
        HEVCSequenceParameterSet(
            vpsID: 0,
            maxSubLayersMinus1: 0,
            temporalIDNestingFlag: true,
            profileTierLevel: defaultPTL(),
            spsID: 0,
            chromaFormatIDC: .format420,
            picWidthInLumaSamples: 1920,
            picHeightInLumaSamples: 1088,
            conformanceWindow: HEVCSequenceParameterSet.ConformanceWindow(
                leftOffset: 0, rightOffset: 0, topOffset: 0, bottomOffset: 4
            ),
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
            amplificationEnabledFlag: true,
            sampleAdaptiveOffsetEnabledFlag: true,
            spsTemporalMVPEnabledFlag: true,
            strongIntraSmoothingEnabledFlag: true
        )
    }

    @Test
    func main1080pRoundTrip() throws {
        let sps = Self.main1080p()
        let encoded = sps.encode()
        let decoded = try HEVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
    }

    @Test
    func codedDimensions1080pWithConformance() {
        let sps = Self.main1080p()
        let dims = sps.codedDimensions
        // 1088 - 2 * (0 + 4) = 1080
        #expect(dims.width == 1920)
        #expect(dims.height == 1080)
    }

    @Test
    func main10WithBitDepth10() throws {
        var sps = Self.main1080p()
        sps = HEVCSequenceParameterSet(
            vpsID: sps.vpsID,
            maxSubLayersMinus1: sps.maxSubLayersMinus1,
            temporalIDNestingFlag: sps.temporalIDNestingFlag,
            profileTierLevel: sps.profileTierLevel,
            spsID: sps.spsID,
            chromaFormatIDC: sps.chromaFormatIDC,
            picWidthInLumaSamples: sps.picWidthInLumaSamples,
            picHeightInLumaSamples: sps.picHeightInLumaSamples,
            conformanceWindow: sps.conformanceWindow,
            bitDepthYMinus8: 2,
            bitDepthCMinus8: 2,
            log2MaxPicOrderCntLsbMinus4: sps.log2MaxPicOrderCntLsbMinus4,
            subLayerOrderingInfoPresentFlag: sps.subLayerOrderingInfoPresentFlag,
            subLayerOrderingInfo: sps.subLayerOrderingInfo,
            log2MinLumaCodingBlockSizeMinus3: sps.log2MinLumaCodingBlockSizeMinus3,
            log2DiffMaxMinLumaCodingBlockSize: sps.log2DiffMaxMinLumaCodingBlockSize,
            log2MinLumaTransformBlockSizeMinus2: sps.log2MinLumaTransformBlockSizeMinus2,
            log2DiffMaxMinLumaTransformBlockSize: sps.log2DiffMaxMinLumaTransformBlockSize,
            maxTransformHierarchyDepthInter: sps.maxTransformHierarchyDepthInter,
            maxTransformHierarchyDepthIntra: sps.maxTransformHierarchyDepthIntra,
            amplificationEnabledFlag: sps.amplificationEnabledFlag,
            sampleAdaptiveOffsetEnabledFlag: sps.sampleAdaptiveOffsetEnabledFlag,
            spsTemporalMVPEnabledFlag: sps.spsTemporalMVPEnabledFlag,
            strongIntraSmoothingEnabledFlag: sps.strongIntraSmoothingEnabledFlag
        )
        let encoded = sps.encode()
        let decoded = try HEVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
        #expect(decoded.bitDepthYMinus8 == 2)
    }

    @Test
    func withShortTermRefPicSets() throws {
        var sps = Self.main1080p()
        let rps = HEVCShortTermRefPicSet(
            form: .explicit(
                negativePics: [
                    HEVCShortTermRefPicSet.DeltaPOCEntry(
                        deltaPocMinus1: 0,
                        usedByCurrPicFlag: true
                    )
                ],
                positivePics: []
            )
        )
        sps = HEVCSequenceParameterSet(
            vpsID: sps.vpsID,
            maxSubLayersMinus1: sps.maxSubLayersMinus1,
            temporalIDNestingFlag: sps.temporalIDNestingFlag,
            profileTierLevel: sps.profileTierLevel,
            spsID: sps.spsID,
            chromaFormatIDC: sps.chromaFormatIDC,
            picWidthInLumaSamples: sps.picWidthInLumaSamples,
            picHeightInLumaSamples: sps.picHeightInLumaSamples,
            conformanceWindow: sps.conformanceWindow,
            bitDepthYMinus8: sps.bitDepthYMinus8,
            bitDepthCMinus8: sps.bitDepthCMinus8,
            log2MaxPicOrderCntLsbMinus4: sps.log2MaxPicOrderCntLsbMinus4,
            subLayerOrderingInfoPresentFlag: sps.subLayerOrderingInfoPresentFlag,
            subLayerOrderingInfo: sps.subLayerOrderingInfo,
            log2MinLumaCodingBlockSizeMinus3: sps.log2MinLumaCodingBlockSizeMinus3,
            log2DiffMaxMinLumaCodingBlockSize: sps.log2DiffMaxMinLumaCodingBlockSize,
            log2MinLumaTransformBlockSizeMinus2: sps.log2MinLumaTransformBlockSizeMinus2,
            log2DiffMaxMinLumaTransformBlockSize: sps.log2DiffMaxMinLumaTransformBlockSize,
            maxTransformHierarchyDepthInter: sps.maxTransformHierarchyDepthInter,
            maxTransformHierarchyDepthIntra: sps.maxTransformHierarchyDepthIntra,
            amplificationEnabledFlag: sps.amplificationEnabledFlag,
            sampleAdaptiveOffsetEnabledFlag: sps.sampleAdaptiveOffsetEnabledFlag,
            shortTermRefPicSets: [rps],
            spsTemporalMVPEnabledFlag: sps.spsTemporalMVPEnabledFlag,
            strongIntraSmoothingEnabledFlag: sps.strongIntraSmoothingEnabledFlag
        )
        let encoded = sps.encode()
        let decoded = try HEVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
    }

    @Test
    func chromaFormat444WithSeparateColour() throws {
        let sps = HEVCSequenceParameterSet(
            vpsID: 0,
            maxSubLayersMinus1: 0,
            temporalIDNestingFlag: true,
            profileTierLevel: Self.defaultPTL(),
            spsID: 0,
            chromaFormatIDC: .format444,
            separateColourPlaneFlag: false,
            picWidthInLumaSamples: 640,
            picHeightInLumaSamples: 480,
            bitDepthYMinus8: 0,
            bitDepthCMinus8: 0,
            log2MaxPicOrderCntLsbMinus4: 0,
            subLayerOrderingInfoPresentFlag: true,
            subLayerOrderingInfo: [
                HEVCVideoParameterSet.SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: 1,
                    maxNumReorderPics: 0,
                    maxLatencyIncreasePlus1: 0
                )
            ],
            log2MinLumaCodingBlockSizeMinus3: 0,
            log2DiffMaxMinLumaCodingBlockSize: 0,
            log2MinLumaTransformBlockSizeMinus2: 0,
            log2DiffMaxMinLumaTransformBlockSize: 0,
            maxTransformHierarchyDepthInter: 0,
            maxTransformHierarchyDepthIntra: 0,
            amplificationEnabledFlag: false,
            sampleAdaptiveOffsetEnabledFlag: false,
            spsTemporalMVPEnabledFlag: false,
            strongIntraSmoothingEnabledFlag: false
        )
        let encoded = sps.encode()
        let decoded = try HEVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
        #expect(decoded.separateColourPlaneFlag == false)
    }

    @Test
    func equalityAndHashing() {
        let a = Self.main1080p()
        let b = Self.main1080p()
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}

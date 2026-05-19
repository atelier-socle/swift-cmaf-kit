// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AV1SequenceHeader")
struct AV1SequenceHeaderTests {

    private static func main1080p() -> AV1SequenceHeader {
        AV1SequenceHeader(
            seqProfile: .main,
            stillPicture: false,
            reducedStillPictureHeader: false,
            initialDisplayDelayPresentFlag: false,
            operatingPoints: [
                AV1OperatingPoint(
                    operatingPointIDC: 0, seqLevelIDX: .level4_0, seqTier: .main
                )
            ],
            frameWidthBitsMinus1: 11,  // up to 4096
            frameHeightBitsMinus1: 11,
            maxFrameWidthMinus1: 1919,
            maxFrameHeightMinus1: 1079,
            frameIDNumbersPresentFlag: false,
            use128x128Superblock: true,
            enableFilterIntra: true,
            enableIntraEdgeFilter: true,
            enableInterIntraCompound: false,
            enableMaskedCompound: false,
            enableWarpedMotion: false,
            enableDualFilter: false,
            enableOrderHint: false,
            enableJntComp: false,
            enableRefFrameMVs: false,
            seqChooseScreenContentTools: true,
            seqForceScreenContentTools: 2,
            seqChooseIntegerMV: true,
            enableSuperRes: false,
            enableCDEF: true,
            enableRestoration: true,
            colorConfig: AV1SequenceHeader.ColorConfig(
                highBitDepth: false,
                monochrome: false,
                colorRange: .limited,
                subsamplingX: true,
                subsamplingY: true,
                chromaSamplePosition: .unknown,
                separateUVDeltaQ: false
            ),
            filmGrainParamsPresent: false
        )
    }

    @Test
    func main1080pRoundTrip() throws {
        let header = Self.main1080p()
        let encoded = header.encode()
        let decoded = try AV1SequenceHeader.parse(bitstream: encoded)
        #expect(decoded == header)
    }

    @Test
    func reducedStillPictureRoundTrip() throws {
        let header = AV1SequenceHeader(
            seqProfile: .main,
            stillPicture: true,
            reducedStillPictureHeader: true,
            initialDisplayDelayPresentFlag: false,
            operatingPoints: [
                AV1OperatingPoint(operatingPointIDC: 0, seqLevelIDX: .level3_0)
            ],
            frameWidthBitsMinus1: 10,
            frameHeightBitsMinus1: 10,
            maxFrameWidthMinus1: 1279,
            maxFrameHeightMinus1: 719,
            frameIDNumbersPresentFlag: false,
            use128x128Superblock: false,
            enableFilterIntra: false,
            enableIntraEdgeFilter: false,
            enableSuperRes: false,
            enableCDEF: false,
            enableRestoration: false,
            colorConfig: AV1SequenceHeader.ColorConfig(
                highBitDepth: false,
                monochrome: false,
                colorRange: .limited,
                subsamplingX: true,
                subsamplingY: true,
                chromaSamplePosition: .unknown,
                separateUVDeltaQ: false
            ),
            filmGrainParamsPresent: false
        )
        let encoded = header.encode()
        let decoded = try AV1SequenceHeader.parse(bitstream: encoded)
        #expect(decoded == header)
    }

    @Test
    func withTimingInfo() throws {
        var header = Self.main1080p()
        header = AV1SequenceHeader(
            seqProfile: header.seqProfile,
            stillPicture: header.stillPicture,
            reducedStillPictureHeader: header.reducedStillPictureHeader,
            timingInfo: AV1SequenceHeader.TimingInfo(
                numUnitsInDisplayTick: 1,
                timeScale: 60,
                equalPictureInterval: false
            ),
            initialDisplayDelayPresentFlag: header.initialDisplayDelayPresentFlag,
            operatingPoints: header.operatingPoints,
            frameWidthBitsMinus1: header.frameWidthBitsMinus1,
            frameHeightBitsMinus1: header.frameHeightBitsMinus1,
            maxFrameWidthMinus1: header.maxFrameWidthMinus1,
            maxFrameHeightMinus1: header.maxFrameHeightMinus1,
            frameIDNumbersPresentFlag: header.frameIDNumbersPresentFlag,
            use128x128Superblock: header.use128x128Superblock,
            enableFilterIntra: header.enableFilterIntra,
            enableIntraEdgeFilter: header.enableIntraEdgeFilter,
            enableSuperRes: header.enableSuperRes,
            enableCDEF: header.enableCDEF,
            enableRestoration: header.enableRestoration,
            colorConfig: header.colorConfig,
            filmGrainParamsPresent: header.filmGrainParamsPresent
        )
        let encoded = header.encode()
        let decoded = try AV1SequenceHeader.parse(bitstream: encoded)
        #expect(decoded.timingInfo?.timeScale == 60)
    }

    @Test
    func withColorDescription() throws {
        var header = Self.main1080p()
        let cc = AV1SequenceHeader.ColorConfig(
            highBitDepth: false,
            monochrome: false,
            colorDescription: AV1SequenceHeader.ColorConfig.ColorDescription(
                colorPrimaries: .bt709,
                transferCharacteristics: .bt709,
                matrixCoefficients: .bt709
            ),
            colorRange: .full,
            subsamplingX: true,
            subsamplingY: true,
            chromaSamplePosition: .colocated,
            separateUVDeltaQ: false
        )
        header = AV1SequenceHeader(
            seqProfile: header.seqProfile,
            stillPicture: header.stillPicture,
            reducedStillPictureHeader: header.reducedStillPictureHeader,
            initialDisplayDelayPresentFlag: header.initialDisplayDelayPresentFlag,
            operatingPoints: header.operatingPoints,
            frameWidthBitsMinus1: header.frameWidthBitsMinus1,
            frameHeightBitsMinus1: header.frameHeightBitsMinus1,
            maxFrameWidthMinus1: header.maxFrameWidthMinus1,
            maxFrameHeightMinus1: header.maxFrameHeightMinus1,
            frameIDNumbersPresentFlag: header.frameIDNumbersPresentFlag,
            use128x128Superblock: header.use128x128Superblock,
            enableFilterIntra: header.enableFilterIntra,
            enableIntraEdgeFilter: header.enableIntraEdgeFilter,
            enableSuperRes: header.enableSuperRes,
            enableCDEF: header.enableCDEF,
            enableRestoration: header.enableRestoration,
            colorConfig: cc,
            filmGrainParamsPresent: header.filmGrainParamsPresent
        )
        let encoded = header.encode()
        let decoded = try AV1SequenceHeader.parse(bitstream: encoded)
        #expect(decoded.colorConfig.colorDescription?.colorPrimaries == .bt709)
        #expect(decoded.colorConfig.colorRange == .full)
    }

    @Test
    func multipleOperatingPoints() throws {
        var header = Self.main1080p()
        header = AV1SequenceHeader(
            seqProfile: header.seqProfile,
            stillPicture: header.stillPicture,
            reducedStillPictureHeader: header.reducedStillPictureHeader,
            initialDisplayDelayPresentFlag: false,
            operatingPoints: [
                AV1OperatingPoint(operatingPointIDC: 0, seqLevelIDX: .level3_0),
                AV1OperatingPoint(
                    operatingPointIDC: 0x0100, seqLevelIDX: .level4_0, seqTier: .main
                )
            ],
            frameWidthBitsMinus1: header.frameWidthBitsMinus1,
            frameHeightBitsMinus1: header.frameHeightBitsMinus1,
            maxFrameWidthMinus1: header.maxFrameWidthMinus1,
            maxFrameHeightMinus1: header.maxFrameHeightMinus1,
            frameIDNumbersPresentFlag: header.frameIDNumbersPresentFlag,
            use128x128Superblock: header.use128x128Superblock,
            enableFilterIntra: header.enableFilterIntra,
            enableIntraEdgeFilter: header.enableIntraEdgeFilter,
            enableSuperRes: header.enableSuperRes,
            enableCDEF: header.enableCDEF,
            enableRestoration: header.enableRestoration,
            colorConfig: header.colorConfig,
            filmGrainParamsPresent: header.filmGrainParamsPresent
        )
        let encoded = header.encode()
        let decoded = try AV1SequenceHeader.parse(bitstream: encoded)
        #expect(decoded.operatingPoints.count == 2)
    }
}

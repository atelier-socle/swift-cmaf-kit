// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AV1SequenceHeader coverage")
struct AV1SequenceHeaderCoverageTests {

    // MARK: builders

    private static func basicColorConfig(
        highBitDepth: Bool = false,
        twelveBit: Bool? = nil,
        monochrome: Bool = false,
        colorDescription: AV1SequenceHeader.ColorConfig.ColorDescription? = nil,
        colorRange: VideoFullRangeFlag = .limited,
        subsamplingX: Bool = true,
        subsamplingY: Bool = true,
        chromaSamplePosition: AV1ChromaSamplePosition? = .unknown,
        separateUVDeltaQ: Bool = false
    ) -> AV1SequenceHeader.ColorConfig {
        AV1SequenceHeader.ColorConfig(
            highBitDepth: highBitDepth,
            twelveBit: twelveBit,
            monochrome: monochrome,
            colorDescription: colorDescription,
            colorRange: colorRange,
            subsamplingX: subsamplingX,
            subsamplingY: subsamplingY,
            chromaSamplePosition: chromaSamplePosition,
            separateUVDeltaQ: separateUVDeltaQ
        )
    }

    private static func presentation1080p(
        profile: AV1Profile = .main,
        timingInfo: AV1SequenceHeader.TimingInfo? = nil,
        decoderModelInfo: AV1DecoderModelInfo? = nil,
        initialDisplayDelayPresent: Bool = false,
        operatingPoints: [AV1OperatingPoint]? = nil,
        use128x128Superblock: Bool = true,
        enableOrderHint: Bool = false,
        orderHintBitsMinus1: UInt8? = nil,
        seqChooseSCT: Bool = true,
        seqForceSCT: UInt8 = 2,
        seqChooseIntegerMV: Bool? = true,
        seqForceIntegerMV: UInt8? = nil,
        colorConfig: AV1SequenceHeader.ColorConfig? = nil,
        filmGrain: Bool = false
    ) -> AV1SequenceHeader {
        let ops =
            operatingPoints ?? [
                AV1OperatingPoint(
                    operatingPointIDC: 0, seqLevelIDX: .level4_0, seqTier: .main
                )
            ]
        let color = colorConfig ?? Self.basicColorConfig()
        return AV1SequenceHeader(
            seqProfile: profile,
            stillPicture: false,
            reducedStillPictureHeader: false,
            timingInfo: timingInfo,
            decoderModelInfo: decoderModelInfo,
            initialDisplayDelayPresentFlag: initialDisplayDelayPresent,
            operatingPoints: ops,
            frameWidthBitsMinus1: 11,
            frameHeightBitsMinus1: 11,
            maxFrameWidthMinus1: 1919,
            maxFrameHeightMinus1: 1079,
            frameIDNumbersPresentFlag: false,
            use128x128Superblock: use128x128Superblock,
            enableFilterIntra: true,
            enableIntraEdgeFilter: true,
            enableOrderHint: enableOrderHint,
            seqChooseScreenContentTools: seqChooseSCT,
            seqForceScreenContentTools: seqForceSCT,
            seqChooseIntegerMV: seqChooseIntegerMV,
            seqForceIntegerMV: seqForceIntegerMV,
            orderHintBitsMinus1: orderHintBitsMinus1,
            enableSuperRes: false,
            enableCDEF: true,
            enableRestoration: true,
            colorConfig: color,
            filmGrainParamsPresent: filmGrain
        )
    }

    // MARK: tests

    @Test
    func mainProfile8BitYUV420RoundTrip() throws {
        let header = Self.presentation1080p()
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded == header)
    }

    @Test
    func mainProfile10BitYUV420HDRPQ() throws {
        let cc = Self.basicColorConfig(
            highBitDepth: true,
            colorDescription: AV1SequenceHeader.ColorConfig.ColorDescription(
                colorPrimaries: .bt2020,
                transferCharacteristics: .smpteST2084_PQ,
                matrixCoefficients: .bt2020NCL
            ),
            colorRange: .limited
        )
        let header = Self.presentation1080p(profile: .main, colorConfig: cc)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.colorConfig.highBitDepth == true)
        #expect(decoded.colorConfig.colorDescription?.transferCharacteristics == .smpteST2084_PQ)
    }

    @Test
    func highProfileYUV444RoundTrip() throws {
        // .high → subX=false, subY=false; chromaSamplePosition not signalled.
        let cc = Self.basicColorConfig(
            highBitDepth: false,
            monochrome: false,
            colorRange: .full,
            subsamplingX: false,
            subsamplingY: false,
            chromaSamplePosition: nil
        )
        let header = Self.presentation1080p(profile: .high, colorConfig: cc)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.seqProfile == .high)
        #expect(decoded.colorConfig.subsamplingX == false)
    }

    @Test
    func professionalProfile12BitYUV444() throws {
        // .professional + 12-bit + 4:4:4 (subX=false). Per AV1 §5.5.2,
        // 12-bit forces explicit subsampling signaling.
        let cc = Self.basicColorConfig(
            highBitDepth: true,
            twelveBit: true,
            monochrome: false,
            colorRange: .limited,
            subsamplingX: false,
            subsamplingY: false,
            chromaSamplePosition: nil
        )
        let header = Self.presentation1080p(profile: .professional, colorConfig: cc)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.seqProfile == .professional)
        #expect(decoded.colorConfig.twelveBit == true)
        #expect(decoded.colorConfig.subsamplingX == false)
    }

    @Test
    func professionalProfile12BitYUV420() throws {
        // .professional + 12-bit + 4:2:0 (subX=true && subY=true).
        let cc = Self.basicColorConfig(
            highBitDepth: true,
            twelveBit: true,
            monochrome: false,
            colorRange: .limited,
            subsamplingX: true,
            subsamplingY: true,
            chromaSamplePosition: .colocated
        )
        let header = Self.presentation1080p(profile: .professional, colorConfig: cc)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.colorConfig.subsamplingX == true)
        #expect(decoded.colorConfig.subsamplingY == true)
        #expect(decoded.colorConfig.chromaSamplePosition == .colocated)
    }

    @Test
    func monochromeProfessionalRoundTrip() throws {
        let cc = Self.basicColorConfig(
            highBitDepth: true,
            twelveBit: false,
            monochrome: true,
            colorDescription: nil,
            colorRange: .limited,
            subsamplingX: true,
            subsamplingY: true,
            chromaSamplePosition: nil
        )
        let header = Self.presentation1080p(profile: .professional, colorConfig: cc)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.colorConfig.monochrome == true)
    }

    @Test
    func reducedStillPictureHeaderRoundTrip() throws {
        let cc = Self.basicColorConfig()
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
            colorConfig: cc,
            filmGrainParamsPresent: false
        )
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.reducedStillPictureHeader == true)
    }

    @Test
    func sequenceWithTimingInfoEqualInterval() throws {
        let timing = AV1SequenceHeader.TimingInfo(
            numUnitsInDisplayTick: 1,
            timeScale: 60,
            equalPictureInterval: true,
            numTicksPerPictureMinus1: 0
        )
        let header = Self.presentation1080p(timingInfo: timing)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.timingInfo?.equalPictureInterval == true)
        #expect(decoded.timingInfo?.numTicksPerPictureMinus1 == 0)
    }

    @Test
    func sequenceWithDecoderModelInfo() throws {
        let timing = AV1SequenceHeader.TimingInfo(
            numUnitsInDisplayTick: 1,
            timeScale: 60,
            equalPictureInterval: false
        )
        let model = AV1DecoderModelInfo(
            bufferDelayLengthMinus1: 23,
            numUnitsInDecodingTick: 1_001,
            bufferRemovalTimeLengthMinus1: 23,
            framePresentationTimeLengthMinus1: 23
        )
        let header = Self.presentation1080p(
            timingInfo: timing,
            decoderModelInfo: model
        )
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.decoderModelInfo == model)
    }

    @Test
    func opWithOperatingParametersInfo() throws {
        let timing = AV1SequenceHeader.TimingInfo(
            numUnitsInDisplayTick: 1,
            timeScale: 60,
            equalPictureInterval: false
        )
        let model = AV1DecoderModelInfo(
            bufferDelayLengthMinus1: 15,
            numUnitsInDecodingTick: 1_001,
            bufferRemovalTimeLengthMinus1: 15,
            framePresentationTimeLengthMinus1: 15
        )
        let opParams = AV1OperatingParametersInfo(
            decoderBufferDelay: 500,
            encoderBufferDelay: 500,
            lowDelayModeFlag: false
        )
        let op = AV1OperatingPoint(
            operatingPointIDC: 0,
            seqLevelIDX: .level4_0,
            seqTier: .main,
            operatingParametersInfo: opParams
        )
        let header = Self.presentation1080p(
            timingInfo: timing,
            decoderModelInfo: model,
            operatingPoints: [op]
        )
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.operatingPoints[0].operatingParametersInfo == opParams)
    }

    @Test
    func multipleOperatingPointsRoundTrip() throws {
        let ops: [AV1OperatingPoint] = [
            AV1OperatingPoint(operatingPointIDC: 0, seqLevelIDX: .level3_0),
            AV1OperatingPoint(
                operatingPointIDC: 0x0100, seqLevelIDX: .level4_0, seqTier: .high
            ),
            AV1OperatingPoint(
                operatingPointIDC: 0x0F00, seqLevelIDX: .level5_0, seqTier: .main
            )
        ]
        let header = Self.presentation1080p(operatingPoints: ops)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.operatingPoints.count == 3)
        #expect(decoded.operatingPoints[1].seqTier == .high)
    }

    @Test
    func initialDisplayDelayPresentRoundTrip() throws {
        let op = AV1OperatingPoint(
            operatingPointIDC: 0,
            seqLevelIDX: .level4_0,
            seqTier: .main,
            initialDisplayDelayMinus1: 3
        )
        let header = Self.presentation1080p(
            initialDisplayDelayPresent: true,
            operatingPoints: [op]
        )
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.initialDisplayDelayPresentFlag == true)
        #expect(decoded.operatingPoints[0].initialDisplayDelayMinus1 == 3)
    }

    @Test
    func use128x128SuperblockOff() throws {
        let header = Self.presentation1080p(use128x128Superblock: false)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.use128x128Superblock == false)
    }

    @Test
    func enableOrderHintWithBits() throws {
        let header = Self.presentation1080p(
            enableOrderHint: true,
            orderHintBitsMinus1: 7
        )
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.enableOrderHint == true)
        #expect(decoded.orderHintBitsMinus1 == 7)
    }

    @Test
    func filmGrainParamsPresentRoundTrip() throws {
        let header = Self.presentation1080p(filmGrain: true)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.filmGrainParamsPresent == true)
    }

    @Test
    func separateUVDeltaQEnabled() throws {
        let cc = Self.basicColorConfig(separateUVDeltaQ: true)
        let header = Self.presentation1080p(colorConfig: cc)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.colorConfig.separateUVDeltaQ == true)
    }

    @Test
    func colorDescriptionAbsentRoundTrip() throws {
        let cc = Self.basicColorConfig(colorDescription: nil)
        let header = Self.presentation1080p(colorConfig: cc)
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.colorConfig.colorDescription == nil)
    }

    @Test
    func seqChooseScreenContentToolsOffWithForce() throws {
        let header = Self.presentation1080p(
            seqChooseSCT: false,
            seqForceSCT: 1,
            seqChooseIntegerMV: false,
            seqForceIntegerMV: 1
        )
        let decoded = try AV1SequenceHeader.parse(bitstream: header.encode())
        #expect(decoded.seqChooseScreenContentTools == false)
        #expect(decoded.seqForceScreenContentTools == 1)
    }
}

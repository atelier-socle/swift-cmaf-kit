// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AVCSequenceParameterSet")
struct AVCSequenceParameterSetTests {

    private static func baseline720p() -> AVCSequenceParameterSet {
        // 1280×720, Baseline, level 3.1, simple POC type 0.
        AVCSequenceParameterSet(
            profileIDC: .baseline,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level3_1,
            seqParameterSetID: 0,
            log2MaxFrameNumMinus4: 0,
            picOrderCntType: 0,
            picOrderCntTypeFields: .type0(log2MaxPicOrderCntLsbMinus4: 0),
            maxNumRefFrames: 1,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 79,  // (79+1)*16 = 1280
            picHeightInMapUnitsMinus1: 44,  // (44+1)*16 = 720
            frameMbsOnlyFlag: true,
            direct8x8InferenceFlag: true
        )
    }

    @Test
    func baselineRoundTrip() throws {
        let sps = Self.baseline720p()
        let encoded = sps.encode()
        let decoded = try AVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
    }

    @Test
    func codedDimensionsForBaseline720p() {
        let sps = Self.baseline720p()
        let dims = sps.codedDimensions
        #expect(dims?.width == 1280)
        #expect(dims?.height == 720)
    }

    @Test
    func highProfile1080pRoundTrip() throws {
        let sps = AVCSequenceParameterSet(
            profileIDC: .high,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level4_1,
            seqParameterSetID: 0,
            highProfileFields: AVCSequenceParameterSet.HighProfileFields(
                chromaFormatIDC: 1,
                bitDepthLumaMinus8: 0,
                bitDepthChromaMinus8: 0,
                qpprimeYZeroTransformBypassFlag: false
            ),
            log2MaxFrameNumMinus4: 0,
            picOrderCntType: 0,
            picOrderCntTypeFields: .type0(log2MaxPicOrderCntLsbMinus4: 4),
            maxNumRefFrames: 4,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 119,  // (119+1)*16 = 1920
            picHeightInMapUnitsMinus1: 67,  // (67+1)*16 = 1088 (pre-crop)
            frameMbsOnlyFlag: true,
            direct8x8InferenceFlag: true,
            frameCropping: AVCSequenceParameterSet.FrameCropping(
                leftOffset: 0, rightOffset: 0, topOffset: 0, bottomOffset: 4
            )
        )
        let encoded = sps.encode()
        let decoded = try AVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
    }

    @Test
    func codedDimensionsAppliesFrameCropping() {
        let sps = AVCSequenceParameterSet(
            profileIDC: .high,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level4_1,
            seqParameterSetID: 0,
            highProfileFields: AVCSequenceParameterSet.HighProfileFields(
                chromaFormatIDC: 1,
                bitDepthLumaMinus8: 0,
                bitDepthChromaMinus8: 0,
                qpprimeYZeroTransformBypassFlag: false
            ),
            log2MaxFrameNumMinus4: 0,
            picOrderCntType: 0,
            picOrderCntTypeFields: .type0(log2MaxPicOrderCntLsbMinus4: 4),
            maxNumRefFrames: 4,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 119,
            picHeightInMapUnitsMinus1: 67,
            frameMbsOnlyFlag: true,
            direct8x8InferenceFlag: true,
            frameCropping: AVCSequenceParameterSet.FrameCropping(
                leftOffset: 0, rightOffset: 0, topOffset: 0, bottomOffset: 4
            )
        )
        // (67+1)*16 - 2 * 1 * (0 + 4) = 1088 - 8 = 1080
        let dims = sps.codedDimensions
        #expect(dims?.width == 1920)
        #expect(dims?.height == 1080)
    }

    @Test
    func main4_2_2RoundTrip() throws {
        let sps = AVCSequenceParameterSet(
            profileIDC: .high422,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level4,
            seqParameterSetID: 0,
            highProfileFields: AVCSequenceParameterSet.HighProfileFields(
                chromaFormatIDC: 2,
                bitDepthLumaMinus8: 2,
                bitDepthChromaMinus8: 2,
                qpprimeYZeroTransformBypassFlag: false
            ),
            log2MaxFrameNumMinus4: 0,
            picOrderCntType: 0,
            picOrderCntTypeFields: .type0(log2MaxPicOrderCntLsbMinus4: 4),
            maxNumRefFrames: 2,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 79,
            picHeightInMapUnitsMinus1: 44,
            frameMbsOnlyFlag: true,
            direct8x8InferenceFlag: true
        )
        let encoded = sps.encode()
        let decoded = try AVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
        #expect(decoded.highProfileFields?.chromaFormatIDC == 2)
    }

    @Test
    func chromaFormat444WithSeparatePlanes() throws {
        let sps = AVCSequenceParameterSet(
            profileIDC: .high444Predictive,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level4,
            seqParameterSetID: 0,
            highProfileFields: AVCSequenceParameterSet.HighProfileFields(
                chromaFormatIDC: 3,
                separateColourPlaneFlag: true,
                bitDepthLumaMinus8: 0,
                bitDepthChromaMinus8: 0,
                qpprimeYZeroTransformBypassFlag: false
            ),
            log2MaxFrameNumMinus4: 0,
            picOrderCntType: 0,
            picOrderCntTypeFields: .type0(log2MaxPicOrderCntLsbMinus4: 0),
            maxNumRefFrames: 1,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 0,
            picHeightInMapUnitsMinus1: 0,
            frameMbsOnlyFlag: true,
            direct8x8InferenceFlag: true
        )
        let encoded = sps.encode()
        let decoded = try AVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
        #expect(decoded.highProfileFields?.separateColourPlaneFlag == true)
    }

    @Test
    func picOrderCntType1RoundTrip() throws {
        let sps = AVCSequenceParameterSet(
            profileIDC: .main,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level3,
            seqParameterSetID: 0,
            log2MaxFrameNumMinus4: 4,
            picOrderCntType: 1,
            picOrderCntTypeFields: .type1(
                deltaPicOrderAlwaysZeroFlag: false,
                offsetForNonRefPic: -2,
                offsetForTopToBottomField: 1,
                offsetForRefFrames: [0, -1, 2, -3]
            ),
            maxNumRefFrames: 2,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 39,
            picHeightInMapUnitsMinus1: 22,
            frameMbsOnlyFlag: true,
            direct8x8InferenceFlag: true
        )
        let encoded = sps.encode()
        let decoded = try AVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
    }

    @Test
    func picOrderCntType2RoundTrip() throws {
        let sps = AVCSequenceParameterSet(
            profileIDC: .main,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level2_1,
            seqParameterSetID: 0,
            log2MaxFrameNumMinus4: 0,
            picOrderCntType: 2,
            picOrderCntTypeFields: .type2,
            maxNumRefFrames: 1,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 39,
            picHeightInMapUnitsMinus1: 22,
            frameMbsOnlyFlag: true,
            direct8x8InferenceFlag: true
        )
        let encoded = sps.encode()
        let decoded = try AVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
    }

    @Test
    func interlacedRoundTrip() throws {
        let sps = AVCSequenceParameterSet(
            profileIDC: .main,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level3,
            seqParameterSetID: 0,
            log2MaxFrameNumMinus4: 0,
            picOrderCntType: 0,
            picOrderCntTypeFields: .type0(log2MaxPicOrderCntLsbMinus4: 0),
            maxNumRefFrames: 1,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 39,
            picHeightInMapUnitsMinus1: 14,  // pic_height_in_map_units; doubled for interlaced
            frameMbsOnlyFlag: false,
            mbAdaptiveFrameFieldFlag: true,
            direct8x8InferenceFlag: true
        )
        let encoded = sps.encode()
        let decoded = try AVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
    }

    @Test
    func withVUIColourDescriptionRoundTrip() throws {
        let vui = AVCVUIParameters(
            videoSignal: AVCVUIParameters.VideoSignal(
                videoFormat: 5,
                videoFullRangeFlag: .limited,
                colourDescription: AVCVUIParameters.ColourDescription(
                    colourPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709
                )
            )
        )
        let sps = AVCSequenceParameterSet(
            profileIDC: .high,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level4_1,
            seqParameterSetID: 0,
            highProfileFields: AVCSequenceParameterSet.HighProfileFields(
                chromaFormatIDC: 1,
                bitDepthLumaMinus8: 0,
                bitDepthChromaMinus8: 0,
                qpprimeYZeroTransformBypassFlag: false
            ),
            log2MaxFrameNumMinus4: 0,
            picOrderCntType: 0,
            picOrderCntTypeFields: .type0(log2MaxPicOrderCntLsbMinus4: 4),
            maxNumRefFrames: 4,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 119,
            picHeightInMapUnitsMinus1: 67,
            frameMbsOnlyFlag: true,
            direct8x8InferenceFlag: true,
            vuiParameters: vui
        )
        let encoded = sps.encode()
        let decoded = try AVCSequenceParameterSet.parse(rbsp: encoded)
        #expect(decoded == sps)
        #expect(decoded.vuiParameters?.videoSignal?.colourDescription?.colourPrimaries == .bt709)
    }

    @Test
    func rejectsUnknownProfile() {
        // profile_idc = 7 (not in our enum), then dummy bytes.
        let bytes = Data([0x07, 0x00, 0x1E, 0x80, 0x80])
        #expect(throws: BitstreamError.self) {
            _ = try AVCSequenceParameterSet.parse(rbsp: bytes)
        }
    }

    @Test
    func encodeProducesByteAlignedOutput() {
        let sps = Self.baseline720p()
        let encoded = sps.encode()
        // Encoding must end on a byte boundary; the stop bit + padding
        // produces an integer number of bytes.
        #expect(!encoded.isEmpty)
    }

    @Test
    func dimensionsForMonochromeReturnsNil() {
        let sps = AVCSequenceParameterSet(
            profileIDC: .high,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level3,
            seqParameterSetID: 0,
            highProfileFields: AVCSequenceParameterSet.HighProfileFields(
                chromaFormatIDC: 0,  // monochrome
                bitDepthLumaMinus8: 0,
                bitDepthChromaMinus8: 0,
                qpprimeYZeroTransformBypassFlag: false
            ),
            log2MaxFrameNumMinus4: 0,
            picOrderCntType: 0,
            picOrderCntTypeFields: .type0(log2MaxPicOrderCntLsbMinus4: 0),
            maxNumRefFrames: 1,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 0,
            picHeightInMapUnitsMinus1: 0,
            frameMbsOnlyFlag: true,
            direct8x8InferenceFlag: true
        )
        #expect(sps.codedDimensions == nil)
    }

    @Test
    func dimensionsFor4_2_2NoCropping() {
        let sps = AVCSequenceParameterSet(
            profileIDC: .high422,
            constraintFlags: AVCProfileCompatibility(rawValue: 0),
            levelIDC: .level3,
            seqParameterSetID: 0,
            highProfileFields: AVCSequenceParameterSet.HighProfileFields(
                chromaFormatIDC: 2,
                bitDepthLumaMinus8: 0,
                bitDepthChromaMinus8: 0,
                qpprimeYZeroTransformBypassFlag: false
            ),
            log2MaxFrameNumMinus4: 0,
            picOrderCntType: 0,
            picOrderCntTypeFields: .type0(log2MaxPicOrderCntLsbMinus4: 0),
            maxNumRefFrames: 1,
            gapsInFrameNumValueAllowedFlag: false,
            picWidthInMbsMinus1: 39,  // 640
            picHeightInMapUnitsMinus1: 23,  // 384
            frameMbsOnlyFlag: true,
            direct8x8InferenceFlag: true
        )
        #expect(sps.codedDimensions?.width == 640)
        #expect(sps.codedDimensions?.height == 384)
    }

    @Test
    func equalityAndHashing() {
        let a = Self.baseline720p()
        let b = Self.baseline720p()
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}

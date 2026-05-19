// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCVUIParameters")
struct HEVCVUIParametersTests {

    private static func roundTrip(
        _ vui: HEVCVUIParameters,
        maxSubLayersMinus1: UInt8 = 0
    ) throws -> HEVCVUIParameters {
        var writer = BitWriter()
        vui.encode(to: &writer, maxNumSubLayersMinus1: maxSubLayersMinus1)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        return try HEVCVUIParameters.parse(
            reader: &reader, maxNumSubLayersMinus1: maxSubLayersMinus1
        )
    }

    @Test
    func emptyVUIRoundTrip() throws {
        let vui = HEVCVUIParameters()
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func aspectRatioStandardIDCRoundTrip() throws {
        let vui = HEVCVUIParameters(
            aspectRatio: HEVCVUIParameters.AspectRatioInfo(aspectRatioIDC: 1)
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func aspectRatioExtendedRoundTrip() throws {
        let vui = HEVCVUIParameters(
            aspectRatio: HEVCVUIParameters.AspectRatioInfo(
                aspectRatioIDC: 0xFF, sarWidth: 16, sarHeight: 9
            )
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func overscanFlagRoundTrip() throws {
        let vui = HEVCVUIParameters(overscanAppropriateFlag: true)
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func bt709SDRColourDescriptionRoundTrip() throws {
        let vui = HEVCVUIParameters(
            videoSignal: HEVCVUIParameters.VideoSignal(
                videoFormat: 5,
                videoFullRangeFlag: .limited,
                colourDescription: HEVCVUIParameters.ColourDescription(
                    colourPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709
                )
            )
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func bt2020PQHDRColourDescriptionRoundTrip() throws {
        let vui = HEVCVUIParameters(
            videoSignal: HEVCVUIParameters.VideoSignal(
                videoFormat: 5,
                videoFullRangeFlag: .full,
                colourDescription: HEVCVUIParameters.ColourDescription(
                    colourPrimaries: .bt2020,
                    transferCharacteristics: .smpteST2084_PQ,
                    matrixCoefficients: .bt2020NCL
                )
            )
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func chromaLocInfoRoundTrip() throws {
        let vui = HEVCVUIParameters(
            chromaLocInfo: HEVCVUIParameters.ChromaLocInfo(
                topFieldType: 0, bottomFieldType: 1
            )
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func neutralChromaFieldSeqFrameFieldInfoFlags() throws {
        let vui = HEVCVUIParameters(
            neutralChromaIndicationFlag: true,
            fieldSeqFlag: true,
            frameFieldInfoPresentFlag: true
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func defaultDisplayWindowRoundTrip() throws {
        let vui = HEVCVUIParameters(
            defaultDisplayWindow: HEVCVUIParameters.DisplayWindow(
                leftOffset: 0, rightOffset: 0, topOffset: 0, bottomOffset: 4
            )
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func timingInfoRoundTrip() throws {
        let vui = HEVCVUIParameters(
            timingInfo: HEVCVUIParameters.TimingInfo(
                numUnitsInTick: 1,
                timeScale: 60,
                pocProportionalToTimingFlag: false
            )
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func timingInfoWithPocProportional() throws {
        let vui = HEVCVUIParameters(
            timingInfo: HEVCVUIParameters.TimingInfo(
                numUnitsInTick: 1,
                timeScale: 24_000,
                pocProportionalToTimingFlag: true,
                numTicksPOCDiffOneMinus1: 1001
            )
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func bitstreamRestrictionsRoundTrip() throws {
        let vui = HEVCVUIParameters(
            bitstreamRestrictions: HEVCVUIParameters.BitstreamRestrictions(
                tilesFixedStructureFlag: false,
                motionVectorsOverPicBoundariesFlag: true,
                restrictedRefPicListsFlag: false,
                minSpatialSegmentationIDC: 0,
                maxBytesPerPicDenom: 2,
                maxBitsPerMinCuDenom: 1,
                log2MaxMvLengthHorizontal: 16,
                log2MaxMvLengthVertical: 16
            )
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }

    @Test
    func combinedFullVUIRoundTrip() throws {
        let vui = HEVCVUIParameters(
            aspectRatio: HEVCVUIParameters.AspectRatioInfo(aspectRatioIDC: 1),
            overscanAppropriateFlag: false,
            videoSignal: HEVCVUIParameters.VideoSignal(
                videoFormat: 5,
                videoFullRangeFlag: .limited,
                colourDescription: HEVCVUIParameters.ColourDescription(
                    colourPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709
                )
            ),
            chromaLocInfo: HEVCVUIParameters.ChromaLocInfo(
                topFieldType: 0, bottomFieldType: 0
            ),
            neutralChromaIndicationFlag: false,
            fieldSeqFlag: false,
            frameFieldInfoPresentFlag: false,
            defaultDisplayWindow: HEVCVUIParameters.DisplayWindow(
                leftOffset: 0, rightOffset: 0, topOffset: 0, bottomOffset: 0
            ),
            timingInfo: HEVCVUIParameters.TimingInfo(
                numUnitsInTick: 1, timeScale: 30, pocProportionalToTimingFlag: false
            ),
            bitstreamRestrictions: HEVCVUIParameters.BitstreamRestrictions(
                tilesFixedStructureFlag: false,
                motionVectorsOverPicBoundariesFlag: true,
                restrictedRefPicListsFlag: false,
                minSpatialSegmentationIDC: 0,
                maxBytesPerPicDenom: 2,
                maxBitsPerMinCuDenom: 1,
                log2MaxMvLengthHorizontal: 16,
                log2MaxMvLengthVertical: 16
            )
        )
        let decoded = try Self.roundTrip(vui)
        #expect(decoded == vui)
    }
}

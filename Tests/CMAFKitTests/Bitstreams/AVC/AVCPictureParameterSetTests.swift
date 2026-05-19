// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AVCPictureParameterSet")
struct AVCPictureParameterSetTests {

    private static func minimalPPS() -> AVCPictureParameterSet {
        AVCPictureParameterSet(
            picParameterSetID: 0,
            seqParameterSetID: 0,
            entropyCodingModeFlag: false,
            bottomFieldPicOrderInFramePresentFlag: false,
            numSliceGroupsMinus1: 0,
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            weightedPredFlag: false,
            weightedBipredIDC: 0,
            picInitQPMinus26: 0,
            picInitQSMinus26: 0,
            chromaQPIndexOffset: 0,
            deblockingFilterControlPresentFlag: false,
            constrainedIntraPredFlag: false,
            redundantPicCntPresentFlag: false
        )
    }

    @Test
    func minimalRoundTrip() throws {
        let pps = Self.minimalPPS()
        let encoded = pps.encode()
        let decoded = try AVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded == pps)
    }

    @Test
    func cabacPPSRoundTrip() throws {
        let pps = AVCPictureParameterSet(
            picParameterSetID: 0,
            seqParameterSetID: 0,
            entropyCodingModeFlag: true,
            bottomFieldPicOrderInFramePresentFlag: false,
            numSliceGroupsMinus1: 0,
            numRefIdxL0DefaultActiveMinus1: 4,
            numRefIdxL1DefaultActiveMinus1: 0,
            weightedPredFlag: false,
            weightedBipredIDC: 2,
            picInitQPMinus26: -2,
            picInitQSMinus26: 0,
            chromaQPIndexOffset: -3,
            deblockingFilterControlPresentFlag: true,
            constrainedIntraPredFlag: false,
            redundantPicCntPresentFlag: false
        )
        let encoded = pps.encode()
        let decoded = try AVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded == pps)
    }

    @Test
    func ppsWithOptionalTailRoundTrip() throws {
        let pps = AVCPictureParameterSet(
            picParameterSetID: 0,
            seqParameterSetID: 0,
            entropyCodingModeFlag: true,
            bottomFieldPicOrderInFramePresentFlag: true,
            numSliceGroupsMinus1: 0,
            numRefIdxL0DefaultActiveMinus1: 4,
            numRefIdxL1DefaultActiveMinus1: 4,
            weightedPredFlag: true,
            weightedBipredIDC: 2,
            picInitQPMinus26: -3,
            picInitQSMinus26: 0,
            chromaQPIndexOffset: 0,
            deblockingFilterControlPresentFlag: true,
            constrainedIntraPredFlag: false,
            redundantPicCntPresentFlag: false,
            tail: AVCPictureParameterSet.OptionalTail(
                transform8x8ModeFlag: true,
                secondChromaQPIndexOffset: 0
            )
        )
        let encoded = pps.encode()
        let decoded = try AVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded == pps)
        #expect(decoded.tail?.transform8x8ModeFlag == true)
    }

    @Test
    func dispersedSliceGroupRoundTrip() throws {
        let pps = AVCPictureParameterSet(
            picParameterSetID: 0,
            seqParameterSetID: 0,
            entropyCodingModeFlag: false,
            bottomFieldPicOrderInFramePresentFlag: false,
            numSliceGroupsMinus1: 1,
            sliceGroupMap: .dispersed,
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            weightedPredFlag: false,
            weightedBipredIDC: 0,
            picInitQPMinus26: 0,
            picInitQSMinus26: 0,
            chromaQPIndexOffset: 0,
            deblockingFilterControlPresentFlag: false,
            constrainedIntraPredFlag: false,
            redundantPicCntPresentFlag: false
        )
        let encoded = pps.encode()
        let decoded = try AVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded == pps)
    }

    @Test
    func interleavedSliceGroupRoundTrip() throws {
        let pps = AVCPictureParameterSet(
            picParameterSetID: 0,
            seqParameterSetID: 0,
            entropyCodingModeFlag: false,
            bottomFieldPicOrderInFramePresentFlag: false,
            numSliceGroupsMinus1: 2,
            sliceGroupMap: .interleaved(runLengthMinus1: [3, 5, 7]),
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            weightedPredFlag: false,
            weightedBipredIDC: 0,
            picInitQPMinus26: 0,
            picInitQSMinus26: 0,
            chromaQPIndexOffset: 0,
            deblockingFilterControlPresentFlag: false,
            constrainedIntraPredFlag: false,
            redundantPicCntPresentFlag: false
        )
        let encoded = pps.encode()
        let decoded = try AVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded == pps)
    }

    @Test
    func equalityAndHashing() {
        let a = Self.minimalPPS()
        let b = Self.minimalPPS()
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func negativeQPIndexOffset() throws {
        let pps = AVCPictureParameterSet(
            picParameterSetID: 0,
            seqParameterSetID: 0,
            entropyCodingModeFlag: false,
            bottomFieldPicOrderInFramePresentFlag: false,
            numSliceGroupsMinus1: 0,
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            weightedPredFlag: false,
            weightedBipredIDC: 0,
            picInitQPMinus26: -15,
            picInitQSMinus26: -10,
            chromaQPIndexOffset: -12,
            deblockingFilterControlPresentFlag: false,
            constrainedIntraPredFlag: false,
            redundantPicCntPresentFlag: false
        )
        let encoded = pps.encode()
        let decoded = try AVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded.picInitQPMinus26 == -15)
        #expect(decoded.picInitQSMinus26 == -10)
        #expect(decoded.chromaQPIndexOffset == -12)
    }
}

@Suite("AVCHRDParameters")
struct AVCHRDParametersTests {

    @Test
    func minimalRoundTrip() throws {
        let hrd = AVCHRDParameters(
            cpbCountMinus1: 0,
            bitRateScale: 0,
            cpbSizeScale: 0,
            cpbEntries: [
                AVCHRDParameters.CPBEntry(
                    bitRateValueMinus1: 99,
                    cpbSizeValueMinus1: 199,
                    cbrFlag: true
                )
            ],
            initialCPBRemovalDelayLengthMinus1: 23,
            cpbRemovalDelayLengthMinus1: 23,
            dpbOutputDelayLengthMinus1: 23,
            timeOffsetLength: 24
        )
        var writer = BitWriter()
        hrd.encode(to: &writer)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCHRDParameters.parse(reader: &reader)
        #expect(decoded == hrd)
    }

    @Test
    func multipleCPBEntries() throws {
        var entries: [AVCHRDParameters.CPBEntry] = []
        for i: Int in 0..<4 {
            entries.append(
                AVCHRDParameters.CPBEntry(
                    bitRateValueMinus1: UInt32(i * 100),
                    cpbSizeValueMinus1: UInt32(i * 200),
                    cbrFlag: i % 2 == 0
                )
            )
        }
        let hrd = AVCHRDParameters(
            cpbCountMinus1: 3,
            bitRateScale: 5,
            cpbSizeScale: 7,
            cpbEntries: entries,
            initialCPBRemovalDelayLengthMinus1: 23,
            cpbRemovalDelayLengthMinus1: 23,
            dpbOutputDelayLengthMinus1: 23,
            timeOffsetLength: 24
        )
        var writer = BitWriter()
        hrd.encode(to: &writer)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCHRDParameters.parse(reader: &reader)
        #expect(decoded == hrd)
    }

    @Test
    func bitScalesPreserved() throws {
        let hrd = AVCHRDParameters(
            cpbCountMinus1: 0,
            bitRateScale: 0x0F,
            cpbSizeScale: 0x0F,
            cpbEntries: [
                AVCHRDParameters.CPBEntry(
                    bitRateValueMinus1: 0, cpbSizeValueMinus1: 0, cbrFlag: false
                )
            ],
            initialCPBRemovalDelayLengthMinus1: 0,
            cpbRemovalDelayLengthMinus1: 0,
            dpbOutputDelayLengthMinus1: 0,
            timeOffsetLength: 0
        )
        var writer = BitWriter()
        hrd.encode(to: &writer)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCHRDParameters.parse(reader: &reader)
        #expect(decoded.bitRateScale == 0x0F)
        #expect(decoded.cpbSizeScale == 0x0F)
    }
}

@Suite("AVCVUIParameters")
struct AVCVUIParametersTests {

    @Test
    func emptyVUIRoundTrip() throws {
        let vui = AVCVUIParameters()
        var writer = BitWriter()
        vui.encode(to: &writer)
        // Add a stop bit so the BitReader can find a non-zero buffer.
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCVUIParameters.parse(reader: &reader)
        #expect(decoded == vui)
    }

    @Test
    func aspectRatioStandardCodeRoundTrip() throws {
        let vui = AVCVUIParameters(
            aspectRatio: AVCVUIParameters.AspectRatioInfo(aspectRatioIDC: 1)
        )
        var writer = BitWriter()
        vui.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCVUIParameters.parse(reader: &reader)
        #expect(decoded == vui)
    }

    @Test
    func aspectRatioExtendedRoundTrip() throws {
        let vui = AVCVUIParameters(
            aspectRatio: AVCVUIParameters.AspectRatioInfo(
                aspectRatioIDC: 0xFF,
                sarWidth: 16,
                sarHeight: 9
            )
        )
        var writer = BitWriter()
        vui.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCVUIParameters.parse(reader: &reader)
        #expect(decoded == vui)
    }

    @Test
    func videoSignalWithColourDescriptionRoundTrip() throws {
        let vui = AVCVUIParameters(
            videoSignal: AVCVUIParameters.VideoSignal(
                videoFormat: 5,
                videoFullRangeFlag: .full,
                colourDescription: AVCVUIParameters.ColourDescription(
                    colourPrimaries: .bt2020,
                    transferCharacteristics: .smpteST2084_PQ,
                    matrixCoefficients: .bt2020NCL
                )
            )
        )
        var writer = BitWriter()
        vui.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCVUIParameters.parse(reader: &reader)
        #expect(decoded == vui)
    }

    @Test
    func timingInfoRoundTrip() throws {
        let vui = AVCVUIParameters(
            timingInfo: AVCVUIParameters.TimingInfo(
                numUnitsInTick: 1,
                timeScale: 60,
                fixedFrameRateFlag: true
            )
        )
        var writer = BitWriter()
        vui.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCVUIParameters.parse(reader: &reader)
        #expect(decoded == vui)
        #expect(decoded.timingInfo?.timeScale == 60)
    }

    @Test
    func bitstreamRestrictionsRoundTrip() throws {
        let vui = AVCVUIParameters(
            bitstreamRestrictions: AVCVUIParameters.BitstreamRestrictions(
                motionVectorsOverPicBoundariesFlag: true,
                maxBytesPerPicDenom: 2,
                maxBitsPerMBDenom: 1,
                log2MaxMvLengthHorizontal: 8,
                log2MaxMvLengthVertical: 8,
                maxNumReorderFrames: 1,
                maxDecFrameBuffering: 4
            )
        )
        var writer = BitWriter()
        vui.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCVUIParameters.parse(reader: &reader)
        #expect(decoded == vui)
    }

    @Test
    func nalHRDWithLowDelayRoundTrip() throws {
        let hrd = AVCHRDParameters(
            cpbCountMinus1: 0,
            bitRateScale: 0, cpbSizeScale: 0,
            cpbEntries: [
                AVCHRDParameters.CPBEntry(
                    bitRateValueMinus1: 0, cpbSizeValueMinus1: 0, cbrFlag: true
                )
            ],
            initialCPBRemovalDelayLengthMinus1: 23,
            cpbRemovalDelayLengthMinus1: 23,
            dpbOutputDelayLengthMinus1: 23,
            timeOffsetLength: 24
        )
        let vui = AVCVUIParameters(
            nalHRDParameters: hrd,
            lowDelayHRDFlag: false
        )
        var writer = BitWriter()
        vui.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCVUIParameters.parse(reader: &reader)
        #expect(decoded == vui)
    }

    @Test
    func chromaLocInfoRoundTrip() throws {
        let vui = AVCVUIParameters(
            chromaLocInfo: AVCVUIParameters.ChromaLocationInfo(
                topFieldType: 0, bottomFieldType: 0
            )
        )
        var writer = BitWriter()
        vui.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCVUIParameters.parse(reader: &reader)
        #expect(decoded == vui)
    }

    @Test
    func picStructPresentRoundTrip() throws {
        let vui = AVCVUIParameters(picStructPresentFlag: true)
        var writer = BitWriter()
        vui.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try AVCVUIParameters.parse(reader: &reader)
        #expect(decoded.picStructPresentFlag == true)
    }
}

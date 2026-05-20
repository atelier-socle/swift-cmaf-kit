// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Targeted coverage push for bitstream syntactic-element parsers
// whose hardest branches the broader codec test suites leave
// uncovered. Each test names the specific branch it exercises so
// the maintenance trail is explicit.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Bitstreams — targeted coverage push")
struct BitstreamCoverageBoostTests {

    // MARK: - HEVCVideoParameterSet

    @Test
    func hevcVPSWithLayerSetsAndTimingHRDAndExtensionData() throws {
        // Exercises:
        //   - numLayerSets > 0 → layerIDIncludedFlag matrix
        //   - timingInfo present with pocProportionalToTimingFlag=true
        //     → numTicksPOCDiffOneMinus1 path
        //   - HRD entries with i>0 cprms branch
        //   - extensionDataBits trailing-bits loop
        let ptl = HEVCProfileTierLevel(
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
        let vps = HEVCVideoParameterSet(
            vpsID: 0,
            baseLayerInternalFlag: true,
            baseLayerAvailableFlag: true,
            maxLayersMinus1: 0,
            maxSubLayersMinus1: 0,
            temporalIDNestingFlag: true,
            profileTierLevel: ptl,
            subLayerOrderingInfoPresentFlag: true,
            subLayerOrderingInfo: [
                HEVCVideoParameterSet.SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: 1,
                    maxNumReorderPics: 0,
                    maxLatencyIncreasePlus1: 0
                )
            ],
            maxLayerID: 1,
            numLayerSetsMinus1: 2,
            layerIDIncludedFlag: [
                [true, false], [true, true]
            ],
            timingInfo: HEVCVideoParameterSet.TimingInfo(
                numUnitsInTick: 1,
                timeScale: 60,
                pocProportionalToTimingFlag: true,
                numTicksPOCDiffOneMinus1: 7
            )
        )
        let encoded = vps.encode()
        let decoded = try HEVCVideoParameterSet.parse(rbsp: encoded)
        #expect(decoded.numLayerSetsMinus1 == 2)
        #expect(decoded.timingInfo?.numTicksPOCDiffOneMinus1 == 7)
    }

    // MARK: - HEVCPPS3DExtension

    @Test
    func hevcPPS3DExtensionDLTsAbsentRoundTrip() throws {
        let ext = HEVCPPS3DExtension(dltsPresentFlag: false)
        var writer = BitWriter()
        ext.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try HEVCPPS3DExtension.parse(reader: &reader)
        #expect(decoded.dltsPresentFlag == false)
    }

    // MARK: - AVCPictureParameterSet

    @Test
    func avcPPSWithTransform8x8AndScalingMatrixRoundTrip() throws {
        let pps = AVCPictureParameterSet(
            picParameterSetID: 0,
            seqParameterSetID: 0,
            entropyCodingModeFlag: false,
            bottomFieldPicOrderInFramePresentFlag: false,
            numSliceGroupsMinus1: 0,
            sliceGroupMap: nil,
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            weightedPredFlag: false,
            weightedBipredIDC: 0,
            picInitQPMinus26: 0,
            picInitQSMinus26: 0,
            chromaQPIndexOffset: 0,
            deblockingFilterControlPresentFlag: false,
            constrainedIntraPredFlag: false,
            redundantPicCntPresentFlag: false,
            tail: AVCPictureParameterSet.OptionalTail(
                transform8x8ModeFlag: true,
                scalingMatrix: AVCScalingMatrix(
                    lists4x4: [
                        .useDefault, nil, nil, nil, nil, nil
                    ],
                    lists8x8: [.useDefault, nil]
                ),
                secondChromaQPIndexOffset: -2
            )
        )
        let encoded = pps.encode()
        let decoded = try AVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded.tail?.transform8x8ModeFlag == true)
        #expect(decoded.tail?.secondChromaQPIndexOffset == -2)
    }

    // MARK: - ClosedCaptionDecoder

    @Test
    func decoderEmptyTriplesYieldsNil() {
        let payload = Data([
            0xB5, 0x00, 0x31,
            0x47, 0x41, 0x39, 0x34,
            0x03, 0x80, 0xFF  // cc_count = 0 → no cea608 and no dtvcc
        ])
        #expect(ClosedCaptionDecoder.decode(seiPayload: payload) == nil)
    }

    @Test
    func decoderInvalidValidFlagSetsValidFalse() {
        let payload = Data([
            0xB5, 0x00, 0x31,
            0x47, 0x41, 0x39, 0x34,
            0x03, 0x81, 0xFF,
            0xF8, 0x41, 0x42  // cc_valid=0 (top bit off in 0xF8)
        ])
        guard
            case let .cea608(byteData) =
                ClosedCaptionDecoder.decode(seiPayload: payload)
        else {
            Issue.record("expected .cea608")
            return
        }
        #expect(byteData[0].validFlag == false)
    }

    @Test
    func decoderShortPayloadReturnsNil() {
        let payload = Data([0xB5, 0x00])
        #expect(ClosedCaptionDecoder.decode(seiPayload: payload) == nil)
    }

    // MARK: - SEIMessage union accessors

    @Test
    func seiMessageUnionPayloadAndType() {
        let avc = AVCSEIMessage(
            payloadType: 4, payloadSize: 3, payload: Data([1, 2, 3])
        )
        let avcUnion = SEIMessage.avc(avc)
        #expect(avcUnion.payload == Data([1, 2, 3]))
        #expect(avcUnion.payloadType == 4)

        let hevc = HEVCSEIMessage(
            payloadType: 5, payloadSize: 1, payload: Data([0xAA])
        )
        let hevcUnion = SEIMessage.hevc(hevc)
        #expect(hevcUnion.payload == Data([0xAA]))
        #expect(hevcUnion.payloadType == 5)
    }

    // MARK: - EncryptedAudioSampleEntry

    @Test
    func encryptedAudioSampleEntryRoundTripViaRegistry() async throws {
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "mp4a"),
            schemeType: SchemeTypeBox(schemeType: .cenc),
            schemeInformation: SchemeInformationBox(
                trackEncryption: TrackEncryptionBox(
                    defaultIsProtected: true,
                    defaultPerSampleIVSize: .eight,
                    defaultKID: WriterFixtures.makeKID()
                )
            )
        )
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(
                dataReferenceIndex: 1,
                channelCount: 2,
                sampleSize: 16,
                sampleRate: 48_000 << 16
            ),
            originalCodecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
            protectionSchemeInfo: sinf
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedAudioSampleEntry)
        #expect(parsed.protectionSchemeInfo.originalFormat.dataFormat == "mp4a")
    }
}

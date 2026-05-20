// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage lift for the SampleEntry protocol-witness accessors. The
// twenty `dataReferenceIndex` accessors in
// ``SampleEntryConformances.swift`` are invoked only when the entry
// is accessed through the protocol; direct field reads bypass them.
// One test per witness verifies the accessor returns the expected
// value.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleEntry conformances — dataReferenceIndex witnesses")
struct SampleEntryConformancesCoverageLiftTests {

    private static let drIndex: UInt16 = 7

    private static func visual() -> VisualSampleEntryFields {
        VisualSampleEntryFields(
            dataReferenceIndex: drIndex,
            width: 1920,
            height: 1080
        )
    }

    private static func audio() -> AudioSampleEntryFields {
        AudioSampleEntryFields(
            dataReferenceIndex: drIndex,
            channelCount: 2,
            sampleSize: 16,
            sampleRate: 48_000 << 16
        )
    }

    private static func avcConfig() -> AVCDecoderConfigurationRecord {
        SampleEntryComposerCodecSweepTests.makeAVCConfig()
    }

    private static func hevcConfig() -> HEVCDecoderConfigurationRecord {
        SampleEntryComposerCodecSweepTests.makeHEVCConfig()
    }

    @Test
    func avcSampleEntryWitness() {
        let entry: any SampleEntry = AVCSampleEntry(
            visualFields: Self.visual(),
            configuration: Self.avcConfig()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func avcSampleEntryInbandWitness() {
        let entry: any SampleEntry = AVCSampleEntryInband(
            visualFields: Self.visual(),
            configuration: Self.avcConfig()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func hevcSampleEntryWitness() {
        let entry: any SampleEntry = HEVCSampleEntry(
            visualFields: Self.visual(),
            configuration: Self.hevcConfig()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func hevcSampleEntryInbandWitness() {
        let entry: any SampleEntry = HEVCSampleEntryInband(
            visualFields: Self.visual(),
            configuration: Self.hevcConfig()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func dolbyVisionHEVCSampleEntryWitness() {
        let dvc = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile5, level: .level05,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .nonCompatible
        )
        let entry: any SampleEntry = DolbyVisionHEVCSampleEntry(
            visualFields: Self.visual(),
            hevcConfiguration: Self.hevcConfig(),
            dolbyVisionConfiguration: dvc
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func dolbyVisionHEVCSampleEntryInbandWitness() {
        let dvc = DolbyVisionConfiguration(
            versionMajor: 1, versionMinor: 0,
            profile: .profile8(subProfile: .hdr10Compatible),
            level: .level05,
            rpuPresent: true, elPresent: false, blPresent: true,
            blSignalCompatibilityID: .hdr10Compatible
        )
        let entry: any SampleEntry = DolbyVisionHEVCSampleEntryInband(
            visualFields: Self.visual(),
            hevcConfiguration: Self.hevcConfig(),
            dolbyVisionConfiguration: dvc
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func vp8SampleEntryWitness() {
        let entry: any SampleEntry = VP8SampleEntry(
            visualFields: Self.visual(),
            configuration: SampleEntryComposerCodecSweepTests.makeVPConfig()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func vp9SampleEntryWitness() {
        let entry: any SampleEntry = VP9SampleEntry(
            visualFields: Self.visual(),
            configuration: SampleEntryComposerCodecSweepTests.makeVPConfig()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func av1SampleEntryWitness() {
        let entry: any SampleEntry = AV1SampleEntry(
            visualFields: Self.visual(),
            configuration: SampleEntryComposerCodecSweepTests.makeAV1Config()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func mp4VisualSampleEntryWitness() {
        let entry: any SampleEntry = MP4VisualSampleEntry(
            visualFields: Self.visual(),
            elementaryStreamDescriptor: WriterFixtures.makeESDS()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func encryptedVideoSampleEntryWitness() {
        let entry: any SampleEntry = EncryptedVideoSampleEntry(
            visualFields: Self.visual(),
            originalCodecConfiguration: .avc(Self.avcConfig()),
            protectionSchemeInfo: ProtectionSchemeInfoBox(
                originalFormat: OriginalFormatBox(dataFormat: "avc1"),
                schemeType: SchemeTypeBox(schemeType: .cenc),
                schemeInformation: SchemeInformationBox(
                    trackEncryption: TrackEncryptionBox(
                        defaultIsProtected: true,
                        defaultPerSampleIVSize: .eight,
                        defaultKID: WriterFixtures.makeKID()
                    )
                )
            )
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func mp4AudioSampleEntryWitness() {
        let entry: any SampleEntry = MP4AudioSampleEntry(
            audioFields: Self.audio(),
            elementaryStreamDescriptor: WriterFixtures.makeESDS()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func ac3SampleEntryWitness() {
        let entry: any SampleEntry = AC3SampleEntry(
            audioFields: Self.audio(),
            specificBox: SampleEntryComposerCodecSweepTests.makeAC3()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func ec3SampleEntryWitness() {
        let entry: any SampleEntry = EC3SampleEntry(
            audioFields: Self.audio(),
            specificBox: Self.makeEC3()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func ac4SampleEntryWitness() {
        let entry: any SampleEntry = AC4SampleEntry(
            audioFields: Self.audio(),
            specificBox: Self.makeAC4()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func opusSampleEntryWitness() {
        let entry: any SampleEntry = OpusSampleEntry(
            audioFields: Self.audio(),
            specificBox: Self.makeOpus()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func flacSampleEntryWitness() {
        let entry: any SampleEntry = FLACSampleEntry(
            audioFields: Self.audio(),
            specificBox: Self.makeFLAC()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func mpegHAudioSampleEntryWitness() {
        let entry: any SampleEntry = MPEGHAudioSampleEntry(
            audioFields: Self.audio(),
            configuration: Self.makeMPEGH()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    @Test
    func mpegHAudioSampleEntryMultiStreamWitness() {
        let entry: any SampleEntry = MPEGHAudioSampleEntryMultiStream(
            audioFields: Self.audio(),
            configuration: Self.makeMPEGH()
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }

    // MARK: - Codec config factories

    private static func makeEC3() -> EC3SpecificBox {
        EC3SpecificBox(
            dataRate: 192,
            independentSubstreams: [
                EC3SpecificBox.IndependentSubstream(
                    fscod: .freq48000,
                    bsid: 16,
                    asvc: false,
                    bsmod: .completeMain,
                    acmod: .stereo,
                    lfeon: false,
                    dependentSubstreamCount: 0,
                    dependentSubstreamChannelLocation: nil
                )
            ]
        )
    }

    private static func makeAC4() -> AC4SpecificBox {
        AC4SpecificBox(
            bitstreamVersion: 2,
            presentations: []
        )
    }

    private static func makeOpus() -> OpusSpecificBox {
        OpusSpecificBox(
            outputChannelCount: 2,
            preSkip: 312,
            inputSampleRate: 48_000,
            outputGainQ78: 0,
            channelMappingFamily: .rtpMonoStereo
        )
    }

    private static func makeFLAC() -> FLACSpecificBox {
        // STREAMINFO block per RFC 9639 §8.2.1 — 34 bytes payload.
        let streamInfoPayload = Data(repeating: 0, count: 34)
        return FLACSpecificBox(
            metadataBlocks: [
                FLACSpecificBox.FLACMetadataBlock(
                    isLast: true,
                    blockType: .streamInfo,
                    blockData: streamInfoPayload
                )
            ]
        )
    }

    private static func makeMPEGH() -> MPEGHConfigurationBox {
        MPEGHConfigurationBox(
            profileLevelIndication: .lcProfileLevel1,
            referenceChannelLayout: 2,
            mpegh3daConfig: Data([0x00])
        )
    }

    // MARK: - Encrypted entry witness

    @Test
    func encryptedAudioSampleEntryWitness() {
        let entry: any SampleEntry = EncryptedAudioSampleEntry(
            audioFields: Self.audio(),
            originalCodecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
            protectionSchemeInfo: ProtectionSchemeInfoBox(
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
        )
        #expect(entry.dataReferenceIndex == Self.drIndex)
    }
}

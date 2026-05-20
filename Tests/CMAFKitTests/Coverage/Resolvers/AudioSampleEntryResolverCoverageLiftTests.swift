// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage lift for ``AudioSampleEntryResolver``. The resolver
// dispatches on Swift type to map each audio sample-entry into a
// ``ResolvedAudioEntry``; the codec sweep tests cover only mp4a +
// ac3, leaving ec3 / ac4 / opus / flac / mhm1 / mhm2 / encrypted
// uncovered. Each test here invokes the resolver with one entry
// shape and verifies the recovered codec + configuration.

import Foundation
import Testing

@testable import CMAFKit

@Suite("AudioSampleEntryResolver — coverage lift")
struct AudioSampleEntryResolverCoverageLiftTests {

    private static func audio() -> AudioSampleEntryFields {
        AudioSampleEntryFields(
            dataReferenceIndex: 1,
            channelCount: 2,
            sampleSize: 16,
            sampleRate: 48_000 << 16
        )
    }

    @Test
    func resolvesMP4A() throws {
        let entry = MP4AudioSampleEntry(
            audioFields: Self.audio(),
            elementaryStreamDescriptor: WriterFixtures.makeESDS()
        )
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        #expect(resolved.codec == .mp4a)
        if case .mp4Audio = resolved.codecConfiguration {
        } else {
            Issue.record("expected .mp4Audio")
        }
    }

    @Test
    func resolvesAC3() throws {
        let entry = AC3SampleEntry(
            audioFields: Self.audio(),
            specificBox: SampleEntryComposerCodecSweepTests.makeAC3()
        )
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        #expect(resolved.codec == .ac3)
    }

    @Test
    func resolvesEC3() throws {
        let entry = EC3SampleEntry(
            audioFields: Self.audio(),
            specificBox: Self.makeEC3()
        )
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        #expect(resolved.codec == .ec3)
    }

    @Test
    func resolvesAC4() throws {
        let entry = AC4SampleEntry(
            audioFields: Self.audio(),
            specificBox: AC4SpecificBox(bitstreamVersion: 2, presentations: [])
        )
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        #expect(resolved.codec == .ac4)
    }

    @Test
    func resolvesOpus() throws {
        let entry = OpusSampleEntry(
            audioFields: Self.audio(),
            specificBox: OpusSpecificBox(
                outputChannelCount: 2,
                preSkip: 312,
                inputSampleRate: 48_000,
                outputGainQ78: 0,
                channelMappingFamily: .rtpMonoStereo
            )
        )
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        #expect(resolved.codec == .opus)
    }

    @Test
    func resolvesFLAC() throws {
        let streamInfo = Data(repeating: 0, count: 34)
        let entry = FLACSampleEntry(
            audioFields: Self.audio(),
            specificBox: FLACSpecificBox(
                metadataBlocks: [
                    FLACSpecificBox.FLACMetadataBlock(
                        isLast: true,
                        blockType: .streamInfo,
                        blockData: streamInfo
                    )
                ]
            )
        )
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        #expect(resolved.codec == .flac)
    }

    @Test
    func resolvesMPEGHMain() throws {
        let entry = MPEGHAudioSampleEntry(
            audioFields: Self.audio(),
            configuration: Self.makeMPEGH()
        )
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        #expect(resolved.codec == .mpegHMain)
    }

    @Test
    func resolvesMPEGHMultiStream() throws {
        let entry = MPEGHAudioSampleEntryMultiStream(
            audioFields: Self.audio(),
            configuration: Self.makeMPEGH()
        )
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        #expect(resolved.codec == .mpegHMultiStream)
    }

    // MARK: - Encrypted-arm coverage for each original format

    @Test
    func resolvesEncryptedMP4A() throws {
        try assertEncryptedOriginal(format: "mp4a", expected: .mp4a)
    }

    @Test
    func resolvesEncryptedAC3() throws {
        try assertEncryptedOriginal(format: "ac-3", expected: .ac3)
    }

    @Test
    func resolvesEncryptedEC3() throws {
        try assertEncryptedOriginal(format: "ec-3", expected: .ec3)
    }

    @Test
    func resolvesEncryptedAC4() throws {
        try assertEncryptedOriginal(format: "ac-4", expected: .ac4)
    }

    @Test
    func resolvesEncryptedOpus() throws {
        try assertEncryptedOriginal(format: "Opus", expected: .opus)
    }

    @Test
    func resolvesEncryptedFLAC() throws {
        try assertEncryptedOriginal(format: "fLaC", expected: .flac)
    }

    @Test
    func resolvesEncryptedMHM1() throws {
        try assertEncryptedOriginal(format: "mhm1", expected: .mpegHMain)
    }

    @Test
    func resolvesEncryptedMHM2() throws {
        try assertEncryptedOriginal(format: "mhm2", expected: .mpegHMultiStream)
    }

    @Test
    func resolvesEncryptedUnknownFourCCFallsBackToMP4A() throws {
        // Unknown original format inside enca: resolver falls back
        // to mp4a per the default arm.
        try assertEncryptedOriginal(format: "xxxx", expected: .mp4a)
    }

    @Test
    func nonAudioEntryThrows() {
        let entry = AVCSampleEntry(
            visualFields: VisualSampleEntryFields(
                dataReferenceIndex: 1, width: 100, height: 100
            ),
            configuration: SampleEntryComposerCodecSweepTests.makeAVCConfig()
        )
        #expect(throws: CMAFReaderError.self) {
            _ = try AudioSampleEntryResolver.resolve(entry: entry)
        }
    }

    // MARK: - Encryption-parameters reconstruction

    @Test
    func encryptionParametersRecoveredFromSinf() throws {
        let entry = encryptedEntry(format: "mp4a")
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        let params = resolved.encryptionParameters(psshBoxes: [])
        try #require(params != nil)
        #expect(params?.scheme == .cenc)
    }

    // MARK: - Helpers

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

    private static func makeMPEGH() -> MPEGHConfigurationBox {
        MPEGHConfigurationBox(
            profileLevelIndication: .lcProfileLevel1,
            referenceChannelLayout: 2,
            mpegh3daConfig: Data([0x00])
        )
    }

    private func encryptedEntry(format: FourCC) -> EncryptedAudioSampleEntry {
        EncryptedAudioSampleEntry(
            audioFields: Self.audio(),
            originalCodecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
            protectionSchemeInfo: ProtectionSchemeInfoBox(
                originalFormat: OriginalFormatBox(dataFormat: format),
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
    }

    private func assertEncryptedOriginal(
        format: FourCC,
        expected: AudioCodec
    ) throws {
        let entry = encryptedEntry(format: format)
        let resolved = try AudioSampleEntryResolver.resolve(entry: entry)
        #expect(resolved.codec == expected)
        #expect(resolved.protectionSchemeInfo != nil)
    }
}

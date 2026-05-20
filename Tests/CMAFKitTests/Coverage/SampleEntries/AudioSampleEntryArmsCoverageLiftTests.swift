// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage lift for the audio sample-entry round-trips. Each codec
// arm (ec3 / ac4 / opus / flac / mhm1 / mhm2) is exercised through
// the registry parser path; encrypted variants exercise
// ``EncryptedAudioSampleEntry`` and its codec-config dispatch.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Audio sample entries — codec arms coverage lift")
struct AudioSampleEntryArmsCoverageLiftTests {

    private static func audio() -> AudioSampleEntryFields {
        AudioSampleEntryFields(
            dataReferenceIndex: 1,
            channelCount: 2,
            sampleSize: 16,
            sampleRate: 48_000 << 16
        )
    }

    private func roundTrip<E: SampleEntry>(_ entry: E) async throws -> E {
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? E)
    }

    @Test
    func ec3SampleEntryRoundTrip() async throws {
        let entry = EC3SampleEntry(
            audioFields: Self.audio(),
            specificBox: Self.makeEC3()
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.specificBox.dataRate == entry.specificBox.dataRate)
    }

    @Test
    func ac4SampleEntryRoundTrip() async throws {
        let entry = AC4SampleEntry(
            audioFields: Self.audio(),
            specificBox: AC4SpecificBox(bitstreamVersion: 2, presentations: [])
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.specificBox.bitstreamVersion == 2)
    }

    @Test
    func opusSampleEntryRoundTrip() async throws {
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
        let parsed = try await roundTrip(entry)
        #expect(parsed.specificBox.preSkip == 312)
    }

    @Test
    func flacSampleEntryRoundTrip() async throws {
        let entry = FLACSampleEntry(
            audioFields: Self.audio(),
            specificBox: FLACSpecificBox(
                metadataBlocks: [
                    FLACSpecificBox.FLACMetadataBlock(
                        isLast: true,
                        blockType: .streamInfo,
                        blockData: Data(repeating: 0, count: 34)
                    )
                ]
            )
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.specificBox.metadataBlocks.count == 1)
    }

    @Test
    func mpegHMainSampleEntryRoundTrip() async throws {
        let entry = MPEGHAudioSampleEntry(
            audioFields: Self.audio(),
            configuration: Self.makeMPEGH()
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.configuration.profileLevelIndication == .lcProfileLevel1)
    }

    @Test
    func mpegHMultiStreamSampleEntryRoundTrip() async throws {
        let entry = MPEGHAudioSampleEntryMultiStream(
            audioFields: Self.audio(),
            configuration: Self.makeMPEGH()
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.configuration.profileLevelIndication == .lcProfileLevel1)
    }

    // MARK: - Encrypted variants

    private func roundTripEncrypted(
        original: FourCC,
        config: AudioCodecConfiguration
    ) async throws -> EncryptedAudioSampleEntry {
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: original),
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
            audioFields: Self.audio(),
            originalCodecConfiguration: config,
            protectionSchemeInfo: sinf
        )
        return try await roundTrip(entry)
    }

    @Test
    func encryptedEC3RoundTrip() async throws {
        let parsed = try await roundTripEncrypted(
            original: "ec-3", config: .ec3(Self.makeEC3())
        )
        #expect(parsed.protectionSchemeInfo.originalFormat.dataFormat == "ec-3")
        if case .ec3 = parsed.originalCodecConfiguration {
        } else {
            Issue.record("expected .ec3 config")
        }
    }

    @Test
    func encryptedAC4RoundTrip() async throws {
        let parsed = try await roundTripEncrypted(
            original: "ac-4",
            config: .ac4(AC4SpecificBox(bitstreamVersion: 2, presentations: []))
        )
        if case .ac4 = parsed.originalCodecConfiguration {
        } else {
            Issue.record("expected .ac4 config")
        }
    }

    @Test
    func encryptedOpusRoundTrip() async throws {
        let parsed = try await roundTripEncrypted(
            original: "Opus",
            config: .opus(
                OpusSpecificBox(
                    outputChannelCount: 2,
                    preSkip: 312,
                    inputSampleRate: 48_000,
                    outputGainQ78: 0,
                    channelMappingFamily: .rtpMonoStereo
                )
            )
        )
        if case .opus = parsed.originalCodecConfiguration {
        } else {
            Issue.record("expected .opus config")
        }
    }

    @Test
    func encryptedFLACRoundTrip() async throws {
        let parsed = try await roundTripEncrypted(
            original: "fLaC",
            config: .flac(
                FLACSpecificBox(
                    metadataBlocks: [
                        FLACSpecificBox.FLACMetadataBlock(
                            isLast: true,
                            blockType: .streamInfo,
                            blockData: Data(repeating: 0, count: 34)
                        )
                    ]
                )
            )
        )
        if case .flac = parsed.originalCodecConfiguration {
        } else {
            Issue.record("expected .flac config")
        }
    }

    @Test
    func encryptedMPEGHRoundTrip() async throws {
        let parsed = try await roundTripEncrypted(
            original: "mhm1", config: .mpegH(Self.makeMPEGH())
        )
        if case .mpegH = parsed.originalCodecConfiguration {
        } else {
            Issue.record("expected .mpegH config")
        }
    }

    @Test
    func encryptedAC3RoundTrip() async throws {
        let parsed = try await roundTripEncrypted(
            original: "ac-3",
            config: .ac3(SampleEntryComposerCodecSweepTests.makeAC3())
        )
        if case .ac3 = parsed.originalCodecConfiguration {
        } else {
            Issue.record("expected .ac3 config")
        }
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
}

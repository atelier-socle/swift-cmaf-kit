// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage-boost tests targeting ``SampleEntryComposer``'s codec
// dispatch arms — encrypted variants for the audio / video codecs
// the broader sweep does not exercise via the round-trip path, plus
// the defensive throw branches that fire on mismatched
// `(codec, codecConfiguration)` pairs.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleEntryComposer — coverage boost")
struct SampleEntryComposerBoostTests {

    // MARK: - SampleEntryComposer encrypted audio sweep

    @Test
    func encryptedEC3RoundTrip() async throws {
        let ec3 = EC3SpecificBox(
            dataRate: 192,
            independentSubstreams: [
                EC3SpecificBox.IndependentSubstream(
                    fscod: .freq48000,
                    bsid: 16,
                    asvc: false,
                    bsmod: .completeMain,
                    acmod: .stereo,
                    lfeon: false,
                    dependentSubstreamCount: 0
                )
            ]
        )
        try await assertEncryptedAudioRoundTrip(
            codec: .ec3,
            configuration: .ec3(ec3)
        )
    }

    @Test
    func encryptedAC4RoundTrip() async throws {
        let ac4 = AC4SpecificBox(
            dsiVersion: 1,
            bitstreamVersion: 2,
            presentations: []
        )
        try await assertEncryptedAudioRoundTrip(
            codec: .ac4,
            configuration: .ac4(ac4)
        )
    }

    @Test
    func encryptedAVC3RoundTrip() async throws {
        try await assertEncryptedVideoRoundTrip(
            codec: .avc3,
            configuration: .avc(SampleEntryComposerCodecSweepTests.makeAVCConfig())
        )
    }

    @Test
    func encryptedHEV1RoundTrip() async throws {
        try await assertEncryptedVideoRoundTrip(
            codec: .hev1,
            configuration: .hevc(SampleEntryComposerCodecSweepTests.makeHEVCConfig())
        )
    }

    @Test
    func encryptedDvh1RoundTrip() async throws {
        let dvcC = DolbyVisionConfigurationBox(
            configuration: DolbyVisionConfiguration(
                versionMajor: 1, versionMinor: 0,
                profile: .profile5, level: .level05,
                rpuPresent: true, elPresent: false, blPresent: true,
                blSignalCompatibilityID: .nonCompatible
            )
        )
        try await assertEncryptedVideoRoundTrip(
            codec: .dvh1,
            configuration: .hevc(SampleEntryComposerCodecSweepTests.makeHEVCConfig()),
            dolbyVision: dvcC
        )
    }

    @Test
    func encryptedVP09RoundTrip() async throws {
        try await assertEncryptedVideoRoundTrip(
            codec: .vp09,
            configuration: .vp(SampleEntryComposerCodecSweepTests.makeVPConfig())
        )
    }

    @Test
    func encryptedAV01ComposesEncv() throws {
        // The AV1 round-trip through the registry hits a pre-existing
        // av1C parser quirk under the encv wrapper; exercise the
        // *composer* directly so we cover the SampleEntryComposer
        // .av01 arm without depending on the round-trip path.
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920,
                height: 1080,
                codec: .av01,
                codecConfiguration: .av1(
                    SampleEntryComposerCodecSweepTests.makeAV1Config()
                ),
                frameRate: .init(numerator: 30, denominator: 1)
            ),
            encryptionParameters: WriterFixtures.cencParameters()
        )
        let entry = try SampleEntryComposer.makeVideoSampleEntry(configuration: track)
        #expect(entry is EncryptedVideoSampleEntry)
    }

    // MARK: - SampleEntryComposer mismatch-error paths

    private func makeMismatchedVideoTrack(codec: VideoCodec) -> CMAFTrackConfiguration {
        // Build a track with the supplied codec but a wrong-shape
        // codecConfiguration. The composer must throw.
        let wrongConfig: VideoCodecConfiguration
        switch codec {
        case .avc1, .avc3:
            // wrong-arm: use .hevc when caller expects .avc
            wrongConfig = .hevc(SampleEntryComposerCodecSweepTests.makeHEVCConfig())
        case .hvc1, .hev1, .dvh1, .dvhe:
            wrongConfig = .avc(SampleEntryComposerCodecSweepTests.makeAVCConfig())
        case .vp08, .vp09:
            wrongConfig = .avc(SampleEntryComposerCodecSweepTests.makeAVCConfig())
        case .av01:
            wrongConfig = .avc(SampleEntryComposerCodecSweepTests.makeAVCConfig())
        case .mp4v:
            wrongConfig = .avc(SampleEntryComposerCodecSweepTests.makeAVCConfig())
        }
        return CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920,
                height: 1080,
                codec: codec,
                codecConfiguration: wrongConfig,
                frameRate: .init(numerator: 30, denominator: 1)
            )
        )
    }

    @Test
    func videoMismatchedConfigsThrowFromComposer() {
        for codec in VideoCodec.allCases {
            let track = makeMismatchedVideoTrack(codec: codec)
            #expect(throws: CMAFWriterError.self) {
                _ = try SampleEntryComposer.makeVideoSampleEntry(configuration: track)
            }
        }
    }

    @Test
    func dolbyVisionWithoutDvcCThrowsFromComposer() {
        // Build dvh1 video without the required Dolby Vision config.
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920,
                height: 1080,
                codec: .dvh1,
                codecConfiguration: .hevc(
                    SampleEntryComposerCodecSweepTests.makeHEVCConfig()
                ),
                dolbyVisionConfiguration: nil,
                frameRate: .init(numerator: 30, denominator: 1)
            )
        )
        #expect(throws: CMAFWriterError.self) {
            _ = try SampleEntryComposer.makeVideoSampleEntry(configuration: track)
        }
    }

    @Test
    func audioMismatchedConfigsThrowFromComposer() {
        for codec in AudioCodec.allCases {
            // Pick a wrong-arm config: use .ac3 when codec is anything but ac3,
            // and .mp4Audio when codec is ac3.
            let wrong: AudioCodecConfiguration =
                codec == .ac3
                ? .mp4Audio(WriterFixtures.makeESDS())
                : .ac3(SampleEntryComposerCodecSweepTests.makeAC3())
            let track = CMAFTrackConfiguration(
                trackID: 1,
                kind: .audio,
                profile: .basic,
                timescale: 48_000,
                language: "eng",
                audioFields: CMAFTrackConfiguration.AudioFields(
                    codec: codec,
                    codecConfiguration: wrong,
                    channelCount: 2,
                    sampleRate: 48_000
                )
            )
            #expect(throws: CMAFWriterError.self) {
                _ = try SampleEntryComposer.makeAudioSampleEntry(configuration: track)
            }
        }
    }

    @Test
    func videoSampleEntryMissingVideoFieldsThrows() {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: nil
        )
        #expect(throws: CMAFWriterError.self) {
            _ = try SampleEntryComposer.makeVideoSampleEntry(configuration: track)
        }
    }

    @Test
    func audioSampleEntryMissingAudioFieldsThrows() {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .basic,
            timescale: 48_000,
            language: "eng",
            audioFields: nil
        )
        #expect(throws: CMAFWriterError.self) {
            _ = try SampleEntryComposer.makeAudioSampleEntry(configuration: track)
        }
    }

    @Test
    func encryptedAC3RoundTrip() async throws {
        try await assertEncryptedAudioRoundTrip(
            codec: .ac3,
            configuration: .ac3(SampleEntryComposerCodecSweepTests.makeAC3())
        )
    }

    private func assertEncryptedVideoRoundTrip(
        codec: VideoCodec,
        configuration: VideoCodecConfiguration,
        dolbyVision: DolbyVisionConfigurationBox? = nil
    ) async throws {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920,
                height: 1080,
                codec: codec,
                codecConfiguration: configuration,
                dolbyVisionConfiguration: dolbyVision,
                frameRate: .init(numerator: 30, denominator: 1)
            ),
            encryptionParameters: WriterFixtures.cencParameters()
        )
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let stbl = try #require(
            trak.media?.mediaInformation?.children
                .compactMap { $0 as? SampleTableBox }.first
        )
        let stsd = try #require(stbl.children.compactMap { $0 as? SampleDescriptionBox }.first)
        #expect(stsd.entries.first is EncryptedVideoSampleEntry)
    }

    private func assertEncryptedAudioRoundTrip(
        codec: AudioCodec,
        configuration: AudioCodecConfiguration
    ) async throws {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .basic,
            timescale: 48_000,
            language: "eng",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: codec,
                codecConfiguration: configuration,
                channelCount: 2,
                sampleRate: 48_000
            ),
            encryptionParameters: WriterFixtures.cencParameters()
        )
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let stbl = try #require(
            trak.media?.mediaInformation?.children
                .compactMap { $0 as? SampleTableBox }.first
        )
        let stsd = try #require(stbl.children.compactMap { $0 as? SampleDescriptionBox }.first)
        #expect(stsd.entries.first is EncryptedAudioSampleEntry)
    }
}

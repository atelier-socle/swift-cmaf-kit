// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Codec-by-codec round-trip sweep through the reader path. The
// companion writer test ``SampleEntryComposerCodecSweepTests``
// validates each codec arm of ``SampleEntryComposer``; this suite
// reverses the path and validates each arm of
// ``VideoSampleEntryResolver`` / ``AudioSampleEntryResolver`` /
// ``CMAFTrackResolver``.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Reader — codec sweep")
struct ReaderCodecSweepTests {

    // MARK: - Video arms

    @Test func recoversAVC1() async throws {
        let recovered = try await emitVideoAndRecover(
            codec: .avc1,
            configuration: .avc(SampleEntryComposerCodecSweepTests.makeAVCConfig())
        )
        #expect(recovered.videoFields?.codec == .avc1)
        if case .avc = recovered.videoFields?.codecConfiguration {
        } else {
            Issue.record("expected .avc")
        }
    }

    @Test func recoversAVC3() async throws {
        let recovered = try await emitVideoAndRecover(
            codec: .avc3,
            configuration: .avc(SampleEntryComposerCodecSweepTests.makeAVCConfig())
        )
        #expect(recovered.videoFields?.codec == .avc3)
    }

    @Test func recoversHVC1() async throws {
        let recovered = try await emitVideoAndRecover(
            codec: .hvc1,
            configuration: .hevc(SampleEntryComposerCodecSweepTests.makeHEVCConfig())
        )
        #expect(recovered.videoFields?.codec == .hvc1)
    }

    @Test func recoversHEV1() async throws {
        let recovered = try await emitVideoAndRecover(
            codec: .hev1,
            configuration: .hevc(SampleEntryComposerCodecSweepTests.makeHEVCConfig())
        )
        #expect(recovered.videoFields?.codec == .hev1)
    }

    @Test func recoversVP08() async throws {
        let recovered = try await emitVideoAndRecover(
            codec: .vp08,
            configuration: .vp(SampleEntryComposerCodecSweepTests.makeVPConfig())
        )
        #expect(recovered.videoFields?.codec == .vp08)
    }

    @Test func recoversVP09() async throws {
        let recovered = try await emitVideoAndRecover(
            codec: .vp09,
            configuration: .vp(SampleEntryComposerCodecSweepTests.makeVPConfig())
        )
        #expect(recovered.videoFields?.codec == .vp09)
    }

    @Test func recoversAV01() async throws {
        let recovered = try await emitVideoAndRecover(
            codec: .av01,
            configuration: .av1(SampleEntryComposerCodecSweepTests.makeAV1Config())
        )
        #expect(recovered.videoFields?.codec == .av01)
    }

    @Test func recoversMP4V() async throws {
        let recovered = try await emitVideoAndRecover(
            codec: .mp4v,
            configuration: .mp4Visual(WriterFixtures.makeESDS())
        )
        #expect(recovered.videoFields?.codec == .mp4v)
    }

    @Test func recoversEncryptedVideo() async throws {
        let recovered = try await emitVideoAndRecover(
            codec: .avc1,
            configuration: .avc(SampleEntryComposerCodecSweepTests.makeAVCConfig()),
            encrypted: WriterFixtures.cencParameters()
        )
        #expect(recovered.encryptionParameters?.scheme == .cenc)
    }

    // MARK: - Audio arms

    @Test func recoversMP4A() async throws {
        let recovered = try await emitAudioAndRecover(
            codec: .mp4a,
            configuration: .mp4Audio(WriterFixtures.makeESDS())
        )
        #expect(recovered.audioFields?.codec == .mp4a)
    }

    @Test func recoversAC3() async throws {
        let recovered = try await emitAudioAndRecover(
            codec: .ac3,
            configuration: .ac3(SampleEntryComposerCodecSweepTests.makeAC3())
        )
        #expect(recovered.audioFields?.codec == .ac3)
    }

    @Test func recoversEncryptedAudio() async throws {
        let recovered = try await emitAudioAndRecover(
            codec: .mp4a,
            configuration: .mp4Audio(WriterFixtures.makeESDS()),
            encrypted: WriterFixtures.cencParameters()
        )
        #expect(recovered.encryptionParameters?.scheme == .cenc)
    }

    // MARK: - Subtitle + metadata

    @Test func recoversWebVTTSubtitle() async throws {
        let recovered = try await emitSubtitleAndRecover(codec: .webVTT)
        #expect(recovered.kind == .subtitle)
    }

    @Test func recoversIMSC1TextSubtitle() async throws {
        let recovered = try await emitSubtitleAndRecover(codec: .imsc1Text)
        #expect(recovered.kind == .subtitle)
    }

    @Test func recoversID3Metadata() async throws {
        let recovered = try await emitMetadataAndRecover(metadataType: .id3)
        #expect(recovered.kind == .metadata)
    }

    @Test func recoversKLVMetadata() async throws {
        let recovered = try await emitMetadataAndRecover(metadataType: .klv)
        #expect(recovered.kind == .metadata)
    }

    @Test func recoversURIMetadata() async throws {
        let recovered = try await emitMetadataAndRecover(
            metadataType: .uri("urn:test:scheme")
        )
        #expect(recovered.kind == .metadata)
    }

    @Test func recoversTimedTextMetadata() async throws {
        let recovered = try await emitMetadataAndRecover(metadataType: .timedText)
        #expect(recovered.kind == .metadata)
    }

    // MARK: - Helpers

    private func emitVideoAndRecover(
        codec: VideoCodec,
        configuration: VideoCodecConfiguration,
        encrypted: CMAFEncryptionParameters? = nil
    ) async throws -> CMAFTrackConfiguration {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920, height: 1080,
                codec: codec, codecConfiguration: configuration,
                frameRate: .init(numerator: 30, denominator: 1)
            ),
            encryptionParameters: encrypted
        )
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        return try #require(reader.tracks().first)
    }

    private func emitAudioAndRecover(
        codec: AudioCodec,
        configuration: AudioCodecConfiguration,
        encrypted: CMAFEncryptionParameters? = nil
    ) async throws -> CMAFTrackConfiguration {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .basic,
            timescale: 48_000,
            language: "eng",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: codec, codecConfiguration: configuration,
                channelCount: 2, sampleRate: 48_000
            ),
            encryptionParameters: encrypted
        )
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        return try #require(reader.tracks().first)
    }

    private func emitSubtitleAndRecover(
        codec: SubtitleCodec
    ) async throws -> CMAFTrackConfiguration {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .subtitle,
            profile: .basic,
            timescale: 1000,
            language: "eng",
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: codec, language: "eng"
            )
        )
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        return try #require(reader.tracks().first)
    }

    private func emitMetadataAndRecover(
        metadataType: MetadataType
    ) async throws -> CMAFTrackConfiguration {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .metadata,
            profile: .basic,
            timescale: 1000,
            language: "und",
            metadataFields: CMAFTrackConfiguration.MetadataFields(
                handlerType: "meta",
                metadataType: metadataType
            )
        )
        let writer = try CMAFInitSegmentWriter(configurations: [track])
        let bytes = try writer.emit()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        return try #require(reader.tracks().first)
    }
}

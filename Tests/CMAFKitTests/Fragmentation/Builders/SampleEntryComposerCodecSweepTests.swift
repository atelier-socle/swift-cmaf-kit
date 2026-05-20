// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

/// Codec-by-codec round-trip sweep: every supported video and audio
/// codec is composed via ``SampleEntryComposer``, emitted into a
/// minimal init segment, parsed back through `BoxRegistry`, and
/// checked for the correct sample-entry type.
@Suite("SampleEntryComposer — codec sweep")
struct SampleEntryComposerCodecSweepTests {

    // MARK: - Video sweep

    @Test
    func avc1RoundTrip() async throws {
        let entry = try await emitAndParseVideo(codec: .avc1)
        #expect(entry is AVCSampleEntry)
    }

    @Test
    func avc3RoundTrip() async throws {
        let entry = try await emitAndParseVideo(codec: .avc3)
        #expect(entry is AVCSampleEntryInband)
    }

    @Test
    func hvc1RoundTrip() async throws {
        let entry = try await emitAndParseVideo(
            codec: .hvc1, configuration: .hevc(Self.makeHEVCConfig())
        )
        #expect(entry is HEVCSampleEntry)
    }

    @Test
    func hev1RoundTrip() async throws {
        let entry = try await emitAndParseVideo(
            codec: .hev1, configuration: .hevc(Self.makeHEVCConfig())
        )
        #expect(entry is HEVCSampleEntryInband)
    }

    @Test
    func dvh1RoundTrip() async throws {
        let dvcC = DolbyVisionConfigurationBox(
            configuration: DolbyVisionConfiguration(
                versionMajor: 1,
                versionMinor: 0,
                profile: .profile5,
                level: .level05,
                rpuPresent: true,
                elPresent: false,
                blPresent: true,
                blSignalCompatibilityID: .nonCompatible
            )
        )
        let entry = try await emitAndParseVideo(
            codec: .dvh1,
            configuration: .hevc(Self.makeHEVCConfig()),
            dolbyVision: dvcC
        )
        #expect(entry is DolbyVisionHEVCSampleEntry)
    }

    @Test
    func dvheRoundTrip() async throws {
        let dvcC = DolbyVisionConfigurationBox(
            configuration: DolbyVisionConfiguration(
                versionMajor: 1,
                versionMinor: 0,
                profile: .profile8(subProfile: .hdr10Compatible),
                level: .level05,
                rpuPresent: true,
                elPresent: false,
                blPresent: true,
                blSignalCompatibilityID: .hdr10Compatible
            )
        )
        let entry = try await emitAndParseVideo(
            codec: .dvhe,
            configuration: .hevc(Self.makeHEVCConfig()),
            dolbyVision: dvcC
        )
        #expect(entry is DolbyVisionHEVCSampleEntryInband)
    }

    @Test
    func vp08RoundTrip() async throws {
        let entry = try await emitAndParseVideo(
            codec: .vp08, configuration: .vp(Self.makeVPConfig())
        )
        #expect(entry is VP8SampleEntry)
    }

    @Test
    func vp09RoundTrip() async throws {
        let entry = try await emitAndParseVideo(
            codec: .vp09, configuration: .vp(Self.makeVPConfig())
        )
        #expect(entry is VP9SampleEntry)
    }

    @Test
    func av01RoundTrip() async throws {
        let entry = try await emitAndParseVideo(
            codec: .av01, configuration: .av1(Self.makeAV1Config())
        )
        #expect(entry is AV1SampleEntry)
    }

    @Test
    func mp4vRoundTrip() async throws {
        let entry = try await emitAndParseVideo(
            codec: .mp4v, configuration: .mp4Visual(WriterFixtures.makeESDS())
        )
        #expect(entry is MP4VisualSampleEntry)
    }

    // MARK: - Audio sweep

    @Test
    func mp4aRoundTrip() async throws {
        let entry = try await emitAndParseAudio(
            codec: .mp4a, configuration: .mp4Audio(WriterFixtures.makeESDS())
        )
        #expect(entry is MP4AudioSampleEntry)
    }

    @Test
    func ac3RoundTrip() async throws {
        let entry = try await emitAndParseAudio(
            codec: .ac3, configuration: .ac3(Self.makeAC3())
        )
        #expect(entry is AC3SampleEntry)
    }

    // MARK: - Encrypted variants

    @Test
    func encryptedAVCEmitsEncv() async throws {
        let entry = try await emitAndParseVideo(
            codec: .avc1,
            encrypted: WriterFixtures.cencParameters()
        )
        #expect(entry is EncryptedVideoSampleEntry)
    }

    @Test
    func encryptedHEVCEmitsEncv() async throws {
        let entry = try await emitAndParseVideo(
            codec: .hvc1,
            configuration: .hevc(Self.makeHEVCConfig()),
            encrypted: WriterFixtures.cencParameters()
        )
        #expect(entry is EncryptedVideoSampleEntry)
    }

    @Test
    func encryptedAACEmitsEnca() async throws {
        let entry = try await emitAndParseAudio(
            codec: .mp4a,
            configuration: .mp4Audio(WriterFixtures.makeESDS()),
            encrypted: WriterFixtures.cencParameters()
        )
        #expect(entry is EncryptedAudioSampleEntry)
    }

    // MARK: - Subtitle sweep

    @Test
    func webVTTRoundTrip() async throws {
        let entry = try await emitAndParseSubtitle(codec: .webVTT)
        #expect(entry is WebVTTSampleEntry)
    }

    @Test
    func imsc1TextRoundTrip() async throws {
        let entry = try await emitAndParseSubtitle(codec: .imsc1Text)
        #expect(entry is XMLSubtitleSampleEntry)
    }

    @Test
    func imsc1ImageRoundTrip() async throws {
        let entry = try await emitAndParseSubtitle(codec: .imsc1Image)
        #expect(entry is XMLSubtitleSampleEntry)
    }

    // MARK: - Metadata sweep

    @Test
    func id3MetadataRoundTrip() async throws {
        let entry = try await emitAndParseMetadata(metadataType: .id3)
        #expect(entry is ID3SampleEntry)
    }

    @Test
    func klvMetadataRoundTrip() async throws {
        let entry = try await emitAndParseMetadata(metadataType: .klv)
        #expect(entry is TextMetadataSampleEntry)
    }

    @Test
    func timedTextMetadataRoundTrip() async throws {
        let entry = try await emitAndParseMetadata(metadataType: .timedText)
        #expect(entry is TextMetadataSampleEntry)
    }

    @Test
    func uriMetadataRoundTrip() async throws {
        let entry = try await emitAndParseMetadata(
            metadataType: .uri("urn:custom:scheme")
        )
        #expect(entry is URIMetadataSampleEntry)
    }

    // MARK: - Helpers

    private func emitAndParseVideo(
        codec: VideoCodec,
        configuration: VideoCodecConfiguration? = nil,
        dolbyVision: DolbyVisionConfigurationBox? = nil,
        encrypted: CMAFEncryptionParameters? = nil
    ) async throws -> any SampleEntry {
        let cfg = configuration ?? .avc(Self.makeAVCConfig())
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
                codecConfiguration: cfg,
                dolbyVisionConfiguration: dolbyVision,
                frameRate: .init(numerator: 30, denominator: 1)
            ),
            encryptionParameters: encrypted
        )
        return try await firstStsdEntry(in: [track])
    }

    private func emitAndParseAudio(
        codec: AudioCodec,
        configuration: AudioCodecConfiguration,
        encrypted: CMAFEncryptionParameters? = nil
    ) async throws -> any SampleEntry {
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
            encryptionParameters: encrypted
        )
        return try await firstStsdEntry(in: [track])
    }

    private func emitAndParseSubtitle(codec: SubtitleCodec) async throws -> any SampleEntry {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .subtitle,
            profile: .basic,
            timescale: 1000,
            language: "eng",
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: codec,
                language: "eng"
            )
        )
        return try await firstStsdEntry(in: [track])
    }

    private func emitAndParseMetadata(metadataType: MetadataType) async throws -> any SampleEntry {
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
        return try await firstStsdEntry(in: [track])
    }

    private func firstStsdEntry(
        in tracks: [CMAFTrackConfiguration]
    ) async throws -> any SampleEntry {
        let writer = try CMAFInitSegmentWriter(configurations: tracks)
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
        return try #require(stsd.entries.first)
    }

    // MARK: - Codec config factories

    internal static func makeAVCConfig() -> AVCDecoderConfigurationRecord {
        AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0xE0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))],
            pictureParameterSets: [AVCParameterSet(rbspBytes: Data([0x68, 0xCE, 0x3C, 0x80]))]
        )
    }

    internal static func makeHEVCConfig() -> HEVCDecoderConfigurationRecord {
        HEVCDecoderConfigurationRecord(
            configurationVersion: 1,
            profileSpace: .zero,
            tierFlag: .main,
            profileIDC: .main,
            profileCompatibilityFlags: HEVCProfileCompatibilityFlags(rawValue: 0x6000_0000),
            constraintIndicatorFlags: HEVCConstraintIndicatorFlags(rawValueBigEndian: 0),
            levelIDC: .level4,
            minSpatialSegmentationIDC: 0,
            parallelismType: .mixedOrUnknown,
            chromaFormat: .format420,
            bitDepthLuma: 8,
            bitDepthChroma: 8,
            avgFrameRate: 0,
            constantFrameRate: .unknown,
            numTemporalLayers: 1,
            temporalIdNested: false,
            lengthSize: .fourBytes,
            parameterSetArrays: []
        )
    }

    internal static func makeVPConfig() -> VPCodecConfigurationRecord {
        VPCodecConfigurationRecord(
            profile: .profile0,
            level: .level40,
            bitDepth: 8,
            chromaSubsampling: .format420Vertical,
            videoFullRangeFlag: .limited,
            colourPrimaries: .bt709,
            transferCharacteristics: .bt709,
            matrixCoefficients: .bt709
        )
    }

    internal static func makeAV1Config() -> AV1CodecConfigurationRecord {
        AV1CodecConfigurationRecord(
            seqProfile: .main,
            seqLevelIdx0: .level4_0,
            seqTier0: .main,
            highBitdepth: false,
            twelveBit: false,
            monochrome: false,
            chromaSubsamplingX: true,
            chromaSubsamplingY: true,
            chromaSamplePosition: .unknown
        )
    }

    internal static func makeAC3() -> AC3SpecificBox {
        AC3SpecificBox(
            fscod: .freq48000,
            bsid: 8,
            bsmod: .completeMain,
            acmod: .stereo,
            lfeon: false,
            bitRateCode: 6
        )
    }
}

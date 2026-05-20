// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Reader-side round-trip scenarios 1 through 10 — the S10c writer
// scenarios reversed: emit through writer, parse back through the
// reader actor stack, assert per-sample byte equivalence.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Reader round-trip scenarios 1-10")
struct ReaderRoundTripScenarios01to10Tests {

    // MARK: - 1. AVC SDR 1080p stereo AAC LC, basic CMAF, 6s fragments

    @Test
    func scenario01_readBack_avc_sdr_1080p_stereo_aac() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let samples = RoundTripFixtures.videoSamples(count: 8)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(
                configuration: video,
                samples: samples,
                fragmentBoundary: .durationSeconds(6.0)
            )
        )
        RoundTripAssertions.assertTrackShape(
            recovered: result.recoveredTracks, original: [video]
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
    }

    // MARK: - 2. HEVC HDR10 4K stereo AAC LC, fragmented, sidx-indexed

    @Test
    func scenario02_readBack_hevc_hdr10_4k_aac_sidx() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .hvc1,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig()),
            width: 3840,
            height: 2160,
            profile: .fragmented,
            colorInformation: EndToEndFixtures.bt2020PQ,
            masteringDisplay: EndToEndFixtures.mdcv,
            contentLightLevel: EndToEndFixtures.clli
        )
        let samples = RoundTripFixtures.videoSamples(count: 4)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(configuration: video, samples: samples, emitSegmentIndex: true)
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
        #expect(result.recoveredTracks.first?.videoFields?.codec == .hvc1)
    }

    // MARK: - 3. HEVC HDR10+ 4K 5.1 EC-3 LL-CMAF, 0.5s partial chunks

    @Test
    func scenario03_readBack_hevc_hdr10plus_4k_ec3_partial_chunks() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .hvc1,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig()),
            width: 3840,
            height: 2160,
            profile: .lowLatency,
            colorInformation: EndToEndFixtures.bt2020PQ
        )
        let samples = RoundTripFixtures.videoSamples(count: 6)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(
                configuration: video,
                samples: samples,
                partialChunkBoundary: .durationSeconds(0.5)
            )
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
    }

    // MARK: - 4. Dolby Vision Profile 8.1 (HDR10-compatible BL) + AAC LC, CMAF for HLS

    @Test
    func scenario04_readBack_dolbyVision_profile81_bl_aac() async throws {
        let dvcC = DolbyVisionConfigurationBox(
            configuration: DolbyVisionConfiguration(
                versionMajor: 1, versionMinor: 0,
                profile: .profile8(subProfile: .hdr10Compatible),
                level: .level05,
                rpuPresent: true, elPresent: false, blPresent: true,
                blSignalCompatibilityID: .hdr10Compatible
            )
        )
        let video = EndToEndFixtures.videoConfig(
            codec: .dvhe,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig()),
            profile: .hls,
            dolbyVisionConfiguration: dvcC
        )
        let samples = RoundTripFixtures.videoSamples(count: 4)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(configuration: video, samples: samples)
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
        #expect(result.recoveredTracks.first?.videoFields?.codec == .dvhe)
    }

    // MARK: - 5. Dolby Vision Profile 7 dual-layer + EC-3 Atmos, fragmented

    @Test
    func scenario05_readBack_dolbyVision_profile7_hevc_ec3_atmos() async throws {
        let dvcC = DolbyVisionConfigurationBox(
            configuration: DolbyVisionConfiguration(
                versionMajor: 1, versionMinor: 0,
                profile: .profile7, level: .level06,
                rpuPresent: true, elPresent: true, blPresent: true,
                blSignalCompatibilityID: .nonCompatible
            )
        )
        let video = EndToEndFixtures.videoConfig(
            codec: .dvhe,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig()),
            profile: .fragmented,
            dolbyVisionConfiguration: dvcC
        )
        let samples = RoundTripFixtures.videoSamples(count: 4)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(configuration: video, samples: samples)
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
    }

    // MARK: - 6. AV1 SDR 4K Opus mono, CMAF for DASH

    @Test
    func scenario06_readBack_av1_sdr_4k_opus_mono_dash() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .av01,
            codecConfiguration: .av1(EndToEndFixtures.makeAV1Config()),
            width: 3840,
            height: 2160,
            profile: .dash
        )
        let samples = RoundTripFixtures.videoSamples(count: 4)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(configuration: video, samples: samples, emitSegmentIndex: true)
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
        #expect(result.majorBrand == "cmfd")
    }

    // MARK: - 7. AV1 HDR10 PQ 4K Opus stereo, low-latency partial chunks

    @Test
    func scenario07_readBack_av1_hdr10pq_4k_opus_stereo_llcmaf() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .av01,
            codecConfiguration: .av1(EndToEndFixtures.makeAV1Config()),
            width: 3840,
            height: 2160,
            profile: .lowLatency,
            colorInformation: EndToEndFixtures.bt2020PQ
        )
        let samples = RoundTripFixtures.videoSamples(count: 4)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(
                configuration: video,
                samples: samples,
                partialChunkBoundary: .sampleCount(1)
            )
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
    }

    // MARK: - 8. VP9 SDR 1080p Opus 5.1, CMAF basic

    @Test
    func scenario08_readBack_vp9_sdr_1080p_opus_51_basic() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .vp09,
            codecConfiguration: .vp(EndToEndFixtures.makeVPConfig())
        )
        let samples = RoundTripFixtures.videoSamples(count: 4)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(configuration: video, samples: samples)
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
    }

    // MARK: - 9. WebVTT subtitle + 1080p HEVC + AAC LC, multi-track init

    @Test
    func scenario09_readBack_webVTT_subtitle_hevc_aac_multitrack_init() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .hvc1,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig())
        )
        let audio = EndToEndFixtures.audioConfig(
            codec: .mp4a,
            codecConfiguration: .mp4Audio(WriterFixtures.makeESDS())
        )
        let subtitle = CMAFTrackConfiguration(
            trackID: 3,
            kind: .subtitle,
            profile: .basic,
            timescale: 1000,
            language: "eng",
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: .webVTT, language: "eng"
            )
        )
        let initBytes = try CMAFInitSegmentWriter(
            configurations: [video, audio, subtitle]
        ).emit()
        let result = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: []
        )
        #expect(result.recoveredTracks.count == 3)
        let kinds = Set(result.recoveredTracks.map { $0.kind })
        #expect(kinds == [.video, .audio, .subtitle])
    }

    // MARK: - 10. IMSC1 text subtitle + dvh1 video + AC-3, CMAF for HLS

    @Test
    func scenario10_readBack_imsc1_text_dvh1_ac3_hls() async throws {
        let dvcC = DolbyVisionConfigurationBox(
            configuration: DolbyVisionConfiguration(
                versionMajor: 1, versionMinor: 0,
                profile: .profile5, level: .level05,
                rpuPresent: true, elPresent: false, blPresent: true,
                blSignalCompatibilityID: .nonCompatible
            )
        )
        let video = EndToEndFixtures.videoConfig(
            codec: .dvh1,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig()),
            profile: .hls,
            dolbyVisionConfiguration: dvcC
        )
        let audio = EndToEndFixtures.audioConfig(
            codec: .ac3,
            codecConfiguration: .ac3(EndToEndFixtures.makeAC3()),
            profile: .hls
        )
        let subtitle = CMAFTrackConfiguration(
            trackID: 3,
            kind: .subtitle,
            profile: .hls,
            timescale: 1000,
            language: "eng",
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: .imsc1Text, language: "eng"
            )
        )
        let initBytes = try CMAFInitSegmentWriter(
            configurations: [video, audio, subtitle]
        ).emit()
        let result = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: []
        )
        #expect(result.recoveredTracks.count == 3)
        let videoTrack = result.recoveredTracks.first { $0.kind == .video }
        #expect(videoTrack?.videoFields?.codec == .dvh1)
    }
}

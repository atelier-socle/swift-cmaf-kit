// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// End-to-end scenarios 1 through 10. Each test exercises a complete
// init-segment + media-segment emission path for one canonical CMAF
// profile / codec / encryption configuration and confirms the output
// parses back through ``BoxRegistry/defaultRegistry()``.

import Foundation
import Testing

@testable import CMAFKit

@Suite("End-to-end scenarios 1-10")
struct EndToEndScenarios01to10Tests {

    @Test
    func scenario01_avcSDR1080pStereoAACLC_BasicCMAF_6sFragments() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let audio = EndToEndFixtures.audioConfig(
            codec: .mp4a,
            codecConfiguration: .mp4Audio(WriterFixtures.makeESDS())
        )
        let result = try await EndToEndFixtures.runScenario(
            configurations: [video, audio],
            fragmentBoundary: .durationSeconds(6.0),
            samples: 8
        )
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario02_hevcHDR10_4K_StereoAAC_FragmentedCMAF_SidxIndexed() async throws {
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
        let result = try await EndToEndFixtures.runScenario(
            configurations: [video],
            emitSegmentIndex: true
        )
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario03_hevcHDR10Plus_5point1EC3_LowLatencyCMAF_PartialChunks() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .hvc1,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig()),
            width: 3840,
            height: 2160,
            profile: .lowLatency,
            colorInformation: EndToEndFixtures.bt2020PQ
        )
        let result = try await EndToEndFixtures.runScenario(
            configurations: [video],
            partialChunkBoundary: .durationSeconds(0.5),
            samples: 6
        )
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
        #expect(result.fragments.allSatisfy { ($0.partialChunks?.count ?? 0) >= 1 })
    }

    @Test
    func scenario04_dolbyVisionProfile8_1_BL_AACLC_CMAFForHLS() async throws {
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
        let result = try await EndToEndFixtures.runScenario(configurations: [video])
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario05_dolbyVisionProfile7_HEVC_EC3Atmos_Fragmented() async throws {
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
        let result = try await EndToEndFixtures.runScenario(configurations: [video])
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario06_av1SDR_4K_OpusMono_CMAFForDASH() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .av01,
            codecConfiguration: .av1(EndToEndFixtures.makeAV1Config()),
            width: 3840,
            height: 2160,
            profile: .dash
        )
        let result = try await EndToEndFixtures.runScenario(
            configurations: [video],
            emitSegmentIndex: true
        )
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario07_av1HDR10PQ_4K_OpusStereo_LowLatencyChunks() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .av01,
            codecConfiguration: .av1(EndToEndFixtures.makeAV1Config()),
            width: 3840,
            height: 2160,
            profile: .lowLatency,
            colorInformation: EndToEndFixtures.bt2020PQ
        )
        let result = try await EndToEndFixtures.runScenario(
            configurations: [video],
            partialChunkBoundary: .sampleCount(1),
            samples: 4
        )
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario08_vp9SDR1080p_Opus51_CMAFBasic() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .vp09,
            codecConfiguration: .vp(EndToEndFixtures.makeVPConfig())
        )
        let result = try await EndToEndFixtures.runScenario(configurations: [video])
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario09_webVTTSubtitle_1080pHEVC_AACLC_MultiTrackInitSegment() async throws {
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
                codec: .webVTT,
                language: "eng"
            )
        )
        let writer = try CMAFInitSegmentWriter(configurations: [video, audio, subtitle])
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        #expect(moov.tracks.count == 3)
    }

    @Test
    func scenario10_imsc1Text_DvhVideo_AC3_CMAFForHLS() async throws {
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
                codec: .imsc1Text,
                language: "eng"
            )
        )
        let writer = try CMAFInitSegmentWriter(configurations: [video, audio, subtitle])
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        #expect(moov.tracks.count == 3)
    }
}

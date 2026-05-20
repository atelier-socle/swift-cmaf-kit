// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// End-to-end scenarios 21 through 30.

import Foundation
import Testing

@testable import CMAFKit

@Suite("End-to-end scenarios 21-30")
struct EndToEndScenarios21to30Tests {

    @Test
    func scenario21_stillImageProfile_SingleFrame() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let result = try await EndToEndFixtures.runScenario(
            configurations: [video],
            fragmentBoundary: .sampleCount(1),
            samples: 1
        )
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
        #expect(result.fragments.count == 1)
    }

    @Test
    func scenario22_chunkedTextTrack_ID3Metadata_RegularCadence() async throws {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .metadata,
            profile: .basic,
            timescale: 1000,
            language: "und",
            metadataFields: CMAFTrackConfiguration.MetadataFields(
                handlerType: "meta",
                metadataType: .id3
            )
        )
        let bytes = try CMAFInitSegmentWriter(configurations: [track]).emit()
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
        #expect(stsd.entries.first is ID3SampleEntry)
    }

    @Test
    func scenario23_AVCBFrames_CompositionTimeOffset() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(3)
        )
        var emitted: [CMAFFragmentSegment] = []
        emitted += try await writer.appendSample(
            CMAFSampleInput(
                bytes: Data(repeating: 0xAB, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: 0,
                flags: .syncSample
            ),
            toTrack: 1
        )
        emitted += try await writer.appendSample(
            CMAFSampleInput(
                bytes: Data(repeating: 0xCD, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: 6000,
                flags: .nonSyncSample
            ),
            toTrack: 1
        )
        emitted += try await writer.appendSample(
            CMAFSampleInput(
                bytes: Data(repeating: 0xEF, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: -3000,
                flags: .nonSyncSample
            ),
            toTrack: 1
        )
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        try await EndToEndFixtures.assertScenario(initSegment: initBytes, fragments: emitted)
    }

    @Test
    func scenario24_HEVCBFrames_CompositionTimeOffset() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .hvc1,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig())
        )
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(3)
        )
        var emitted: [CMAFFragmentSegment] = []
        emitted += try await writer.appendSample(
            CMAFSampleInput(
                bytes: Data(repeating: 0x11, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: 0,
                flags: .syncSample
            ),
            toTrack: 1
        )
        emitted += try await writer.appendSample(
            CMAFSampleInput(
                bytes: Data(repeating: 0x22, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: 9000,
                flags: .nonSyncSample
            ),
            toTrack: 1
        )
        emitted += try await writer.appendSample(
            CMAFSampleInput(
                bytes: Data(repeating: 0x33, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: -3000,
                flags: .nonSyncSample
            ),
            toTrack: 1
        )
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        try await EndToEndFixtures.assertScenario(initSegment: initBytes, fragments: emitted)
    }

    @Test
    func scenario25_NonSyncSampleSequence_PBOnlyAfterIDR() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(6)
        )
        var emitted: [CMAFFragmentSegment] = []
        _ = try await writer.appendSample(
            WriterFixtures.videoSample(isSync: true), toTrack: 1
        )
        for _ in 0..<5 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(isSync: false), toTrack: 1
            )
        }
        emitted += try await writer.finalize()
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        try await EndToEndFixtures.assertScenario(initSegment: initBytes, fragments: emitted)
    }

    @Test
    func scenario26_SyncSampleOnly_EverySampleIsSync() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(3)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<6 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(isSync: true), toTrack: 1
            )
        }
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        try await EndToEndFixtures.assertScenario(initSegment: initBytes, fragments: emitted)
    }

    @Test
    func scenario27_FragmentWith1Sample_BoundaryCase() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(1)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<3 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(isSync: true), toTrack: 1
            )
        }
        #expect(emitted.count == 3)
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        try await EndToEndFixtures.assertScenario(initSegment: initBytes, fragments: emitted)
    }

    @Test
    func scenario28_FragmentWith10000Samples_LargeBoundary() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(10_000)
        )
        var emitted: [CMAFFragmentSegment] = []
        for index in 0..<10_000 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(size: 16, isSync: index == 0),
                toTrack: 1
            )
        }
        #expect(emitted.count == 1)
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        try await EndToEndFixtures.assertScenario(initSegment: initBytes, fragments: emitted)
    }

    @Test
    func scenario29_MultiFragmentLLHLS_PartialChunks200ms_4sFragments() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig()),
            profile: .lowLatency
        )
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .durationSeconds(0.20),
            partialChunkBoundary: .durationSeconds(0.10)
        )
        var emitted: [CMAFFragmentSegment] = []
        for index in 0..<12 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(
                    size: 256,
                    durationInTimescale: 3000,
                    isSync: index % 3 == 0
                ),
                toTrack: 1
            )
        }
        emitted += try await writer.finalize()
        #expect(emitted.count >= 2)
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        try await EndToEndFixtures.assertScenario(initSegment: initBytes, fragments: emitted)
    }

    @Test
    func scenario30_MultiTrackLLHLS_VideoAudioSyncedChunks() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig()),
            profile: .lowLatency,
            trackID: 1
        )
        let audio = EndToEndFixtures.audioConfig(
            codec: .mp4a,
            codecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
            trackID: 2,
            profile: .lowLatency
        )
        let initBytes = try CMAFInitSegmentWriter(configurations: [video, audio]).emit()

        let videoWriter = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
        let audioWriter = try CMAFMediaSegmentWriter(
            configuration: audio,
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )

        var emittedVideo: [CMAFFragmentSegment] = []
        var emittedAudio: [CMAFFragmentSegment] = []
        for _ in 0..<4 {
            emittedVideo += try await videoWriter.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
            emittedAudio += try await audioWriter.appendSample(
                WriterFixtures.videoSample(isSync: true),
                toTrack: 2
            )
        }

        try await EndToEndFixtures.assertScenario(
            initSegment: initBytes,
            fragments: emittedVideo
        )
        try await EndToEndFixtures.assertScenario(
            initSegment: initBytes,
            fragments: emittedAudio
        )
    }
}

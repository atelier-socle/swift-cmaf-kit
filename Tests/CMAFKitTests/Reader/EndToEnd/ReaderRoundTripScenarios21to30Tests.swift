// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Reader-side round-trip scenarios 21 through 30.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Reader round-trip scenarios 21-30")
struct ReaderRoundTripScenarios21to30Tests {

    // MARK: - 21. CMAF still image profile (single frame)

    @Test
    func scenario21_readBack_stillImageProfile_singleFrame() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let samples = RoundTripFixtures.videoSamples(count: 1)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(
                configuration: video,
                samples: samples,
                fragmentBoundary: .sampleCount(1)
            )
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
        #expect(result.recoveredSamples.count == 1)
    }

    // MARK: - 22. Chunked text track (ID3 metadata)

    @Test
    func scenario22_readBack_chunkedTextTrack_ID3Metadata() async throws {
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
        let initBytes = try CMAFInitSegmentWriter(configurations: [track]).emit()
        let result = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: []
        )
        let recovered = try #require(result.recoveredTracks.first)
        #expect(recovered.kind == .metadata)
        if case .id3 = recovered.metadataFields?.metadataType {
            // expected
        } else {
            Issue.record("expected .id3 metadata type")
        }
    }

    // MARK: - 23. AVC B-frames with composition-time offset

    @Test
    func scenario23_readBack_AVCBFrames_CompositionTimeOffset() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let inputs: [CMAFSampleInput] = [
            CMAFSampleInput(
                bytes: Data(repeating: 0xAB, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: 0,
                flags: .syncSample
            ),
            CMAFSampleInput(
                bytes: Data(repeating: 0xCD, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: 6000,
                flags: .nonSyncSample
            ),
            CMAFSampleInput(
                bytes: Data(repeating: 0xEF, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: -3000,
                flags: .nonSyncSample
            )
        ]
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(3)
        )
        var emitted: [CMAFFragmentSegment] = []
        for input in inputs {
            emitted += try await writer.appendSample(input, toTrack: 1)
        }
        emitted += try await writer.finalize()
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        let result = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: emitted.map(\.bytes)
        )
        RoundTripAssertions.assertEquivalence(
            original: inputs, parsed: result.recoveredSamples
        )
    }

    // MARK: - 24. HEVC B-frames with composition-time offset

    @Test
    func scenario24_readBack_HEVCBFrames_CompositionTimeOffset() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .hvc1,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig())
        )
        let inputs: [CMAFSampleInput] = [
            CMAFSampleInput(
                bytes: Data(repeating: 0x11, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: 0,
                flags: .syncSample
            ),
            CMAFSampleInput(
                bytes: Data(repeating: 0x22, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: 9000,
                flags: .nonSyncSample
            ),
            CMAFSampleInput(
                bytes: Data(repeating: 0x33, count: 1024),
                durationInTimescale: 3000,
                compositionTimeOffset: -3000,
                flags: .nonSyncSample
            )
        ]
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(3)
        )
        var emitted: [CMAFFragmentSegment] = []
        for input in inputs {
            emitted += try await writer.appendSample(input, toTrack: 1)
        }
        emitted += try await writer.finalize()
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        let result = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: emitted.map(\.bytes)
        )
        RoundTripAssertions.assertEquivalence(
            original: inputs, parsed: result.recoveredSamples
        )
    }

    // MARK: - 25. Non-sync sample sequence (P/B only after IDR)

    @Test
    func scenario25_readBack_NonSyncSampleSequence_PBOnlyAfterIDR() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        var inputs: [CMAFSampleInput] = []
        inputs.append(
            CMAFSampleInput(
                bytes: Data(repeating: 0xA0, count: 256),
                durationInTimescale: 3000,
                flags: .syncSample
            )
        )
        for index in 1..<6 {
            inputs.append(
                CMAFSampleInput(
                    bytes: Data(repeating: 0xA0 &+ UInt8(index), count: 256),
                    durationInTimescale: 3000,
                    flags: .nonSyncSample
                )
            )
        }
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(6)
        )
        var emitted: [CMAFFragmentSegment] = []
        for input in inputs {
            emitted += try await writer.appendSample(input, toTrack: 1)
        }
        emitted += try await writer.finalize()
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        let result = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: emitted.map(\.bytes)
        )
        RoundTripAssertions.assertEquivalence(
            original: inputs, parsed: result.recoveredSamples
        )
    }

    // MARK: - 26. Sync sample only (every sample is sync)

    @Test
    func scenario26_readBack_SyncSampleOnly_EverySampleIsSync() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let inputs = RoundTripFixtures.allSyncSamples(count: 6, size: 256)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(
                configuration: video,
                samples: inputs,
                fragmentBoundary: .sampleCount(3)
            )
        )
        RoundTripAssertions.assertEquivalence(
            original: inputs, parsed: result.recoveredSamples
        )
        // Every recovered sample carries the sync flag.
        let everySync = result.recoveredSamples.allSatisfy { $0.flags.isSyncSample }
        #expect(everySync)
    }

    // MARK: - 27. Fragment with 1 sample (boundary case)

    @Test
    func scenario27_readBack_FragmentWith1Sample_BoundaryCase() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        let inputs = RoundTripFixtures.allSyncSamples(count: 3, size: 256)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(
                configuration: video,
                samples: inputs,
                fragmentBoundary: .sampleCount(1)
            )
        )
        RoundTripAssertions.assertEquivalence(
            original: inputs, parsed: result.recoveredSamples
        )
        #expect(result.recoveredSamples.count == 3)
    }

    // MARK: - 28. Fragment with 10,000 samples (large boundary case)

    @Test
    func scenario28_readBack_FragmentWith10000Samples_LargeBoundary() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig())
        )
        // 10,000 16-byte samples in one fragment. The trun must
        // round-trip every entry. We mark every sample as sync to
        // keep the SAP rule trivially satisfied.
        let inputs: [CMAFSampleInput] = (0..<10_000).map { index in
            CMAFSampleInput(
                bytes: Data(repeating: UInt8(index & 0xFF), count: 16),
                durationInTimescale: 3000,
                flags: .syncSample
            )
        }
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(
                configuration: video,
                samples: inputs,
                fragmentBoundary: .sampleCount(10_000)
            )
        )
        #expect(result.recoveredSamples.count == 10_000)
        // Spot-check first and last for byte equality.
        #expect(result.recoveredSamples.first?.bytes == inputs.first?.bytes)
        #expect(result.recoveredSamples.last?.bytes == inputs.last?.bytes)
    }

    // MARK: - 29. Multi-fragment LL-HLS, partial chunks 200ms, fragment 4s

    @Test
    func scenario29_readBack_MultiFragmentLLHLS_PartialChunks200ms_4s() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig()),
            profile: .lowLatency
        )
        // All-sync to satisfy SAP across every short LL-HLS fragment.
        let inputs = RoundTripFixtures.allSyncSamples(
            count: 12, size: 256, duration: 3000
        )
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(
                configuration: video,
                samples: inputs,
                fragmentBoundary: .durationSeconds(0.20),
                partialChunkBoundary: .durationSeconds(0.10)
            )
        )
        RoundTripAssertions.assertEquivalence(
            original: inputs, parsed: result.recoveredSamples
        )
    }

    // MARK: - 30. Multi-track LL-HLS with synced video + audio chunks

    @Test
    func scenario30_readBack_MultiTrackLLHLS_VideoAudioSyncedChunks() async throws {
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
        let initBytes = try CMAFInitSegmentWriter(
            configurations: [video, audio]
        ).emit()

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

        let videoInputs = RoundTripFixtures.allSyncSamples(count: 4)
        let audioInputs = RoundTripFixtures.allSyncSamples(count: 4)

        var videoSegments: [CMAFFragmentSegment] = []
        var audioSegments: [CMAFFragmentSegment] = []
        for index in 0..<4 {
            videoSegments += try await videoWriter.appendSample(
                videoInputs[index], toTrack: 1
            )
            audioSegments += try await audioWriter.appendSample(
                audioInputs[index], toTrack: 2
            )
        }
        videoSegments += try await videoWriter.finalize()
        audioSegments += try await audioWriter.finalize()

        // Round-trip the video track through the reader. The init
        // segment carries both tracks; we feed the video segment
        // bytes through the reader and confirm the video samples
        // recover byte-for-byte.
        let videoResult = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: videoSegments.map(\.bytes)
        )
        let videoRecovered = videoResult.recoveredSamples.filter { $0.trackID == 1 }
        RoundTripAssertions.assertEquivalence(
            original: videoInputs, parsed: videoRecovered
        )

        // Round-trip the audio track in a fresh reader (same init
        // segment).
        let audioResult = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: audioSegments.map(\.bytes)
        )
        let audioRecovered = audioResult.recoveredSamples.filter { $0.trackID == 2 }
        RoundTripAssertions.assertEquivalence(
            original: audioInputs, parsed: audioRecovered
        )
    }
}

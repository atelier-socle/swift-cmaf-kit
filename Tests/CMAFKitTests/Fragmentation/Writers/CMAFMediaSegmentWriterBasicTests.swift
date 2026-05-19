// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFMediaSegmentWriter — basic")
struct CMAFMediaSegmentWriterBasicTests {

    @Test
    func initialStateIsEmpty() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(4)
        )
        let state = await writer.state
        #expect(state == .empty)
    }

    @Test
    func subtitleTrackRejected() {
        #expect(throws: CMAFWriterError.self) {
            let config = CMAFTrackConfiguration(
                trackID: 1,
                kind: .subtitle,
                profile: .basic,
                timescale: 1000,
                language: "eng",
                subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                    codec: .webVTT,
                    language: "eng"
                )
            )
            _ = try CMAFMediaSegmentWriter(
                configuration: config,
                fragmentBoundary: .sampleCount(1)
            )
        }
    }

    @Test
    func appendSampleTransitionsToOpenFragment() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(10)
        )
        _ = try await writer.appendSample(
            WriterFixtures.videoSample(),
            toTrack: 1
        )
        let state = await writer.state
        if case .openFragment(_, let count) = state {
            #expect(count == 1)
        } else {
            Issue.record("expected openFragment state, got \(state)")
        }
    }

    @Test
    func sampleCountBoundaryEmitsFragment() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(3)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<3 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        #expect(emitted.count == 1)
        #expect(emitted.first?.sequenceNumber == 1)
        let state = await writer.state
        #expect(state == .empty)
    }

    @Test
    func multiFragmentSequenceNumbersIncrement() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<6 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        #expect(emitted.map { $0.sequenceNumber } == [1, 2, 3])
    }

    @Test
    func durationBoundaryEmitsFragment() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .durationSeconds(0.1)
        )
        // Each sample is 3000/90_000 = 0.0333s; need 3 samples to hit 0.1s.
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<3 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(durationInTimescale: 3000),
                toTrack: 1
            )
        }
        #expect(emitted.count == 1)
    }

    @Test
    func finalizeEmitsTrailingFragment() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(10)
        )
        _ = try await writer.appendSample(WriterFixtures.videoSample(), toTrack: 1)
        _ = try await writer.appendSample(WriterFixtures.videoSample(), toTrack: 1)
        let trailing = try await writer.finalize()
        #expect(trailing.count == 1)
        let state = await writer.state
        #expect(state == .finalized)
    }

    @Test
    func appendAfterFinalizeThrows() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(10)
        )
        _ = try await writer.appendSample(WriterFixtures.videoSample(), toTrack: 1)
        _ = try await writer.finalize()
        await #expect(throws: CMAFWriterError.self) {
            _ = try await writer.appendSample(WriterFixtures.videoSample(), toTrack: 1)
        }
    }

    @Test
    func doubleFinalizeThrows() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(10)
        )
        _ = try await writer.appendSample(WriterFixtures.videoSample(), toTrack: 1)
        _ = try await writer.finalize()
        await #expect(throws: CMAFWriterError.self) {
            _ = try await writer.finalize()
        }
    }

    @Test
    func wrongTrackIDRejected() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(trackID: 1),
            fragmentBoundary: .sampleCount(10)
        )
        await #expect(throws: CMAFWriterError.self) {
            _ = try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 99
            )
        }
    }

    @Test
    func finalizeWithoutSamplesYieldsEmptyArray() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(10)
        )
        let trailing = try await writer.finalize()
        #expect(trailing.isEmpty)
    }

    @Test
    func emittedSegmentRoundTripsThroughRegistry() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(3)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<3 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        #expect(boxes.contains { $0 is SegmentTypeBox })
        #expect(boxes.contains { $0 is MovieFragmentBox })
        #expect(boxes.contains { $0 is MediaDataBox })
    }

    @Test
    func deterministicByteForByteWithSameInput() async throws {
        async let bytes1 = makeSimpleFragment()
        async let bytes2 = makeSimpleFragment()
        let (b1, b2) = try await (bytes1, bytes2)
        #expect(b1 == b2)
    }

    private func makeSimpleFragment() async throws -> Data {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2)
        )
        _ = try await writer.appendSample(WriterFixtures.videoSample(), toTrack: 1)
        let result = try await writer.appendSample(
            WriterFixtures.videoSample(isSync: false),
            toTrack: 1
        )
        return result.first?.bytes ?? Data()
    }

    @Test
    func baseMediaDecodeTimeAdvances() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<4 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        #expect(emitted.count == 2)
        #expect(emitted[0].baseMediaDecodeTime == 0)
        #expect(emitted[1].baseMediaDecodeTime == 6000)
    }

    @Test
    func onSyncSampleBoundaryClosesBeforeNextSync() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .onSyncSample
        )
        // Sequence: SYNC, non-sync, non-sync, SYNC (closes here)
        _ = try await writer.appendSample(
            WriterFixtures.videoSample(isSync: true),
            toTrack: 1
        )
        _ = try await writer.appendSample(
            WriterFixtures.videoSample(isSync: false),
            toTrack: 1
        )
        _ = try await writer.appendSample(
            WriterFixtures.videoSample(isSync: false),
            toTrack: 1
        )
        let emitted = try await writer.appendSample(
            WriterFixtures.videoSample(isSync: true),
            toTrack: 1
        )
        #expect(emitted.count == 1)
        let state = await writer.state
        // The sync sample becomes the lead of the next fragment.
        if case .openFragment(_, let count) = state {
            #expect(count == 1)
        } else {
            Issue.record("expected openFragment after sync-cut")
        }
    }

    @Test
    func finalizeFlushesPendingEvenAfterBoundary() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2)
        )
        _ = try await writer.appendSample(WriterFixtures.videoSample(), toTrack: 1)
        _ = try await writer.appendSample(WriterFixtures.videoSample(), toTrack: 1)
        _ = try await writer.appendSample(WriterFixtures.videoSample(), toTrack: 1)
        let trailing = try await writer.finalize()
        #expect(trailing.count == 1)
        #expect(trailing[0].sequenceNumber == 2)
    }
}

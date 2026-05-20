// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFMediaSegmentWriter — LL-HLS partial chunks")
struct CMAFMediaSegmentWriterLLHLSTests {

    // MARK: - Helpers

    private static func lowLatencyVideoConfig() -> CMAFTrackConfiguration {
        WriterFixtures.videoConfig(profile: .lowLatency)
    }

    // MARK: - Construction

    @Test
    func writerWithPartialChunksAccepted() throws {
        _ = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
    }

    // MARK: - Chunk emission

    @Test
    func twoChunksEmittedInOneFragment() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<4 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let chunks = try #require(segment.partialChunks)
        #expect(chunks.count == 2)
    }

    @Test
    func firstChunkIsIndependent() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<4 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let chunks = try #require(emitted.first?.partialChunks)
        #expect(chunks.first?.isIndependent == true)
    }

    @Test
    func nonSyncChunkIsNotIndependent() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        // Sample sequence: sync, non-sync, non-sync, non-sync.
        emitted += try await writer.appendSample(
            WriterFixtures.videoSample(isSync: true), toTrack: 1
        )
        for _ in 0..<3 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(isSync: false),
                toTrack: 1
            )
        }
        let chunks = try #require(emitted.first?.partialChunks)
        #expect(chunks.count == 2)
        #expect(chunks[0].isIndependent)
        #expect(chunks[1].isIndependent == false)
    }

    @Test
    func chunkIndicesAreZeroBased() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(6),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<6 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let chunks = try #require(emitted.first?.partialChunks)
        #expect(chunks.map { $0.chunkIndex } == [0, 1, 2])
    }

    @Test
    func chunksConcatenateIntoFragmentBytes() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<4 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let chunks = try #require(segment.partialChunks)
        let concatenated = chunks.reduce(into: Data()) { $0.append($1.bytes) }
        // The fragment bytes contain styp + concatenated chunk bytes.
        #expect(segment.bytes.suffix(concatenated.count) == concatenated)
    }

    @Test
    func partialChunkBoundaryByDuration() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(8),
            partialChunkBoundary: .durationSeconds(0.05)
        )
        var emitted: [CMAFFragmentSegment] = []
        // 8 samples at 3000/90000 = 0.0333s. Boundary at 0.05s closes
        // chunk after 2 samples.
        for _ in 0..<8 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(durationInTimescale: 3000),
                toTrack: 1
            )
        }
        let chunks = try #require(emitted.first?.partialChunks)
        #expect(chunks.count >= 2)
    }

    @Test
    func partialChunkBoundaryPerSample() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(3),
            partialChunkBoundary: .perSample
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<3 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let chunks = try #require(emitted.first?.partialChunks)
        #expect(chunks.count == 3)
    }

    @Test
    func chunkSequenceNumbersAreGloballyMonotonic() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<8 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        #expect(emitted.count == 2)
        // Each fragment's chunks have their own sequence numbers
        // that monotonically increase across the writer's lifetime.
        // We verify by checking the second fragment's chunks
        // round-trip with mfhd.sequence_number > first fragment's.
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let firstChunkBytes = try #require(emitted[0].partialChunks?.first?.bytes)
        let lastChunkBytes = try #require(emitted[1].partialChunks?.last?.bytes)
        let firstBoxes = try await reader.readBoxes(
            from: firstChunkBytes, using: registry
        )
        let lastBoxes = try await reader.readBoxes(
            from: lastChunkBytes, using: registry
        )
        let firstSeq = try mfhdSequenceNumber(of: firstBoxes)
        let lastSeq = try mfhdSequenceNumber(of: lastBoxes)
        #expect(lastSeq > firstSeq)
    }

    @Test
    func chunkBaseMediaDecodeTimeAdvancesAcrossChunks() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<4 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(durationInTimescale: 3000),
                toTrack: 1
            )
        }
        let chunks = try #require(emitted.first?.partialChunks)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let firstChunkBoxes = try await reader.readBoxes(
            from: chunks[0].bytes, using: registry
        )
        let secondChunkBoxes = try await reader.readBoxes(
            from: chunks[1].bytes, using: registry
        )
        let firstDecodeTime = try tfdtBaseMediaDecodeTime(of: firstChunkBoxes)
        let secondDecodeTime = try tfdtBaseMediaDecodeTime(of: secondChunkBoxes)
        #expect(secondDecodeTime == firstDecodeTime + 6000)
    }

    @Test
    func multipleFragmentsEachWithChunks() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<12 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        #expect(emitted.count == 3)
        for segment in emitted {
            #expect(segment.partialChunks?.count == 2)
        }
    }

    @Test
    func chunkBytesParseAsValidMoofMdat() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<4 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let chunk = try #require(emitted.first?.partialChunks?.first)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: chunk.bytes, using: registry)
        #expect(boxes.contains { $0 is MovieFragmentBox })
        #expect(boxes.contains { $0 is MediaDataBox })
    }

    @Test
    func finalizeFlushesTrailingChunk() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(10),
            partialChunkBoundary: .sampleCount(2)
        )
        for _ in 0..<3 {
            _ = try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let trailing = try await writer.finalize()
        #expect(trailing.count == 1)
        // The trailing fragment must have at least one chunk
        // covering all samples observed so far.
        let chunks = try #require(trailing.first?.partialChunks)
        #expect(chunks.isEmpty == false)
    }

    @Test
    func chunkDurationsSumToFragmentDuration() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(6),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<6 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(durationInTimescale: 3000),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let chunks = try #require(segment.partialChunks)
        let chunkDurations = chunks.reduce(0) { $0 + $1.durationInTimescale }
        // Sample-count boundary cuts after 6th sample, so the fragment
        // has 3 chunks × 2 samples each.
        #expect(chunkDurations == segment.durationInTimescale)
    }

    @Test
    func fragmentBytesIncludeStypAndChunks() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: Self.lowLatencyVideoConfig(),
            fragmentBoundary: .sampleCount(2),
            partialChunkBoundary: .sampleCount(1)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<2 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        #expect(boxes.first is SegmentTypeBox)
    }

    // MARK: - Private parse helpers

    private func mfhdSequenceNumber(of boxes: [any ISOBox]) throws -> UInt32 {
        let moof = try #require(boxes.compactMap { $0 as? MovieFragmentBox }.first)
        let mfhd = try #require(moof.children.compactMap { $0 as? MovieFragmentHeaderBox }.first)
        return mfhd.sequenceNumber
    }

    private func tfdtBaseMediaDecodeTime(of boxes: [any ISOBox]) throws -> UInt64 {
        let moof = try #require(boxes.compactMap { $0 as? MovieFragmentBox }.first)
        let traf = try #require(moof.children.compactMap { $0 as? TrackFragmentBox }.first)
        let tfdt = try #require(
            traf.children.compactMap { $0 as? TrackFragmentDecodeTimeBox }.first
        )
        return tfdt.baseMediaDecodeTime
    }
}

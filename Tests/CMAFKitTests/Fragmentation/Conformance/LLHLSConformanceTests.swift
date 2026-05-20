// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("LL-HLS conformance")
struct LLHLSConformanceTests {

    private func llHLSTrack() -> CMAFTrackConfiguration {
        WriterFixtures.videoConfig(profile: .lowLatency)
    }

    @Test
    func lowLatencyProfileRejectsWriterWithoutPartialChunks() {
        #expect(throws: CMAFWriterError.self) {
            _ = try CMAFMediaSegmentWriter(
                configuration: llHLSTrack(),
                fragmentBoundary: .sampleCount(4),
                partialChunkBoundary: nil
            )
        }
    }

    @Test
    func lowLatencyProfileBrandsCarryCmfl() async throws {
        let writer = try CMAFInitSegmentWriter(configurations: [llHLSTrack()])
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let ftyp = try #require(boxes.first as? FileTypeBox)
        #expect(ftyp.majorBrand == "cmfl")
        #expect(ftyp.compatibleBrands.contains("cmfl"))
    }

    @Test
    func firstPartialChunkIsAlwaysIndependent() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: llHLSTrack(),
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
    func nonSyncIntermediateChunkIsNotIndependent() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: llHLSTrack(),
            fragmentBoundary: .sampleCount(4),
            partialChunkBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        emitted += try await writer.appendSample(
            WriterFixtures.videoSample(isSync: true), toTrack: 1
        )
        for _ in 0..<3 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(isSync: false), toTrack: 1
            )
        }
        let chunks = try #require(emitted.first?.partialChunks)
        #expect(chunks.count == 2)
        #expect(chunks[0].isIndependent)
        #expect(chunks[1].isIndependent == false)
    }

    @Test
    func chunkSequenceNumbersAreMonotonicAcrossFragments() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: llHLSTrack(),
            fragmentBoundary: .sampleCount(2),
            partialChunkBoundary: .sampleCount(1)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<4 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        #expect(emitted.count == 2)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        var seqs: [UInt32] = []
        for segment in emitted {
            for chunk in segment.partialChunks ?? [] {
                let boxes = try await reader.readBoxes(from: chunk.bytes, using: registry)
                let moof = try #require(boxes.compactMap { $0 as? MovieFragmentBox }.first)
                let mfhd = try #require(
                    moof.children.compactMap { $0 as? MovieFragmentHeaderBox }.first
                )
                seqs.append(mfhd.sequenceNumber)
            }
        }
        #expect(seqs == seqs.sorted())
    }

    @Test
    func chunkDurationsAreNonZero() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: llHLSTrack(),
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
        for chunk in chunks {
            #expect(chunk.durationInTimescale > 0)
        }
    }

    @Test
    func chunksRoundTripParseAsMoofMdat() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: llHLSTrack(),
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
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        for chunk in emitted.first?.partialChunks ?? [] {
            let boxes = try await reader.readBoxes(from: chunk.bytes, using: registry)
            #expect(boxes.contains { $0 is MovieFragmentBox })
            #expect(boxes.contains { $0 is MediaDataBox })
        }
    }

    @Test
    func chunkBytesArePresentInFragmentBytes() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: llHLSTrack(),
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
        let chunks = try #require(segment.partialChunks)
        let concat = chunks.reduce(into: Data()) { $0.append($1.bytes) }
        #expect(segment.bytes.contains(concat[0]))
    }

    @Test
    func chunkTfdtDecodeTimesIncreaseStrictly() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: llHLSTrack(),
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
        var decodeTimes: [UInt64] = []
        for chunk in chunks {
            let boxes = try await reader.readBoxes(from: chunk.bytes, using: registry)
            let moof = try #require(boxes.compactMap { $0 as? MovieFragmentBox }.first)
            let traf = try #require(moof.children.compactMap { $0 as? TrackFragmentBox }.first)
            let tfdt = try #require(
                traf.children.compactMap { $0 as? TrackFragmentDecodeTimeBox }.first
            )
            decodeTimes.append(tfdt.baseMediaDecodeTime)
        }
        for i in 1..<decodeTimes.count {
            #expect(decodeTimes[i] > decodeTimes[i - 1])
        }
    }

    @Test
    func partialChunkBoundaryPerSampleAllowsTightChunking() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: llHLSTrack(),
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
    func emittedFragmentRoundTripsThroughRegistry() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: llHLSTrack(),
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
        // Two chunks → two moof + two mdat — plus the leading styp.
        #expect(boxes.contains { $0 is SegmentTypeBox })
        let moofs = boxes.filter { $0 is MovieFragmentBox }
        let mdats = boxes.filter { $0 is MediaDataBox }
        #expect(moofs.count == 2)
        #expect(mdats.count == 2)
    }
}

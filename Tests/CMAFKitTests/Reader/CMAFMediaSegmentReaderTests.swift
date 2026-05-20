// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFMediaSegmentReader — round-trip with writer")
struct CMAFMediaSegmentReaderTests {

    @Test
    func initialStateIsIdle() async throws {
        let track = WriterFixtures.videoConfig()
        let reader = try CMAFMediaSegmentReader(
            initSegmentConfiguration: [track],
            movieTimescale: 1000
        )
        let state = await reader.state
        #expect(state == .idle)
    }

    @Test
    func parsesSegmentEmittedByWriter() async throws {
        let track = WriterFixtures.videoConfig()
        let writer = try CMAFMediaSegmentWriter(
            configuration: track,
            fragmentBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<2 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let reader = try CMAFMediaSegmentReader(
            initSegmentConfiguration: [track],
            movieTimescale: 1000
        )
        let parsed = try await reader.appendSegmentBytes(segment.bytes)
        #expect(parsed.samples.count == 2)
        #expect(parsed.samples[0].trackID == 1)
    }

    @Test
    func parsedSampleBytesEqualWrittenBytes() async throws {
        let track = WriterFixtures.videoConfig()
        let writer = try CMAFMediaSegmentWriter(
            configuration: track,
            fragmentBoundary: .sampleCount(2)
        )
        let writtenSample = WriterFixtures.videoSample(size: 256, isSync: true)
        _ = try await writer.appendSample(writtenSample, toTrack: 1)
        let emitted = try await writer.appendSample(writtenSample, toTrack: 1)
        let segment = try #require(emitted.first)
        let reader = try CMAFMediaSegmentReader(
            initSegmentConfiguration: [track],
            movieTimescale: 1000
        )
        let parsed = try await reader.appendSegmentBytes(segment.bytes)
        #expect(parsed.samples.first?.bytes == writtenSample.bytes)
    }

    @Test
    func multiFragmentDecodeTimesAdvance() async throws {
        let track = WriterFixtures.videoConfig()
        let writer = try CMAFMediaSegmentWriter(
            configuration: track,
            fragmentBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<6 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(durationInTimescale: 3000),
                toTrack: 1
            )
        }
        let reader = try CMAFMediaSegmentReader(
            initSegmentConfiguration: [track],
            movieTimescale: 1000
        )
        var decodeTimes: [UInt64] = []
        for segment in emitted {
            let parsed = try await reader.appendSegmentBytes(segment.bytes)
            decodeTimes.append(contentsOf: parsed.samples.map { $0.decodeTime })
        }
        #expect(decodeTimes == decodeTimes.sorted())
    }

    @Test
    func finalizeTransitionsState() async throws {
        let track = WriterFixtures.videoConfig()
        let reader = try CMAFMediaSegmentReader(
            initSegmentConfiguration: [track],
            movieTimescale: 1000
        )
        try await reader.finalize()
        let state = await reader.state
        #expect(state == .finalized)
    }

    @Test
    func appendAfterFinalizeThrows() async throws {
        let track = WriterFixtures.videoConfig()
        let reader = try CMAFMediaSegmentReader(
            initSegmentConfiguration: [track],
            movieTimescale: 1000
        )
        try await reader.finalize()
        await #expect(throws: CMAFReaderError.self) {
            _ = try await reader.appendSegmentBytes(Data())
        }
    }

    @Test
    func doubleFinalizeThrows() async throws {
        let track = WriterFixtures.videoConfig()
        let reader = try CMAFMediaSegmentReader(
            initSegmentConfiguration: [track],
            movieTimescale: 1000
        )
        try await reader.finalize()
        await #expect(throws: CMAFReaderError.self) {
            try await reader.finalize()
        }
    }

    @Test
    func encryptedSegmentRecoverSencMetadata() async throws {
        let encParams = WriterFixtures.cencParameters()
        let track = WriterFixtures.videoConfig(encrypted: encParams)
        let writer = try CMAFMediaSegmentWriter(
            configuration: track,
            fragmentBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<2 {
            emitted += try await writer.appendSample(
                WriterFixtures.encryptedVideoSample(),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let reader = try CMAFMediaSegmentReader(
            initSegmentConfiguration: [track],
            movieTimescale: 1000,
            trackEncryptionContexts: [1: encParams.makeTrackEncryptionBox()]
        )
        let parsed = try await reader.appendSegmentBytes(segment.bytes)
        #expect(parsed.samples.first?.encryption?.initializationVector.count == 8)
    }

    @Test
    func sequenceNumberMonotonicAcrossSegments() async throws {
        let track = WriterFixtures.videoConfig()
        let writer = try CMAFMediaSegmentWriter(
            configuration: track,
            fragmentBoundary: .sampleCount(2)
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<6 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let reader = try CMAFMediaSegmentReader(
            initSegmentConfiguration: [track],
            movieTimescale: 1000
        )
        var lastSeq: UInt32 = 0
        for segment in emitted {
            let parsed = try await reader.appendSegmentBytes(segment.bytes)
            for seq in parsed.movieFragmentSequenceNumbers {
                #expect(seq > lastSeq)
                lastSeq = seq
            }
        }
    }
}

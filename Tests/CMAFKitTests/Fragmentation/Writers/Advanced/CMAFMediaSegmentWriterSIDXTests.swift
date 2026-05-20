// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFMediaSegmentWriter — sidx")
struct CMAFMediaSegmentWriterSIDXTests {

    @Test
    func sidxEmittedWhenEnabled() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true
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
        #expect(boxes.contains { $0 is SegmentIndexBox })
    }

    @Test
    func sidxNotEmittedWhenDisabled() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: false
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
        #expect(!boxes.contains { $0 is SegmentIndexBox })
    }

    @Test
    func sapTypeOneForSyncStart() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<2 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(isSync: true),
                toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        let sidx = try #require(boxes.compactMap { $0 as? SegmentIndexBox }.first)
        let firstEntry = try #require(sidx.table.first)
        #expect(firstEntry.startsWithSAP)
        #expect(firstEntry.sapType == 1)
    }

    @Test
    func sidxReferenceIDMatchesTrack() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<2 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(), toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        let sidx = try #require(boxes.compactMap { $0 as? SegmentIndexBox }.first)
        #expect(sidx.referenceID == 1)
    }

    @Test
    func sidxTimescaleMatchesTrack() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<2 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(), toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        let sidx = try #require(boxes.compactMap { $0 as? SegmentIndexBox }.first)
        #expect(sidx.timescale == 90_000)
    }

    @Test
    func sidxEarliestPresentationTimeMatchesDecodeTime() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<4 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(durationInTimescale: 3000),
                toTrack: 1
            )
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        // Second fragment's sidx earliestPresentationTime == 6000.
        let segment = emitted[1]
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        let sidx = try #require(boxes.compactMap { $0 as? SegmentIndexBox }.first)
        #expect(sidx.earliestPresentationTime == 6000)
    }

    @Test
    func sidxRoundTrip() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<2 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(), toTrack: 1
            )
        }
        let segment = try #require(emitted.first)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        let sidx = try #require(boxes.compactMap { $0 as? SegmentIndexBox }.first)
        var w = BinaryWriter()
        sidx.encode(to: &w)
        let reparsed = try await reader.readBoxes(from: w.data, using: registry)
        let sidx2 = try #require(reparsed.first as? SegmentIndexBox)
        #expect(sidx == sidx2)
    }

    @Test
    func sidxReferencedSizeReflectsFragmentBytes() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(3),
            emitSegmentIndex: true
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
        let sidx = try #require(boxes.compactMap { $0 as? SegmentIndexBox }.first)
        let entry = try #require(sidx.table.first)
        // referencedSize > 0 confirms the writer recorded the fragment
        // size into sidx.
        #expect(entry.referencedSize > 0)
    }
}

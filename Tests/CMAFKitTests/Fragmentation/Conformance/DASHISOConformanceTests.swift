// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("DASH-IF CMAF conformance")
struct DASHISOConformanceTests {

    private func dashTrack() -> CMAFTrackConfiguration {
        WriterFixtures.videoConfig(profile: .dash)
    }

    @Test
    func dashProfileRejectsWriterWithoutSidx() {
        #expect(throws: CMAFWriterError.self) {
            _ = try CMAFMediaSegmentWriter(
                configuration: dashTrack(),
                fragmentBoundary: .sampleCount(4),
                emitSegmentIndex: false
            )
        }
    }

    @Test
    func dashWriterRequiresSidxAndAccepts() throws {
        _ = try CMAFMediaSegmentWriter(
            configuration: dashTrack(),
            fragmentBoundary: .sampleCount(4),
            emitSegmentIndex: true
        )
    }

    @Test
    func dashWriterEmittedFragmentCarriesSidx() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: dashTrack(),
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
    func dashFragmentBeginsWithSAP() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: dashTrack(),
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
        #expect(emitted.first?.isStreamAccessPoint == true)
    }

    @Test
    func dashProfileBrandsCarryDashAndMsdh() async throws {
        let writer = try CMAFInitSegmentWriter(configurations: [dashTrack()])
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let ftyp = try #require(boxes.first as? FileTypeBox)
        #expect(ftyp.majorBrand == "cmfd")
        #expect(ftyp.compatibleBrands.contains("dash"))
        #expect(ftyp.compatibleBrands.contains("msdh"))
    }

    @Test
    func dashSidxStartsWithSyncSample() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: dashTrack(),
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
        #expect(sidx.table.first?.startsWithSAP == true)
    }

    @Test
    func dashWriterRejectsPartialChunks() {
        #expect(throws: CMAFWriterError.self) {
            _ = try CMAFMediaSegmentWriter(
                configuration: dashTrack(),
                fragmentBoundary: .sampleCount(4),
                partialChunkBoundary: .perSample,
                emitSegmentIndex: true
            )
        }
    }

    @Test
    func dashWriterAcceptsEmsgEventAttachment() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: dashTrack(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true
        )
        let event = EventMessageBox(
            schemeIDURI: "urn:mpeg:dash:event:2012",
            value: "1",
            timescale: 90_000,
            presentationTimeDelta: 0,
            eventDuration: 90_000,
            id: 1,
            messageData: Data()
        )
        await writer.attachEventMessage(event)
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
        #expect(boxes.contains { $0 is EventMessageBox })
    }

    @Test
    func dashWriterAcceptsPrft() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: dashTrack(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true,
            emitProducerReferenceTime: true
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
        #expect(boxes.contains { $0 is ProducerReferenceTimeBox })
    }

    @Test
    func dashMultiFragmentSidxIndependence() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: dashTrack(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true
        )
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<6 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(durationInTimescale: 3000),
                toTrack: 1
            )
        }
        #expect(emitted.count == 3)
        // Each fragment carries its own sidx with the right earliest
        // presentation time.
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        var ept: [UInt64] = []
        for segment in emitted {
            let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
            let sidx = try #require(boxes.compactMap { $0 as? SegmentIndexBox }.first)
            ept.append(sidx.earliestPresentationTime)
        }
        #expect(ept == ept.sorted())
    }

    @Test
    func dashSegmentBytesParseBack() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: dashTrack(),
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
        #expect(boxes.contains { $0 is SegmentTypeBox })
        #expect(boxes.contains { $0 is SegmentIndexBox })
        #expect(boxes.contains { $0 is MovieFragmentBox })
        #expect(boxes.contains { $0 is MediaDataBox })
    }
}

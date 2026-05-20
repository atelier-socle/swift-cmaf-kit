// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFMediaSegmentWriter — prft + emsg")
struct CMAFMediaSegmentWriterPRFTAndEMSGTests {

    @Test
    func prftEmittedWhenEnabled() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
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
    func prftNotEmittedWhenDisabled() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitProducerReferenceTime: false
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
        #expect(!boxes.contains { $0 is ProducerReferenceTimeBox })
    }

    @Test
    func prftReferenceTrackIDMatches() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitProducerReferenceTime: true
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
        let prft = try #require(boxes.compactMap { $0 as? ProducerReferenceTimeBox }.first)
        #expect(prft.referenceTrackID == 1)
    }

    @Test
    func prftEveryFragment() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitProducerReferenceTime: true
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
        for segment in emitted {
            let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
            #expect(boxes.contains { $0 is ProducerReferenceTimeBox })
        }
    }

    @Test
    func emsgAttachedBeforeNextFragment() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2)
        )
        let event = EventMessageBox(
            schemeIDURI: "urn:mpeg:dash:event:2012",
            value: "1",
            timescale: 90_000,
            presentationTimeDelta: 0,
            eventDuration: 90_000,
            id: 42,
            messageData: Data([0xCA, 0xFE])
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
    func emsgEmittedOnlyOnce() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2)
        )
        let event = EventMessageBox(
            schemeIDURI: "u",
            value: "v",
            timescale: 1,
            presentationTimeDelta: 0,
            eventDuration: 0,
            id: 0,
            messageData: Data()
        )
        await writer.attachEventMessage(event)
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<4 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        var countWithEmsg = 0
        for segment in emitted {
            let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
            if boxes.contains(where: { $0 is EventMessageBox }) {
                countWithEmsg += 1
            }
        }
        #expect(countWithEmsg == 1)
    }

    @Test
    func multipleEmsgsAttachedToOneFragment() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2)
        )
        let e1 = EventMessageBox(
            schemeIDURI: "urn:scte35", value: "1",
            timescale: 90_000, presentationTimeDelta: 0,
            eventDuration: 0, id: 1, messageData: Data()
        )
        let e2 = EventMessageBox(
            schemeIDURI: "urn:nielsen", value: "2",
            timescale: 90_000, presentationTimeDelta: 0,
            eventDuration: 0, id: 2, messageData: Data()
        )
        await writer.attachEventMessage(e1)
        await writer.attachEventMessage(e2)
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
        let emsgs = boxes.compactMap { $0 as? EventMessageBox }
        #expect(emsgs.count == 2)
    }
}

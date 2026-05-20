// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

/// Verifies that every box type emitted by the writers round-trips
/// through `BoxRegistry.defaultRegistry()` without loss.
///
/// The registry-driven parse path is the same one consumers will run
/// against the writer's output, so passing this suite is the
/// strongest form of contract verification CMAFKit ships.
@Suite("ISOBMFF round-trip via BoxRegistry")
struct ISOBMFFRoundTripWithRegistryTests {

    // MARK: - Init segment round-trips

    @Test
    func videoOnlyInitSegmentRoundTrip() async throws {
        try await assertInitSegmentRoundTrips(
            configurations: [WriterFixtures.videoConfig()]
        )
    }

    @Test
    func audioOnlyInitSegmentRoundTrip() async throws {
        try await assertInitSegmentRoundTrips(
            configurations: [WriterFixtures.audioConfig()]
        )
    }

    @Test
    func multiTrackInitSegmentRoundTrip() async throws {
        try await assertInitSegmentRoundTrips(
            configurations: [
                WriterFixtures.videoConfig(trackID: 1),
                WriterFixtures.audioConfig(trackID: 2)
            ]
        )
    }

    @Test
    func encryptedInitSegmentRoundTrip() async throws {
        try await assertInitSegmentRoundTrips(
            configurations: [
                WriterFixtures.videoConfig(encrypted: WriterFixtures.cencParameters())
            ]
        )
    }

    @Test
    func subtitleInitSegmentRoundTrip() async throws {
        let track = CMAFTrackConfiguration(
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
        try await assertInitSegmentRoundTrips(configurations: [track])
    }

    @Test
    func id3MetadataInitSegmentRoundTrip() async throws {
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
        try await assertInitSegmentRoundTrips(configurations: [track])
    }

    // MARK: - Media segment round-trips

    @Test
    func videoMediaSegmentRoundTrip() async throws {
        try await assertMediaSegmentRoundTrips(
            configuration: WriterFixtures.videoConfig()
        )
    }

    @Test
    func audioMediaSegmentRoundTrip() async throws {
        try await assertMediaSegmentRoundTrips(
            configuration: WriterFixtures.audioConfig()
        )
    }

    @Test
    func cencEncryptedMediaSegmentRoundTrip() async throws {
        try await assertMediaSegmentRoundTrips(
            configuration: WriterFixtures.videoConfig(
                encrypted: WriterFixtures.cencParameters()
            ),
            useEncryption: true
        )
    }

    @Test
    func cbcsEncryptedMediaSegmentRoundTrip() async throws {
        try await assertMediaSegmentRoundTrips(
            configuration: WriterFixtures.videoConfig(
                encrypted: try WriterFixtures.cbcsParameters()
            ),
            useEncryption: true,
            ivSize: 0
        )
    }

    @Test
    func sidxMediaSegmentRoundTrip() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true
        )
        try await assertSegmentRoundTripsViaWriter(writer)
    }

    @Test
    func prftMediaSegmentRoundTrip() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(),
            fragmentBoundary: .sampleCount(2),
            emitProducerReferenceTime: true
        )
        try await assertSegmentRoundTripsViaWriter(writer)
    }

    @Test
    func emsgMediaSegmentRoundTrip() async throws {
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
            id: 1,
            messageData: Data()
        )
        await writer.attachEventMessage(event)
        try await assertSegmentRoundTripsViaWriter(writer)
    }

    @Test
    func llHLSPartialChunksRoundTrip() async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: WriterFixtures.videoConfig(profile: .lowLatency),
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
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
        #expect(boxes.contains { $0 is MovieFragmentBox })
    }

    // MARK: - Direct box round-trips

    @Test
    func sidxBoxRoundTrip() async throws {
        let box = SegmentIndexBox(
            version: 1,
            referenceID: 1,
            timescale: 90_000,
            earliestPresentationTime: 0,
            firstOffset: 0,
            table: SegmentIndexTable(entries: [
                SegmentIndexEntry(
                    referenceType: false,
                    referencedSize: 1024,
                    subsegmentDuration: 90_000,
                    startsWithSAP: true,
                    sapType: 1,
                    sapDeltaTime: 0
                )
            ])
        )
        var w = BinaryWriter()
        box.encode(to: &w)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w.data, using: registry)
        let parsed = try #require(boxes.first as? SegmentIndexBox)
        #expect(parsed == box)
    }

    @Test
    func prftBoxRoundTrip() async throws {
        let box = ProducerReferenceTimeBox(
            version: 1,
            referenceTrackID: 1,
            ntpTimestamp: 0xE93E_F36B_8000_0000,
            mediaDecodeTime: 90_000_000
        )
        var w = BinaryWriter()
        box.encode(to: &w)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w.data, using: registry)
        let parsed = try #require(boxes.first as? ProducerReferenceTimeBox)
        #expect(parsed == box)
    }

    @Test
    func emsgBoxRoundTrip() async throws {
        let box = EventMessageBox(
            timescale: 90_000,
            presentationTime: 1_440_000,
            eventDuration: 90_000,
            id: 42,
            schemeIDURI: "urn:scte35",
            value: "splice",
            messageData: Data([0xFC, 0x00, 0x14])
        )
        var w = BinaryWriter()
        box.encode(to: &w)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w.data, using: registry)
        let parsed = try #require(boxes.first as? EventMessageBox)
        #expect(parsed == box)
    }

    @Test
    func wvttBoxRoundTrip() async throws {
        let box = WebVTTSampleEntry(
            configuration: WebVTTConfigurationBox(headerText: "WEBVTT\n")
        )
        var w = BinaryWriter()
        box.encode(to: &w)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w.data, using: registry)
        let parsed = try #require(boxes.first as? WebVTTSampleEntry)
        #expect(parsed == box)
    }

    @Test
    func stppBoxRoundTrip() async throws {
        let box = XMLSubtitleSampleEntry(
            namespace: "http://www.w3.org/ns/ttml",
            auxiliaryMIMETypes: "application/ttml+xml"
        )
        var w = BinaryWriter()
        box.encode(to: &w)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w.data, using: registry)
        let parsed = try #require(boxes.first as? XMLSubtitleSampleEntry)
        #expect(parsed == box)
    }

    @Test
    func mettBoxRoundTrip() async throws {
        let box = TextMetadataSampleEntry(mimeFormat: "text/plain")
        var w = BinaryWriter()
        box.encode(to: &w)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w.data, using: registry)
        let parsed = try #require(boxes.first as? TextMetadataSampleEntry)
        #expect(parsed == box)
    }

    @Test
    func id3BoxRoundTrip() async throws {
        let box = ID3SampleEntry()
        var w = BinaryWriter()
        box.encode(to: &w)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w.data, using: registry)
        let parsed = try #require(boxes.first as? ID3SampleEntry)
        #expect(parsed == box)
    }

    @Test
    func urimBoxRoundTrip() async throws {
        let box = URIMetadataSampleEntry(
            uri: URIBox(uri: "urn:example:scheme")
        )
        var w = BinaryWriter()
        box.encode(to: &w)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w.data, using: registry)
        let parsed = try #require(boxes.first as? URIMetadataSampleEntry)
        #expect(parsed == box)
    }

    @Test
    func elstBoxRoundTrip() async throws {
        let entry = EditListEntry(
            segmentDuration: 1000,
            mediaTime: -1,
            mediaRateInteger: 1,
            mediaRateFraction: 0
        )
        let box = EditListBox(
            version: 1,
            table: EditListTable(entries: [entry], version: 1)
        )
        var w = BinaryWriter()
        box.encode(to: &w)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w.data, using: registry)
        let parsed = try #require(boxes.first as? EditListBox)
        #expect(parsed == box)
    }

    // MARK: - Helpers

    private func assertInitSegmentRoundTrips(
        configurations: [CMAFTrackConfiguration]
    ) async throws {
        let writer = try CMAFInitSegmentWriter(configurations: configurations)
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        var rewrite = BinaryWriter()
        for box in boxes {
            box.encode(to: &rewrite)
        }
        #expect(rewrite.data == bytes)
    }

    private func assertMediaSegmentRoundTrips(
        configuration: CMAFTrackConfiguration,
        useEncryption: Bool = false,
        ivSize: Int = 8
    ) async throws {
        let writer = try CMAFMediaSegmentWriter(
            configuration: configuration,
            fragmentBoundary: .sampleCount(2)
        )
        try await assertSegmentRoundTripsViaWriter(
            writer,
            useEncryption: useEncryption,
            ivSize: ivSize
        )
    }

    private func assertSegmentRoundTripsViaWriter(
        _ writer: CMAFMediaSegmentWriter,
        useEncryption: Bool = false,
        ivSize: Int = 8
    ) async throws {
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<2 {
            let sample: CMAFSampleInput
            if useEncryption {
                sample =
                    ivSize == 0
                    ? CMAFSampleInput(
                        bytes: Data(repeating: 0xCC, count: 256),
                        durationInTimescale: 3000,
                        flags: .syncSample,
                        encryption: CMAFSampleInput.EncryptionMetadata(
                            initializationVector: Data()
                        )
                    )
                    : WriterFixtures.encryptedVideoSample(ivSize: ivSize)
            } else {
                sample = WriterFixtures.videoSample()
            }
            emitted += try await writer.appendSample(
                sample, toTrack: await writer.configuration.trackID
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
}

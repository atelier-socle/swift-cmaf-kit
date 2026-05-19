// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFInitSegmentWriter — basic")
struct CMAFInitSegmentWriterBasicTests {

    @Test
    func emptyConfigurationsRejected() {
        #expect(throws: CMAFWriterError.self) {
            _ = try CMAFInitSegmentWriter(configurations: [])
        }
    }

    @Test
    func duplicateTrackIDsRejected() {
        #expect(throws: CMAFWriterError.self) {
            _ = try CMAFInitSegmentWriter(configurations: [
                WriterFixtures.videoConfig(trackID: 1),
                WriterFixtures.audioConfig(trackID: 1)
            ])
        }
    }

    @Test
    func mismatchedProfilesRejected() {
        #expect(throws: CMAFWriterError.self) {
            _ = try CMAFInitSegmentWriter(configurations: [
                WriterFixtures.videoConfig(trackID: 1, profile: .basic),
                WriterFixtures.audioConfig(trackID: 2, profile: .dash)
            ])
        }
    }

    @Test
    func videoOnlyInitSegmentEmits() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.videoConfig()]
        )
        let bytes = try writer.emit()
        #expect(bytes.count > 8)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        #expect(boxes.first is FileTypeBox)
        #expect(boxes.contains(where: { $0 is MovieBox }))
    }

    @Test
    func audioOnlyInitSegmentEmits() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.audioConfig()]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        #expect(moov.tracks.first?.media?.handlerReference?.handlerType == "soun")
    }

    @Test
    func audioVideoInitSegmentTwoTracks() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [
                WriterFixtures.videoConfig(trackID: 1),
                WriterFixtures.audioConfig(trackID: 2)
            ]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        #expect(moov.tracks.count == 2)
    }

    @Test
    func ftypMajorBrandMatchesProfile() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.videoConfig(profile: .dash)]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let ftyp = try #require(boxes.first as? FileTypeBox)
        #expect(ftyp.majorBrand == "cmfd")
    }

    @Test
    func deterministicByteForByte() throws {
        let configs = [
            WriterFixtures.videoConfig(trackID: 1),
            WriterFixtures.audioConfig(trackID: 2)
        ]
        let writer1 = try CMAFInitSegmentWriter(configurations: configs)
        let writer2 = try CMAFInitSegmentWriter(configurations: configs)
        let bytes1 = try writer1.emit()
        let bytes2 = try writer2.emit()
        #expect(bytes1 == bytes2)
    }

    @Test
    func mvhdNextTrackIDComputedFromMax() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [
                WriterFixtures.videoConfig(trackID: 7),
                WriterFixtures.audioConfig(trackID: 12)
            ]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        #expect(moov.movieHeader?.nextTrackID == 13)
    }

    @Test
    func emittedSegmentRoundTripsThroughRegistry() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.videoConfig()]
        )
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

    @Test
    func ftypCompatibleBrandsAlwaysIncludeIso6() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.videoConfig()]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let ftyp = try #require(boxes.first as? FileTypeBox)
        #expect(ftyp.compatibleBrands.contains("iso6"))
    }
}

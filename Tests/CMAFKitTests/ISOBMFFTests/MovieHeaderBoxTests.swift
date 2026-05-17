// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for MovieHeaderBox (mvhd) — ISO/IEC 14496-12 §8.2.2.
// Covers v0 / v1, matrix, MP4 epoch conversions.

import Foundation
import Testing

@testable import CMAFKit

@Suite("MovieHeaderBox")
struct MovieHeaderBoxTests {

    @Test
    func roundTripV1() async throws {
        let original = MovieHeaderBox(
            version: 1,
            creationTime: 3_700_000_000,  // > UInt32.max; requires v1
            modificationTime: 3_700_000_001,
            timescale: 90_000,
            duration: 5_400_000,
            nextTrackID: 3
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieHeaderBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripV0() async throws {
        let original = MovieHeaderBox(
            version: 0,
            creationTime: 1_000,
            modificationTime: 2_000,
            timescale: 1_000,
            duration: 60_000,
            nextTrackID: 2
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieHeaderBox)
        #expect(parsed.version == 0)
        #expect(parsed == original)
    }

    @Test
    func identityMatrixIsCorrect() {
        let identity = MovieHeaderBox.identityMatrix
        #expect(identity == [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0])
    }

    @Test
    func rotationMatrixRoundTrip() async throws {
        // 90° rotation: [0, 1, 0, -1, 0, 0, 0, 0, 1]
        let rotation: [Double] = [0.0, 1.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0]
        let original = MovieHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 1000,
            duration: 0,
            matrix: rotation,
            nextTrackID: 2
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieHeaderBox)
        #expect(parsed.matrix == rotation)
    }

    @Test
    func mp4EpochOriginIsExact() {
        // 0 seconds since 1904-01-01 = 1904-01-01 00:00:00 UTC.
        let epoch = MP4Epoch.date(fromMP4Seconds: 0)
        // Convert back to MP4 seconds: must return 0.
        // (Going through Date risks subsecond accuracy on Linux, so use
        // the offset directly.)
        let unix = epoch.timeIntervalSince1970
        #expect(Int64(unix) == -MP4Epoch.macOSEpochOffsetSeconds)
    }

    @Test
    func mp4EpochUnixOriginRoundTrip() {
        // 2_082_844_800 MP4 seconds = 1970-01-01 00:00:00 UTC (Unix epoch).
        let unixEpochAsMP4: UInt64 = 2_082_844_800
        let date = MP4Epoch.date(fromMP4Seconds: unixEpochAsMP4)
        #expect(Int64(date.timeIntervalSince1970) == 0)
        let mp4 = MP4Epoch.mp4Seconds(from: date)
        #expect(mp4 == unixEpochAsMP4)
    }

    @Test
    func unsupportedVersionThrows() async throws {
        // Synthesize a mvhd with version=2 (unsupported).
        var writer = BinaryWriter()
        writer.writeFullBox(type: "mvhd", version: 2, flags: 0) { body in
            body.writeZeros(8)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func defaultRateAndVolumeArePreserved() async throws {
        let original = MovieHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            timescale: 1000,
            duration: 0,
            nextTrackID: 2
        )
        #expect(original.rate == 1.0)
        #expect(original.volume == 1.0)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieHeaderBox)
        #expect(parsed.rate == 1.0)
        #expect(parsed.volume == 1.0)
    }

    @Test
    func nextTrackIDPreserved() async throws {
        for nextID: UInt32 in [1, 2, 100, 0xFFFF, 0xFFFF_FFFE] {
            let original = MovieHeaderBox(
                creationTime: 0,
                modificationTime: 0,
                timescale: 1000,
                duration: 0,
                nextTrackID: nextID
            )
            var writer = BinaryWriter()
            original.encode(to: &writer)
            let registry = await BoxRegistry.defaultRegistry()
            let reader = ISOBoxReader()
            let boxes = try await reader.readBoxes(from: writer.data, using: registry)
            let parsed = try #require(boxes.first as? MovieHeaderBox)
            #expect(parsed.nextTrackID == nextID)
        }
    }
}

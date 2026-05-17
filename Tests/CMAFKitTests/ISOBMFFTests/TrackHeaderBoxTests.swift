// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for TrackHeaderBox (tkhd) — ISO/IEC 14496-12 §8.3.2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("TrackHeaderBox")
struct TrackHeaderBoxTests {

    @Test
    func roundTripV1Video() async throws {
        let original = TrackHeaderBox(
            version: 1,
            creationTime: 3_700_000_000,
            modificationTime: 3_700_000_001,
            trackID: 1,
            duration: 5_400_000,
            volume: 0.0,
            width: 1920.0,
            height: 1080.0
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackHeaderBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripV0Audio() async throws {
        let original = TrackHeaderBox(
            version: 0,
            creationTime: 1000,
            modificationTime: 2000,
            trackID: 2,
            duration: 60_000,
            volume: 1.0
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackHeaderBox)
        #expect(parsed.version == 0)
        #expect(parsed.trackID == 2)
        #expect(parsed.volume == 1.0)
    }

    @Test
    func defaultFlagsAreEnabledInMovieInPreview() {
        let box = TrackHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            trackID: 1,
            duration: 0
        )
        #expect(box.flags & TrackHeaderBox.flagEnabled != 0)
        #expect(box.flags & TrackHeaderBox.flagInMovie != 0)
        #expect(box.flags & TrackHeaderBox.flagInPreview != 0)
        #expect(box.flags & TrackHeaderBox.flagInPoster == 0)
    }

    @Test
    func flagConstantsMatchStandard() {
        #expect(TrackHeaderBox.flagEnabled == 0x0000_0001)
        #expect(TrackHeaderBox.flagInMovie == 0x0000_0002)
        #expect(TrackHeaderBox.flagInPreview == 0x0000_0004)
        #expect(TrackHeaderBox.flagInPoster == 0x0000_0008)
    }

    @Test
    func videoDimensionsPreserved() async throws {
        let original = TrackHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            trackID: 1,
            duration: 0,
            width: 3840.0,
            height: 2160.0
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackHeaderBox)
        #expect(parsed.width == 3840.0)
        #expect(parsed.height == 2160.0)
    }

    @Test
    func alternateGroupAndLayerPreserved() async throws {
        let original = TrackHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            trackID: 5,
            duration: 0,
            layer: -1,
            alternateGroup: 7
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackHeaderBox)
        #expect(parsed.layer == -1)
        #expect(parsed.alternateGroup == 7)
    }

    @Test
    func customFlagsPreserved() async throws {
        let customFlags: UInt32 = TrackHeaderBox.flagEnabled | TrackHeaderBox.flagInPoster
        let original = TrackHeaderBox(
            flags: customFlags,
            creationTime: 0,
            modificationTime: 0,
            trackID: 1,
            duration: 0
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackHeaderBox)
        #expect(parsed.flags == customFlags)
    }

    @Test
    func mirrorMatrixRoundTrip() async throws {
        // Horizontal mirror: x → -x. Matrix is [-1, 0, 0, 0, 1, 0, 0, 0, 1].
        let mirror: [Double] = [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
        let original = TrackHeaderBox(
            creationTime: 0,
            modificationTime: 0,
            trackID: 1,
            duration: 0,
            matrix: mirror
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackHeaderBox)
        #expect(parsed.matrix == mirror)
    }

    @Test
    func unsupportedVersionThrows() async throws {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "tkhd", version: 3, flags: 0) { body in
            body.writeZeros(8)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }
}

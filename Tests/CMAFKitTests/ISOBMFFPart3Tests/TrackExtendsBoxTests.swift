// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for TrackExtendsBox (trex) — ISO/IEC 14496-12 §8.8.3.

import Foundation
import Testing

@testable import CMAFKit

@Suite("TrackExtendsBox")
struct TrackExtendsBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let original = TrackExtendsBox(trackID: 1)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackExtendsBox)
        #expect(parsed == original)
        #expect(parsed.defaultSampleDescriptionIndex == 1)
    }

    @Test
    func roundTripExplicitDefaults() async throws {
        let original = TrackExtendsBox(
            trackID: 7,
            defaultSampleDescriptionIndex: 2,
            defaultSampleDuration: 1024,
            defaultSampleSize: 512,
            defaultSampleFlags: 0x0101_0000
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackExtendsBox)
        #expect(parsed == original)
        #expect(parsed.trackID == 7)
        #expect(parsed.defaultSampleFlags == 0x0101_0000)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = TrackExtendsBox(
            trackID: 1,
            defaultSampleDescriptionIndex: 1,
            defaultSampleDuration: 0,
            defaultSampleSize: 0,
            defaultSampleFlags: 0
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 20 74 72 65 78
                00 00 00 00
                00 00 00 01 00 00 00 01
                00 00 00 00 00 00 00 00 00 00 00 00
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 20 74 72 65 78
                00 00 00 00
                00 00 00 03
                00 00 00 02
                00 00 04 00
                00 00 02 00
                01 00 00 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? TrackExtendsBox)
        #expect(parsed.trackID == 3)
        #expect(parsed.defaultSampleDescriptionIndex == 2)
        #expect(parsed.defaultSampleDuration == 0x400)
        #expect(parsed.defaultSampleSize == 0x200)
        #expect(parsed.defaultSampleFlags == 0x0100_0000)
    }

    @Test
    func throwsOnTruncation() async throws {
        let bytes = Data(hex: "00 00 00 14 74 72 65 78 00 00 00 00 00 00 00 01 00 00 00 01")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }
}

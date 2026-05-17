// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for MovieFragmentHeaderBox (mfhd) — ISO/IEC 14496-12 §8.8.5.

import Foundation
import Testing

@testable import CMAFKit

@Suite("MovieFragmentHeaderBox")
struct MovieFragmentHeaderBoxTests {

    @Test
    func roundTripFirstFragment() async throws {
        let original = MovieFragmentHeaderBox(sequenceNumber: 1)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentHeaderBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripLargeSequenceNumber() async throws {
        let original = MovieFragmentHeaderBox(sequenceNumber: 0xFFFF_FFFE)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentHeaderBox)
        #expect(parsed.sequenceNumber == 0xFFFF_FFFE)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = MovieFragmentHeaderBox(sequenceNumber: 0x1234)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 10 6D 66 68 64
                00 00 00 00
                00 00 12 34
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 10 6D 66 68 64
                00 00 00 00
                00 00 00 07
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentHeaderBox)
        #expect(parsed.sequenceNumber == 7)
    }

    @Test
    func throwsOnTruncation() async throws {
        let bytes = Data(hex: "00 00 00 10 6D 66 68 64 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }
}

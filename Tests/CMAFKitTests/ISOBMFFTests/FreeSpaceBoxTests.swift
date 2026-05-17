// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for FreeSpaceBox (free / skip) — ISO/IEC 14496-12 §8.1.2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("FreeSpaceBox")
struct FreeSpaceBoxTests {

    @Test
    func roundTripFree() async throws {
        let original = FreeSpaceBox(onWireType: "free", payload: Data([0xAA, 0xBB, 0xCC, 0xDD]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FreeSpaceBox)
        #expect(parsed == original)
        #expect(parsed.onWireType == "free")
    }

    @Test
    func roundTripSkip() async throws {
        let original = FreeSpaceBox(onWireType: "skip", payload: Data([0x11, 0x22]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FreeSpaceBox)
        #expect(parsed.onWireType == "skip")
        #expect(parsed.payload == Data([0x11, 0x22]))
    }

    @Test
    func freeAndSkipPreservedDistinctly() async throws {
        let free = FreeSpaceBox(onWireType: "free", payload: Data())
        let skip = FreeSpaceBox(onWireType: "skip", payload: Data())
        var writer = BinaryWriter()
        free.encode(to: &writer)
        skip.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.count == 2)
        let f = try #require(boxes[0] as? FreeSpaceBox)
        let s = try #require(boxes[1] as? FreeSpaceBox)
        #expect(f.onWireType == "free")
        #expect(s.onWireType == "skip")
    }

    @Test
    func emptyPayload() async throws {
        let original = FreeSpaceBox(onWireType: "free", payload: Data())
        var writer = BinaryWriter()
        original.encode(to: &writer)
        #expect(Array(writer.data) == [0x00, 0x00, 0x00, 0x08, 0x66, 0x72, 0x65, 0x65])
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = FreeSpaceBox(onWireType: "skip", payload: Data([0xFF]))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(hex: "00 00 00 09 73 6B 69 70 FF")
        #expect(writer.data == expected)
    }

    @Test
    func throwsOnSizeSmallerThanHeader() async throws {
        let bad = Data(hex: "00 00 00 04 66 72 65 65")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bad, using: registry)
        }
    }
}

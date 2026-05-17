// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for MediaDataBox (mdat) — ISO/IEC 14496-12 §8.1.1.
// Includes largesize encoding when the payload would not fit in a UInt32 size field.

import Foundation
import Testing

@testable import CMAFKit

@Suite("MediaDataBox")
struct MediaDataBoxTests {

    @Test
    func roundTripSmallPayload() async throws {
        let original = MediaDataBox(data: Data([0xDE, 0xAD, 0xBE, 0xEF]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MediaDataBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripEmptyPayload() async throws {
        let original = MediaDataBox(data: Data())
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MediaDataBox)
        #expect(parsed.data.isEmpty)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = MediaDataBox(data: Data([0x01, 0x02, 0x03, 0x04]))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        #expect(
            Array(writer.data) == [
                0x00, 0x00, 0x00, 0x0C,
                0x6D, 0x64, 0x61, 0x74,
                0x01, 0x02, 0x03, 0x04
            ])
    }

    @Test
    func largesizeHeaderEmittedForOversizedPayload() throws {
        // Exercises the writer's largesize selection without allocating 4 GiB.
        // We bypass the public encode and call writeBoxHeader directly with a
        // body size that would overflow the 32-bit size field.
        var writer = BinaryWriter()
        let bodySize: UInt64 = UInt64(UInt32.max) - 7  // total = UInt32.max + 1 → largesize
        writer.writeBoxHeader(type: "mdat", bodySize: bodySize)
        #expect(writer.data.count == 16)
        var reader = BinaryReader(writer.data)
        // size=1 (largesize sentinel)
        let size = try reader.readUInt32()
        #expect(size == 1)
        // type='mdat'
        let type = try reader.readFourCC()
        #expect(type == "mdat")
        // 64-bit total size = bodySize + 16 (8 header + 8 largesize)
        let total = try reader.readUInt64()
        #expect(total == bodySize + 16)
    }

    @Test
    func standardHeaderForFitsInUInt32() {
        var writer = BinaryWriter()
        let bodySize: UInt64 = 100
        writer.writeBoxHeader(type: "mdat", bodySize: bodySize)
        #expect(writer.data.count == 8)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 10 6D 64 61 74")  // declared 16 but only 8
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }

    @Test
    func throwsOnSizeSmallerThanHeader() async throws {
        let bad = Data(hex: "00 00 00 04 6D 64 61 74")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bad, using: registry)
        }
    }
}

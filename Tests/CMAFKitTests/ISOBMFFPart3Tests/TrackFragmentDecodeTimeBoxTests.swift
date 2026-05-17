// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for TrackFragmentDecodeTimeBox (tfdt) — ISO/IEC 14496-12 §8.8.12.

import Foundation
import Testing

@testable import CMAFKit

@Suite("TrackFragmentDecodeTimeBox")
struct TrackFragmentDecodeTimeBoxTests {

    @Test
    func roundTripV1Default() async throws {
        let original = TrackFragmentDecodeTimeBox(baseMediaDecodeTime: 0)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentDecodeTimeBox)
        #expect(parsed == original)
        #expect(parsed.version == 1)
    }

    @Test
    func roundTripV0Compact() async throws {
        let original = TrackFragmentDecodeTimeBox(version: 0, baseMediaDecodeTime: 0xDEAD_BEEF)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentDecodeTimeBox)
        #expect(parsed == original)
        #expect(parsed.version == 0)
        #expect(parsed.baseMediaDecodeTime == 0xDEAD_BEEF)
    }

    @Test
    func v1Survives32BitOverflow() async throws {
        let beyond32: UInt64 = UInt64(UInt32.max) + 1
        let original = TrackFragmentDecodeTimeBox(baseMediaDecodeTime: beyond32)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentDecodeTimeBox)
        #expect(parsed.baseMediaDecodeTime == beyond32)
    }

    @Test
    func encodeMatchesKnownBytesV1() {
        let box = TrackFragmentDecodeTimeBox(baseMediaDecodeTime: 0x0102_0304_0506_0708)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 14 74 66 64 74
                01 00 00 00
                01 02 03 04 05 06 07 08
                """)
        #expect(writer.data == expected)
    }

    @Test
    func unsupportedVersionThrows() async throws {
        let bytes = Data(hex: "00 00 00 10 74 66 64 74 05 00 00 00 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }
}

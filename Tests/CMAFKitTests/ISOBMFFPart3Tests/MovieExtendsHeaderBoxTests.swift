// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for MovieExtendsHeaderBox (mehd) — ISO/IEC 14496-12 §8.8.2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("MovieExtendsHeaderBox")
struct MovieExtendsHeaderBoxTests {

    @Test
    func roundTripV1Default() async throws {
        let original = MovieExtendsHeaderBox(fragmentDuration: 1_000_000)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieExtendsHeaderBox)
        #expect(parsed == original)
        #expect(parsed.version == 1)
    }

    @Test
    func roundTripV0() async throws {
        let original = MovieExtendsHeaderBox(version: 0, fragmentDuration: 0xABCD_1234)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieExtendsHeaderBox)
        #expect(parsed == original)
        #expect(parsed.version == 0)
        #expect(parsed.fragmentDuration == 0xABCD_1234)
    }

    @Test
    func v1FragmentDurationFits64Bits() async throws {
        let huge: UInt64 = 0x0123_4567_89AB_CDEF
        let original = MovieExtendsHeaderBox(fragmentDuration: huge)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieExtendsHeaderBox)
        #expect(parsed.fragmentDuration == huge)
    }

    @Test
    func unsupportedVersionThrows() async throws {
        // version = 2 (unsupported)
        let bytes = Data(hex: "00 00 00 10 6D 65 68 64 02 00 00 00 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func defaultV1ProducesV1OnWire() {
        let box = MovieExtendsHeaderBox(fragmentDuration: 42)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // First 4 bytes after the header should encode version 1 + flags 0.
        let versionFlagsOffset = 8
        #expect(writer.data[versionFlagsOffset] == 0x01)
    }
}

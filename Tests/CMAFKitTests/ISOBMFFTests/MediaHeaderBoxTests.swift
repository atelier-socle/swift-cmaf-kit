// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for MediaHeaderBox (mdhd) — ISO/IEC 14496-12 §8.4.2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("MediaHeaderBox")
struct MediaHeaderBoxTests {

    @Test
    func roundTripV1() async throws {
        let original = MediaHeaderBox(
            version: 1,
            creationTime: 3_700_000_000,
            modificationTime: 3_700_000_001,
            timescale: 90_000,
            duration: 5_400_000,
            language: "eng"
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MediaHeaderBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripV0() async throws {
        let original = MediaHeaderBox(
            version: 0,
            creationTime: 1000,
            modificationTime: 2000,
            timescale: 48_000,
            duration: 96_000,
            language: "fra"
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MediaHeaderBox)
        #expect(parsed.version == 0)
        #expect(parsed.language == "fra")
    }

    @Test
    func languageCodeRoundTripCommon() async throws {
        for code in ["eng", "fra", "spa", "deu", "jpn", "und"] {
            let original = MediaHeaderBox(
                creationTime: 0,
                modificationTime: 0,
                timescale: 1000,
                duration: 0,
                language: code
            )
            var writer = BinaryWriter()
            original.encode(to: &writer)
            let registry = await BoxRegistry.defaultRegistry()
            let reader = ISOBoxReader()
            let boxes = try await reader.readBoxes(from: writer.data, using: registry)
            let parsed = try #require(boxes.first as? MediaHeaderBox)
            #expect(parsed.language == code)
        }
    }

    @Test
    func unsupportedVersionThrows() async throws {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "mdhd", version: 5, flags: 0) { body in
            body.writeZeros(8)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func timescalePreservedExactly() async throws {
        for timescale: UInt32 in [1, 1000, 48_000, 90_000, 1_000_000, UInt32.max] {
            let original = MediaHeaderBox(
                creationTime: 0,
                modificationTime: 0,
                timescale: timescale,
                duration: 0,
                language: "und"
            )
            var writer = BinaryWriter()
            original.encode(to: &writer)
            let registry = await BoxRegistry.defaultRegistry()
            let reader = ISOBoxReader()
            let boxes = try await reader.readBoxes(from: writer.data, using: registry)
            let parsed = try #require(boxes.first as? MediaHeaderBox)
            #expect(parsed.timescale == timescale)
        }
    }

    @Test
    func longDurationV1() async throws {
        // Duration > UInt32.max — requires v1.
        let duration: UInt64 = UInt64(UInt32.max) + 1_000_000
        let original = MediaHeaderBox(
            version: 1,
            creationTime: 0,
            modificationTime: 0,
            timescale: 90_000,
            duration: duration,
            language: "und"
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MediaHeaderBox)
        #expect(parsed.duration == duration)
    }

    @Test
    func v0DurationClampsAtUInt32Max() async throws {
        // A v0 box with duration > UInt32.max would have to truncate on encode.
        let original = MediaHeaderBox(
            version: 0,
            creationTime: 0,
            modificationTime: 0,
            timescale: 1000,
            duration: UInt64(UInt32.max) + 100,
            language: "und"
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MediaHeaderBox)
        #expect(parsed.duration == UInt64(UInt32.max))
    }

    @Test
    func roundTripPreservesFlags() async throws {
        let original = MediaHeaderBox(
            flags: 0x00AB_CDEF,
            creationTime: 0,
            modificationTime: 0,
            timescale: 1000,
            duration: 0,
            language: "und"
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MediaHeaderBox)
        #expect(parsed.flags == 0x00AB_CDEF)
    }
}

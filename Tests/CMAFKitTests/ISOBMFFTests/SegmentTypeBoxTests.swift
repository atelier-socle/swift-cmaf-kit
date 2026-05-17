// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SegmentTypeBox (styp) — ISO/IEC 14496-12 §8.16.2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SegmentTypeBox")
struct SegmentTypeBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let original = SegmentTypeBox(
            majorBrand: "cmfc",
            minorVersion: 0,
            compatibleBrands: ["cmfc", "iso6"]
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SegmentTypeBox)
        #expect(parsed == original)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = SegmentTypeBox(
            majorBrand: "cmfc",
            minorVersion: 0,
            compatibleBrands: ["cmfc", "iso6"]
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 18 73 74 79 70
                63 6D 66 63 00 00 00 00
                63 6D 66 63 69 73 6F 36
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 18 73 74 79 70
                63 6D 66 32 00 00 00 01
                63 6D 66 32 63 6D 66 63
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SegmentTypeBox)
        #expect(parsed.majorBrand == "cmf2")
        #expect(parsed.minorVersion == 1)
        #expect(parsed.compatibleBrands == ["cmf2", "cmfc"])
    }

    @Test
    func emptyCompatibleBrands() async throws {
        let original = SegmentTypeBox(majorBrand: "cmfl", minorVersion: 0, compatibleBrands: [])
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SegmentTypeBox)
        #expect(parsed == original)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 20 73 74 79 70")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }

    @Test
    func throwsOnSizeSmallerThanHeader() async throws {
        let bad = Data(hex: "00 00 00 04 73 74 79 70")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bad, using: registry)
        }
    }
}

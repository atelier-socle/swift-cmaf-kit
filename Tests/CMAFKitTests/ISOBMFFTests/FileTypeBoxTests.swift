// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for FileTypeBox (ftyp) — ISO/IEC 14496-12 §4.3.

import Foundation
import Testing

@testable import CMAFKit

@Suite("FileTypeBox")
struct FileTypeBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let original = FileTypeBox(
            majorBrand: "isom",
            minorVersion: 0x200,
            compatibleBrands: ["isom", "iso2", "avc1", "mp41"]
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FileTypeBox)
        #expect(parsed == original)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = FileTypeBox(
            majorBrand: "isom",
            minorVersion: 0x200,
            compatibleBrands: ["isom", "iso2", "avc1", "mp41"]
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 20 66 74 79 70
                69 73 6F 6D 00 00 02 00
                69 73 6F 6D 69 73 6F 32
                61 76 63 31 6D 70 34 31
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 20 66 74 79 70
                69 73 6F 6D 00 00 02 00
                69 73 6F 6D 69 73 6F 32
                61 76 63 31 6D 70 34 31
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? FileTypeBox)
        #expect(parsed.majorBrand == "isom")
        #expect(parsed.minorVersion == 0x200)
        #expect(parsed.compatibleBrands == ["isom", "iso2", "avc1", "mp41"])
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 20 66 74 79 70 69 73 6F 6D")  // only 12 bytes
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }

    @Test
    func throwsOnSizeSmallerThanHeader() async throws {
        let bad = Data(hex: "00 00 00 04 66 74 79 70")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bad, using: registry)
        }
    }

    @Test
    func emptyCompatibleBrandsRoundTrip() async throws {
        let original = FileTypeBox(
            majorBrand: "cmf2",
            minorVersion: 0,
            compatibleBrands: []
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? FileTypeBox)
        #expect(parsed == original)
    }
}

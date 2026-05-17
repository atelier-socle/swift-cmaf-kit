// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for ISOBoxReader — top-level box parsing, random access, path lookup.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ISOBoxReader")
struct ISOBoxReaderTests {

    @Test
    func readsSingleTopLevelBox() async throws {
        let ftyp = FileTypeBox(majorBrand: "isom", minorVersion: 0, compatibleBrands: [])
        var writer = BinaryWriter()
        ftyp.encode(to: &writer)

        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.count == 1)
        let parsed = try #require(boxes.first as? FileTypeBox)
        #expect(parsed.majorBrand == "isom")
    }

    @Test
    func readsMultipleTopLevelBoxes() async throws {
        let ftyp = FileTypeBox(majorBrand: "cmfc", minorVersion: 0, compatibleBrands: ["isom"])
        let free = FreeSpaceBox(onWireType: "free", payload: Data([0xAA, 0xBB]))
        var writer = BinaryWriter()
        ftyp.encode(to: &writer)
        free.encode(to: &writer)

        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.count == 2)
        #expect(boxes[0] is FileTypeBox)
        #expect(boxes[1] is FreeSpaceBox)
    }

    @Test
    func unknownTypeFallsBackToUnknownBox() async throws {
        // 'xxxx' is not registered.
        var writer = BinaryWriter()
        writer.writeBox(type: "xxxx", body: Data([0x01, 0x02, 0x03]))

        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let unknown = try #require(boxes.first as? UnknownBox)
        #expect(unknown.actualType == "xxxx")
        #expect(unknown.payload == Data([0x01, 0x02, 0x03]))
    }

    @Test
    func readBoxAtOffsetReturnsTypedInstance() async throws {
        let free = FreeSpaceBox(onWireType: "free", payload: Data())
        let ftyp = FileTypeBox(majorBrand: "mp42", minorVersion: 1, compatibleBrands: ["isom"])
        var writer = BinaryWriter()
        free.encode(to: &writer)
        let ftypOffset = writer.data.count
        ftyp.encode(to: &writer)

        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let parsed = try await reader.readBox(
            FileTypeBox.self,
            from: writer.data,
            at: ftypOffset,
            using: registry
        )
        #expect(parsed.majorBrand == "mp42")
    }

    @Test
    func readBoxAtOffsetThrowsOnTypeMismatch() async throws {
        let free = FreeSpaceBox(onWireType: "free", payload: Data())
        var writer = BinaryWriter()
        free.encode(to: &writer)

        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBox(
                FileTypeBox.self,
                from: writer.data,
                at: 0,
                using: registry
            )
        }
    }

    @Test
    func findBoxAtPathSingleSegment() async throws {
        let ftyp = FileTypeBox(majorBrand: "isom", minorVersion: 0, compatibleBrands: [])
        var writer = BinaryWriter()
        ftyp.encode(to: &writer)
        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let result = reader.findBox(at: "ftyp", in: boxes)
        #expect(result is FileTypeBox)
    }

    @Test
    func findBoxAtPathWithLeadingSlash() async throws {
        let ftyp = FileTypeBox(majorBrand: "isom", minorVersion: 0, compatibleBrands: [])
        var writer = BinaryWriter()
        ftyp.encode(to: &writer)
        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let result = reader.findBox(at: "/ftyp", in: boxes)
        #expect(result is FileTypeBox)
    }

    @Test
    func findBoxAtPathReturnsNilOnMissing() async throws {
        let ftyp = FileTypeBox(majorBrand: "isom", minorVersion: 0, compatibleBrands: [])
        var writer = BinaryWriter()
        ftyp.encode(to: &writer)
        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let result = reader.findBox(at: "moov", in: boxes)
        #expect(result == nil)
    }

    @Test
    func emptyBufferReturnsEmptyArray() async throws {
        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: Data(), using: registry)
        #expect(boxes.isEmpty)
    }

    @Test
    func roundTripPreservesByteSequence() async throws {
        // Encode → parse → re-encode; bytes must be identical.
        let original = FileTypeBox(
            majorBrand: "cmf2",
            minorVersion: 0x100,
            compatibleBrands: ["isom", "cmfc"]
        )
        var w1 = BinaryWriter()
        original.encode(to: &w1)

        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes {
            box.encode(to: &w2)
        }
        #expect(w1.data == w2.data)
    }
}

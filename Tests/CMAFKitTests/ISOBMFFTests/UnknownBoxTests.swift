// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for UnknownBox — fallback for unregistered FourCCs, preserves payload.

import Foundation
import Testing

@testable import CMAFKit

@Suite("UnknownBox")
struct UnknownBoxTests {

    @Test
    func sentinelBoxType() {
        #expect(UnknownBox.boxType == FourCC(0))
    }

    @Test
    func encodeReEmitsActualType() {
        let header = ISOBoxHeader(type: "xxxx", size: 11, headerSize: 8)
        let unknown = UnknownBox(actualType: "xxxx", header: header, payload: Data([0xAA, 0xBB, 0xCC]))
        var writer = BinaryWriter()
        unknown.encode(to: &writer)
        // size(4) + type(4) + body(3) = 11
        #expect(
            Array(writer.data) == [
                0x00, 0x00, 0x00, 0x0B,
                0x78, 0x78, 0x78, 0x78,
                0xAA, 0xBB, 0xCC
            ])
    }

    @Test
    func roundTripPreservesPayload() async throws {
        // Write an unknown box, parse it back, ensure payload survives.
        var writer = BinaryWriter()
        writer.writeBox(type: "rare", body: Data([0x01, 0x02, 0x03, 0x04, 0x05]))

        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let unknown = try #require(boxes.first as? UnknownBox)
        #expect(unknown.actualType == "rare")
        #expect(unknown.payload == Data([0x01, 0x02, 0x03, 0x04, 0x05]))
    }

    @Test
    func roundTripPreservesUUIDExtendedType() async throws {
        let extType = try #require(UUID(uuidString: "01234567-89AB-CDEF-FEDC-BA9876543210"))
        var writer = BinaryWriter()
        writer.writeUUIDBox(extendedType: extType, body: Data([0xFF, 0xEE]))

        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        // uuid is registered as UUIDBox, not UnknownBox. Verify it parses as UUIDBox.
        let uuidBox = try #require(boxes.first as? UUIDBox)
        #expect(uuidBox.extendedType == extType)
        #expect(uuidBox.payload == Data([0xFF, 0xEE]))
    }

    @Test
    func unknownChildInsideContainerRoundTrip() async throws {
        // moov containing an unknown 'priv' child.
        let header = ISOBoxHeader(type: "moov", size: 16, headerSize: 8)
        let privHeader = ISOBoxHeader(type: "priv", size: 8, headerSize: 8)
        let unknown = UnknownBox(actualType: "priv", header: privHeader, payload: Data())
        let movie = MovieBox(header: header, children: [unknown])
        var writer = BinaryWriter()
        movie.encode(to: &writer)

        let reader = ISOBoxReader()
        let registry = await BoxRegistry.defaultRegistry()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsedMovie = try #require(boxes.first as? MovieBox)
        #expect(parsedMovie.children.count == 1)
        let parsedChild = try #require(parsedMovie.children.first as? UnknownBox)
        #expect(parsedChild.actualType == "priv")
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for UUIDBox (uuid) — ISO/IEC 14496-12 §4.2 extended user type.

import Foundation
import Testing

@testable import CMAFKit

@Suite("UUIDBox")
struct UUIDBoxTests {

    @Test
    func roundTripWithKnownUUID() async throws {
        let extType = try #require(UUID(uuidString: "01234567-89AB-CDEF-FEDC-BA9876543210"))
        let original = UUIDBox(extendedType: extType, payload: Data([0xAA, 0xBB, 0xCC]))
        var writer = BinaryWriter()
        original.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? UUIDBox)
        #expect(parsed == original)
    }

    @Test
    func emptyPayload() async throws {
        let extType = try #require(UUID(uuidString: "ABCDEF01-2345-6789-ABCD-EF0123456789"))
        let original = UUIDBox(extendedType: extType, payload: Data())
        var writer = BinaryWriter()
        original.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? UUIDBox)
        #expect(parsed.extendedType == extType)
        #expect(parsed.payload.isEmpty)
    }

    @Test
    func headerSizeIsTwentyFour() async throws {
        let extType = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let original = UUIDBox(extendedType: extType, payload: Data())
        var writer = BinaryWriter()
        original.encode(to: &writer)
        // size(4) + type(4) + uuid(16) + body(0) = 24
        var reader = BinaryReader(writer.data)
        #expect(try reader.readUInt32() == 24)
    }

    @Test
    func parsedHeaderCarriesUUID() async throws {
        let extType = try #require(UUID(uuidString: "FEDCBA98-7654-3210-0123-456789ABCDEF"))
        let original = UUIDBox(extendedType: extType, payload: Data([0xFF]))
        var writer = BinaryWriter()
        original.encode(to: &writer)

        // Verify the parser's header carries the extended type.
        var binReader = BinaryReader(writer.data)
        let isoReader = ISOBoxReader()
        let header = try isoReader.parseBoxHeader(&binReader)
        #expect(header.type == "uuid")
        #expect(header.userType == extType)
    }

    @Test
    func encodeMatchesExpectedFraming() async throws {
        let extType = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        let original = UUIDBox(extendedType: extType, payload: Data([0xAA]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        // size = 25 bytes: 4 size + 4 type + 16 uuid + 1 body
        #expect(
            Array(writer.data.prefix(8)) == [
                0x00, 0x00, 0x00, 0x19,
                0x75, 0x75, 0x69, 0x64
            ])
        #expect(writer.data.count == 25)
    }

    @Test
    func throwsOnTruncatedExtendedType() async throws {
        // declared size = 4 (smaller than even the standard header); the
        // parser tries to read the 16-byte extended type and fails first
        // with `insufficientData` from the binary reader, before the
        // structural size check fires.
        let bad = Data(hex: "00 00 00 04 75 75 69 64")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: bad, using: registry)
        }
    }
}

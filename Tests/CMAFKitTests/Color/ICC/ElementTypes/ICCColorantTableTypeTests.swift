// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCColorantTableType")
struct ICCColorantTableTypeTests {

    private static func name32(_ ascii: String) -> Data {
        var data = Data(ascii.utf8)
        if data.count > 32 { data = data.prefix(32) }
        data.append(contentsOf: Array(repeating: UInt8(0), count: 32 - data.count))
        return data
    }

    private static func makeColorant(
        name: String = "Cyan",
        pcs: [UInt16] = [0x8000, 0x4000, 0x2000]
    ) -> ICCColorantTableType.Colorant {
        ICCColorantTableType.Colorant(
            name: name32(name),
            pcsCoordinates: pcs
        )
    }

    @Test
    func emptyRoundTrip() throws {
        let original = ICCColorantTableType(colorants: [])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCColorantTableType.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
        #expect(decoded.colorants.isEmpty)
    }

    @Test
    func singleColorantRoundTrip() throws {
        let original = ICCColorantTableType(colorants: [Self.makeColorant()])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCColorantTableType.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
    }

    @Test
    func cmykRoundTrip() throws {
        let original = ICCColorantTableType(colorants: [
            Self.makeColorant(name: "Cyan", pcs: [0x8000, 0x4000, 0x2000]),
            Self.makeColorant(name: "Magenta", pcs: [0x4000, 0x8000, 0x2000]),
            Self.makeColorant(name: "Yellow", pcs: [0x4000, 0x4000, 0x8000]),
            Self.makeColorant(name: "Key", pcs: [0x0000, 0x0000, 0x0000])
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCColorantTableType.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
        #expect(decoded.colorants.count == 4)
    }

    @Test
    func bodySizePerColorantIs38Bytes() {
        let original = ICCColorantTableType(colorants: [Self.makeColorant()])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        // 4 (count) + 32 (name) + 3*2 (pcs) = 42
        #expect(writer.data.count == 4 + 32 + 6)
    }

    @Test
    func parseFromKnownHex() throws {
        // count = 1, name "X" + 31 nulls, pcs = [0x1234, 0x5678, 0x9ABC]
        let nameHex =
            "58000000000000000000000000000000"
            + "00000000000000000000000000000000"
        let bytes = Data(hex: "00000001 " + nameHex + " 1234 5678 9ABC")
        var reader = BinaryReader(bytes)
        let decoded = try ICCColorantTableType.parsePayload(
            reader: &reader,
            byteCount: bytes.count
        )
        #expect(decoded.colorants.count == 1)
        #expect(decoded.colorants[0].name.first == 0x58)  // 'X'
        #expect(decoded.colorants[0].pcsCoordinates == [0x1234, 0x5678, 0x9ABC])
    }

    @Test
    func encodeProducesExpectedBytes() {
        let nameData = Self.name32("X")
        let colorant = ICCColorantTableType.Colorant(
            name: nameData,
            pcsCoordinates: [0x1234, 0x5678, 0x9ABC]
        )
        let value = ICCColorantTableType(colorants: [colorant])
        var writer = BinaryWriter()
        value.encodePayload(to: &writer)

        var expected = Data(hex: "00000001")
        expected.append(nameData)
        expected.append(Data(hex: "1234 5678 9ABC"))
        #expect(writer.data == expected)
    }

    @Test
    func roundTripThroughICCElementDispatch() throws {
        let value = ICCColorantTableType(colorants: [
            Self.makeColorant(name: "Red"),
            Self.makeColorant(name: "Green"),
            Self.makeColorant(name: "Blue")
        ])
        let element = ICCElement.colorantTable(value)

        var writer = BinaryWriter()
        element.encode(to: &writer)
        let elementBytes = writer.data

        var reader = BinaryReader(elementBytes)
        let decoded = try ICCElement.parse(
            reader: &reader,
            payloadByteCount: elementBytes.count
        )
        #expect(decoded == element)
    }

    @Test
    func truncatedInputThrows() {
        // declares count = 5 but only one partial colorant follows.
        let bytes = Data(hex: "00000005 41 42 43")
        #expect(throws: Error.self) {
            var reader = BinaryReader(bytes)
            _ = try ICCColorantTableType.parsePayload(
                reader: &reader,
                byteCount: bytes.count
            )
        }
    }

    @Test
    func equalityAndHashing() {
        let a = ICCColorantTableType(colorants: [Self.makeColorant()])
        let b = ICCColorantTableType(colorants: [Self.makeColorant()])
        let c = ICCColorantTableType(colorants: [
            Self.makeColorant(name: "Other")
        ])
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }

    @Test
    func nameNullPaddedCorrectly() throws {
        // 4-char name should be padded to 32 with nulls.
        let nameData = Self.name32("RGB")
        #expect(nameData.count == 32)
        #expect(nameData[0] == 0x52)  // 'R'
        #expect(nameData[1] == 0x47)  // 'G'
        #expect(nameData[2] == 0x42)  // 'B'
        #expect(nameData[3] == 0x00)
        #expect(nameData[31] == 0x00)
    }

    @Test
    func nameAtMaxLengthRoundTrip() throws {
        // 32-char name (no room for null terminator).
        let max = String(repeating: "A", count: 32)
        let colorant = ICCColorantTableType.Colorant(
            name: Self.name32(max),
            pcsCoordinates: [0, 0, 0]
        )
        let original = ICCColorantTableType(colorants: [colorant])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCColorantTableType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
        #expect(decoded.colorants[0].name.count == 32)
    }

    @Test
    func pcsCoordsExtremeValuesRoundTrip() throws {
        let original = ICCColorantTableType(colorants: [
            Self.makeColorant(name: "Zero", pcs: [0, 0, 0]),
            Self.makeColorant(name: "Max", pcs: [0xFFFF, 0xFFFF, 0xFFFF])
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCColorantTableType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.colorants[0].pcsCoordinates == [0, 0, 0])
        #expect(decoded.colorants[1].pcsCoordinates == [0xFFFF, 0xFFFF, 0xFFFF])
    }

    @Test
    func nameWith8BitBytesPreserved() throws {
        // Raw 32 bytes with high-bit content (not ASCII) round-trip verbatim.
        let rawName = Data((0..<32).map { UInt8(0x80 | ($0 & 0x7F)) })
        let colorant = ICCColorantTableType.Colorant(
            name: rawName,
            pcsCoordinates: [1, 2, 3]
        )
        let original = ICCColorantTableType(colorants: [colorant])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCColorantTableType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.colorants[0].name == rawName)
    }

    @Test
    func manyColorantsRoundTrip() throws {
        let colorants = (0..<32).map { i in
            Self.makeColorant(
                name: "Color\(i)",
                pcs: [UInt16(i), UInt16(i * 2), UInt16(i * 3)]
            )
        }
        let original = ICCColorantTableType(colorants: colorants)
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCColorantTableType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
        #expect(decoded.colorants.count == 32)
    }
}

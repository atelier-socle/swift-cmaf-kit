// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCNamedColor2Type")
struct ICCNamedColor2TypeTests {

    private static func pad32(_ ascii: String) -> Data {
        var data = Data(ascii.utf8)
        if data.count > 32 { data = data.prefix(32) }
        data.append(contentsOf: Array(repeating: UInt8(0), count: 32 - data.count))
        return data
    }

    private static func makeColor(
        name: String = "Sample",
        deviceCoordCount: Int = 3
    ) -> ICCNamedColor2Type.NamedColor {
        ICCNamedColor2Type.NamedColor(
            nameSuffix: pad32(name),
            pcsCoordinates: [0x1234, 0x5678, 0x9ABC],
            deviceCoordinates: (0..<deviceCoordCount).map { UInt16($0 * 100) }
        )
    }

    @Test
    func emptyColorsRoundTrip() throws {
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 0,
            prefix: Self.pad32(""),
            suffix: Self.pad32(""),
            colors: []
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
    }

    @Test
    func singleColorRoundTrip() throws {
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 3,
            prefix: Self.pad32("Pre-"),
            suffix: Self.pad32("-Suf"),
            colors: [Self.makeColor()]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
    }

    @Test
    func multipleColorsRoundTrip() throws {
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 3,
            prefix: Self.pad32("PANTONE "),
            suffix: Self.pad32(" CV"),
            colors: [
                Self.makeColor(name: "185"),
                Self.makeColor(name: "286"),
                Self.makeColor(name: "354")
            ]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
        #expect(decoded.colors.count == 3)
    }

    @Test
    func bodySizeForEmpty() {
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 0,
            prefix: Self.pad32(""),
            suffix: Self.pad32(""),
            colors: []
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        // 4 + 4 + 4 + 32 + 32 = 76
        #expect(writer.data.count == 76)
    }

    @Test
    func bodySizeForFourCMYK() {
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 4,
            prefix: Self.pad32(""),
            suffix: Self.pad32(""),
            colors: [Self.makeColor(deviceCoordCount: 4)]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        // 76 + 32 (name) + 6 (pcs) + 8 (device) = 122
        #expect(writer.data.count == 76 + 32 + 6 + 8)
    }

    @Test
    func roundTripThroughICCElementDispatch() throws {
        let value = ICCNamedColor2Type(
            vendorFlags: 0x4242,
            deviceCoordinateCount: 3,
            prefix: Self.pad32("rgb-"),
            suffix: Self.pad32(""),
            colors: [Self.makeColor()]
        )
        let element = ICCElement.namedColor2(value)

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
        // Insufficient bytes for prefix.
        let bytes = Data(hex: "00000000 00000001 00000000 AABBCC")
        #expect(throws: Error.self) {
            var reader = BinaryReader(bytes)
            _ = try ICCNamedColor2Type.parsePayload(
                reader: &reader,
                byteCount: bytes.count
            )
        }
    }

    @Test
    func equalityAndHashing() {
        let a = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 3,
            prefix: Self.pad32("A"),
            suffix: Self.pad32("B"),
            colors: [Self.makeColor()]
        )
        let b = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 3,
            prefix: Self.pad32("A"),
            suffix: Self.pad32("B"),
            colors: [Self.makeColor()]
        )
        let c = ICCNamedColor2Type(
            vendorFlags: 1,
            deviceCoordinateCount: 3,
            prefix: Self.pad32("A"),
            suffix: Self.pad32("B"),
            colors: [Self.makeColor()]
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }

}

@Suite("ICCNamedColor2Type field handling")
struct ICCNamedColor2TypeFieldTests {

    private static func pad32(_ ascii: String) -> Data {
        var data = Data(ascii.utf8)
        if data.count > 32 { data = data.prefix(32) }
        data.append(contentsOf: Array(repeating: UInt8(0), count: 32 - data.count))
        return data
    }

    private static func makeColor(
        name: String = "Sample",
        deviceCoordCount: Int = 3
    ) -> ICCNamedColor2Type.NamedColor {
        ICCNamedColor2Type.NamedColor(
            nameSuffix: pad32(name),
            pcsCoordinates: [0x1234, 0x5678, 0x9ABC],
            deviceCoordinates: (0..<deviceCoordCount).map { UInt16($0 * 100) }
        )
    }

    @Test
    func prefixAndSuffixRoundTrip() throws {
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 0,
            prefix: Self.pad32("BRAND-"),
            suffix: Self.pad32("-2026"),
            colors: []
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.prefix == Self.pad32("BRAND-"))
        #expect(decoded.suffix == Self.pad32("-2026"))
    }

    @Test
    func zeroDeviceCoordinatesRoundTrip() throws {
        let color = ICCNamedColor2Type.NamedColor(
            nameSuffix: Self.pad32("c1"),
            pcsCoordinates: [0xAAAA, 0xBBBB, 0xCCCC],
            deviceCoordinates: []
        )
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 0,
            prefix: Self.pad32(""),
            suffix: Self.pad32(""),
            colors: [color]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
        #expect(decoded.colors[0].deviceCoordinates.isEmpty)
    }

    @Test
    func fourDeviceCoordinatesRoundTrip() throws {
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 4,
            prefix: Self.pad32(""),
            suffix: Self.pad32(""),
            colors: [Self.makeColor(deviceCoordCount: 4)]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
        #expect(decoded.colors[0].deviceCoordinates.count == 4)
    }

    @Test
    func vendorFlagsPreserved() throws {
        let original = ICCNamedColor2Type(
            vendorFlags: 0xDEAD_BEEF,
            deviceCoordinateCount: 0,
            prefix: Self.pad32(""),
            suffix: Self.pad32(""),
            colors: []
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.vendorFlags == 0xDEAD_BEEF)
    }

    @Test
    func deviceCoordinatesArrayLengthMatchesCount() throws {
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 5,
            prefix: Self.pad32(""),
            suffix: Self.pad32(""),
            colors: [
                Self.makeColor(name: "a", deviceCoordCount: 5),
                Self.makeColor(name: "b", deviceCoordCount: 5),
                Self.makeColor(name: "c", deviceCoordCount: 5)
            ]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.colors.count == 3)
        for color in decoded.colors {
            #expect(color.deviceCoordinates.count == 5)
        }
    }

    @Test
    func parseFromKnownHex() throws {
        // vendorFlags=0, count=1, deviceCount=3
        // prefix and suffix 32 zero bytes each
        // color: name 32 zero bytes, pcs [0x1111, 0x2222, 0x3333], device [0xAAAA, 0xBBBB, 0xCCCC]
        let zeros32 = String(repeating: "00", count: 32)
        let hex =
            "00000000 00000001 00000003 "
            + zeros32 + " " + zeros32 + " " + zeros32
            + " 1111 2222 3333 AAAA BBBB CCCC"
        let bytes = Data(hex: hex)
        var reader = BinaryReader(bytes)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: bytes.count
        )
        #expect(decoded.deviceCoordinateCount == 3)
        #expect(decoded.colors.count == 1)
        #expect(decoded.colors[0].pcsCoordinates == [0x1111, 0x2222, 0x3333])
        #expect(decoded.colors[0].deviceCoordinates == [0xAAAA, 0xBBBB, 0xCCCC])
    }

    @Test
    func pcsExtremeValuesRoundTrip() throws {
        let color = ICCNamedColor2Type.NamedColor(
            nameSuffix: Self.pad32("X"),
            pcsCoordinates: [0xFFFF, 0x0000, 0xFFFF],
            deviceCoordinates: []
        )
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 0,
            prefix: Self.pad32(""),
            suffix: Self.pad32(""),
            colors: [color]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.colors[0].pcsCoordinates == [0xFFFF, 0x0000, 0xFFFF])
    }

    @Test
    func nonAsciiPrefixAndSuffixPreserved() throws {
        let rawPrefix = Data((0..<32).map { UInt8(0x80 | ($0 & 0x7F)) })
        let rawSuffix = Data((0..<32).map { UInt8(0xC0 | ($0 & 0x3F)) })
        let original = ICCNamedColor2Type(
            vendorFlags: 0,
            deviceCoordinateCount: 0,
            prefix: rawPrefix,
            suffix: rawSuffix,
            colors: []
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCNamedColor2Type.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded.prefix == rawPrefix)
        #expect(decoded.suffix == rawSuffix)
    }
}

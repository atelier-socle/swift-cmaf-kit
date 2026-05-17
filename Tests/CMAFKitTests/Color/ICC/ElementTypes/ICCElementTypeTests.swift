// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCXYZType")
struct ICCXYZTypeTests {

    @Test
    func singleValueRoundTrip() throws {
        let original = ICCXYZType(values: [
            ICCXYZNumber(
                x: ICCS15Fixed16Number(0.9505),
                y: ICCS15Fixed16Number(1.0),
                z: ICCS15Fixed16Number(1.0890)
            )
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCXYZType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func multipleValuesRoundTrip() throws {
        let original = ICCXYZType(values: [
            ICCXYZNumber(x: ICCS15Fixed16Number(0.5), y: ICCS15Fixed16Number(0.5), z: ICCS15Fixed16Number(0.5)),
            ICCXYZNumber(x: ICCS15Fixed16Number(1.0), y: ICCS15Fixed16Number(1.0), z: ICCS15Fixed16Number(1.0))
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCXYZType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func emptyArrayRoundTrip() throws {
        let original = ICCXYZType(values: [])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        #expect(writer.data.count == 0)
    }
}

@Suite("ICCCurveType")
struct ICCCurveTypeTests {

    @Test
    func identityCurveRoundTrip() throws {
        let original = ICCCurveType(values: [])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCCurveType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
        #expect(decoded.isIdentity)
    }

    @Test
    func singleGammaValueIsExposed() throws {
        // gamma 2.2 in u8.8 ≈ 0x0233
        let original = ICCCurveType(values: [0x0233])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCCurveType.parsePayload(reader: &reader, byteCount: writer.data.count)
        let gamma = try #require(decoded.gammaValue)
        #expect((gamma - 2.2).magnitude < 0.01)
    }

    @Test
    func sampledCurveRoundTrip() throws {
        let original = ICCCurveType(values: [0, 256, 512, 768, 1024])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCCurveType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded.values == original.values)
        #expect(decoded.gammaValue == nil)
    }

    @Test
    func emptyCurveIsIdentity() {
        let c = ICCCurveType(values: [])
        #expect(c.isIdentity)
    }
}

@Suite("ICCParametricCurveType")
struct ICCParametricCurveTypeTests {

    @Test
    func gammaOnlyRoundTrip() throws {
        let original = ICCParametricCurveType(
            functionType: .gammaOnly,
            parameters: [ICCS15Fixed16Number(2.2)]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCParametricCurveType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func ifNonNegativeRoundTrip() throws {
        let original = ICCParametricCurveType(
            functionType: .ifNonNegative,
            parameters: [
                ICCS15Fixed16Number(2.4),
                ICCS15Fixed16Number(1.0 / 1.055),
                ICCS15Fixed16Number(0.055 / 1.055)
            ]
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCParametricCurveType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func piecewise4RoundTrip() throws {
        let original = ICCParametricCurveType(
            functionType: .piecewise4,
            parameters: (0..<7).map { ICCS15Fixed16Number(Double($0) * 0.1) }
        )
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCParametricCurveType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded == original)
    }

    @Test
    func unknownFunctionTypeThrows() async throws {
        let bytes = Data([0x00, 0x05, 0x00, 0x00])  // functionType=5 (unknown)
        var reader = BinaryReader(bytes)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCParametricCurveType.parsePayload(reader: &reader, byteCount: 4)
        }
    }
}

@Suite("ICCMultiLocalizedUnicodeType")
struct ICCMultiLocalizedUnicodeTypeTests {

    @Test
    func singleStringRoundTrip() throws {
        let original = ICCMultiLocalizedUnicodeType(strings: [
            .init(languageCode: 0x656E, countryCode: 0x5553, text: "Display P3")
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCMultiLocalizedUnicodeType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded.strings.count == 1)
        #expect(decoded.strings[0].text == "Display P3")
        #expect(decoded.strings[0].languageCode == 0x656E)
    }

    @Test
    func multipleLanguagesRoundTrip() throws {
        let original = ICCMultiLocalizedUnicodeType(strings: [
            .init(languageCode: 0x656E, countryCode: 0x5553, text: "Hello"),
            .init(languageCode: 0x6672, countryCode: 0x4652, text: "Bonjour")
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCMultiLocalizedUnicodeType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded.strings.count == 2)
        #expect(decoded.strings[0].text == "Hello")
        #expect(decoded.strings[1].text == "Bonjour")
    }

    @Test
    func emptyStringsRoundTrip() throws {
        let original = ICCMultiLocalizedUnicodeType(strings: [
            .init(languageCode: 0x656E, countryCode: 0x5553, text: "")
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCMultiLocalizedUnicodeType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded.strings.count == 1)
        #expect(decoded.strings[0].text == "")
    }

    @Test
    func nameRecordSizeIs12() {
        let m = ICCMultiLocalizedUnicodeType(strings: [
            .init(languageCode: 0x656E, countryCode: 0x5553, text: "X")
        ])
        var writer = BinaryWriter()
        m.encodePayload(to: &writer)
        // bytes 4..7 = nameRecordSize == 12
        let recordSize = Data(writer.data[4..<8])
        var reader = BinaryReader(recordSize)
        let value = try? reader.readUInt32()
        #expect(value == 12)
    }

    @Test
    func invalidRecordSizeThrows() async throws {
        // numberOfNames=1, nameRecordSize=8 (invalid)
        let bytes = Data([0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x08])
        var reader = BinaryReader(bytes)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCMultiLocalizedUnicodeType.parsePayload(reader: &reader, byteCount: 8)
        }
    }

    @Test
    func utf16BERoundTrip() throws {
        let original = ICCMultiLocalizedUnicodeType(strings: [
            .init(languageCode: 0x6A61, countryCode: 0x4A50, text: "日本語")
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCMultiLocalizedUnicodeType.parsePayload(reader: &reader, byteCount: writer.data.count)
        #expect(decoded.strings[0].text == "日本語")
    }
}

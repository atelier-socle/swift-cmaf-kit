// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCS15Fixed16ArrayType")
struct ICCS15Fixed16ArrayTypeTests {

    @Test
    func emptyArrayRoundTrip() throws {
        let original = ICCS15Fixed16ArrayType(values: [])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCS15Fixed16ArrayType.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
        #expect(decoded.values.isEmpty)
    }

    @Test
    func singleValueRoundTrip() throws {
        let original = ICCS15Fixed16ArrayType(values: [
            ICCS15Fixed16Number(rawValue: 0x0001_0000)  // 1.0
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        let payload = writer.data
        var reader = BinaryReader(payload)
        let decoded = try ICCS15Fixed16ArrayType.parsePayload(
            reader: &reader,
            byteCount: payload.count
        )
        #expect(decoded == original)
        #expect(decoded.values.count == 1)
        #expect(decoded.values[0].doubleValue == 1.0)
    }

    @Test
    func bodySizeIsFourBytesPerEntry() {
        let original = ICCS15Fixed16ArrayType(values: [
            ICCS15Fixed16Number(0.5),
            ICCS15Fixed16Number(-0.5),
            ICCS15Fixed16Number(2.0)
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        #expect(writer.data.count == 12)
    }

    @Test
    func parseFromKnownHex() throws {
        // Two values: 1.0 (0x00010000) and -1.0 (0xFFFF0000).
        let bytes = Data(hex: "00010000 FFFF0000")
        var reader = BinaryReader(bytes)
        let decoded = try ICCS15Fixed16ArrayType.parsePayload(
            reader: &reader,
            byteCount: bytes.count
        )
        #expect(decoded.values.count == 2)
        #expect(decoded.values[0].doubleValue == 1.0)
        #expect(decoded.values[1].doubleValue == -1.0)
    }

    @Test
    func encodeProducesExpectedBytes() {
        let value = ICCS15Fixed16ArrayType(values: [
            ICCS15Fixed16Number(rawValue: 0x0001_0000),
            ICCS15Fixed16Number(rawValue: 0x0002_0000)
        ])
        var writer = BinaryWriter()
        value.encodePayload(to: &writer)
        let expected = Data(hex: "00010000 00020000")
        #expect(writer.data == expected)
    }

    @Test
    func roundTripThroughICCElementDispatch() throws {
        let value = ICCS15Fixed16ArrayType(values: [
            ICCS15Fixed16Number(1.0),
            ICCS15Fixed16Number(0.0),
            ICCS15Fixed16Number(-1.0)
        ])
        let element = ICCElement.s15Fixed16Array(value)

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
        // byteCount declares 4 (one entry) but only 2 bytes are available.
        let bytes = Data(hex: "AABB")
        #expect(throws: Error.self) {
            var reader = BinaryReader(bytes)
            _ = try ICCS15Fixed16ArrayType.parsePayload(
                reader: &reader,
                byteCount: 4
            )
        }
    }

    @Test
    func equalityAndHashing() {
        let a = ICCS15Fixed16ArrayType(values: [
            ICCS15Fixed16Number(1.0), ICCS15Fixed16Number(2.0)
        ])
        let b = ICCS15Fixed16ArrayType(values: [
            ICCS15Fixed16Number(1.0), ICCS15Fixed16Number(2.0)
        ])
        let c = ICCS15Fixed16ArrayType(values: [
            ICCS15Fixed16Number(1.0), ICCS15Fixed16Number(3.0)
        ])
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }

    @Test
    func signedValuesRoundTrip() throws {
        let original = ICCS15Fixed16ArrayType(values: [
            ICCS15Fixed16Number(-1.0),
            ICCS15Fixed16Number(0.0),
            ICCS15Fixed16Number(1.0),
            ICCS15Fixed16Number(0.5),
            ICCS15Fixed16Number(-0.5)
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCS15Fixed16ArrayType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
    }

    @Test
    func identityMatrix3x3RoundTrip() throws {
        // Canonical chad identity matrix.
        let original = ICCS15Fixed16ArrayType(values: [
            ICCS15Fixed16Number(1.0), ICCS15Fixed16Number(0.0), ICCS15Fixed16Number(0.0),
            ICCS15Fixed16Number(0.0), ICCS15Fixed16Number(1.0), ICCS15Fixed16Number(0.0),
            ICCS15Fixed16Number(0.0), ICCS15Fixed16Number(0.0), ICCS15Fixed16Number(1.0)
        ])
        var writer = BinaryWriter()
        original.encodePayload(to: &writer)
        #expect(writer.data.count == 36)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCS15Fixed16ArrayType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        #expect(decoded == original)
        #expect(decoded.values.count == 9)
    }

    @Test
    func doubleConversionRoundTripWithinPrecision() throws {
        // 1/65536 is the minimum representable step.
        let target: Double = 0.123_456_789
        let value = ICCS15Fixed16Number(target)
        // Round-trip via raw value.
        let arr = ICCS15Fixed16ArrayType(values: [value])
        var writer = BinaryWriter()
        arr.encodePayload(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCS15Fixed16ArrayType.parsePayload(
            reader: &reader,
            byteCount: writer.data.count
        )
        let recovered = decoded.values[0].doubleValue
        let epsilon = 1.0 / 65536.0
        #expect(abs(recovered - target) <= epsilon)
    }

    @Test
    func zeroByteCountYieldsEmptyArray() throws {
        let bytes = Data()
        var reader = BinaryReader(bytes)
        let decoded = try ICCS15Fixed16ArrayType.parsePayload(
            reader: &reader,
            byteCount: 0
        )
        #expect(decoded.values.isEmpty)
    }

    @Test
    func nonMultipleOfFourTruncatesEntries() throws {
        // 6 bytes → only 1 entry (6 / 4 = 1). Parser consumes 4 of the 6.
        let bytes = Data(hex: "00010000 ABCD")
        var reader = BinaryReader(bytes)
        let decoded = try ICCS15Fixed16ArrayType.parsePayload(
            reader: &reader,
            byteCount: bytes.count
        )
        #expect(decoded.values.count == 1)
        #expect(decoded.values[0].doubleValue == 1.0)
    }
}

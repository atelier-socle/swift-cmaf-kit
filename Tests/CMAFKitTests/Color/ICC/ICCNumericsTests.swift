// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCDateTimeNumber")
struct ICCDateTimeNumberTests {

    @Test
    func roundTripBasic() throws {
        let original = ICCDateTimeNumber(year: 2026, month: 5, day: 17, hour: 21, minute: 30, second: 0)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCDateTimeNumber.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func isTwelveBytesOnWire() {
        let dt = ICCDateTimeNumber(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        var writer = BinaryWriter()
        dt.encode(to: &writer)
        #expect(writer.data.count == 12)
    }

    @Test
    func parseFromKnownHex() throws {
        // 2026-05-17 21:30:00
        let bytes = Data(hex: "07 EA 00 05 00 11 00 15 00 1E 00 00")
        var reader = BinaryReader(bytes)
        let decoded = try ICCDateTimeNumber.parse(reader: &reader)
        #expect(decoded.year == 2026)
        #expect(decoded.month == 5)
        #expect(decoded.day == 17)
        #expect(decoded.hour == 21)
        #expect(decoded.minute == 30)
        #expect(decoded.second == 0)
    }

    @Test
    func zeroValuesRoundTrip() throws {
        let original = ICCDateTimeNumber(year: 0, month: 0, day: 0, hour: 0, minute: 0, second: 0)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCDateTimeNumber.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func maxValuesRoundTrip() throws {
        let original = ICCDateTimeNumber(year: 65535, month: 65535, day: 65535, hour: 65535, minute: 65535, second: 65535)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCDateTimeNumber.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func hashableConformance() {
        let a = ICCDateTimeNumber(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        let b = ICCDateTimeNumber(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        #expect(a.hashValue == b.hashValue)
    }
}

@Suite("ICCS15Fixed16Number")
struct ICCS15Fixed16NumberTests {

    @Test
    func rawValueRoundTrip() throws {
        let original = ICCS15Fixed16Number(rawValue: 0x0001_0000)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCS15Fixed16Number.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func doubleConversionToOne() {
        let n = ICCS15Fixed16Number(1.0)
        #expect(n.rawValue == 0x0001_0000)
        #expect(n.doubleValue == 1.0)
    }

    @Test
    func doubleConversionToHalf() {
        let n = ICCS15Fixed16Number(0.5)
        #expect(n.rawValue == 0x0000_8000)
        #expect(n.doubleValue == 0.5)
    }

    @Test
    func negativeValueRoundTrip() {
        let n = ICCS15Fixed16Number(-1.5)
        #expect((n.doubleValue - (-1.5)).magnitude < 0.001)
    }

    @Test
    func isFourBytesOnWire() {
        let n = ICCS15Fixed16Number(rawValue: 0)
        var writer = BinaryWriter()
        n.encode(to: &writer)
        #expect(writer.data.count == 4)
    }

    @Test
    func d50IlluminantApproximation() {
        let xN = ICCS15Fixed16Number(0.9642)
        #expect((xN.doubleValue - 0.9642).magnitude < 0.001)
    }

    @Test
    func minValueRoundTrip() throws {
        let original = ICCS15Fixed16Number(rawValue: Int32.min)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCS15Fixed16Number.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func maxValueRoundTrip() throws {
        let original = ICCS15Fixed16Number(rawValue: Int32.max)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCS15Fixed16Number.parse(reader: &reader)
        #expect(decoded == original)
    }
}

@Suite("ICCU16Fixed16Number")
struct ICCU16Fixed16NumberTests {

    @Test
    func rawValueRoundTrip() throws {
        let original = ICCU16Fixed16Number(rawValue: 0x0002_0000)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCU16Fixed16Number.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func doubleConversionToTwo() {
        let n = ICCU16Fixed16Number(2.0)
        #expect(n.rawValue == 0x0002_0000)
        #expect(n.doubleValue == 2.0)
    }

    @Test
    func zeroRoundTrip() throws {
        let original = ICCU16Fixed16Number(0.0)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCU16Fixed16Number.parse(reader: &reader)
        #expect(decoded.doubleValue == 0.0)
    }

    @Test
    func maxRoundTrip() throws {
        let original = ICCU16Fixed16Number(rawValue: UInt32.max)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCU16Fixed16Number.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func isFourBytesOnWire() {
        let n = ICCU16Fixed16Number(rawValue: 0)
        var writer = BinaryWriter()
        n.encode(to: &writer)
        #expect(writer.data.count == 4)
    }

    @Test
    func hashable() {
        let a = ICCU16Fixed16Number(1.5)
        let b = ICCU16Fixed16Number(1.5)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func halfValueExact() {
        let n = ICCU16Fixed16Number(0.5)
        #expect(n.rawValue == 0x0000_8000)
    }

    @Test
    func quarterValueExact() {
        let n = ICCU16Fixed16Number(0.25)
        #expect(n.rawValue == 0x0000_4000)
    }
}

@Suite("ICCXYZNumber")
struct ICCXYZNumberTests {

    @Test
    func d50Illuminant() throws {
        let original = ICCXYZNumber(
            x: ICCS15Fixed16Number(0.9642),
            y: ICCS15Fixed16Number(1.0),
            z: ICCS15Fixed16Number(0.8249)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCXYZNumber.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func d65Illuminant() throws {
        let original = ICCXYZNumber(
            x: ICCS15Fixed16Number(0.9505),
            y: ICCS15Fixed16Number(1.0),
            z: ICCS15Fixed16Number(1.0890)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCXYZNumber.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func zeroXYZ() throws {
        let original = ICCXYZNumber(
            x: ICCS15Fixed16Number(0.0),
            y: ICCS15Fixed16Number(0.0),
            z: ICCS15Fixed16Number(0.0)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCXYZNumber.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func isTwelveBytesOnWire() {
        let n = ICCXYZNumber(
            x: ICCS15Fixed16Number(0.0),
            y: ICCS15Fixed16Number(0.0),
            z: ICCS15Fixed16Number(0.0)
        )
        var writer = BinaryWriter()
        n.encode(to: &writer)
        #expect(writer.data.count == 12)
    }

    @Test
    func negativeComponentsAllowed() throws {
        let original = ICCXYZNumber(
            x: ICCS15Fixed16Number(-0.5),
            y: ICCS15Fixed16Number(1.0),
            z: ICCS15Fixed16Number(-2.0)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCXYZNumber.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func hashable() {
        let a = ICCXYZNumber(
            x: ICCS15Fixed16Number(0.9642),
            y: ICCS15Fixed16Number(1.0),
            z: ICCS15Fixed16Number(0.8249)
        )
        let b = a
        #expect(a.hashValue == b.hashValue)
    }
}

@Suite("ICCResponse16Number")
struct ICCResponse16NumberTests {

    @Test
    func roundTrip() throws {
        let original = ICCResponse16Number(
            deviceValue: 32_768,
            measurementValue: ICCS15Fixed16Number(0.5)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCResponse16Number.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func isEightBytesOnWire() {
        let r = ICCResponse16Number(
            deviceValue: 0,
            measurementValue: ICCS15Fixed16Number(0.0)
        )
        var writer = BinaryWriter()
        r.encode(to: &writer)
        #expect(writer.data.count == 8)
    }

    @Test
    func reservedBytesAreZero() {
        let r = ICCResponse16Number(
            deviceValue: 0x1234,
            measurementValue: ICCS15Fixed16Number(rawValue: Int32(bitPattern: 0xDEAD_BEEF))
        )
        var writer = BinaryWriter()
        r.encode(to: &writer)
        // Bytes 2 and 3 are reserved.
        #expect(writer.data[2] == 0x00)
        #expect(writer.data[3] == 0x00)
    }

    @Test
    func zeroValuesRoundTrip() throws {
        let original = ICCResponse16Number(
            deviceValue: 0,
            measurementValue: ICCS15Fixed16Number(0.0)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCResponse16Number.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func maxDeviceValueRoundTrip() throws {
        let original = ICCResponse16Number(
            deviceValue: UInt16.max,
            measurementValue: ICCS15Fixed16Number(1.0)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCResponse16Number.parse(reader: &reader)
        #expect(decoded == original)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for BinaryWriter — symmetric write counterparts with round-trip checks
// against BinaryReader. ISO/IEC 14496-12 §4.2, §8.3, §8.4.2.3 references.

import Foundation
import Testing

@testable import CMAFKit

@Suite("BinaryWriter")
struct BinaryWriterTests {

    // MARK: Unsigned integers

    @Test
    func writeUInt8() {
        var writer = BinaryWriter()
        writer.writeUInt8(0x42)
        writer.writeUInt8(0xFF)
        #expect(Array(writer.data) == [0x42, 0xFF])
    }

    @Test
    func writeUInt16BigEndian() {
        var writer = BinaryWriter()
        writer.writeUInt16(0x1234)
        #expect(Array(writer.data) == [0x12, 0x34])
    }

    @Test
    func writeUInt24BigEndian() {
        var writer = BinaryWriter()
        writer.writeUInt24(0x0012_3456)
        #expect(Array(writer.data) == [0x12, 0x34, 0x56])
    }

    @Test
    func writeUInt32BigEndian() {
        var writer = BinaryWriter()
        writer.writeUInt32(0xDEAD_BEEF)
        #expect(Array(writer.data) == [0xDE, 0xAD, 0xBE, 0xEF])
    }

    @Test
    func writeUInt64BigEndian() {
        var writer = BinaryWriter()
        writer.writeUInt64(0x0102_0304_0506_0708)
        #expect(Array(writer.data) == [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
    }

    // MARK: Signed integers — round-trip with reader

    @Test
    func writeReadInt16RoundTrip() throws {
        for value in [Int16.min, -1, 0, 1, Int16.max] {
            var writer = BinaryWriter()
            writer.writeInt16(value)
            var reader = BinaryReader(writer.data)
            #expect(try reader.readInt16() == value)
        }
    }

    @Test
    func writeReadInt32RoundTrip() throws {
        for value in [Int32.min, -1, 0, 1, Int32.max] {
            var writer = BinaryWriter()
            writer.writeInt32(value)
            var reader = BinaryReader(writer.data)
            #expect(try reader.readInt32() == value)
        }
    }

    // MARK: Fixed-point round-trips

    @Test
    func writeFixed16_16Identity() {
        var writer = BinaryWriter()
        writer.writeFixed16_16(1.0)
        #expect(Array(writer.data) == [0x00, 0x01, 0x00, 0x00])
    }

    @Test
    func writeFixed16_16RoundTrip() throws {
        for value in [1.0, 0.5, -1.0, 12345.6789, -0.0001] {
            var writer = BinaryWriter()
            writer.writeFixed16_16(value)
            var reader = BinaryReader(writer.data)
            let decoded = try reader.readFixed16_16()
            // Rounding tolerance: ±1 LSB in 16.16 fixed = 1/65536
            #expect(abs(decoded - value) <= 1.0 / 65536.0)
        }
    }

    @Test
    func writeFixed2_30Identity() {
        var writer = BinaryWriter()
        writer.writeFixed2_30(1.0)
        #expect(Array(writer.data) == [0x40, 0x00, 0x00, 0x00])
    }

    @Test
    func writeFixed8_8RoundTrip() throws {
        for value in [1.0, 0.5, -1.0, 12.5] {
            var writer = BinaryWriter()
            writer.writeFixed8_8(value)
            var reader = BinaryReader(writer.data)
            let decoded = try reader.readFixed8_8()
            #expect(abs(decoded - value) <= 1.0 / 256.0)
        }
    }

    // MARK: Matrix round-trip

    @Test
    func writeMatrix3x3IdentityBytes() {
        var writer = BinaryWriter()
        writer.writeMatrix3x3([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0])
        let expected: [UInt8] = [
            0x00, 0x01, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x01, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x40, 0x00, 0x00, 0x00
        ]
        #expect(Array(writer.data) == expected)
    }

    @Test
    func writeMatrix3x3RotationRoundTrip() throws {
        let rotation: [Double] = [0.0, 1.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0]
        var writer = BinaryWriter()
        writer.writeMatrix3x3(rotation)
        var reader = BinaryReader(writer.data)
        let decoded = try reader.readMatrix3x3()
        #expect(decoded == rotation)
    }

    // MARK: FourCC

    @Test
    func writeFourCC() {
        var writer = BinaryWriter()
        writer.writeFourCC("ftyp")
        #expect(Array(writer.data) == [0x66, 0x74, 0x79, 0x70])
    }

    @Test
    func writeFourCCMoovHvc1() {
        var writer = BinaryWriter()
        writer.writeFourCC("moov")
        writer.writeFourCC("hvc1")
        #expect(
            Array(writer.data) == [
                0x6D, 0x6F, 0x6F, 0x76,
                0x68, 0x76, 0x63, 0x31
            ])
    }

    // MARK: Strings

    @Test
    func writeStringUTF8() {
        var writer = BinaryWriter()
        writer.writeString("hello")
        #expect(Array(writer.data) == Array("hello".utf8))
    }

    @Test
    func writeNullTerminatedString() {
        var writer = BinaryWriter()
        writer.writeNullTerminatedString("hi")
        #expect(Array(writer.data) == [0x68, 0x69, 0x00])
    }

    // MARK: UUID

    @Test
    func writeUUIDRoundTrip() throws {
        let original = try #require(UUID(uuidString: "01234567-89AB-CDEF-FEDC-BA9876543210"))
        var writer = BinaryWriter()
        writer.writeUUID(original)
        var reader = BinaryReader(writer.data)
        let decoded = try reader.readUUID()
        #expect(decoded == original)
    }

    // MARK: Language code

    @Test
    func writeLanguageCodeEng() {
        var writer = BinaryWriter()
        writer.writeLanguageCode("eng")
        #expect(Array(writer.data) == [0x15, 0xC7])
    }

    @Test
    func writeLanguageCodeFra() {
        var writer = BinaryWriter()
        writer.writeLanguageCode("fra")
        #expect(Array(writer.data) == [0x1A, 0x41])
    }

    @Test
    func writeLanguageCodeRoundTrip() throws {
        for code in ["eng", "fra", "spa", "deu", "und"] {
            var writer = BinaryWriter()
            writer.writeLanguageCode(code)
            var reader = BinaryReader(writer.data)
            #expect(try reader.readLanguageCode() == code)
        }
    }

    // MARK: Zero padding

    @Test
    func writeZeros() {
        var writer = BinaryWriter()
        writer.writeZeros(5)
        #expect(Array(writer.data) == [0x00, 0x00, 0x00, 0x00, 0x00])
    }

    @Test
    func writeZerosWithNegativeIsNoop() {
        var writer = BinaryWriter()
        writer.writeZeros(0)
        writer.writeZeros(-3)
        #expect(writer.data.isEmpty)
    }

    // MARK: Accumulation

    @Test
    func dataAccumulatesAcrossWrites() {
        var writer = BinaryWriter()
        writer.writeUInt8(0xAA)
        writer.writeUInt16(0x1234)
        writer.writeUInt32(0xDEAD_BEEF)
        #expect(
            Array(writer.data) == [
                0xAA, 0x12, 0x34, 0xDE, 0xAD, 0xBE, 0xEF
            ])
    }

    // MARK: writeData

    @Test
    func writeDataAppends() {
        var writer = BinaryWriter()
        writer.writeData(Data([0x01, 0x02, 0x03]))
        writer.writeData(Data([0x04, 0x05]))
        #expect(Array(writer.data) == [0x01, 0x02, 0x03, 0x04, 0x05])
    }

    @Test
    func writeBytesAppends() {
        var writer = BinaryWriter()
        writer.writeBytes([0x10, 0x20, 0x30])
        #expect(Array(writer.data) == [0x10, 0x20, 0x30])
    }
}

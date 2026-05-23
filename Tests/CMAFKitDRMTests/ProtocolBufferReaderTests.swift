// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("ProtocolBufferReader")
struct ProtocolBufferReaderTests {

    @Test
    func varintReadsSingleByte() throws {
        var reader = ProtocolBufferReader(Data([0x00]))
        #expect(try reader.readVarint() == 0)
    }

    @Test
    func varintReadsByteWithValue127() throws {
        var reader = ProtocolBufferReader(Data([0x7F]))
        #expect(try reader.readVarint() == 127)
    }

    @Test
    func varintReadsTwoByteValue128() throws {
        // 128 = 0b1000_0000_0000_0001 (LE 7-bit groups)
        var reader = ProtocolBufferReader(Data([0x80, 0x01]))
        #expect(try reader.readVarint() == 128)
    }

    @Test
    func varintReadsLargeValue300() throws {
        // 300 = 0b1010_1100_0000_0010
        var reader = ProtocolBufferReader(Data([0xAC, 0x02]))
        #expect(try reader.readVarint() == 300)
    }

    @Test
    func varintReadsMaxUInt32() throws {
        // 0xFFFF_FFFF = 4_294_967_295
        var reader = ProtocolBufferReader(Data([0xFF, 0xFF, 0xFF, 0xFF, 0x0F]))
        #expect(try reader.readVarint() == 0xFFFF_FFFF)
    }

    @Test
    func varintReadsMaxUInt64() throws {
        var reader = ProtocolBufferReader(
            Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
        )
        #expect(try reader.readVarint() == UInt64.max)
    }

    @Test
    func varintTruncatedThrows() {
        var reader = ProtocolBufferReader(Data([0x80]))
        #expect(throws: DRMSystemError.self) {
            _ = try reader.readVarint()
        }
    }

    @Test
    func varintOverflowOn11thByteThrows() {
        var reader = ProtocolBufferReader(
            Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
        )
        #expect(throws: DRMSystemError.self) {
            _ = try reader.readVarint()
        }
    }

    @Test
    func tagReadsFieldNumberAndWireType() throws {
        // (field 1, wire type 2) = (1 << 3) | 2 = 0x0A
        var reader = ProtocolBufferReader(Data([0x0A]))
        let (fieldNumber, wireType) = try reader.readTag()
        #expect(fieldNumber == 1)
        #expect(wireType == 2)
    }

    @Test
    func tagFieldNumberZeroThrows() {
        // Tag with field number 0 = wire type only (invalid).
        var reader = ProtocolBufferReader(Data([0x00]))
        #expect(throws: DRMSystemError.self) {
            _ = try reader.readTag()
        }
    }

    @Test
    func lengthDelimitedReadsLengthPrefixedBytes() throws {
        var reader = ProtocolBufferReader(Data([0x04, 0xDE, 0xAD, 0xBE, 0xEF]))
        let bytes = try reader.readLengthDelimited()
        #expect(bytes == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }

    @Test
    func lengthDelimitedTruncatedThrows() {
        var reader = ProtocolBufferReader(Data([0x05, 0xDE, 0xAD]))
        #expect(throws: DRMSystemError.self) {
            _ = try reader.readLengthDelimited()
        }
    }

    @Test
    func fixed32ReadsLittleEndian() throws {
        var reader = ProtocolBufferReader(Data([0x78, 0x56, 0x34, 0x12]))
        #expect(try reader.readFixed32() == 0x1234_5678)
    }

    @Test
    func fixed64ReadsLittleEndian() throws {
        var reader = ProtocolBufferReader(
            Data([0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01])
        )
        #expect(try reader.readFixed64() == 0x0123_4567_89AB_CDEF)
    }

    @Test
    func fixed32TruncatedThrows() {
        var reader = ProtocolBufferReader(Data([0x78, 0x56]))
        #expect(throws: DRMSystemError.self) {
            _ = try reader.readFixed32()
        }
    }

    @Test
    func skipVarint() throws {
        var reader = ProtocolBufferReader(Data([0xAC, 0x02, 0x42]))
        try reader.skip(wireType: 0)
        #expect(reader.remaining == 1)
    }

    @Test
    func skipFixed64() throws {
        var reader = ProtocolBufferReader(
            Data([0, 0, 0, 0, 0, 0, 0, 0, 0xAA])
        )
        try reader.skip(wireType: 1)
        #expect(reader.remaining == 1)
    }

    @Test
    func skipLengthDelimited() throws {
        var reader = ProtocolBufferReader(Data([0x02, 0xAA, 0xBB, 0xCC]))
        try reader.skip(wireType: 2)
        #expect(reader.remaining == 1)
    }

    @Test
    func skipFixed32() throws {
        var reader = ProtocolBufferReader(Data([0, 0, 0, 0, 0xCC]))
        try reader.skip(wireType: 5)
        #expect(reader.remaining == 1)
    }

    @Test
    func skipUnknownWireTypeThrows() {
        var reader = ProtocolBufferReader(Data([0x00]))
        #expect(throws: DRMSystemError.self) {
            try reader.skip(wireType: 6)
        }
    }

    @Test
    func systemIDPropagatesToErrors() {
        var reader = ProtocolBufferReader(Data([0x80]), systemID: .clearKey)
        #expect(throws: DRMSystemError.self) {
            _ = try reader.readVarint()
        }
    }
}

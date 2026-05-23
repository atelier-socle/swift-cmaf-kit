// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("ProtocolBufferWriter")
struct ProtocolBufferWriterTests {

    @Test
    func varintWritesSingleByte() {
        var writer = ProtocolBufferWriter()
        writer.writeVarint(0)
        #expect(writer.data == Data([0x00]))
    }

    @Test
    func varintWritesByteValue127() {
        var writer = ProtocolBufferWriter()
        writer.writeVarint(127)
        #expect(writer.data == Data([0x7F]))
    }

    @Test
    func varintWritesTwoByteValue128() {
        var writer = ProtocolBufferWriter()
        writer.writeVarint(128)
        #expect(writer.data == Data([0x80, 0x01]))
    }

    @Test
    func varintWritesValue300() {
        var writer = ProtocolBufferWriter()
        writer.writeVarint(300)
        #expect(writer.data == Data([0xAC, 0x02]))
    }

    @Test
    func tagWritesEncodedFieldNumberAndWireType() {
        var writer = ProtocolBufferWriter()
        writer.writeTag(fieldNumber: 1, wireType: 2)
        #expect(writer.data == Data([0x0A]))
    }

    @Test
    func lengthDelimitedWritesPrefixedBytes() {
        var writer = ProtocolBufferWriter()
        writer.writeLengthDelimited(Data([0xDE, 0xAD, 0xBE, 0xEF]))
        #expect(writer.data == Data([0x04, 0xDE, 0xAD, 0xBE, 0xEF]))
    }

    @Test
    func fixed32WritesLittleEndian() {
        var writer = ProtocolBufferWriter()
        writer.writeFixed32(0x1234_5678)
        #expect(writer.data == Data([0x78, 0x56, 0x34, 0x12]))
    }

    @Test
    func fixed64WritesLittleEndian() {
        var writer = ProtocolBufferWriter()
        writer.writeFixed64(0x0123_4567_89AB_CDEF)
        #expect(
            writer.data
                == Data([0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01])
        )
    }

    @Test
    func writerReaderRoundTripVarint() throws {
        var writer = ProtocolBufferWriter()
        writer.writeVarint(1_234_567_890)
        var reader = ProtocolBufferReader(writer.data)
        #expect(try reader.readVarint() == 1_234_567_890)
    }

    @Test
    func writerReaderRoundTripFixed64() throws {
        var writer = ProtocolBufferWriter()
        writer.writeFixed64(0xDEAD_BEEF_CAFE_BABE)
        var reader = ProtocolBufferReader(writer.data)
        #expect(try reader.readFixed64() == 0xDEAD_BEEF_CAFE_BABE)
    }

    @Test
    func varintFieldRoundTrip() throws {
        var writer = ProtocolBufferWriter()
        writer.writeVarintField(fieldNumber: 7, value: 42)
        var reader = ProtocolBufferReader(writer.data)
        let (fieldNumber, wireType) = try reader.readTag()
        #expect(fieldNumber == 7)
        #expect(wireType == 0)
        #expect(try reader.readVarint() == 42)
    }

    @Test
    func bytesFieldRoundTrip() throws {
        var writer = ProtocolBufferWriter()
        let payload = Data([0x10, 0x20, 0x30])
        writer.writeBytesField(fieldNumber: 4, value: payload)
        var reader = ProtocolBufferReader(writer.data)
        let (fieldNumber, wireType) = try reader.readTag()
        #expect(fieldNumber == 4)
        #expect(wireType == 2)
        #expect(try reader.readLengthDelimited() == payload)
    }

    @Test
    func stringFieldRoundTrip() throws {
        var writer = ProtocolBufferWriter()
        writer.writeStringField(fieldNumber: 3, value: "Atelier Socle")
        var reader = ProtocolBufferReader(writer.data)
        _ = try reader.readTag()
        let bytes = try reader.readLengthDelimited()
        #expect(String(data: bytes, encoding: .utf8) == "Atelier Socle")
    }

    @Test
    func fixed32FieldRoundTrip() throws {
        var writer = ProtocolBufferWriter()
        writer.writeFixed32Field(fieldNumber: 5, value: 0xDEAD_BEEF)
        var reader = ProtocolBufferReader(writer.data)
        let (fieldNumber, wireType) = try reader.readTag()
        #expect(fieldNumber == 5)
        #expect(wireType == 5)
        #expect(try reader.readFixed32() == 0xDEAD_BEEF)
    }

    @Test
    func fixed64FieldRoundTrip() throws {
        var writer = ProtocolBufferWriter()
        writer.writeFixed64Field(fieldNumber: 1, value: 0xCAFE_BABE_DEAD_BEEF)
        var reader = ProtocolBufferReader(writer.data)
        let (fieldNumber, wireType) = try reader.readTag()
        #expect(fieldNumber == 1)
        #expect(wireType == 1)
        #expect(try reader.readFixed64() == 0xCAFE_BABE_DEAD_BEEF)
    }
}

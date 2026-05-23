// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage lift for `ProtocolBufferWriter`. The S12b suite covered
// the wire types Widevine uses (0 and 2); these tests exercise
// the I32 / I64 wire-type writes (1 and 5) and varint edge cases
// near the 64-bit boundary.

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("ProtocolBufferWriter — coverage lift")
struct ProtocolBufferWriterCoverageLiftTests {

    @Test
    func varintWritesValue0xFFFFFFFFFFFFFFFE() {
        var writer = ProtocolBufferWriter()
        writer.writeVarint(0xFFFF_FFFF_FFFF_FFFE)
        // 10-byte varint (highest bit of last byte = 0).
        #expect(writer.data.count == 10)
        #expect(writer.data.last == 0x01)
    }

    @Test
    func varintMaxValueRoundTrip() throws {
        var writer = ProtocolBufferWriter()
        writer.writeVarint(UInt64.max)
        var reader = ProtocolBufferReader(writer.data)
        #expect(try reader.readVarint() == UInt64.max)
    }

    @Test
    func varintMaxInt32BoundaryRoundTrip() throws {
        var writer = ProtocolBufferWriter()
        writer.writeVarint(UInt64(Int32.max))
        var reader = ProtocolBufferReader(writer.data)
        #expect(try reader.readVarint() == UInt64(Int32.max))
    }

    @Test
    func fixed32FieldRoundTripValuesAcrossRange() throws {
        for value: UInt32 in [0, 1, 0x80, 0xFFFF, 0xFFFF_FFFF] {
            var writer = ProtocolBufferWriter()
            writer.writeFixed32Field(fieldNumber: 5, value: value)
            var reader = ProtocolBufferReader(writer.data)
            let (fieldNumber, wireType) = try reader.readTag()
            #expect(fieldNumber == 5)
            #expect(wireType == 5)
            #expect(try reader.readFixed32() == value)
        }
    }

    @Test
    func fixed64FieldRoundTripValuesAcrossRange() throws {
        for value: UInt64 in [0, 0xCAFE, 0x1234_5678_9ABC_DEF0, UInt64.max] {
            var writer = ProtocolBufferWriter()
            writer.writeFixed64Field(fieldNumber: 9, value: value)
            var reader = ProtocolBufferReader(writer.data)
            let (fieldNumber, wireType) = try reader.readTag()
            #expect(fieldNumber == 9)
            #expect(wireType == 1)
            #expect(try reader.readFixed64() == value)
        }
    }

    @Test
    func tagWriteFieldNumberMaxRoundTrip() throws {
        var writer = ProtocolBufferWriter()
        writer.writeTag(fieldNumber: 536_870_911, wireType: 0)  // 2^29-1 max
        var reader = ProtocolBufferReader(writer.data)
        let (fieldNumber, wireType) = try reader.readTag()
        #expect(fieldNumber == 536_870_911)
        #expect(wireType == 0)
    }

    @Test
    func writeFixed64DataIsExactlyEightBytes() {
        var writer = ProtocolBufferWriter()
        writer.writeFixed64(0)
        #expect(writer.data.count == 8)
    }

    @Test
    func writeFixed32DataIsExactlyFourBytes() {
        var writer = ProtocolBufferWriter()
        writer.writeFixed32(0)
        #expect(writer.data.count == 4)
    }

    @Test
    func mixedFieldsConcatenateCorrectly() throws {
        var writer = ProtocolBufferWriter()
        writer.writeVarintField(fieldNumber: 1, value: 7)
        writer.writeFixed32Field(fieldNumber: 5, value: 0xABCD_EF00)
        writer.writeFixed64Field(fieldNumber: 9, value: 0x1122_3344_5566_7788)
        var reader = ProtocolBufferReader(writer.data)
        var seen: [UInt32] = []
        while reader.hasMore {
            let (fieldNumber, wireType) = try reader.readTag()
            seen.append(fieldNumber)
            try reader.skip(wireType: wireType)
        }
        #expect(seen == [1, 5, 9])
    }

    @Test
    func writerDataAccessorReturnsSnapshot() {
        var writer = ProtocolBufferWriter()
        writer.writeVarint(42)
        let snapshot = writer.data
        writer.writeVarint(99)
        #expect(snapshot.count < writer.data.count)
    }
}

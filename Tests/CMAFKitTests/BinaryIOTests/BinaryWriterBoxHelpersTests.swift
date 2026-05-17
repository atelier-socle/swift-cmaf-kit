// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for the box assembly helpers on BinaryWriter
// (writeBox + writeFullBox), per ISO/IEC 14496-12 §4.2.
//
// CMAFKit provides no separate ISOBoxWriter type — these helpers plus
// per-box `encode(to:)` are the entire ISOBMFF writing surface.

import Foundation
import Testing

@testable import CMAFKit

@Suite("BinaryWriter — box helpers")
struct BinaryWriterBoxHelpersTests {

    // MARK: writeBox standard 8-byte header

    @Test
    func writeBoxProducesStandardHeader() {
        var writer = BinaryWriter()
        let body = Data([0x01, 0x02, 0x03, 0x04])
        writer.writeBox(type: "free", body: body)
        // size (4) + type (4) + body (4) = 12
        let expected: [UInt8] = [
            0x00, 0x00, 0x00, 0x0C,  // size = 12
            0x66, 0x72, 0x65, 0x65,  // 'free'
            0x01, 0x02, 0x03, 0x04  // body
        ]
        #expect(Array(writer.data) == expected)
    }

    @Test
    func writeBoxEmptyBody() {
        var writer = BinaryWriter()
        writer.writeBox(type: "free", body: Data())
        let expected: [UInt8] = [
            0x00, 0x00, 0x00, 0x08,  // size = 8 (header only)
            0x66, 0x72, 0x65, 0x65  // 'free'
        ]
        #expect(Array(writer.data) == expected)
    }

    @Test
    func writeBoxClosureForm() {
        var writer = BinaryWriter()
        writer.writeBox(type: "ftyp") { inner in
            inner.writeFourCC("isom")
            inner.writeUInt32(0)
            inner.writeFourCC("cmfc")
        }
        // size (4) + type (4) + body (4+4+4) = 20
        let expected: [UInt8] = [
            0x00, 0x00, 0x00, 0x14,
            0x66, 0x74, 0x79, 0x70,
            0x69, 0x73, 0x6F, 0x6D,
            0x00, 0x00, 0x00, 0x00,
            0x63, 0x6D, 0x66, 0x63
        ]
        #expect(Array(writer.data) == expected)
    }

    // MARK: Nested boxes via closure

    @Test
    func writeBoxNestedClosure() throws {
        // Build moov { mvhd (full box) }
        var writer = BinaryWriter()
        writer.writeBox(type: "moov") { moov in
            moov.writeFullBox(type: "mvhd", version: 0, flags: 0) { mvhd in
                mvhd.writeUInt32(0)  // creation_time
                mvhd.writeUInt32(0)  // modification_time
                mvhd.writeUInt32(1000)  // timescale
                mvhd.writeUInt32(5000)  // duration
            }
        }
        // Parse it back to verify the framing
        var reader = BinaryReader(writer.data)
        let moovSize = try reader.readUInt32()
        let moovType = try reader.readFourCC()
        #expect(moovType == "moov")
        let mvhdSize = try reader.readUInt32()
        let mvhdType = try reader.readFourCC()
        #expect(mvhdType == "mvhd")
        #expect(try reader.readUInt8() == 0)  // version
        #expect(try reader.readUInt24() == 0)  // flags
        #expect(try reader.readUInt32() == 0)  // creation
        #expect(try reader.readUInt32() == 0)  // modification
        #expect(try reader.readUInt32() == 1000)  // timescale
        #expect(try reader.readUInt32() == 5000)  // duration
        // mvhd: size(4) + type(4) + ver(1) + flags(3) + 4*4 body = 28
        #expect(mvhdSize == 28)
        // moov contains mvhd → moov size = 8 + 28 = 36
        #expect(moovSize == 36)
    }

    // MARK: writeFullBox

    @Test
    func writeFullBoxVersionZeroFlagsZero() {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "tkhd", version: 0, flags: 0, body: Data([0xAA, 0xBB]))
        // size(4) + type(4) + ver(1) + flags(3) + body(2) = 14
        let expected: [UInt8] = [
            0x00, 0x00, 0x00, 0x0E,
            0x74, 0x6B, 0x68, 0x64,
            0x00,  // version
            0x00, 0x00, 0x00,  // flags
            0xAA, 0xBB  // body
        ]
        #expect(Array(writer.data) == expected)
    }

    @Test
    func writeFullBoxVersionOneFlagsNonZero() {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "trun", version: 1, flags: 0x0000_0001, body: Data([0x00, 0x00, 0x00, 0x05]))
        let expected: [UInt8] = [
            0x00, 0x00, 0x00, 0x10,
            0x74, 0x72, 0x75, 0x6E,
            0x01,  // version
            0x00, 0x00, 0x01,  // flags
            0x00, 0x00, 0x00, 0x05  // body
        ]
        #expect(Array(writer.data) == expected)
    }

    @Test
    func writeFullBoxClosureForm() throws {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "tfhd", version: 0, flags: 0x0001_0000) { body in
            body.writeUInt32(1)  // track_id
            body.writeUInt64(123_456)  // base_data_offset
        }
        // body: 4 + 8 = 12; full box: 8 (size+type) + 4 (ver+flags) + 12 = 24
        var reader = BinaryReader(writer.data)
        #expect(try reader.readUInt32() == 24)
        #expect(try reader.readFourCC() == "tfhd")
        #expect(try reader.readUInt8() == 0)
        #expect(try reader.readUInt24() == 0x0001_0000)
        #expect(try reader.readUInt32() == 1)
        #expect(try reader.readUInt64() == 123_456)
    }

    // MARK: Largesize boundary — internal helper

    @Test
    func writeBoxHeaderStandardEncoding() throws {
        // bodySize fits in UInt32 → standard 8-byte header.
        var writer = BinaryWriter()
        writer.writeBoxHeader(type: "mdat", bodySize: 1024)
        // Expect: [size:4-be][type:4]
        #expect(writer.data.count == 8)
        var reader = BinaryReader(writer.data)
        #expect(try reader.readUInt32() == 1024 + 8)
        #expect(try reader.readFourCC() == "mdat")
    }

    @Test
    func writeBoxHeaderLargesizeEncoding() throws {
        // bodySize big enough to require largesize: pick something > UInt32.max-8.
        var writer = BinaryWriter()
        let hugeBody: UInt64 = UInt64(UInt32.max) + 1
        writer.writeBoxHeader(type: "mdat", bodySize: hugeBody)
        // Expect: [size=1:4-be][type:4][largesize:8-be]
        #expect(writer.data.count == 16)
        var reader = BinaryReader(writer.data)
        #expect(try reader.readUInt32() == 1)  // size sentinel
        #expect(try reader.readFourCC() == "mdat")
        #expect(try reader.readUInt64() == hugeBody + 16)  // total largesize incl. header
    }

    @Test
    func writeBoxHeaderBoundaryExactlyUInt32Max() throws {
        // bodySize such that total = UInt32.max exactly → standard header.
        var writer = BinaryWriter()
        let bodySize = UInt64(UInt32.max) - 8
        writer.writeBoxHeader(type: "free", bodySize: bodySize)
        #expect(writer.data.count == 8)
        var reader = BinaryReader(writer.data)
        #expect(try reader.readUInt32() == UInt32.max)
        #expect(try reader.readFourCC() == "free")
    }

    @Test
    func writeBoxHeaderBoundaryJustOverUInt32() throws {
        // bodySize + 8 = UInt32.max + 1 → must switch to largesize.
        var writer = BinaryWriter()
        let bodySize = UInt64(UInt32.max) - 7
        writer.writeBoxHeader(type: "mdat", bodySize: bodySize)
        // The standard encoding is at risk of overflow → largesize triggers.
        // Total over UInt32.max ⇒ largesize on.
        #expect(writer.data.count == 16)
        var reader = BinaryReader(writer.data)
        #expect(try reader.readUInt32() == 1)
        #expect(try reader.readFourCC() == "mdat")
        #expect(try reader.readUInt64() == bodySize + 16)
    }

    // MARK: Full round-trip — synthesized small fragment

    @Test
    func writeBoxAndReadHeaderBack() throws {
        // Build a tiny pdin full box, then read its header surface back.
        var writer = BinaryWriter()
        writer.writeFullBox(type: "pdin", version: 0, flags: 0, body: Data(repeating: 0xAA, count: 8))
        var reader = BinaryReader(writer.data)
        let size = try reader.readUInt32()
        let type = try reader.readFourCC()
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        #expect(size == 20)  // 8 (size+type) + 4 (ver+flags) + 8 (body)
        #expect(type == "pdin")
        #expect(version == 0)
        #expect(flags == 0)
    }
}

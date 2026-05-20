// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage lift for ``ISOBoxOpaque``. The parser has three
// size-handling paths (regular 32-bit size, 64-bit largesize when
// size==1, "to-end-of-file" when size==0) plus a malformed-input
// throw. Each path gets its own test.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ISOBoxOpaque — coverage lift")
struct ISOBoxOpaqueCoverageLiftTests {

    @Test
    func parsesRegular32BitSizeBox() throws {
        // Hand-build a 16-byte 'free' box: 4-byte size + 4-byte
        // type + 8-byte payload.
        var bytes: [UInt8] = [
            0x00, 0x00, 0x00, 0x10,  // size=16
            0x66, 0x72, 0x65, 0x65,  // 'free'
            0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08
        ]
        var reader = BinaryReader(Data(bytes))
        let box = try ISOBoxOpaque.parse(reader: &reader)
        #expect(box.boxType == "free")
        #expect(box.rawBytes.count == 16)
        bytes.removeAll()
    }

    @Test
    func parsesLargesize64BitBox() throws {
        // size32 = 1 signals 64-bit largesize follows.
        var bytes: [UInt8] = []
        bytes.append(contentsOf: [0x00, 0x00, 0x00, 0x01])  // size=1
        bytes.append(contentsOf: [0x66, 0x72, 0x65, 0x65])  // 'free'
        // largesize = 24 bytes total
        bytes.append(contentsOf: [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18
        ])
        bytes.append(contentsOf: [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22])
        var reader = BinaryReader(Data(bytes))
        let box = try ISOBoxOpaque.parse(reader: &reader)
        #expect(box.boxType == "free")
        #expect(box.rawBytes.count == 24)
    }

    @Test
    func parsesEndOfFileBox() throws {
        // size32 = 0 means "extends to end of file". The reader
        // captures the rest of the input.
        var bytes: [UInt8] = []
        bytes.append(contentsOf: [0x00, 0x00, 0x00, 0x00])  // size=0
        bytes.append(contentsOf: [0x66, 0x72, 0x65, 0x65])  // 'free'
        // Plus 12 bytes that should be swallowed.
        bytes.append(contentsOf: Array(repeating: UInt8(0xAB), count: 12))
        var reader = BinaryReader(Data(bytes))
        let box = try ISOBoxOpaque.parse(reader: &reader)
        #expect(box.boxType == "free")
        #expect(box.rawBytes.count == 8 + 12)
    }

    @Test
    func rejectsMalformedSizeSmallerThanHeader() {
        let bytes: [UInt8] = [
            0x00, 0x00, 0x00, 0x04,  // bogus size = 4 (< 8)
            0x66, 0x72, 0x65, 0x65
        ]
        var reader = BinaryReader(Data(bytes))
        #expect(throws: ISOBoxError.self) {
            _ = try ISOBoxOpaque.parse(reader: &reader)
        }
    }

    @Test
    func writeRawAppendsBytesVerbatim() throws {
        let raw = Data([0x00, 0x00, 0x00, 0x0C, 0x66, 0x72, 0x65, 0x65, 0xFA, 0xCE, 0xCA, 0xFE])
        let box = ISOBoxOpaque(boxType: "free", rawBytes: raw)
        var writer = BinaryWriter()
        box.writeRaw(to: &writer)
        #expect(writer.data == raw)
    }

    @Test
    func equatableHashable() {
        let a = ISOBoxOpaque(boxType: "free", rawBytes: Data([0xAA]))
        let b = ISOBoxOpaque(boxType: "free", rawBytes: Data([0xAA]))
        let c = ISOBoxOpaque(boxType: "free", rawBytes: Data([0xBB]))
        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func boxTypeAccessor() {
        let box = ISOBoxOpaque(boxType: "skip", rawBytes: Data([0x00, 0x00, 0x00, 0x08, 0x73, 0x6B, 0x69, 0x70]))
        #expect(box.boxType == "skip")
    }

    @Test
    func rawBytesAccessor() {
        let raw = Data([0x00, 0x00, 0x00, 0x08, 0x66, 0x72, 0x65, 0x65])
        let box = ISOBoxOpaque(boxType: "free", rawBytes: raw)
        #expect(box.rawBytes == raw)
    }
}

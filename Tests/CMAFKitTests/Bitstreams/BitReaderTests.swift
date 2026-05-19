// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("BitReader")
struct BitReaderTests {

    @Test
    func readSingleBitsMSBFirst() throws {
        // 0b10110100 = 0xB4
        var reader = BitReader(Data([0xB4]))
        #expect(try reader.readBit() == 1)
        #expect(try reader.readBit() == 0)
        #expect(try reader.readBit() == 1)
        #expect(try reader.readBit() == 1)
        #expect(try reader.readBit() == 0)
        #expect(try reader.readBit() == 1)
        #expect(try reader.readBit() == 0)
        #expect(try reader.readBit() == 0)
    }

    @Test
    func readBitsCrossesByteBoundary() throws {
        // 0xAB 0xCD = 1010_1011 1100_1101
        // first 12 bits = 1010_1011_1100 = 0xABC = 2748
        var reader = BitReader(Data([0xAB, 0xCD]))
        let value = try reader.readBits(12)
        #expect(value == 0xABC)
    }

    @Test
    func readFullByte() throws {
        var reader = BitReader(Data([0xFE]))
        #expect(try reader.readBits(8) == 0xFE)
    }

    @Test
    func readZeroBitsReturnsZero() throws {
        var reader = BitReader(Data([0xFF]))
        #expect(try reader.readBits(0) == 0)
        #expect(reader.bitsRemaining == 8)
    }

    @Test
    func readBeyondEndThrows() {
        var reader = BitReader(Data([0xFF]))
        #expect(throws: BitstreamError.self) {
            _ = try reader.readBits(9)
        }
    }

    @Test
    func bitsRemainingTracksConsumption() throws {
        var reader = BitReader(Data([0xAA, 0xBB]))
        #expect(reader.bitsRemaining == 16)
        _ = try reader.readBits(3)
        #expect(reader.bitsRemaining == 13)
        _ = try reader.readBits(13)
        #expect(reader.bitsRemaining == 0)
    }

    @Test
    func peekBitsDoesNotAdvance() throws {
        let reader = BitReader(Data([0xAB]))
        let peeked = try reader.peekBits(4)
        #expect(peeked == 0xA)
        #expect(reader.bitsRemaining == 8)
    }

    @Test
    func skipBitsAdvancesCursor() throws {
        var reader = BitReader(Data([0x12, 0x34]))
        try reader.skipBits(4)
        #expect(try reader.readBits(4) == 0x2)
        #expect(try reader.readBits(8) == 0x34)
    }

    @Test
    func skipBitsBeyondEndThrows() {
        var reader = BitReader(Data([0x00]))
        #expect(throws: BitstreamError.self) {
            try reader.skipBits(9)
        }
    }

    @Test
    func byteAlignAfterPartialReadAdvancesToNextByte() throws {
        var reader = BitReader(Data([0xAB, 0xCD]))
        _ = try reader.readBits(3)
        #expect(reader.isByteAligned == false)
        reader.byteAlign()
        #expect(reader.isByteAligned == true)
        #expect(try reader.readBits(8) == 0xCD)
    }

    @Test
    func byteAlignWhenAlignedIsNoOp() throws {
        var reader = BitReader(Data([0xAB, 0xCD]))
        reader.byteAlign()
        #expect(reader.bitsRemaining == 16)
    }

    @Test
    func readBoolReturnsTrueForOneBit() throws {
        var reader = BitReader(Data([0x80]))  // 1000_0000
        #expect(try reader.readBool() == true)
        #expect(try reader.readBool() == false)
    }

    @Test
    func unsignedExpGolombKnownValues() throws {
        // Table 9-1 of ITU-T H.264 §9.1: codenum → bits
        // 0 → 1
        // 1 → 010
        // 2 → 011
        // 3 → 00100
        // 4 → 00101
        let bytes = Data([
            // "1 010 011 00100 00101" packed MSB-first:
            // 1010_0110_0100_0010_1xxx_xxxx
            0b1010_0110, 0b0100_0010, 0b1000_0000
        ])
        var reader = BitReader(bytes)
        #expect(try reader.readUnsignedExpGolomb() == 0)
        #expect(try reader.readUnsignedExpGolomb() == 1)
        #expect(try reader.readUnsignedExpGolomb() == 2)
        #expect(try reader.readUnsignedExpGolomb() == 3)
        #expect(try reader.readUnsignedExpGolomb() == 4)
    }

    @Test
    func signedExpGolombKnownValues() throws {
        // Mapping (Table 9-3): unsigned k → signed:
        // 0 → 0, 1 → 1, 2 → -1, 3 → 2, 4 → -2
        let bytes = Data([0b1010_0110, 0b0100_0010, 0b1000_0000])
        var reader = BitReader(bytes)
        #expect(try reader.readSignedExpGolomb() == 0)
        #expect(try reader.readSignedExpGolomb() == 1)
        #expect(try reader.readSignedExpGolomb() == -1)
        #expect(try reader.readSignedExpGolomb() == 2)
        #expect(try reader.readSignedExpGolomb() == -2)
    }

    @Test
    func expGolombLargeValueRoundTrip() throws {
        // 65535 → 00000000_00000001_00000000_00000000 (33 bits total)
        // codeNum = 65536 = 0x10000 → bitWidth 17 → 16 zeros + 17 bits
        var writer = BitWriter()
        writer.writeUnsignedExpGolomb(65535)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        #expect(try reader.readUnsignedExpGolomb() == 65535)
    }

    @Test
    func unsignedExpGolombOverflowThrows() {
        // 33+ leading zeros → would overflow.
        let bytes = Data(repeating: 0x00, count: 8)
        var reader = BitReader(bytes)
        #expect(throws: BitstreamError.self) {
            _ = try reader.readUnsignedExpGolomb()
        }
    }

    @Test
    func unsignedExpGolombTruncatedThrows() {
        // "00" then EOF — not a complete codeword.
        let bytes = Data([0x00])
        var reader = BitReader(bytes)
        #expect(throws: BitstreamError.self) {
            _ = try reader.readUnsignedExpGolomb()
        }
    }

    @Test
    func byteOffsetReflectsByteAlignedReads() throws {
        var reader = BitReader(Data([0x11, 0x22, 0x33]))
        _ = try reader.readBits(8)
        #expect(reader.byteOffset == 1)
        _ = try reader.readBits(8)
        #expect(reader.byteOffset == 2)
    }

    @Test
    func readBits64() throws {
        let bytes = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE])
        var reader = BitReader(bytes)
        #expect(try reader.readBits(64) == 0xDEAD_BEEF_CAFE_BABE)
    }

    @Test
    func readBitsInvalidNegativeBypassedByPrecondition() throws {
        // Implementation precondition prevents negative count; here we
        // verify it still accepts 0 sanely.
        var reader = BitReader(Data([0xFF]))
        #expect(try reader.readBits(0) == 0)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("BitWriter")
struct BitWriterTests {

    @Test
    func writeSingleBitsMSBFirst() {
        var writer = BitWriter()
        for bit in [1, 0, 1, 1, 0, 1, 0, 0] as [UInt8] {
            writer.writeBit(bit)
        }
        #expect(writer.data == Data([0xB4]))
    }

    @Test
    func writeBitsAcrossByteBoundary() {
        var writer = BitWriter()
        writer.writeBits(0xABC, count: 12)
        writer.byteAlign()
        #expect(writer.data == Data([0xAB, 0xC0]))
    }

    @Test
    func writeBitsRoundTripsThroughReader() throws {
        var writer = BitWriter()
        writer.writeBits(0xDEAD_BEEF, count: 32)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        #expect(try reader.readBits(32) == 0xDEAD_BEEF)
    }

    @Test
    func writeBool() {
        var writer = BitWriter()
        writer.writeBool(true)
        writer.writeBool(false)
        writer.writeBool(true)
        writer.byteAlign()
        #expect(writer.data == Data([0b1010_0000]))
    }

    @Test
    func byteAlignPadsWithZeros() {
        var writer = BitWriter()
        writer.writeBit(1)
        writer.writeBit(1)
        writer.byteAlign()
        #expect(writer.data == Data([0b1100_0000]))
    }

    @Test
    func byteAlignWhenAlignedIsNoOp() {
        var writer = BitWriter()
        writer.writeBits(0xAB, count: 8)
        writer.byteAlign()
        #expect(writer.data == Data([0xAB]))
    }

    @Test
    func bitCountTracksWritten() {
        var writer = BitWriter()
        writer.writeBit(1)
        writer.writeBit(0)
        #expect(writer.bitCount == 2)
        writer.writeBits(0, count: 8)
        #expect(writer.bitCount == 10)
    }

    @Test
    func unsignedExpGolombRoundTrip() throws {
        var writer = BitWriter()
        for value: UInt32 in [0, 1, 2, 3, 4, 100, 1024, 65_535] {
            writer.writeUnsignedExpGolomb(value)
        }
        writer.byteAlign()
        var reader = BitReader(writer.data)
        for expected: UInt32 in [0, 1, 2, 3, 4, 100, 1024, 65_535] {
            #expect(try reader.readUnsignedExpGolomb() == expected)
        }
    }

    @Test
    func signedExpGolombRoundTrip() throws {
        var writer = BitWriter()
        let values: [Int32] = [0, 1, -1, 2, -2, 10, -10, 1000, -1000]
        for v in values {
            writer.writeSignedExpGolomb(v)
        }
        writer.byteAlign()
        var reader = BitReader(writer.data)
        for expected in values {
            #expect(try reader.readSignedExpGolomb() == expected)
        }
    }

    @Test
    func zeroValueUnsignedGolombIsOneBit() {
        var writer = BitWriter()
        writer.writeUnsignedExpGolomb(0)
        writer.byteAlign()
        #expect(writer.data == Data([0b1000_0000]))
    }

    @Test
    func finishReturnsAlignedData() {
        var writer = BitWriter()
        writer.writeBit(1)
        writer.writeBit(0)
        let data = writer.finish()
        #expect(data == Data([0b1000_0000]))
    }

    @Test
    func reservingCapacityDoesNotAffectContent() {
        var writer = BitWriter(reservingCapacity: 64)
        writer.writeBits(0xABCD, count: 16)
        #expect(writer.data == Data([0xAB, 0xCD]))
    }

    @Test
    func writeBitsZeroCountIsNoOp() {
        var writer = BitWriter()
        writer.writeBits(0xFF, count: 0)
        writer.byteAlign()
        #expect(writer.data.isEmpty)
    }

    @Test
    func signedGolombSymmetricLargeMagnitude() throws {
        var writer = BitWriter()
        writer.writeSignedExpGolomb(-32_000)
        writer.writeSignedExpGolomb(32_000)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        #expect(try reader.readSignedExpGolomb() == -32_000)
        #expect(try reader.readSignedExpGolomb() == 32_000)
    }
}

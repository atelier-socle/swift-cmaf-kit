// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("FLACFrameHeader edge cases")
struct FLACFrameHeaderExtraTests {

    private static func writeHeaderBase(
        blocking: UInt8,
        blockSizeCode: UInt8,
        sampleRateCode: UInt8,
        channel: UInt8,
        bitsCode: UInt8
    ) -> BitWriter {
        var writer = BitWriter()
        writer.writeBits(0x3FFE, count: 14)
        writer.writeBool(false)
        writer.writeBits(UInt64(blocking & 0x01), count: 1)
        writer.writeBits(UInt64(blockSizeCode & 0x0F), count: 4)
        writer.writeBits(UInt64(sampleRateCode & 0x0F), count: 4)
        writer.writeBits(UInt64(channel & 0x0F), count: 4)
        writer.writeBits(UInt64(bitsCode & 0x07), count: 3)
        writer.writeBool(false)
        return writer
    }

    @Test
    func blockSize192RoundTrip() throws {
        var w = Self.writeHeaderBase(
            blocking: 0, blockSizeCode: 1, sampleRateCode: 10, channel: 1, bitsCode: 4
        )
        w.writeBits(0, count: 8)  // UTF-8 number
        w.writeBits(0, count: 8)  // CRC
        w.byteAlign()
        let header = try FLACFrameHeader.parse(bitstream: w.data)
        #expect(header.blockSize == 192)
    }

    @Test
    func blockSize256RoundTrip() throws {
        var w = Self.writeHeaderBase(
            blocking: 0, blockSizeCode: 8, sampleRateCode: 10, channel: 1, bitsCode: 4
        )
        w.writeBits(0, count: 8)
        w.writeBits(0, count: 8)
        w.byteAlign()
        let header = try FLACFrameHeader.parse(bitstream: w.data)
        #expect(header.blockSize == 256)
    }

    @Test
    func blockSizeCode6_8BitSuffixRoundTrip() throws {
        var w = Self.writeHeaderBase(
            blocking: 0, blockSizeCode: 6, sampleRateCode: 10, channel: 1, bitsCode: 4
        )
        w.writeBits(0, count: 8)  // UTF-8 number
        w.writeBits(99, count: 8)  // block size = 99 + 1 = 100
        w.writeBits(0, count: 8)  // CRC
        w.byteAlign()
        let header = try FLACFrameHeader.parse(bitstream: w.data)
        #expect(header.blockSize == 100)
    }

    @Test
    func sampleRate8000And44100() throws {
        for (code, rate) in [(UInt8(4), UInt32(8000)), (UInt8(9), UInt32(44_100))] {
            var w = Self.writeHeaderBase(
                blocking: 0, blockSizeCode: 9, sampleRateCode: code, channel: 1, bitsCode: 4
            )
            w.writeBits(0, count: 8)
            w.writeBits(0, count: 8)
            w.byteAlign()
            let header = try FLACFrameHeader.parse(bitstream: w.data)
            #expect(header.sampleRate == rate)
        }
    }

    @Test
    func sampleRateCode12_8BitKHzSuffix() throws {
        var w = Self.writeHeaderBase(
            blocking: 0, blockSizeCode: 9, sampleRateCode: 12, channel: 1, bitsCode: 4
        )
        w.writeBits(0, count: 8)
        w.writeBits(48, count: 8)  // 48 × 1000 = 48 kHz
        w.writeBits(0, count: 8)
        w.byteAlign()
        let header = try FLACFrameHeader.parse(bitstream: w.data)
        #expect(header.sampleRate == 48_000)
    }

    @Test
    func sampleRateCode14_10HzSuffix() throws {
        var w = Self.writeHeaderBase(
            blocking: 0, blockSizeCode: 9, sampleRateCode: 14, channel: 1, bitsCode: 4
        )
        w.writeBits(0, count: 8)
        w.writeBits(9600, count: 16)  // 9600 × 10 = 96 kHz
        w.writeBits(0, count: 8)
        w.byteAlign()
        let header = try FLACFrameHeader.parse(bitstream: w.data)
        #expect(header.sampleRate == 96_000)
    }

    @Test
    func bitsPerSample20And32() throws {
        // bits code 5 → 20, code 7 → 32.
        for (code, bits) in [(UInt8(5), UInt8(20)), (UInt8(7), UInt8(32))] {
            var w = Self.writeHeaderBase(
                blocking: 0, blockSizeCode: 9, sampleRateCode: 10, channel: 1, bitsCode: code
            )
            w.writeBits(0, count: 8)
            w.writeBits(0, count: 8)
            w.byteAlign()
            let header = try FLACFrameHeader.parse(bitstream: w.data)
            #expect(header.bitsPerSample == bits)
        }
    }

    @Test
    func variableBlockingStrategy() throws {
        var w = Self.writeHeaderBase(
            blocking: 1, blockSizeCode: 9, sampleRateCode: 10, channel: 1, bitsCode: 4
        )
        w.writeBits(0, count: 8)
        w.writeBits(0, count: 8)
        w.byteAlign()
        let header = try FLACFrameHeader.parse(bitstream: w.data)
        #expect(header.blockingStrategy == .variableBlockSize)
    }

    @Test
    func rejectsBlockSizeCodeZero() {
        var w = Self.writeHeaderBase(
            blocking: 0, blockSizeCode: 0, sampleRateCode: 10, channel: 1, bitsCode: 4
        )
        w.writeBits(0, count: 8)
        w.writeBits(0, count: 8)
        w.byteAlign()
        #expect(throws: BitstreamError.self) {
            _ = try FLACFrameHeader.parse(bitstream: w.data)
        }
    }

    @Test
    func rejectsSampleRateCode15() {
        var w = Self.writeHeaderBase(
            blocking: 0, blockSizeCode: 9, sampleRateCode: 15, channel: 1, bitsCode: 4
        )
        w.writeBits(0, count: 8)
        w.writeBits(0, count: 8)
        w.byteAlign()
        #expect(throws: BitstreamError.self) {
            _ = try FLACFrameHeader.parse(bitstream: w.data)
        }
    }

    @Test
    func rejectsBitsPerSampleCode3() {
        var w = Self.writeHeaderBase(
            blocking: 0, blockSizeCode: 9, sampleRateCode: 10, channel: 1, bitsCode: 3
        )
        w.writeBits(0, count: 8)
        w.writeBits(0, count: 8)
        w.byteAlign()
        #expect(throws: BitstreamError.self) {
            _ = try FLACFrameHeader.parse(bitstream: w.data)
        }
    }

    @Test
    func utf8MultibyteFrameNumber() throws {
        // Two-byte UTF-8: leading 110_xxxxx, continuation 10_xxxxxx.
        // 0xC2 = 110_00010, 0x82 = 10_000010 → value = 0b00010_000010 = 0x82 = 130.
        var w = Self.writeHeaderBase(
            blocking: 0, blockSizeCode: 9, sampleRateCode: 10, channel: 1, bitsCode: 4
        )
        w.writeBits(0xC2, count: 8)
        w.writeBits(0x82, count: 8)
        w.writeBits(0, count: 8)
        w.byteAlign()
        let header = try FLACFrameHeader.parse(bitstream: w.data)
        #expect(header.frameOrSampleNumber == 130)
    }
}

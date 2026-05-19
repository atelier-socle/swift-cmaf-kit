// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("FLACFrameHeader")
struct FLACFrameHeaderTests {

    @Test
    func parseSimpleFixedBlockSize() throws {
        // 14-bit sync 0x3FFE + 0 reserved + 0 blocking (fixed)
        // + block-size code 9 (=512) + sample-rate code 10 (=48000)
        // + channel 1 (independent2) + bits 4 (=16) + reserved 0
        // + UTF-8 frame number 0 (1 byte) + CRC-8 placeholder
        //
        // Bits: 11_1111_1111_1110_0_0_1001_1010_0001_100_0_0000_0000_xxxxxxxx
        var writer = BitWriter()
        writer.writeBits(0x3FFE, count: 14)
        writer.writeBool(false)  // reserved
        writer.writeBits(0, count: 1)  // blocking strategy = fixed
        writer.writeBits(9, count: 4)  // block-size code → 512
        writer.writeBits(10, count: 4)  // sample-rate code → 48000
        writer.writeBits(1, count: 4)  // channel assignment → independent2
        writer.writeBits(4, count: 3)  // bits-per-sample → 16
        writer.writeBool(false)  // reserved2
        writer.writeBits(0, count: 8)  // UTF-8 frame number = 0
        writer.writeBits(0xAB, count: 8)  // CRC-8 (any value; not verified)
        writer.byteAlign()

        let header = try FLACFrameHeader.parse(bitstream: writer.data)
        #expect(header.blockingStrategy == .fixedBlockSize)
        #expect(header.blockSize == 512)
        #expect(header.sampleRate == 48_000)
        #expect(header.channelAssignment == .independent2)
        #expect(header.bitsPerSample == 16)
        #expect(header.frameOrSampleNumber == 0)
        #expect(header.crc8 == 0xAB)
    }

    @Test
    func parseVariableBlockSize() throws {
        var writer = BitWriter()
        writer.writeBits(0x3FFE, count: 14)
        writer.writeBool(false)
        writer.writeBits(1, count: 1)  // variable
        writer.writeBits(10, count: 4)  // block-size code → 1024
        writer.writeBits(10, count: 4)  // sample-rate → 48000
        writer.writeBits(2, count: 4)  // channel → independent3
        writer.writeBits(6, count: 3)  // bits → 24
        writer.writeBool(false)
        writer.writeBits(0, count: 8)  // UTF-8 sample number = 0
        writer.writeBits(0x00, count: 8)
        writer.byteAlign()

        let header = try FLACFrameHeader.parse(bitstream: writer.data)
        #expect(header.blockingStrategy == .variableBlockSize)
        #expect(header.blockSize == 1024)
        #expect(header.bitsPerSample == 24)
    }

    @Test
    func sampleRateCode13Uses16BitSuffix() throws {
        var writer = BitWriter()
        writer.writeBits(0x3FFE, count: 14)
        writer.writeBool(false)
        writer.writeBits(0, count: 1)
        writer.writeBits(9, count: 4)
        writer.writeBits(13, count: 4)  // sample-rate code 13 → 16-bit suffix
        writer.writeBits(1, count: 4)
        writer.writeBits(4, count: 3)
        writer.writeBool(false)
        writer.writeBits(0, count: 8)
        writer.writeBits(32_000, count: 16)  // 16-bit Hz suffix
        writer.writeBits(0x00, count: 8)
        writer.byteAlign()

        let header = try FLACFrameHeader.parse(bitstream: writer.data)
        #expect(header.sampleRate == 32_000)
    }

    @Test
    func blockSizeCode7Uses16BitSuffix() throws {
        var writer = BitWriter()
        writer.writeBits(0x3FFE, count: 14)
        writer.writeBool(false)
        writer.writeBits(0, count: 1)
        writer.writeBits(7, count: 4)  // 16-bit block-size suffix
        writer.writeBits(10, count: 4)
        writer.writeBits(1, count: 4)
        writer.writeBits(4, count: 3)
        writer.writeBool(false)
        writer.writeBits(0, count: 8)
        writer.writeBits(4095, count: 16)  // block size = 4095 + 1 = 4096
        writer.writeBits(0x00, count: 8)
        writer.byteAlign()

        let header = try FLACFrameHeader.parse(bitstream: writer.data)
        #expect(header.blockSize == 4096)
    }

    @Test
    func midSideStereo() throws {
        var writer = BitWriter()
        writer.writeBits(0x3FFE, count: 14)
        writer.writeBool(false)
        writer.writeBits(0, count: 1)
        writer.writeBits(9, count: 4)
        writer.writeBits(10, count: 4)
        writer.writeBits(10, count: 4)  // channel → midSide
        writer.writeBits(4, count: 3)
        writer.writeBool(false)
        writer.writeBits(0, count: 8)
        writer.writeBits(0, count: 8)
        writer.byteAlign()

        let header = try FLACFrameHeader.parse(bitstream: writer.data)
        #expect(header.channelAssignment == .midSide)
    }

    @Test
    func badSyncCodeThrows() {
        var writer = BitWriter()
        writer.writeBits(0x3FFF, count: 14)  // wrong sync
        writer.byteAlign()
        #expect(throws: BitstreamError.self) {
            _ = try FLACFrameHeader.parse(bitstream: writer.data)
        }
    }

    @Test
    func reservedBitNonZeroThrows() {
        var writer = BitWriter()
        writer.writeBits(0x3FFE, count: 14)
        writer.writeBool(true)  // reserved must be 0
        writer.byteAlign()
        #expect(throws: BitstreamError.self) {
            _ = try FLACFrameHeader.parse(bitstream: writer.data)
        }
    }

    @Test
    func blockingStrategyCases() {
        #expect(FLACBlockingStrategy.fixedBlockSize.rawValue == 0)
        #expect(FLACBlockingStrategy.variableBlockSize.rawValue == 1)
        #expect(FLACBlockingStrategy.allCases.count == 2)
    }

    @Test
    func channelAssignmentCount() {
        #expect(FLACChannelAssignment.allCases.count == 16)
        #expect(FLACChannelAssignment.leftSide.rawValue == 8)
        #expect(FLACChannelAssignment.rightSide.rawValue == 9)
        #expect(FLACChannelAssignment.midSide.rawValue == 10)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FLACFrameHeader
//
// Reference: Xiph FLAC format specification — FRAME_HEADER.
//
// 14-bit sync code (0x3FFE) + 1 reserved bit + 1 blocking-strategy
// bit + 4-bit block-size code + 4-bit sample-rate code + 4-bit
// channel-assignment code + 3-bit sample-size code + 1 reserved bit
// + UTF-8-encoded frame-or-sample number + optional block-size /
// sample-rate suffix + 8-bit CRC-8.

import Foundation

/// FLAC blocking strategy per Xiph FLAC frame header.
public enum FLACBlockingStrategy: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case fixedBlockSize = 0
    case variableBlockSize = 1
}

/// FLAC channel assignment per Xiph FLAC frame header (4-bit code).
public enum FLACChannelAssignment: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case independent1 = 0
    case independent2 = 1
    case independent3 = 2
    case independent4 = 3
    case independent5 = 4
    case independent6 = 5
    case independent7 = 6
    case independent8 = 7
    case leftSide = 8
    case rightSide = 9
    case midSide = 10
    case reserved11 = 11
    case reserved12 = 12
    case reserved13 = 13
    case reserved14 = 14
    case reserved15 = 15
}

/// FLAC frame header per the Xiph FLAC specification.
public struct FLACFrameHeader: Sendable, Hashable, Equatable {
    public let blockingStrategy: FLACBlockingStrategy
    /// Resolved block size in samples.
    public let blockSize: UInt32
    /// Resolved sample rate in Hz; `0` indicates "inherit from
    /// streaminfo" (block code 0).
    public let sampleRate: UInt32
    public let channelAssignment: FLACChannelAssignment
    /// Resolved bits-per-sample; `0` indicates "inherit from streaminfo".
    public let bitsPerSample: UInt8
    /// UTF-8-encoded frame-or-sample number.
    public let frameOrSampleNumber: UInt64
    /// CRC-8 over the header bytes preceding it.
    public let crc8: UInt8

    public init(
        blockingStrategy: FLACBlockingStrategy,
        blockSize: UInt32,
        sampleRate: UInt32,
        channelAssignment: FLACChannelAssignment,
        bitsPerSample: UInt8,
        frameOrSampleNumber: UInt64,
        crc8: UInt8
    ) {
        self.blockingStrategy = blockingStrategy
        self.blockSize = blockSize
        self.sampleRate = sampleRate
        self.channelAssignment = channelAssignment
        self.bitsPerSample = bitsPerSample
        self.frameOrSampleNumber = frameOrSampleNumber
        self.crc8 = crc8
    }

    /// Sample-rate lookup table indexed by the 4-bit code per the Xiph
    /// FLAC frame header. `0` means "inherit from streaminfo". Codes
    /// 12/13/14 carry the value as a UInt8 / UInt16 suffix in the
    /// frame header. Code 15 is invalid.
    private static let sampleRateTable: [Int: UInt32] = [
        0: 0, 1: 88_200, 2: 176_400, 3: 192_000,
        4: 8_000, 5: 16_000, 6: 22_050, 7: 24_000,
        8: 32_000, 9: 44_100, 10: 48_000, 11: 96_000
    ]

    /// Block-size lookup table. Codes 0, 6, 7 carry the value as a
    /// suffix. Codes 1, 8…15 are fixed values.
    private static let blockSizeTable: [Int: UInt32] = [
        1: 192, 8: 256, 9: 512, 10: 1024, 11: 2048,
        12: 4096, 13: 8192, 14: 16384, 15: 32768
    ]

    private static let bitsPerSampleTable: [Int: UInt8] = [
        0: 0, 1: 8, 2: 12, 4: 16, 5: 20, 6: 24, 7: 32
    ]

    public static func parse(bitstream: Data) throws -> FLACFrameHeader {
        var reader = BitReader(bitstream)
        let sync = UInt16(try reader.readBits(14))
        guard sync == 0x3FFE else {
            throw BitstreamError.flacFrameSyncMismatch(found: sync)
        }
        let reserved = try reader.readBool()
        guard !reserved else {
            throw BitstreamError.reservedBitsNonZero(codec: "FLAC", field: "reserved_1bit")
        }
        let blockingRaw = UInt8(try reader.readBits(1))
        guard let blocking = FLACBlockingStrategy(rawValue: blockingRaw) else {
            throw BitstreamError.unsupportedValue(
                codec: "FLAC", field: "blocking_strategy", value: UInt64(blockingRaw)
            )
        }
        let blockSizeCode = UInt8(try reader.readBits(4))
        let sampleRateCode = UInt8(try reader.readBits(4))
        let channelRaw = UInt8(try reader.readBits(4))
        guard let channelAssignment = FLACChannelAssignment(rawValue: channelRaw) else {
            throw BitstreamError.unsupportedValue(
                codec: "FLAC", field: "channel_assignment", value: UInt64(channelRaw)
            )
        }
        let bitsCode = UInt8(try reader.readBits(3))
        guard let bitsPerSample = bitsPerSampleTable[Int(bitsCode)] else {
            throw BitstreamError.unsupportedValue(
                codec: "FLAC", field: "sample_size_code", value: UInt64(bitsCode)
            )
        }
        let reserved2 = try reader.readBool()
        guard !reserved2 else {
            throw BitstreamError.reservedBitsNonZero(codec: "FLAC", field: "reserved_2")
        }
        let utf8Number = try readUTF8Number(reader: &reader)

        // Resolve block size.
        let resolvedBlockSize: UInt32
        switch blockSizeCode {
        case 0:
            throw BitstreamError.unsupportedValue(
                codec: "FLAC", field: "block_size_code", value: 0
            )
        case 6:
            resolvedBlockSize = UInt32(try reader.readBits(8)) + 1
        case 7:
            resolvedBlockSize = UInt32(try reader.readBits(16)) + 1
        default:
            guard let resolved = blockSizeTable[Int(blockSizeCode)] else {
                throw BitstreamError.unsupportedValue(
                    codec: "FLAC", field: "block_size_code", value: UInt64(blockSizeCode)
                )
            }
            resolvedBlockSize = resolved
        }

        // Resolve sample rate.
        let resolvedSampleRate: UInt32
        switch sampleRateCode {
        case 12:
            resolvedSampleRate = UInt32(try reader.readBits(8)) * 1000
        case 13:
            resolvedSampleRate = UInt32(try reader.readBits(16))
        case 14:
            resolvedSampleRate = UInt32(try reader.readBits(16)) * 10
        case 15:
            throw BitstreamError.unsupportedValue(
                codec: "FLAC", field: "sample_rate_code", value: 15
            )
        default:
            guard let resolved = sampleRateTable[Int(sampleRateCode)] else {
                throw BitstreamError.unsupportedValue(
                    codec: "FLAC", field: "sample_rate_code", value: UInt64(sampleRateCode)
                )
            }
            resolvedSampleRate = resolved
        }

        // CRC-8 — final byte after the header proper.
        let crc8 = UInt8(try reader.readBits(8))

        return FLACFrameHeader(
            blockingStrategy: blocking,
            blockSize: resolvedBlockSize,
            sampleRate: resolvedSampleRate,
            channelAssignment: channelAssignment,
            bitsPerSample: bitsPerSample,
            frameOrSampleNumber: utf8Number,
            crc8: crc8
        )
    }

    /// Decode a FLAC-style UTF-8 frame-or-sample number per the Xiph
    /// FLAC frame-header spec (similar to but not identical to RFC
    /// 3629; this variant supports up to 7-byte sequences).
    private static func readUTF8Number(reader: inout BitReader) throws -> UInt64 {
        let firstByte = UInt8(try reader.readBits(8))
        if firstByte < 0x80 { return UInt64(firstByte) }
        var leadingOnes = 0
        var probe = firstByte
        while probe & 0x80 != 0 {
            leadingOnes += 1
            probe <<= 1
            if leadingOnes > 7 {
                throw BitstreamError.unsupportedValue(
                    codec: "FLAC", field: "utf8_number_leading_ones", value: UInt64(leadingOnes)
                )
            }
        }
        // leadingOnes covers 2…7 byte sequences.
        let payloadMask: UInt8 = UInt8((1 << (8 - leadingOnes)) - 1)
        var value = UInt64(firstByte & payloadMask)
        for _ in 1..<leadingOnes {
            let byte = UInt8(try reader.readBits(8))
            guard (byte & 0xC0) == 0x80 else {
                throw BitstreamError.unsupportedValue(
                    codec: "FLAC",
                    field: "utf8_number_continuation",
                    value: UInt64(byte)
                )
            }
            value = (value << 6) | UInt64(byte & 0x3F)
        }
        return value
    }
}

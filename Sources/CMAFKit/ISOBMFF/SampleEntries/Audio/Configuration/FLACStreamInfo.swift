// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FLACStreamInfo
//
// Reference: Xiph FLAC format specification, METADATA_BLOCK_STREAMINFO.
//
// 34-byte block carrying the codec's stream-wide parameters. The fields
// are bit-packed across byte boundaries (sample rate 20 bits, channels
// 3 bits, bits-per-sample 5 bits, total samples 36 bits).

import Foundation

/// FLAC STREAMINFO metadata block per Xiph FLAC format.
public struct FLACStreamInfo: Sendable, Equatable, Hashable {
    /// Minimum block size in samples.
    public let minBlockSize: UInt16
    /// Maximum block size in samples.
    public let maxBlockSize: UInt16
    /// Minimum frame size in bytes (24-bit value).
    public let minFrameSize: UInt32
    /// Maximum frame size in bytes (24-bit value).
    public let maxFrameSize: UInt32
    /// Sample rate in Hz (20-bit value).
    public let sampleRate: UInt32
    /// Channels (1..8, stored as `channels - 1` on the wire).
    public let channels: UInt8
    /// Bits per sample (4..32, stored as `bitsPerSample - 1` on the wire).
    public let bitsPerSample: UInt8
    /// Total samples (36-bit value).
    public let totalSamples: UInt64
    /// MD5 signature of the unencoded audio (16 bytes).
    public let md5: Data

    public init(
        minBlockSize: UInt16,
        maxBlockSize: UInt16,
        minFrameSize: UInt32,
        maxFrameSize: UInt32,
        sampleRate: UInt32,
        channels: UInt8,
        bitsPerSample: UInt8,
        totalSamples: UInt64,
        md5: Data
    ) {
        precondition(
            minFrameSize <= 0x00FF_FFFF,
            "FLAC minFrameSize must fit in 24 bits"
        )
        precondition(
            maxFrameSize <= 0x00FF_FFFF,
            "FLAC maxFrameSize must fit in 24 bits"
        )
        precondition(
            sampleRate <= 0x000F_FFFF,
            "FLAC sampleRate must fit in 20 bits"
        )
        precondition(
            (1...8).contains(channels),
            "FLAC channels must be in 1...8"
        )
        precondition(
            (4...32).contains(bitsPerSample),
            "FLAC bitsPerSample must be in 4...32"
        )
        precondition(
            totalSamples <= 0x0000_000F_FFFF_FFFF,
            "FLAC totalSamples must fit in 36 bits"
        )
        precondition(
            md5.count == 16,
            "FLAC MD5 must be exactly 16 bytes"
        )
        self.minBlockSize = minBlockSize
        self.maxBlockSize = maxBlockSize
        self.minFrameSize = minFrameSize
        self.maxFrameSize = maxFrameSize
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPerSample = bitsPerSample
        self.totalSamples = totalSamples
        self.md5 = md5
    }

    /// Parse the 34-byte STREAMINFO block contents.
    public static func parse(blockData: Data) throws -> FLACStreamInfo {
        guard blockData.count == 34 else {
            throw ISOBoxError.malformedFullBox(
                type: "dfLa",
                reason: "FLAC STREAMINFO block must be 34 bytes, got \(blockData.count)"
            )
        }
        var reader = BinaryReader(blockData)
        let minBlock = try reader.readUInt16()
        let maxBlock = try reader.readUInt16()
        let minFrame = try reader.readUInt24()
        let maxFrame = try reader.readUInt24()

        // 64 bits: sampleRate (20) + channels-1 (3) + bps-1 (5) + totalSamples (36).
        let word = try reader.readUInt64()
        let sampleRate = UInt32((word >> 44) & 0x000F_FFFF)
        let channelsMinusOne = UInt8((word >> 41) & 0x07)
        let bpsMinusOne = UInt8((word >> 36) & 0x1F)
        let totalSamples = word & 0x0000_000F_FFFF_FFFF

        let md5 = try reader.readData(count: 16)

        return FLACStreamInfo(
            minBlockSize: minBlock,
            maxBlockSize: maxBlock,
            minFrameSize: minFrame,
            maxFrameSize: maxFrame,
            sampleRate: sampleRate,
            channels: channelsMinusOne + 1,
            bitsPerSample: bpsMinusOne + 1,
            totalSamples: totalSamples,
            md5: md5
        )
    }

    /// Emit the 34-byte STREAMINFO block contents.
    public func encode() -> Data {
        var writer = BinaryWriter()
        writer.writeUInt16(minBlockSize)
        writer.writeUInt16(maxBlockSize)
        writer.writeUInt24(minFrameSize & 0x00FF_FFFF)
        writer.writeUInt24(maxFrameSize & 0x00FF_FFFF)
        let word: UInt64 =
            (UInt64(sampleRate & 0x000F_FFFF) << 44)
            | (UInt64((channels - 1) & 0x07) << 41)
            | (UInt64((bitsPerSample - 1) & 0x1F) << 36)
            | (totalSamples & 0x0000_000F_FFFF_FFFF)
        writer.writeUInt64(word)
        writer.writeData(md5)
        return writer.data
    }
}

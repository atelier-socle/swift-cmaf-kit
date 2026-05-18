// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BitRateBox (btrt)
//
// Reference: ISO/IEC 14496-12 §8.5.2.

import Foundation

/// Decoder buffer size and bit-rate hints for a sample entry.
///
/// Reference: ISO/IEC 14496-12 §8.5.2.
public struct BitRateBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "btrt"

    /// Decoder buffer size in bytes.
    public let bufferSizeDB: UInt32
    /// Maximum bit rate in bits per second.
    public let maxBitrate: UInt32
    /// Average bit rate in bits per second.
    public let avgBitrate: UInt32

    public init(bufferSizeDB: UInt32, maxBitrate: UInt32, avgBitrate: UInt32) {
        self.bufferSizeDB = bufferSizeDB
        self.maxBitrate = maxBitrate
        self.avgBitrate = avgBitrate
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> BitRateBox {
        let bufferSizeDB = try reader.readUInt32()
        let maxBitrate = try reader.readUInt32()
        let avgBitrate = try reader.readUInt32()
        return BitRateBox(
            bufferSizeDB: bufferSizeDB,
            maxBitrate: maxBitrate,
            avgBitrate: avgBitrate
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt32(bufferSizeDB)
            body.writeUInt32(maxBitrate)
            body.writeUInt32(avgBitrate)
        }
    }
}

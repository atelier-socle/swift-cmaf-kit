// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SoundMediaHeaderBox (smhd)
//
// Reference: ISO/IEC 14496-12 §8.4.5.3 (sound media header).
//
// Required full box for audio tracks. Carries the stereo balance value.

import Foundation

/// Sound media header.
///
/// Per ISO/IEC 14496-12 §8.4.5.3, every audio track contains this box as a
/// child of its `minf`.
public struct SoundMediaHeaderBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "smhd"

    public let version: UInt8
    public let flags: UInt32
    /// 8.8 fixed stereo balance: `-1.0` (full left) to `+1.0` (full right).
    /// `0.0` is centred — the typical value.
    public let balance: Double

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        balance: Double = 0.0
    ) {
        self.version = version
        self.flags = flags
        self.balance = balance
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SoundMediaHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let balance = try reader.readFixed8_8()
        try reader.skip(2)  // reserved
        return SoundMediaHeaderBox(version: version, flags: flags, balance: balance)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeFixed8_8(balance)
            body.writeZeros(2)
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackFragmentDecodeTimeBox (tfdt)
//
// Reference: ISO/IEC 14496-12 §8.8.12 (track fragment decode time box).
//
// Carries the decode time of the first sample in the fragment, expressed
// in the track's media timescale. Required for any random-access seek
// inside a fragmented presentation.

import Foundation

/// Track-fragment decode time.
///
/// Version 0 stores the decode time as `UInt32`; version 1 as `UInt64`.
/// Newly-constructed boxes default to version 1 because long-form
/// fragmented content readily exceeds 13.6 hours at common 90 kHz
/// timescales.
public struct TrackFragmentDecodeTimeBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "tfdt"

    public let version: UInt8
    public let flags: UInt32
    /// Decode time of the first sample in the fragment, in the track's
    /// media timescale.
    public let baseMediaDecodeTime: UInt64

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        baseMediaDecodeTime: UInt64
    ) {
        self.version = version
        self.flags = flags
        self.baseMediaDecodeTime = baseMediaDecodeTime
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> TrackFragmentDecodeTimeBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let baseMediaDecodeTime: UInt64
        if version == 1 {
            baseMediaDecodeTime = try reader.readUInt64()
        } else if version == 0 {
            baseMediaDecodeTime = UInt64(try reader.readUInt32())
        } else {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }
        return TrackFragmentDecodeTimeBox(
            version: version,
            flags: flags,
            baseMediaDecodeTime: baseMediaDecodeTime
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            if version == 1 {
                body.writeUInt64(baseMediaDecodeTime)
            } else {
                body.writeUInt32(UInt32(min(baseMediaDecodeTime, UInt64(UInt32.max))))
            }
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackExtendsBox (trex)
//
// Reference: ISO/IEC 14496-12 §8.8.3 (track extends box).
//
// Per-track defaults consulted by `tfhd` when those fields are not
// explicitly set at the track-fragment level. One `trex` per track,
// inside the `mvex` container.

import Foundation

/// Per-track fragmentation defaults.
///
/// Each fragmented track has a single `trex` declared at the movie level.
/// Default values declared here apply to every `traf` whose `tfhd` does
/// not override them. No fields are flag-gated; all are mandatory and
/// fixed width.
public struct TrackExtendsBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "trex"

    public let version: UInt8
    public let flags: UInt32
    public let trackID: UInt32
    public let defaultSampleDescriptionIndex: UInt32
    public let defaultSampleDuration: UInt32
    public let defaultSampleSize: UInt32
    public let defaultSampleFlags: UInt32

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        trackID: UInt32,
        defaultSampleDescriptionIndex: UInt32 = 1,
        defaultSampleDuration: UInt32 = 0,
        defaultSampleSize: UInt32 = 0,
        defaultSampleFlags: UInt32 = 0
    ) {
        self.version = version
        self.flags = flags
        self.trackID = trackID
        self.defaultSampleDescriptionIndex = defaultSampleDescriptionIndex
        self.defaultSampleDuration = defaultSampleDuration
        self.defaultSampleSize = defaultSampleSize
        self.defaultSampleFlags = defaultSampleFlags
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> TrackExtendsBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let trackID = try reader.readUInt32()
        let defaultSampleDescriptionIndex = try reader.readUInt32()
        let defaultSampleDuration = try reader.readUInt32()
        let defaultSampleSize = try reader.readUInt32()
        let defaultSampleFlags = try reader.readUInt32()
        return TrackExtendsBox(
            version: version,
            flags: flags,
            trackID: trackID,
            defaultSampleDescriptionIndex: defaultSampleDescriptionIndex,
            defaultSampleDuration: defaultSampleDuration,
            defaultSampleSize: defaultSampleSize,
            defaultSampleFlags: defaultSampleFlags
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(trackID)
            body.writeUInt32(defaultSampleDescriptionIndex)
            body.writeUInt32(defaultSampleDuration)
            body.writeUInt32(defaultSampleSize)
            body.writeUInt32(defaultSampleFlags)
        }
    }
}

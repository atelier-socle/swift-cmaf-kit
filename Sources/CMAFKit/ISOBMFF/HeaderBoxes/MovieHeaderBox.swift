// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MovieHeaderBox (mvhd)
//
// Reference: ISO/IEC 14496-12 §8.2.2 (movie header box).
//
// File-level movie metadata. Version 0 stores timestamps as UInt32 and
// duration as UInt32; version 1 promotes all three to UInt64 to allow
// presentations longer than ~13.6 hours at 90 kHz timescale. CMAFKit
// reads both versions and defaults newly-constructed boxes to version 1.

import Foundation

/// Movie header — file-level metadata for the presentation.
///
/// Both version 0 and version 1 are read; newly-constructed boxes default
/// to version 1 to avoid the 32-bit duration overflow at high timescales.
/// On round-trip, an already-version-0 box re-encodes as version 0,
/// preserving the original.
public struct MovieHeaderBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "mvhd"

    public let version: UInt8
    public let flags: UInt32

    /// Seconds since 1904-01-01 UTC. `UInt64` covers both v0 and v1 storage.
    public let creationTime: UInt64
    public let modificationTime: UInt64
    public let timescale: UInt32
    /// In units of `timescale`. `UInt64` covers both v0 and v1.
    public let duration: UInt64
    /// Playback rate as 16.16 fixed-point. `1.0` is normal speed.
    public let rate: Double
    /// Output volume as 8.8 fixed-point. `1.0` is full volume.
    public let volume: Double
    /// 3×3 transformation matrix (6 × 16.16 fixed-point + 3 × 2.30 fixed-point).
    public let matrix: [Double]
    /// One more than the largest `trackID` used in any contained track.
    public let nextTrackID: UInt32

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        creationTime: UInt64,
        modificationTime: UInt64,
        timescale: UInt32,
        duration: UInt64,
        rate: Double = 1.0,
        volume: Double = 1.0,
        matrix: [Double] = MovieHeaderBox.identityMatrix,
        nextTrackID: UInt32
    ) {
        self.version = version
        self.flags = flags
        self.creationTime = creationTime
        self.modificationTime = modificationTime
        self.timescale = timescale
        self.duration = duration
        self.rate = rate
        self.volume = volume
        precondition(matrix.count == 9, "MovieHeaderBox.matrix must have exactly 9 elements")
        self.matrix = matrix
        self.nextTrackID = nextTrackID
    }

    /// The QuickTime identity transformation matrix.
    public static let identityMatrix: [Double] = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0
    ]

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MovieHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let creationTime: UInt64
        let modificationTime: UInt64
        let timescale: UInt32
        let duration: UInt64

        if version == 1 {
            creationTime = try reader.readUInt64()
            modificationTime = try reader.readUInt64()
            timescale = try reader.readUInt32()
            duration = try reader.readUInt64()
        } else if version == 0 {
            creationTime = UInt64(try reader.readUInt32())
            modificationTime = UInt64(try reader.readUInt32())
            timescale = try reader.readUInt32()
            duration = UInt64(try reader.readUInt32())
        } else {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }

        let rate = try reader.readFixed16_16()
        let volume = try reader.readFixed8_8()
        try reader.skip(10)  // reserved (2 + 8)
        let matrix = try reader.readMatrix3x3()
        try reader.skip(24)  // pre_defined
        let nextTrackID = try reader.readUInt32()

        return MovieHeaderBox(
            version: version,
            flags: flags,
            creationTime: creationTime,
            modificationTime: modificationTime,
            timescale: timescale,
            duration: duration,
            rate: rate,
            volume: volume,
            matrix: matrix,
            nextTrackID: nextTrackID
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            if version == 1 {
                body.writeUInt64(creationTime)
                body.writeUInt64(modificationTime)
                body.writeUInt32(timescale)
                body.writeUInt64(duration)
            } else {
                body.writeUInt32(UInt32(min(creationTime, UInt64(UInt32.max))))
                body.writeUInt32(UInt32(min(modificationTime, UInt64(UInt32.max))))
                body.writeUInt32(timescale)
                body.writeUInt32(UInt32(min(duration, UInt64(UInt32.max))))
            }
            body.writeFixed16_16(rate)
            body.writeFixed8_8(volume)
            body.writeZeros(10)
            body.writeMatrix3x3(matrix)
            body.writeZeros(24)
            body.writeUInt32(nextTrackID)
        }
    }
}

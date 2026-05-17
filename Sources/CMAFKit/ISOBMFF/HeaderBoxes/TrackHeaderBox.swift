// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackHeaderBox (tkhd)
//
// Reference: ISO/IEC 14496-12 §8.3.2 (track header box).
//
// Per-track metadata: ID, timing, geometry. Flags carry enabled /
// in-movie / in-preview / in-poster bits. Versions 0 and 1 differ in
// the width of timestamps and duration as in `mvhd`.

import Foundation

/// Per-track header box.
///
/// Flags bits (per ISO/IEC 14496-12 §8.3.2):
///   - `0x000001` — track enabled
///   - `0x000002` — track in movie
///   - `0x000004` — track in preview
///   - `0x000008` — track in poster
///
/// New tracks default to `0x000007` (enabled + in movie + in preview).
/// Existing tracks preserve the read value.
public struct TrackHeaderBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "tkhd"

    /// Flag bit signalling that the track is enabled.
    public static let flagEnabled: UInt32 = 0x0000_0001
    /// Flag bit signalling that the track contributes to the movie timeline.
    public static let flagInMovie: UInt32 = 0x0000_0002
    /// Flag bit signalling that the track contributes to the preview.
    public static let flagInPreview: UInt32 = 0x0000_0004
    /// Flag bit signalling that the track contributes to the poster frame.
    public static let flagInPoster: UInt32 = 0x0000_0008

    public let version: UInt8
    public let flags: UInt32
    public let creationTime: UInt64
    public let modificationTime: UInt64
    public let trackID: UInt32
    public let duration: UInt64
    /// Composition layer. Lower values render in front; default is `0`.
    public let layer: Int16
    /// Alternate group ID; tracks in the same non-zero group are mutually
    /// exclusive (only one plays at a time).
    public let alternateGroup: Int16
    /// Audio track volume as 8.8 fixed-point. `1.0` is full volume; for
    /// video tracks this field is `0`.
    public let volume: Double
    /// 3×3 transformation matrix (6 × 16.16 fixed-point + 3 × 2.30 fixed-point).
    public let matrix: [Double]
    /// Visual presentation width as 16.16 fixed-point. `0` for non-visual tracks.
    public let width: Double
    /// Visual presentation height as 16.16 fixed-point. `0` for non-visual tracks.
    public let height: Double

    public init(
        version: UInt8 = 1,
        flags: UInt32 = TrackHeaderBox.flagEnabled
            | TrackHeaderBox.flagInMovie
            | TrackHeaderBox.flagInPreview,
        creationTime: UInt64,
        modificationTime: UInt64,
        trackID: UInt32,
        duration: UInt64,
        layer: Int16 = 0,
        alternateGroup: Int16 = 0,
        volume: Double = 0.0,
        matrix: [Double] = MovieHeaderBox.identityMatrix,
        width: Double = 0.0,
        height: Double = 0.0
    ) {
        self.version = version
        self.flags = flags
        self.creationTime = creationTime
        self.modificationTime = modificationTime
        self.trackID = trackID
        self.duration = duration
        self.layer = layer
        self.alternateGroup = alternateGroup
        self.volume = volume
        precondition(matrix.count == 9, "TrackHeaderBox.matrix must have exactly 9 elements")
        self.matrix = matrix
        self.width = width
        self.height = height
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> TrackHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let creationTime: UInt64
        let modificationTime: UInt64
        let trackID: UInt32
        let duration: UInt64

        if version == 1 {
            creationTime = try reader.readUInt64()
            modificationTime = try reader.readUInt64()
            trackID = try reader.readUInt32()
            try reader.skip(4)  // reserved
            duration = try reader.readUInt64()
        } else if version == 0 {
            creationTime = UInt64(try reader.readUInt32())
            modificationTime = UInt64(try reader.readUInt32())
            trackID = try reader.readUInt32()
            try reader.skip(4)  // reserved
            duration = UInt64(try reader.readUInt32())
        } else {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }

        try reader.skip(8)  // reserved
        let layer = try reader.readInt16()
        let alternateGroup = try reader.readInt16()
        let volume = try reader.readFixed8_8()
        try reader.skip(2)  // reserved
        let matrix = try reader.readMatrix3x3()
        let width = try reader.readFixed16_16()
        let height = try reader.readFixed16_16()

        return TrackHeaderBox(
            version: version,
            flags: flags,
            creationTime: creationTime,
            modificationTime: modificationTime,
            trackID: trackID,
            duration: duration,
            layer: layer,
            alternateGroup: alternateGroup,
            volume: volume,
            matrix: matrix,
            width: width,
            height: height
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
                body.writeUInt32(trackID)
                body.writeZeros(4)
                body.writeUInt64(duration)
            } else {
                body.writeUInt32(UInt32(min(creationTime, UInt64(UInt32.max))))
                body.writeUInt32(UInt32(min(modificationTime, UInt64(UInt32.max))))
                body.writeUInt32(trackID)
                body.writeZeros(4)
                body.writeUInt32(UInt32(min(duration, UInt64(UInt32.max))))
            }
            body.writeZeros(8)
            body.writeInt16(layer)
            body.writeInt16(alternateGroup)
            body.writeFixed8_8(volume)
            body.writeZeros(2)
            body.writeMatrix3x3(matrix)
            body.writeFixed16_16(width)
            body.writeFixed16_16(height)
        }
    }
}

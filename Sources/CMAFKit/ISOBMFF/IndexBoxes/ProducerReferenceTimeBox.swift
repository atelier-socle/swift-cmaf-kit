// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ProducerReferenceTimeBox (prft)
//
// Reference: ISO/IEC 14496-12 §8.16.5 (ProducerReferenceTimeBox).
//
// Full box version 0 or 1. Carries a wall-clock NTP timestamp mapped
// to a media decode time, used for live signaling. Version 0 carries
// a 32-bit `media_decode_time`; version 1 widens it to 64 bits.

import Foundation

/// Producer reference time box (`prft`) per ISO/IEC 14496-12 §8.16.5.
///
/// Used to advertise the wall-clock NTP time at which a given media
/// sample was produced. Live encoders typically emit one `prft` per
/// segment so that downstream consumers can align media playback to
/// wall time.
public struct ProducerReferenceTimeBox: ISOFullBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "prft"

    public let version: UInt8
    public let flags: UInt32
    /// Track this reference applies to (`track_ID`).
    public let referenceTrackID: UInt32
    /// 64-bit NTP timestamp: 32 bits seconds since 1900-01-01,
    /// 32 bits fractional seconds.
    public let ntpTimestamp: UInt64
    /// Media decode time the NTP timestamp refers to, in the
    /// reference track's timescale.
    public let mediaDecodeTime: UInt64

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        referenceTrackID: UInt32,
        ntpTimestamp: UInt64,
        mediaDecodeTime: UInt64
    ) {
        precondition(version <= 1, "prft version must be 0 or 1")
        self.version = version
        self.flags = flags
        self.referenceTrackID = referenceTrackID
        self.ntpTimestamp = ntpTimestamp
        self.mediaDecodeTime = mediaDecodeTime
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ProducerReferenceTimeBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        guard version <= 1 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "prft version must be 0 or 1; got \(version)"
            )
        }
        let trackID = try reader.readUInt32()
        let ntp = try reader.readUInt64()
        let decodeTime: UInt64 =
            version == 0
            ? UInt64(try reader.readUInt32())
            : try reader.readUInt64()
        return ProducerReferenceTimeBox(
            version: version,
            flags: flags,
            referenceTrackID: trackID,
            ntpTimestamp: ntp,
            mediaDecodeTime: decodeTime
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(referenceTrackID)
            body.writeUInt64(ntpTimestamp)
            if version == 0 {
                body.writeUInt32(UInt32(clamping: mediaDecodeTime))
            } else {
                body.writeUInt64(mediaDecodeTime)
            }
        }
    }
}

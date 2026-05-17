// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackFragmentHeaderBox (tfhd)
//
// Reference: ISO/IEC 14496-12 §8.8.7 (track fragment header box).
//
// Declares per-fragment defaults for one track. Most fields are optional
// and gated by the box's flags. When a `trun` inside the same `traf` does
// not carry a per-sample value, it falls back to the corresponding `tfhd`
// default — or, if `tfhd` does not provide one, to the `trex.defaultSampleX`
// value in the movie-level `mvex`.

import Foundation

/// Track-fragment header.
///
/// All six payload fields are optional, gated by the flag bits below. The
/// public struct exposes them as `Optional`. Encoders honour the bit
/// presence on encode; decoders read the on-wire flags and populate only
/// the fields whose bits are set. The public initialiser reconciles each
/// optional field's presence with its corresponding flag bit; the
/// decode-side initialiser trusts the on-wire flags verbatim.
public struct TrackFragmentHeaderBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "tfhd"

    /// `baseDataOffset` present.
    public static let flagBaseDataOffset: UInt32 = 0x000001
    /// `sampleDescriptionIndex` present.
    public static let flagSampleDescriptionIndex: UInt32 = 0x000002
    /// `defaultSampleDuration` present.
    public static let flagDefaultSampleDuration: UInt32 = 0x000008
    /// `defaultSampleSize` present.
    public static let flagDefaultSampleSize: UInt32 = 0x000010
    /// `defaultSampleFlags` present.
    public static let flagDefaultSampleFlags: UInt32 = 0x000020
    /// Track is empty for the duration of this fragment.
    public static let flagDurationIsEmpty: UInt32 = 0x010000
    /// Data offsets are relative to the start of the containing `moof`.
    public static let flagDefaultBaseIsMoof: UInt32 = 0x020000

    public let version: UInt8
    public let flags: UInt32
    public let trackID: UInt32
    public let baseDataOffset: UInt64?
    public let sampleDescriptionIndex: UInt32?
    public let defaultSampleDuration: UInt32?
    public let defaultSampleSize: UInt32?
    public let defaultSampleFlags: UInt32?

    /// Public initialiser. Reconciles each optional's presence with the
    /// corresponding flag bit so that the on-wire encoding remains
    /// consistent with the in-memory representation.
    public init(
        version: UInt8 = 0,
        flags: UInt32 = TrackFragmentHeaderBox.flagDefaultBaseIsMoof,
        trackID: UInt32,
        baseDataOffset: UInt64? = nil,
        sampleDescriptionIndex: UInt32? = nil,
        defaultSampleDuration: UInt32? = nil,
        defaultSampleSize: UInt32? = nil,
        defaultSampleFlags: UInt32? = nil
    ) {
        var resolvedFlags = flags
        if baseDataOffset != nil {
            resolvedFlags |= Self.flagBaseDataOffset
        } else {
            resolvedFlags &= ~Self.flagBaseDataOffset
        }
        if sampleDescriptionIndex != nil {
            resolvedFlags |= Self.flagSampleDescriptionIndex
        } else {
            resolvedFlags &= ~Self.flagSampleDescriptionIndex
        }
        if defaultSampleDuration != nil {
            resolvedFlags |= Self.flagDefaultSampleDuration
        } else {
            resolvedFlags &= ~Self.flagDefaultSampleDuration
        }
        if defaultSampleSize != nil {
            resolvedFlags |= Self.flagDefaultSampleSize
        } else {
            resolvedFlags &= ~Self.flagDefaultSampleSize
        }
        if defaultSampleFlags != nil {
            resolvedFlags |= Self.flagDefaultSampleFlags
        } else {
            resolvedFlags &= ~Self.flagDefaultSampleFlags
        }

        self.version = version
        self.flags = resolvedFlags
        self.trackID = trackID
        self.baseDataOffset = baseDataOffset
        self.sampleDescriptionIndex = sampleDescriptionIndex
        self.defaultSampleDuration = defaultSampleDuration
        self.defaultSampleSize = defaultSampleSize
        self.defaultSampleFlags = defaultSampleFlags
    }

    /// `true` when data offsets in the fragment are relative to the
    /// containing `moof`.
    public var defaultBaseIsMoof: Bool { (flags & Self.flagDefaultBaseIsMoof) != 0 }
    /// `true` when this fragment carries no media for the track.
    public var durationIsEmpty: Bool { (flags & Self.flagDurationIsEmpty) != 0 }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> TrackFragmentHeaderBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let trackID = try reader.readUInt32()

        let baseDataOffset: UInt64? =
            (flags & Self.flagBaseDataOffset) != 0
            ? try reader.readUInt64() : nil
        let sampleDescriptionIndex: UInt32? =
            (flags & Self.flagSampleDescriptionIndex) != 0
            ? try reader.readUInt32() : nil
        let defaultSampleDuration: UInt32? =
            (flags & Self.flagDefaultSampleDuration) != 0
            ? try reader.readUInt32() : nil
        let defaultSampleSize: UInt32? =
            (flags & Self.flagDefaultSampleSize) != 0
            ? try reader.readUInt32() : nil
        let defaultSampleFlags: UInt32? =
            (flags & Self.flagDefaultSampleFlags) != 0
            ? try reader.readUInt32() : nil

        return TrackFragmentHeaderBox(
            decodedVersion: version,
            decodedFlagsRaw: flags,
            trackID: trackID,
            baseDataOffset: baseDataOffset,
            sampleDescriptionIndex: sampleDescriptionIndex,
            defaultSampleDuration: defaultSampleDuration,
            defaultSampleSize: defaultSampleSize,
            defaultSampleFlags: defaultSampleFlags
        )
    }

    /// Decode-side initialiser that trusts the on-wire flags verbatim
    /// without the reconciliation performed by the public initialiser.
    internal init(
        decodedVersion version: UInt8,
        decodedFlagsRaw flags: UInt32,
        trackID: UInt32,
        baseDataOffset: UInt64?,
        sampleDescriptionIndex: UInt32?,
        defaultSampleDuration: UInt32?,
        defaultSampleSize: UInt32?,
        defaultSampleFlags: UInt32?
    ) {
        self.version = version
        self.flags = flags
        self.trackID = trackID
        self.baseDataOffset = baseDataOffset
        self.sampleDescriptionIndex = sampleDescriptionIndex
        self.defaultSampleDuration = defaultSampleDuration
        self.defaultSampleSize = defaultSampleSize
        self.defaultSampleFlags = defaultSampleFlags
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(trackID)
            if let value = baseDataOffset { body.writeUInt64(value) }
            if let value = sampleDescriptionIndex { body.writeUInt32(value) }
            if let value = defaultSampleDuration { body.writeUInt32(value) }
            if let value = defaultSampleSize { body.writeUInt32(value) }
            if let value = defaultSampleFlags { body.writeUInt32(value) }
        }
    }
}

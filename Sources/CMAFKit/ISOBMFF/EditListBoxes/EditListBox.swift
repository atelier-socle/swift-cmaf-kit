// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EditListBox (elst)
//
// Reference: ISO/IEC 14496-12 §8.6.6 (edit list box).
//
// Describes a track's timeline: a list of segments each mapping a slice
// of the movie timeline onto a slice of media time. Empty edits (gaps)
// are signalled by ``EditListEntry/mediaTime`` equal to `-1`.

import Foundation

/// One edit-list segment.
public struct EditListEntry: Sendable, Hashable {
    /// Duration of this segment expressed in the movie timescale (the
    /// timescale of the enclosing `mvhd`), not the track's media timescale.
    public let segmentDuration: UInt64
    /// Media time (in the track's media timescale) of the first sample
    /// of this segment, or `-1` to signal an empty edit (a gap on the
    /// presentation timeline).
    public let mediaTime: Int64
    /// Integer part of the playback rate during this segment.
    public let mediaRateInteger: Int16
    /// Fractional part of the playback rate during this segment.
    public let mediaRateFraction: Int16

    public init(
        segmentDuration: UInt64,
        mediaTime: Int64,
        mediaRateInteger: Int16 = 1,
        mediaRateFraction: Int16 = 0
    ) {
        self.segmentDuration = segmentDuration
        self.mediaTime = mediaTime
        self.mediaRateInteger = mediaRateInteger
        self.mediaRateFraction = mediaRateFraction
    }

    /// `true` when this entry signals a gap in the presentation timeline
    /// (``mediaTime`` is `-1`).
    public var isEmptyEdit: Bool { mediaTime == -1 }
}

/// Lazy view over the entries of an ``EditListBox``.
///
/// `EditListTable` conforms to `RandomAccessCollection` and is backed
/// directly by the on-wire byte slice. The per-entry stride is 12 bytes
/// in version 0 and 20 bytes in version 1.
public struct EditListTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data
    /// Box version (0 = 32-bit duration/time, 1 = 64-bit).
    public let version: UInt8

    public typealias Index = Int
    public typealias Element = EditListEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    /// Per-entry byte stride.
    public var entryStride: Int { version == 1 ? 20 : 12 }

    public subscript(position: Int) -> EditListEntry {
        precondition(
            position >= 0 && position < count,
            "EditListTable: index \(position) out of range 0..<\(count)"
        )
        let base = position * entryStride
        let segmentDuration: UInt64
        let mediaTime: Int64
        var cursor: Int
        if version == 1 {
            segmentDuration = rawEntries.readUInt64BigEndian(at: base)
            mediaTime = Int64(bitPattern: rawEntries.readUInt64BigEndian(at: base + 8))
            cursor = base + 16
        } else {
            segmentDuration = UInt64(rawEntries.readUInt32BigEndian(at: base))
            mediaTime = Int64(rawEntries.readInt32BigEndian(at: base + 4))
            cursor = base + 8
        }
        let mediaRateInteger = Int16(bitPattern: rawEntries.readUInt16BigEndian(at: cursor))
        let mediaRateFraction = Int16(bitPattern: rawEntries.readUInt16BigEndian(at: cursor + 2))
        return EditListEntry(
            segmentDuration: segmentDuration,
            mediaTime: mediaTime,
            mediaRateInteger: mediaRateInteger,
            mediaRateFraction: mediaRateFraction
        )
    }

    internal init(count: Int, rawEntries: Data, version: UInt8) {
        precondition(
            version == 0 || version == 1,
            "EditListTable: only versions 0 and 1 are supported"
        )
        self.count = count
        self.rawEntries = rawEntries
        self.version = version
    }

    /// Construct from an array of entries. When ``version`` is 0, each
    /// `segmentDuration` must fit in `UInt32` and each `mediaTime` must
    /// fit in `Int32`; values exceeding those ranges trigger a
    /// precondition failure.
    public init(entries: [EditListEntry], version: UInt8 = 1) {
        precondition(
            version == 0 || version == 1,
            "EditListTable: only versions 0 and 1 are supported"
        )
        let stride = (version == 1) ? 20 : 12
        var bytes = Data()
        bytes.reserveCapacity(entries.count * stride)
        for e in entries {
            if version == 1 {
                bytes.appendUInt64BigEndian(e.segmentDuration)
                bytes.appendUInt64BigEndian(UInt64(bitPattern: e.mediaTime))
            } else {
                precondition(
                    e.segmentDuration <= UInt64(UInt32.max),
                    "EditListTable v0: segmentDuration \(e.segmentDuration) exceeds UInt32.max"
                )
                precondition(
                    e.mediaTime >= Int64(Int32.min) && e.mediaTime <= Int64(Int32.max),
                    "EditListTable v0: mediaTime \(e.mediaTime) out of Int32 range"
                )
                bytes.appendUInt32BigEndian(UInt32(e.segmentDuration))
                bytes.appendInt32BigEndian(Int32(e.mediaTime))
            }
            bytes.appendUInt16BigEndian(UInt16(bitPattern: e.mediaRateInteger))
            bytes.appendUInt16BigEndian(UInt16(bitPattern: e.mediaRateFraction))
        }
        self.init(count: entries.count, rawEntries: bytes, version: version)
    }
}

/// Edit-list box.
public struct EditListBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "elst"

    public let version: UInt8
    public let flags: UInt32
    public let table: EditListTable

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        table: EditListTable
    ) {
        precondition(
            version == table.version,
            "EditListBox: version must match its table's version"
        )
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> EditListBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        if version != 0 && version != 1 {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }
        let entryCount = try reader.readUInt32()
        let stride = (version == 1) ? 20 : 12
        let expectedBytes = Int(entryCount) * stride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = EditListTable(
            count: Int(entryCount),
            rawEntries: rawEntries,
            version: version
        )
        return EditListBox(version: version, flags: flags, table: table)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(UInt32(table.count))
            body.writeData(table.rawEntries)
        }
    }
}

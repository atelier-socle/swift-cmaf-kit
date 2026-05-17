// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackRunBox (trun)
//
// Reference: ISO/IEC 14496-12 §8.8.8 (track fragment run box).
//
// Describes one run of contiguous samples inside a track fragment. The
// four per-sample fields (duration, size, flags, composition offset) are
// each optional and gated by per-sample flag bits. The box header also
// carries two optional fields (data offset, first sample flags).
//
// The table is exposed as a lazy `RandomAccessCollection` whose stride
// depends on the box's `tr_flags`, computed once at parse time. Each
// `TrackRunEntry` field is `Optional`; resolution against `tfhd`/`trex`
// defaults is the Reader module's responsibility (see `SampleResolver`).

import Foundation

/// One sample's per-sample fields, with `nil` for fields whose
/// corresponding flag is not set on the parent ``TrackRunBox``.
///
/// To resolve `nil` values against the parent `traf.tfhd` defaults and
/// the movie-level `mvex.trex` defaults, use the resolver type shipped
/// in the Reader module.
public struct TrackRunEntry: Sendable, Hashable {
    /// Per-sample duration in the track's media timescale.
    public let sampleDuration: UInt32?
    /// Per-sample size in bytes.
    public let sampleSize: UInt32?
    /// Per-sample flags (independence / disposability / leading info).
    public let sampleFlags: UInt32?
    /// Composition-time offset. Signed `Int64` to accommodate both
    /// version-0 unsigned values and version-1 signed values without loss.
    public let sampleCompositionTimeOffset: Int64?

    public init(
        sampleDuration: UInt32? = nil,
        sampleSize: UInt32? = nil,
        sampleFlags: UInt32? = nil,
        sampleCompositionTimeOffset: Int64? = nil
    ) {
        self.sampleDuration = sampleDuration
        self.sampleSize = sampleSize
        self.sampleFlags = sampleFlags
        self.sampleCompositionTimeOffset = sampleCompositionTimeOffset
    }
}

/// A lazy view over the entries of a ``TrackRunBox``.
///
/// Reference: ISO/IEC 14496-12 §8.8.8.
///
/// `TrackRunTable` conforms to `RandomAccessCollection` and is backed
/// directly by the on-wire byte slice. The per-entry stride depends on
/// which of the four per-sample flags are set on the parent
/// ``TrackRunBox``. The stride and field offsets are computed once at
/// construction; subscript reads only the fields whose flags are set,
/// populating the others as `nil` on the returned ``TrackRunEntry``.
///
/// Round-trip re-emits the raw bytes verbatim.
public struct TrackRunTable: RandomAccessCollection, Sendable, Equatable {

    /// Per-sample `duration` is stored on the wire.
    public static let flagSampleDuration: UInt32 = 0x000100
    /// Per-sample `size` is stored on the wire.
    public static let flagSampleSize: UInt32 = 0x000200
    /// Per-sample `flags` is stored on the wire.
    public static let flagSampleFlags: UInt32 = 0x000400
    /// Per-sample `composition_time_offset` is stored on the wire.
    public static let flagSampleCompositionTimeOffsets: UInt32 = 0x000800

    public let count: Int
    public let rawEntries: Data
    /// Flags of the containing ``TrackRunBox``, restricted to the four
    /// per-sample bits. Drives both the stride and the per-field offset.
    public let perSampleFlags: UInt32
    /// Version of the containing box. Version 1 reads composition offsets
    /// as signed `Int32`; version 0 reads them as unsigned `UInt32`.
    public let version: UInt8

    public typealias Index = Int
    public typealias Element = TrackRunEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    /// Per-entry byte stride, computed from the active per-sample flags.
    public var entryStride: Int {
        Self.computeStride(perSampleFlags: perSampleFlags)
    }

    public subscript(position: Int) -> TrackRunEntry {
        precondition(
            position >= 0 && position < count,
            "TrackRunTable: index \(position) out of range 0..<\(count)"
        )
        let stride = entryStride
        let baseOffset = position * stride
        var fieldOffset = 0

        var sampleDuration: UInt32?
        if (perSampleFlags & Self.flagSampleDuration) != 0 {
            sampleDuration = rawEntries.readUInt32BigEndian(at: baseOffset + fieldOffset)
            fieldOffset += 4
        }
        var sampleSize: UInt32?
        if (perSampleFlags & Self.flagSampleSize) != 0 {
            sampleSize = rawEntries.readUInt32BigEndian(at: baseOffset + fieldOffset)
            fieldOffset += 4
        }
        var sampleFlags: UInt32?
        if (perSampleFlags & Self.flagSampleFlags) != 0 {
            sampleFlags = rawEntries.readUInt32BigEndian(at: baseOffset + fieldOffset)
            fieldOffset += 4
        }
        var compositionOffset: Int64?
        if (perSampleFlags & Self.flagSampleCompositionTimeOffsets) != 0 {
            let raw = rawEntries.readUInt32BigEndian(at: baseOffset + fieldOffset)
            compositionOffset =
                (version == 1)
                ? Int64(Int32(bitPattern: raw))
                : Int64(raw)
            fieldOffset += 4
        }

        return TrackRunEntry(
            sampleDuration: sampleDuration,
            sampleSize: sampleSize,
            sampleFlags: sampleFlags,
            sampleCompositionTimeOffset: compositionOffset
        )
    }

    internal init(
        count: Int,
        rawEntries: Data,
        perSampleFlags: UInt32,
        version: UInt8
    ) {
        self.count = count
        self.rawEntries = rawEntries
        self.perSampleFlags = perSampleFlags
        self.version = version
    }

    /// Construct from an entries array. Each entry's optional fields must
    /// be consistent with `perSampleFlags`: a non-nil field requires its
    /// flag bit set, and a nil field requires the flag bit clear.
    public init(
        entries: [TrackRunEntry],
        perSampleFlags: UInt32,
        version: UInt8
    ) {
        for entry in entries {
            precondition(
                (entry.sampleDuration != nil) == ((perSampleFlags & Self.flagSampleDuration) != 0),
                "TrackRunTable: entry.sampleDuration presence mismatches flagSampleDuration"
            )
            precondition(
                (entry.sampleSize != nil) == ((perSampleFlags & Self.flagSampleSize) != 0),
                "TrackRunTable: entry.sampleSize presence mismatches flagSampleSize"
            )
            precondition(
                (entry.sampleFlags != nil) == ((perSampleFlags & Self.flagSampleFlags) != 0),
                "TrackRunTable: entry.sampleFlags presence mismatches flagSampleFlags"
            )
            precondition(
                (entry.sampleCompositionTimeOffset != nil) == ((perSampleFlags & Self.flagSampleCompositionTimeOffsets) != 0),
                "TrackRunTable: entry.sampleCompositionTimeOffset presence mismatches flag"
            )
        }

        var bytes = Data()
        let computedStride = Self.computeStride(perSampleFlags: perSampleFlags)
        bytes.reserveCapacity(entries.count * computedStride)
        for entry in entries {
            if let duration = entry.sampleDuration { bytes.appendUInt32BigEndian(duration) }
            if let size = entry.sampleSize { bytes.appendUInt32BigEndian(size) }
            if let entryFlags = entry.sampleFlags { bytes.appendUInt32BigEndian(entryFlags) }
            if let compositionOffset = entry.sampleCompositionTimeOffset {
                if version == 1 {
                    bytes.appendInt32BigEndian(Int32(compositionOffset))
                } else {
                    bytes.appendUInt32BigEndian(UInt32(compositionOffset))
                }
            }
        }
        self.init(count: entries.count, rawEntries: bytes, perSampleFlags: perSampleFlags, version: version)
    }

    private static func computeStride(perSampleFlags: UInt32) -> Int {
        var stride = 0
        if (perSampleFlags & flagSampleDuration) != 0 { stride += 4 }
        if (perSampleFlags & flagSampleSize) != 0 { stride += 4 }
        if (perSampleFlags & flagSampleFlags) != 0 { stride += 4 }
        if (perSampleFlags & flagSampleCompositionTimeOffsets) != 0 { stride += 4 }
        return stride
    }
}

/// Track-fragment sample run.
///
/// Each `traf` may contain one or more `trun` boxes, each describing a
/// contiguous run of samples. The per-sample fields surfaced by the
/// table are optional; resolution against `tfhd`/`trex` defaults happens
/// in the Reader module.
public struct TrackRunBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "trun"

    /// `dataOffset` is present in the header.
    public static let flagDataOffset: UInt32 = 0x000001
    /// `firstSampleFlags` is present in the header.
    public static let flagFirstSampleFlags: UInt32 = 0x000004

    public let version: UInt8
    public let flags: UInt32
    /// Optional data offset for this run, expressed relative to the
    /// containing `moof` (when `tfhd.defaultBaseIsMoof` is set) or to
    /// `tfhd.baseDataOffset`.
    public let dataOffset: Int32?
    /// Optional override for the first sample's flags, useful when the
    /// first sample is a sync sample and the remaining samples are not.
    public let firstSampleFlags: UInt32?
    /// The lazy per-sample table.
    public let table: TrackRunTable

    /// Public initialiser. Reconciles header-level flag bits with the
    /// optional `dataOffset` / `firstSampleFlags` fields; preserves the
    /// per-sample flag bits from the table.
    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        dataOffset: Int32? = nil,
        firstSampleFlags: UInt32? = nil,
        table: TrackRunTable
    ) {
        precondition(
            version == table.version,
            "TrackRunBox version must match its table's version"
        )
        var resolvedFlags = flags
        if dataOffset != nil {
            resolvedFlags |= Self.flagDataOffset
        } else {
            resolvedFlags &= ~Self.flagDataOffset
        }
        if firstSampleFlags != nil {
            resolvedFlags |= Self.flagFirstSampleFlags
        } else {
            resolvedFlags &= ~Self.flagFirstSampleFlags
        }

        // Per-sample flag bits must match the table.
        let perSampleMask =
            TrackRunTable.flagSampleDuration
            | TrackRunTable.flagSampleSize
            | TrackRunTable.flagSampleFlags
            | TrackRunTable.flagSampleCompositionTimeOffsets
        let resolved = (resolvedFlags & ~perSampleMask) | (table.perSampleFlags & perSampleMask)

        self.version = version
        self.flags = resolved
        self.dataOffset = dataOffset
        self.firstSampleFlags = firstSampleFlags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> TrackRunBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let sampleCount = try reader.readUInt32()

        let dataOffset: Int32? =
            (flags & Self.flagDataOffset) != 0
            ? try reader.readInt32() : nil
        let firstSampleFlags: UInt32? =
            (flags & Self.flagFirstSampleFlags) != 0
            ? try reader.readUInt32() : nil

        // Derive the per-entry stride from the per-sample flags.
        let perSampleMask =
            TrackRunTable.flagSampleDuration
            | TrackRunTable.flagSampleSize
            | TrackRunTable.flagSampleFlags
            | TrackRunTable.flagSampleCompositionTimeOffsets
        let perSampleFlags = flags & perSampleMask
        var stride = 0
        if (perSampleFlags & TrackRunTable.flagSampleDuration) != 0 { stride += 4 }
        if (perSampleFlags & TrackRunTable.flagSampleSize) != 0 { stride += 4 }
        if (perSampleFlags & TrackRunTable.flagSampleFlags) != 0 { stride += 4 }
        if (perSampleFlags & TrackRunTable.flagSampleCompositionTimeOffsets) != 0 { stride += 4 }

        let expectedBytes = Int(sampleCount) * stride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = TrackRunTable(
            count: Int(sampleCount),
            rawEntries: rawEntries,
            perSampleFlags: perSampleFlags,
            version: version
        )

        return TrackRunBox(
            decodedVersion: version,
            decodedFlagsRaw: flags,
            dataOffset: dataOffset,
            firstSampleFlags: firstSampleFlags,
            table: table
        )
    }

    /// Decode-side initialiser that trusts the on-wire flags verbatim.
    internal init(
        decodedVersion version: UInt8,
        decodedFlagsRaw flags: UInt32,
        dataOffset: Int32?,
        firstSampleFlags: UInt32?,
        table: TrackRunTable
    ) {
        self.version = version
        self.flags = flags
        self.dataOffset = dataOffset
        self.firstSampleFlags = firstSampleFlags
        self.table = table
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(UInt32(table.count))
            if let value = dataOffset { body.writeInt32(value) }
            if let value = firstSampleFlags { body.writeUInt32(value) }
            body.writeData(table.rawEntries)
        }
    }
}

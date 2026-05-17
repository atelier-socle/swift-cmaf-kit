// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CompositionOffsetBox (ctts)
//
// Reference: ISO/IEC 14496-12 §8.6.1.3 (composition time to sample box).
//
// Each entry maps a run of consecutive samples to a composition offset
// applied to their decoding time. Version 0 uses unsigned offsets;
// version 1 uses signed offsets, required for content where the
// composition can precede the decoding (for example MV-HEVC layered
// streams where the secondary layer may decode ahead of presentation).

import Foundation

/// One run of equal-composition-offset samples.
///
/// The offset is stored as `Int64` to accommodate both version-0 unsigned
/// (`UInt32`) and version-1 signed (`Int32`) sources without loss.
public struct CompositionOffsetEntry: Sendable, Hashable {
    /// Number of consecutive samples sharing this offset.
    public let sampleCount: UInt32
    /// Composition offset applied to the decoding time of each sample in
    /// the run. Signed for version 1; version-0 unsigned values are
    /// zero-extended into the `Int64` representation.
    public let sampleOffset: Int64

    public init(sampleCount: UInt32, sampleOffset: Int64) {
        self.sampleCount = sampleCount
        self.sampleOffset = sampleOffset
    }
}

/// A lazy view over the entries of a ``CompositionOffsetBox``.
///
/// Reference: ISO/IEC 14496-12 §8.6.1.3.
///
/// `CompositionOffsetTable` conforms to `RandomAccessCollection` and is
/// backed directly by the on-wire byte slice (`count * 8` bytes). Entries
/// are decoded on demand at O(1) cost per index. The version determines
/// the signedness of the on-wire offset; the public
/// ``CompositionOffsetEntry/sampleOffset`` is always `Int64`. Round-trip
/// re-emits the raw bytes verbatim.
public struct CompositionOffsetTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    /// Version of the containing box. `0` = unsigned UInt32 offsets;
    /// `1` = signed Int32 offsets.
    public let version: UInt8

    public typealias Index = Int
    public typealias Element = CompositionOffsetEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> CompositionOffsetEntry {
        precondition(
            position >= 0 && position < count,
            "CompositionOffsetTable: index \(position) out of range 0..<\(count)"
        )
        let baseOffset = position * 8
        let sampleCount = rawEntries.readUInt32BigEndian(at: baseOffset)
        let offsetRaw = rawEntries.readUInt32BigEndian(at: baseOffset + 4)
        let sampleOffset: Int64 =
            (version == 1)
            ? Int64(Int32(bitPattern: offsetRaw))
            : Int64(offsetRaw)
        return CompositionOffsetEntry(sampleCount: sampleCount, sampleOffset: sampleOffset)
    }

    internal init(count: Int, rawEntries: Data, version: UInt8) {
        self.count = count
        self.rawEntries = rawEntries
        self.version = version
    }

    /// Construct from an array of entries.
    ///
    /// Version 0 requires non-negative offsets that fit in `UInt32`;
    /// version 1 accepts the full `Int32` range.
    public init(entries: [CompositionOffsetEntry], version: UInt8 = 1) {
        precondition(version == 0 || version == 1, "CompositionOffsetTable version must be 0 or 1")
        if version == 0 {
            precondition(
                entries.allSatisfy { $0.sampleOffset >= 0 && $0.sampleOffset <= Int64(UInt32.max) },
                "CompositionOffsetTable v0 requires non-negative offsets fitting in UInt32"
            )
        } else {
            precondition(
                entries.allSatisfy { $0.sampleOffset >= Int64(Int32.min) && $0.sampleOffset <= Int64(Int32.max) },
                "CompositionOffsetTable v1 requires offsets fitting in Int32"
            )
        }

        var bytes = Data()
        bytes.reserveCapacity(entries.count * 8)
        for entry in entries {
            bytes.appendUInt32BigEndian(entry.sampleCount)
            if version == 1 {
                bytes.appendInt32BigEndian(Int32(entry.sampleOffset))
            } else {
                bytes.appendUInt32BigEndian(UInt32(entry.sampleOffset))
            }
        }
        self.init(count: entries.count, rawEntries: bytes, version: version)
    }
}

extension CompositionOffsetTable: LazyTableData {
    internal static var entryStride: Int { 8 }
}

/// Composition-time-to-sample box.
public struct CompositionOffsetBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "ctts"

    public let version: UInt8
    public let flags: UInt32
    public let table: CompositionOffsetTable

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        table: CompositionOffsetTable
    ) {
        precondition(
            version == table.version,
            "CompositionOffsetBox version must match its table's version"
        )
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> CompositionOffsetBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        guard version == 0 || version == 1 else {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }
        let entryCount = try reader.readUInt32()
        let expectedBytes = Int(entryCount) * CompositionOffsetTable.entryStride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = CompositionOffsetTable(
            count: Int(entryCount),
            rawEntries: rawEntries,
            version: version
        )
        return CompositionOffsetBox(version: version, flags: flags, table: table)
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

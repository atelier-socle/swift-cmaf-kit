// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SubsegmentIndexBox (ssix)
//
// Reference: ISO/IEC 14496-12 §8.16.4 (subsegment index box).
//
// Indexes one subsegment by content level (per ISO/IEC 14496-12 §I.6).
// Each entry pairs a level with a range size, allowing range-based
// quality-conditional retrieval of fMP4 subsegments.

import Foundation

/// One range in a ``SubsegmentIndexBox``.
public struct SubsegmentIndexEntry: Sendable, Hashable {
    /// Content level identifier.
    public let level: UInt8
    /// Byte size of the range mapped to this level. 24-bit value.
    public let rangeSize: UInt32

    public init(level: UInt8, rangeSize: UInt32) {
        precondition(rangeSize <= 0x00FF_FFFF, "rangeSize must fit in 24 bits")
        self.level = level
        self.rangeSize = rangeSize
    }
}

/// A lazy view over the ranges of a ``SubsegmentIndexBox``.
///
/// Reference: ISO/IEC 14496-12 §8.16.4.
///
/// `SubsegmentIndexTable` conforms to `RandomAccessCollection` and is
/// backed directly by the on-wire byte slice. Entries are decoded on
/// demand at O(1) cost per index. Round-trip re-emits the raw bytes
/// verbatim.
public struct SubsegmentIndexTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = SubsegmentIndexEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> SubsegmentIndexEntry {
        precondition(
            position >= 0 && position < count,
            "SubsegmentIndexTable: index \(position) out of range 0..<\(count)"
        )
        let base = position * 4
        let word = rawEntries.readUInt32BigEndian(at: base)
        let level = UInt8((word >> 24) & 0xFF)
        let rangeSize = word & 0x00FF_FFFF
        return SubsegmentIndexEntry(level: level, rangeSize: rangeSize)
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    public init(entries: [SubsegmentIndexEntry]) {
        var bytes = Data()
        bytes.reserveCapacity(entries.count * 4)
        for entry in entries {
            let word: UInt32 = (UInt32(entry.level) << 24) | (entry.rangeSize & 0x00FF_FFFF)
            bytes.appendUInt32BigEndian(word)
        }
        self.init(count: entries.count, rawEntries: bytes)
    }
}

extension SubsegmentIndexTable: LazyTableData {
    internal static var entryStride: Int { 4 }
}

/// Subsegment index box.
///
/// `ssix` has no explicit entry count for its inner table; the table size
/// is computed by dividing the remaining body length by the 4-byte stride.
/// The outer `subsegmentCount` field reports how many subsegments the box
/// covers (one set of ranges per subsegment in the parent `sidx`).
public struct SubsegmentIndexBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "ssix"

    public let version: UInt8
    public let flags: UInt32
    /// Number of subsegments this box covers, as reported in its header.
    public let subsegmentCount: UInt32
    public let table: SubsegmentIndexTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        subsegmentCount: UInt32,
        table: SubsegmentIndexTable
    ) {
        self.version = version
        self.flags = flags
        self.subsegmentCount = subsegmentCount
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SubsegmentIndexBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let subsegmentCount = try reader.readUInt32()

        // Each entry is 4 bytes; consume floor(remaining / 4) entries.
        let remaining = reader.remaining
        let entriesByteCount = (remaining / 4) * 4
        let rawEntries = try reader.readData(count: entriesByteCount)
        let entryCount = entriesByteCount / 4
        let table = SubsegmentIndexTable(count: entryCount, rawEntries: rawEntries)
        return SubsegmentIndexBox(
            version: version,
            flags: flags,
            subsegmentCount: subsegmentCount,
            table: table
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(subsegmentCount)
            body.writeData(table.rawEntries)
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SegmentIndexBox (sidx)
//
// Reference: ISO/IEC 14496-12 §8.16.3 (segment index box).
//
// Index over a sequence of subsegments. Each entry points to a subsegment
// with a size, duration, and SAP (Stream Access Point) info. Essential
// for DASH / HLS-fMP4 segment-level seek.

import Foundation

/// One reference in a ``SegmentIndexBox``.
public struct SegmentIndexEntry: Sendable, Hashable {
    /// `false` = media reference; `true` = sidx reference (nested sidx).
    public let referenceType: Bool
    /// Size in bytes of the referenced subsegment or nested sidx.
    /// 31-bit value.
    public let referencedSize: UInt32
    /// Duration in the box's timescale.
    public let subsegmentDuration: UInt32
    /// Whether the referenced subsegment begins with a Stream Access Point.
    public let startsWithSAP: Bool
    /// SAP type (0..7 per ISO/IEC 14496-12 §I.3).
    public let sapType: UInt8
    /// Time offset between the SAP and the subsegment start.
    /// 28-bit value.
    public let sapDeltaTime: UInt32

    public init(
        referenceType: Bool,
        referencedSize: UInt32,
        subsegmentDuration: UInt32,
        startsWithSAP: Bool,
        sapType: UInt8,
        sapDeltaTime: UInt32
    ) {
        precondition(referencedSize <= 0x7FFF_FFFF, "referencedSize must fit in 31 bits")
        precondition(sapType <= 7, "sapType must fit in 3 bits")
        precondition(sapDeltaTime <= 0x0FFF_FFFF, "sapDeltaTime must fit in 28 bits")
        self.referenceType = referenceType
        self.referencedSize = referencedSize
        self.subsegmentDuration = subsegmentDuration
        self.startsWithSAP = startsWithSAP
        self.sapType = sapType
        self.sapDeltaTime = sapDeltaTime
    }
}

/// A lazy view over the references of a ``SegmentIndexBox``.
///
/// Reference: ISO/IEC 14496-12 §8.16.3.
///
/// `SegmentIndexTable` conforms to `RandomAccessCollection` and is backed
/// directly by the on-wire byte slice (`count * 12` bytes). Entries are
/// decoded on demand at O(1) cost per index. Round-trip re-emits the raw
/// bytes verbatim.
public struct SegmentIndexTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = SegmentIndexEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> SegmentIndexEntry {
        precondition(
            position >= 0 && position < count,
            "SegmentIndexTable: index \(position) out of range 0..<\(count)"
        )
        let base = position * 12
        let word0 = rawEntries.readUInt32BigEndian(at: base)
        let referenceType = (word0 & 0x8000_0000) != 0
        let referencedSize = word0 & 0x7FFF_FFFF
        let subsegmentDuration = rawEntries.readUInt32BigEndian(at: base + 4)
        let word2 = rawEntries.readUInt32BigEndian(at: base + 8)
        let startsWithSAP = (word2 & 0x8000_0000) != 0
        let sapType = UInt8((word2 >> 28) & 0x07)
        let sapDeltaTime = word2 & 0x0FFF_FFFF
        return SegmentIndexEntry(
            referenceType: referenceType,
            referencedSize: referencedSize,
            subsegmentDuration: subsegmentDuration,
            startsWithSAP: startsWithSAP,
            sapType: sapType,
            sapDeltaTime: sapDeltaTime
        )
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    public init(entries: [SegmentIndexEntry]) {
        var bytes = Data()
        bytes.reserveCapacity(entries.count * 12)
        for entry in entries {
            let word0: UInt32 =
                (entry.referenceType ? 0x8000_0000 : 0)
                | (entry.referencedSize & 0x7FFF_FFFF)
            bytes.appendUInt32BigEndian(word0)
            bytes.appendUInt32BigEndian(entry.subsegmentDuration)
            let word2: UInt32 =
                (entry.startsWithSAP ? 0x8000_0000 : 0)
                | ((UInt32(entry.sapType) & 0x07) << 28)
                | (entry.sapDeltaTime & 0x0FFF_FFFF)
            bytes.appendUInt32BigEndian(word2)
        }
        self.init(count: entries.count, rawEntries: bytes)
    }
}

extension SegmentIndexTable: LazyTableData {
    internal static var entryStride: Int { 12 }
}

/// Segment index box.
public struct SegmentIndexBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "sidx"

    public let version: UInt8
    public let flags: UInt32
    public let referenceID: UInt32
    public let timescale: UInt32
    public let earliestPresentationTime: UInt64
    public let firstOffset: UInt64
    public let table: SegmentIndexTable

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        referenceID: UInt32,
        timescale: UInt32,
        earliestPresentationTime: UInt64,
        firstOffset: UInt64,
        table: SegmentIndexTable
    ) {
        self.version = version
        self.flags = flags
        self.referenceID = referenceID
        self.timescale = timescale
        self.earliestPresentationTime = earliestPresentationTime
        self.firstOffset = firstOffset
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SegmentIndexBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let referenceID = try reader.readUInt32()
        let timescale = try reader.readUInt32()
        let earliestPresentationTime: UInt64
        let firstOffset: UInt64
        if version == 1 {
            earliestPresentationTime = try reader.readUInt64()
            firstOffset = try reader.readUInt64()
        } else if version == 0 {
            earliestPresentationTime = UInt64(try reader.readUInt32())
            firstOffset = UInt64(try reader.readUInt32())
        } else {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }
        try reader.skip(2)  // reserved
        let referenceCount = try reader.readUInt16()

        let expectedBytes = Int(referenceCount) * 12
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = SegmentIndexTable(count: Int(referenceCount), rawEntries: rawEntries)
        return SegmentIndexBox(
            version: version,
            flags: flags,
            referenceID: referenceID,
            timescale: timescale,
            earliestPresentationTime: earliestPresentationTime,
            firstOffset: firstOffset,
            table: table
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(referenceID)
            body.writeUInt32(timescale)
            if version == 1 {
                body.writeUInt64(earliestPresentationTime)
                body.writeUInt64(firstOffset)
            } else {
                body.writeUInt32(UInt32(min(earliestPresentationTime, UInt64(UInt32.max))))
                body.writeUInt32(UInt32(min(firstOffset, UInt64(UInt32.max))))
            }
            body.writeZeros(2)
            body.writeUInt16(UInt16(table.count))
            body.writeData(table.rawEntries)
        }
    }
}

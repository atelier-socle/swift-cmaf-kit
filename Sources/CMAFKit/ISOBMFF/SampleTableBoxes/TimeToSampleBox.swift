// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TimeToSampleBox (stts)
//
// Reference: ISO/IEC 14496-12 §8.6.1.2 (decoding time to sample box).
//
// Compactly represents the decoding time of each sample as runs of
// (sample_count, sample_delta) pairs. The table is exposed as a lazy
// RandomAccessCollection backed directly by the on-wire byte slice.

import Foundation

/// One run of equal-duration samples.
public struct TimeToSampleEntry: Sendable, Hashable {
    /// Number of consecutive samples sharing this duration.
    public let sampleCount: UInt32
    /// Duration of each sample in the run, in media timescale units.
    public let sampleDelta: UInt32

    public init(sampleCount: UInt32, sampleDelta: UInt32) {
        self.sampleCount = sampleCount
        self.sampleDelta = sampleDelta
    }
}

/// A lazy view over the entries of a ``TimeToSampleBox``.
///
/// Reference: ISO/IEC 14496-12 §8.6.1.2.
///
/// `TimeToSampleTable` conforms to `RandomAccessCollection` and is backed
/// directly by the on-wire byte slice. Entries are decoded on demand at
/// O(1) cost per index. The collection's storage footprint equals the raw
/// byte count (`count * 8`), with no per-entry Swift object allocation.
///
/// Encoding the containing ``TimeToSampleBox`` re-emits the raw bytes
/// verbatim, guaranteeing byte-perfect round-trip without iterating the
/// entries.
public struct TimeToSampleTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = TimeToSampleEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> TimeToSampleEntry {
        precondition(
            position >= 0 && position < count,
            "TimeToSampleTable: index \(position) out of range 0..<\(count)"
        )
        let baseOffset = position * 8
        let sampleCount = rawEntries.readUInt32BigEndian(at: baseOffset)
        let sampleDelta = rawEntries.readUInt32BigEndian(at: baseOffset + 4)
        return TimeToSampleEntry(sampleCount: sampleCount, sampleDelta: sampleDelta)
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    /// Public construction from an array of entries.
    public init(entries: [TimeToSampleEntry]) {
        var bytes = Data()
        bytes.reserveCapacity(entries.count * 8)
        for entry in entries {
            bytes.appendUInt32BigEndian(entry.sampleCount)
            bytes.appendUInt32BigEndian(entry.sampleDelta)
        }
        self.init(count: entries.count, rawEntries: bytes)
    }
}

extension TimeToSampleTable: LazyTableData {
    internal static var entryStride: Int { 8 }
}

/// Decoding-time-to-sample box.
public struct TimeToSampleBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "stts"

    public let version: UInt8
    public let flags: UInt32
    public let table: TimeToSampleTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        table: TimeToSampleTable
    ) {
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> TimeToSampleBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let entryCount = try reader.readUInt32()
        let expectedBytes = Int(entryCount) * TimeToSampleTable.entryStride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = TimeToSampleTable(count: Int(entryCount), rawEntries: rawEntries)
        return TimeToSampleBox(version: version, flags: flags, table: table)
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

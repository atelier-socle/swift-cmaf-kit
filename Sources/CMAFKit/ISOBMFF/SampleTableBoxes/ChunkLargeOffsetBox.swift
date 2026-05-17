// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ChunkLargeOffsetBox (co64)
//
// Reference: ISO/IEC 14496-12 §8.7.5 (chunk large offset box, 64-bit).
//
// 64-bit chunk offsets for files exceeding 4 GiB.

import Foundation

/// A lazy view over the 64-bit chunk offsets of a ``ChunkLargeOffsetBox``.
///
/// Reference: ISO/IEC 14496-12 §8.7.5.
///
/// `ChunkLargeOffsetTable` conforms to `RandomAccessCollection` and is
/// backed directly by the on-wire byte slice (`count * 8` bytes). Entries
/// are decoded on demand at O(1) cost per index. Round-trip re-emits the
/// raw bytes verbatim.
public struct ChunkLargeOffsetTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = UInt64

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> UInt64 {
        precondition(
            position >= 0 && position < count,
            "ChunkLargeOffsetTable: index \(position) out of range 0..<\(count)"
        )
        return rawEntries.readUInt64BigEndian(at: position * 8)
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    public init(offsets: [UInt64]) {
        var bytes = Data()
        bytes.reserveCapacity(offsets.count * 8)
        for offset in offsets {
            bytes.appendUInt64BigEndian(offset)
        }
        self.init(count: offsets.count, rawEntries: bytes)
    }
}

extension ChunkLargeOffsetTable: LazyTableData {
    internal static var entryStride: Int { 8 }
}

/// Chunk large offset box (64-bit).
public struct ChunkLargeOffsetBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "co64"

    public let version: UInt8
    public let flags: UInt32
    public let table: ChunkLargeOffsetTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        table: ChunkLargeOffsetTable
    ) {
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ChunkLargeOffsetBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let entryCount = try reader.readUInt32()
        let expectedBytes = Int(entryCount) * ChunkLargeOffsetTable.entryStride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = ChunkLargeOffsetTable(count: Int(entryCount), rawEntries: rawEntries)
        return ChunkLargeOffsetBox(version: version, flags: flags, table: table)
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

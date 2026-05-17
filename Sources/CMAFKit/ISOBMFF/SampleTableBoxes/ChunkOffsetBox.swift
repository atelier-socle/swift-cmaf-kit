// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ChunkOffsetBox (stco)
//
// Reference: ISO/IEC 14496-12 §8.7.5 (chunk offset box, 32-bit version).
//
// Per-chunk byte offset from the start of the file. The 32-bit version
// is for files smaller than 4 GiB; larger files use `co64` instead.

import Foundation

/// A lazy view over the chunk offsets of a ``ChunkOffsetBox``.
///
/// Reference: ISO/IEC 14496-12 §8.7.5.
///
/// `ChunkOffsetTable` conforms to `RandomAccessCollection` and is backed
/// directly by the on-wire byte slice (`count * 4` bytes). Entries are
/// decoded on demand at O(1) cost per index. Round-trip re-emits the raw
/// bytes verbatim.
public struct ChunkOffsetTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = UInt32

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> UInt32 {
        precondition(
            position >= 0 && position < count,
            "ChunkOffsetTable: index \(position) out of range 0..<\(count)"
        )
        return rawEntries.readUInt32BigEndian(at: position * 4)
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    public init(offsets: [UInt32]) {
        var bytes = Data()
        bytes.reserveCapacity(offsets.count * 4)
        for offset in offsets {
            bytes.appendUInt32BigEndian(offset)
        }
        self.init(count: offsets.count, rawEntries: bytes)
    }
}

extension ChunkOffsetTable: LazyTableData {
    internal static var entryStride: Int { 4 }
}

/// Chunk offset box (32-bit).
public struct ChunkOffsetBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "stco"

    public let version: UInt8
    public let flags: UInt32
    public let table: ChunkOffsetTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        table: ChunkOffsetTable
    ) {
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ChunkOffsetBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let entryCount = try reader.readUInt32()
        let expectedBytes = Int(entryCount) * ChunkOffsetTable.entryStride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = ChunkOffsetTable(count: Int(entryCount), rawEntries: rawEntries)
        return ChunkOffsetBox(version: version, flags: flags, table: table)
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

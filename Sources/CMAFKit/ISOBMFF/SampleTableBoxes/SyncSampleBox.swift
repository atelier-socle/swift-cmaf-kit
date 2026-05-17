// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SyncSampleBox (stss)
//
// Reference: ISO/IEC 14496-12 §8.6.2 (sync sample box).
//
// Lists the 1-based indices of samples that are random-access points
// (keyframes). When the box is absent from the track, every sample is a
// sync sample.

import Foundation

/// A lazy view over the sync-sample numbers of a ``SyncSampleBox``.
///
/// Reference: ISO/IEC 14496-12 §8.6.2.
///
/// `SyncSampleTable` conforms to `RandomAccessCollection` and is backed
/// directly by the on-wire byte slice (`count * 4` bytes). Entries are
/// decoded on demand at O(1) cost per index. Round-trip re-emits the raw
/// bytes verbatim.
public struct SyncSampleTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = UInt32

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> UInt32 {
        precondition(
            position >= 0 && position < count,
            "SyncSampleTable: index \(position) out of range 0..<\(count)"
        )
        return rawEntries.readUInt32BigEndian(at: position * 4)
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    public init(sampleNumbers: [UInt32]) {
        var bytes = Data()
        bytes.reserveCapacity(sampleNumbers.count * 4)
        for number in sampleNumbers {
            bytes.appendUInt32BigEndian(number)
        }
        self.init(count: sampleNumbers.count, rawEntries: bytes)
    }
}

extension SyncSampleTable: LazyTableData {
    internal static var entryStride: Int { 4 }
}

/// Sync sample box.
public struct SyncSampleBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "stss"

    public let version: UInt8
    public let flags: UInt32
    public let table: SyncSampleTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        table: SyncSampleTable
    ) {
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SyncSampleBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let entryCount = try reader.readUInt32()
        let expectedBytes = Int(entryCount) * SyncSampleTable.entryStride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = SyncSampleTable(count: Int(entryCount), rawEntries: rawEntries)
        return SyncSampleBox(version: version, flags: flags, table: table)
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

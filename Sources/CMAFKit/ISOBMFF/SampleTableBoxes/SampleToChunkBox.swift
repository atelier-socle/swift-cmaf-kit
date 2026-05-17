// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleToChunkBox (stsc)
//
// Reference: ISO/IEC 14496-12 §8.7.4 (sample to chunk box).
//
// Maps samples to chunks: runs of chunks with N samples each and a
// sample-description index. The first chunk of each run is recorded; the
// run continues until the next entry's `firstChunk`.

import Foundation

/// One run of chunks with constant samples-per-chunk and a single
/// sample-description index.
public struct SampleToChunkEntry: Sendable, Hashable {
    /// 1-based chunk index where this run starts.
    public let firstChunk: UInt32
    /// Number of samples in each chunk of this run.
    public let samplesPerChunk: UInt32
    /// 1-based index into the containing `stsd` entries.
    public let sampleDescriptionIndex: UInt32

    public init(firstChunk: UInt32, samplesPerChunk: UInt32, sampleDescriptionIndex: UInt32) {
        self.firstChunk = firstChunk
        self.samplesPerChunk = samplesPerChunk
        self.sampleDescriptionIndex = sampleDescriptionIndex
    }
}

/// A lazy view over the entries of a ``SampleToChunkBox``.
///
/// Reference: ISO/IEC 14496-12 §8.7.4.
///
/// `SampleToChunkTable` conforms to `RandomAccessCollection` and is backed
/// directly by the on-wire byte slice (`count * 12` bytes). Entries are
/// decoded on demand at O(1) cost per index. Round-trip re-emits the
/// raw bytes verbatim.
public struct SampleToChunkTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = SampleToChunkEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> SampleToChunkEntry {
        precondition(
            position >= 0 && position < count,
            "SampleToChunkTable: index \(position) out of range 0..<\(count)"
        )
        let baseOffset = position * 12
        let firstChunk = rawEntries.readUInt32BigEndian(at: baseOffset)
        let samplesPerChunk = rawEntries.readUInt32BigEndian(at: baseOffset + 4)
        let sampleDescIndex = rawEntries.readUInt32BigEndian(at: baseOffset + 8)
        return SampleToChunkEntry(
            firstChunk: firstChunk,
            samplesPerChunk: samplesPerChunk,
            sampleDescriptionIndex: sampleDescIndex
        )
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    public init(entries: [SampleToChunkEntry]) {
        var bytes = Data()
        bytes.reserveCapacity(entries.count * 12)
        for entry in entries {
            bytes.appendUInt32BigEndian(entry.firstChunk)
            bytes.appendUInt32BigEndian(entry.samplesPerChunk)
            bytes.appendUInt32BigEndian(entry.sampleDescriptionIndex)
        }
        self.init(count: entries.count, rawEntries: bytes)
    }
}

extension SampleToChunkTable: LazyTableData {
    internal static var entryStride: Int { 12 }
}

/// Sample-to-chunk box.
public struct SampleToChunkBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "stsc"

    public let version: UInt8
    public let flags: UInt32
    public let table: SampleToChunkTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        table: SampleToChunkTable
    ) {
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SampleToChunkBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let entryCount = try reader.readUInt32()
        let expectedBytes = Int(entryCount) * SampleToChunkTable.entryStride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = SampleToChunkTable(count: Int(entryCount), rawEntries: rawEntries)
        return SampleToChunkBox(version: version, flags: flags, table: table)
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

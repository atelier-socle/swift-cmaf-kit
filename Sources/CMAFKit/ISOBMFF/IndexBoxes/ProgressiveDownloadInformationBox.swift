// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ProgressiveDownloadInformationBox (pdin)
//
// Reference: ISO/IEC 14496-12 §8.1.3 (progressive download information box).
//
// Hints to download clients about bitrate / initial-delay pairs for
// progressive HTTP delivery.

import Foundation

/// One bitrate / initial-delay pair.
public struct ProgressiveDownloadEntry: Sendable, Hashable {
    /// Suggested download rate in bytes per second.
    public let rate: UInt32
    /// Initial buffering delay in milliseconds at the corresponding rate.
    public let initialDelay: UInt32

    public init(rate: UInt32, initialDelay: UInt32) {
        self.rate = rate
        self.initialDelay = initialDelay
    }
}

/// A lazy view over the entries of a ``ProgressiveDownloadInformationBox``.
///
/// Reference: ISO/IEC 14496-12 §8.1.3.
///
/// `ProgressiveDownloadTable` conforms to `RandomAccessCollection` and is
/// backed directly by the on-wire byte slice (`count * 8` bytes). Entries
/// are decoded on demand at O(1) cost per index. Round-trip re-emits the
/// raw bytes verbatim.
public struct ProgressiveDownloadTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = ProgressiveDownloadEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> ProgressiveDownloadEntry {
        precondition(
            position >= 0 && position < count,
            "ProgressiveDownloadTable: index \(position) out of range 0..<\(count)"
        )
        let base = position * 8
        let rate = rawEntries.readUInt32BigEndian(at: base)
        let delay = rawEntries.readUInt32BigEndian(at: base + 4)
        return ProgressiveDownloadEntry(rate: rate, initialDelay: delay)
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    public init(entries: [ProgressiveDownloadEntry]) {
        var bytes = Data()
        bytes.reserveCapacity(entries.count * 8)
        for entry in entries {
            bytes.appendUInt32BigEndian(entry.rate)
            bytes.appendUInt32BigEndian(entry.initialDelay)
        }
        self.init(count: entries.count, rawEntries: bytes)
    }
}

extension ProgressiveDownloadTable: LazyTableData {
    internal static var entryStride: Int { 8 }
}

/// Progressive download information box.
///
/// `pdin` has no explicit entry count; the body is interpreted as
/// `floor(remaining / 8)` entries.
public struct ProgressiveDownloadInformationBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "pdin"

    public let version: UInt8
    public let flags: UInt32
    public let table: ProgressiveDownloadTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        table: ProgressiveDownloadTable
    ) {
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ProgressiveDownloadInformationBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let remaining = reader.remaining
        let entriesByteCount = (remaining / 8) * 8
        let rawEntries = try reader.readData(count: entriesByteCount)
        let table = ProgressiveDownloadTable(
            count: entriesByteCount / 8,
            rawEntries: rawEntries
        )
        return ProgressiveDownloadInformationBox(
            version: version,
            flags: flags,
            table: table
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeData(table.rawEntries)
        }
    }
}

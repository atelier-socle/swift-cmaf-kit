// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleSizeBox (stsz)
//
// Reference: ISO/IEC 14496-12 §8.7.3.2 (sample size box).
//
// Each sample's size in bytes. When `sample_size` is non-zero, every
// sample has that constant size and the table is absent on the wire.
// Otherwise, the table holds one UInt32 per sample.

import Foundation

/// A lazy view over the sample sizes of a ``SampleSizeBox``.
///
/// Reference: ISO/IEC 14496-12 §8.7.3.2.
///
/// When all samples share the same size (constant-size case), the
/// underlying `rawEntries` is empty and ``constantSize`` carries the
/// shared value; the subscript returns the constant for every index.
/// In the per-sample case, ``constantSize`` is `nil` and the subscript
/// decodes 32-bit big-endian values from `rawEntries` at O(1) per index.
///
/// Round-trip re-emits whichever form the source used.
public struct SampleSizeTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    /// Non-nil iff all samples share a single size; in that case the
    /// table has no on-wire entries.
    public let constantSize: UInt32?

    public typealias Index = Int
    public typealias Element = UInt32

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> UInt32 {
        precondition(
            position >= 0 && position < count,
            "SampleSizeTable: index \(position) out of range 0..<\(count)"
        )
        if let constant = constantSize {
            return constant
        }
        return rawEntries.readUInt32BigEndian(at: position * 4)
    }

    internal init(count: Int, rawEntries: Data, constantSize: UInt32?) {
        self.count = count
        self.rawEntries = rawEntries
        self.constantSize = constantSize
    }

    /// Construct a per-sample size table.
    public init(sizes: [UInt32]) {
        var bytes = Data()
        bytes.reserveCapacity(sizes.count * 4)
        for size in sizes {
            bytes.appendUInt32BigEndian(size)
        }
        self.init(count: sizes.count, rawEntries: bytes, constantSize: nil)
    }

    /// Construct a constant-size table.
    public init(count: Int, constantSize: UInt32) {
        precondition(constantSize > 0, "constantSize must be > 0")
        self.init(count: count, rawEntries: Data(), constantSize: constantSize)
    }
}

extension SampleSizeTable: LazyTableData {
    internal static var entryStride: Int { 4 }
}

/// Sample size box.
public struct SampleSizeBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "stsz"

    public let version: UInt8
    public let flags: UInt32
    public let table: SampleSizeTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        table: SampleSizeTable
    ) {
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SampleSizeBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let sampleSize = try reader.readUInt32()
        let sampleCount = try reader.readUInt32()

        let table: SampleSizeTable
        if sampleSize != 0 {
            table = SampleSizeTable(count: Int(sampleCount), constantSize: sampleSize)
        } else {
            let expectedBytes = Int(sampleCount) * 4
            guard reader.remaining >= expectedBytes else {
                throw BinaryIOError.insufficientData(
                    expected: expectedBytes,
                    available: reader.remaining
                )
            }
            let rawEntries = try reader.readData(count: expectedBytes)
            table = SampleSizeTable(
                count: Int(sampleCount),
                rawEntries: rawEntries,
                constantSize: nil
            )
        }
        return SampleSizeBox(version: version, flags: flags, table: table)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(table.constantSize ?? 0)
            body.writeUInt32(UInt32(table.count))
            if table.constantSize == nil {
                body.writeData(table.rawEntries)
            }
        }
    }
}

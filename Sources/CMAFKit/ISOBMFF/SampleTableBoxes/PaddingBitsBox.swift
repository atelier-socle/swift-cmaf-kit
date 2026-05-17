// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - PaddingBitsBox (padb)
//
// Reference: ISO/IEC 14496-12 §8.7.6 (padding bits box).
//
// One 3-bit padding value per sample, with reserved bits between them.
// On the wire: 8 bits per byte, holding 1 bit reserved + 3 bits for
// sample `n` + 1 bit reserved + 3 bits for sample `n + 1`. CMAFKit
// exposes the table as a lazy collection of `UInt8` padding values in
// the range 0..7; the nibble layout is handled internally.

import Foundation

/// A lazy view over the padding-bit entries of a ``PaddingBitsBox``.
///
/// Reference: ISO/IEC 14496-12 §8.7.6.
///
/// `PaddingBitsTable` conforms to `RandomAccessCollection` and is backed
/// directly by the packed on-wire byte slice. Each byte carries two
/// padding values per the standard's nibble layout. Entries are decoded
/// on demand at O(1) cost per index. Round-trip re-emits the packed
/// bytes verbatim, including the zero-padding nibble produced when
/// `count` is odd.
public struct PaddingBitsTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int

    /// Packed byte storage. Each byte holds two padding values per the
    /// nibble layout described in the standard. The effective byte count
    /// is `(count + 1) / 2`.
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = UInt8

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> UInt8 {
        precondition(
            position >= 0 && position < count,
            "PaddingBitsTable: index \(position) out of range 0..<\(count)"
        )
        let byteIndex = position / 2
        let byte = rawEntries.readUInt8(at: byteIndex)
        if position & 1 == 0 {
            // Even position: high nibble's low 3 bits.
            return (byte >> 4) & 0x07
        } else {
            // Odd position: low nibble's low 3 bits.
            return byte & 0x07
        }
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    /// Construct from an array of padding values. Each value must be in
    /// the range 0..7.
    public init(values: [UInt8]) {
        precondition(
            values.allSatisfy { $0 <= 7 },
            "PaddingBitsTable values must be in 0..7"
        )
        var bytes = Data()
        let byteCount = (values.count + 1) / 2
        bytes.reserveCapacity(byteCount)
        var index = 0
        while index < values.count {
            let high = values[index] & 0x07
            let low: UInt8 = (index + 1 < values.count) ? (values[index + 1] & 0x07) : 0
            bytes.append((high << 4) | low)
            index += 2
        }
        self.init(count: values.count, rawEntries: bytes)
    }
}

extension PaddingBitsTable: LazyTableData {
    /// Reported as 1 for protocol uniformity; the effective on-wire byte
    /// count is `(count + 1) / 2` and is enforced by the parser.
    internal static var entryStride: Int { 1 }
}

/// Padding bits box.
public struct PaddingBitsBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "padb"

    public let version: UInt8
    public let flags: UInt32
    public let table: PaddingBitsTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        table: PaddingBitsTable
    ) {
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> PaddingBitsBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let sampleCount = try reader.readUInt32()
        let byteCount = (Int(sampleCount) + 1) / 2
        guard reader.remaining >= byteCount else {
            throw BinaryIOError.insufficientData(
                expected: byteCount,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: byteCount)
        let table = PaddingBitsTable(count: Int(sampleCount), rawEntries: rawEntries)
        return PaddingBitsBox(version: version, flags: flags, table: table)
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

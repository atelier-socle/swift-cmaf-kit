// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CompactSampleSizeBox (stz2)
//
// Reference: ISO/IEC 14496-12 §8.7.3.3 (compact sample size box).
//
// Like `stsz` but with 4-, 8-, or 16-bit-per-sample packing. The
// `field_size` byte determines the layout. CMAFKit handles the
// nibble-packed case internally so consumers see UInt32 values uniformly.

import Foundation

/// Field size of `stz2` entries.
public enum CompactSampleSizeFieldSize: UInt8, Sendable, Hashable, CaseIterable {
    /// Two entries per byte (high nibble first). The final low nibble is
    /// zero padding when `count` is odd.
    case fourBits = 4
    /// One entry per byte.
    case eightBits = 8
    /// Two bytes per entry, big-endian.
    case sixteenBits = 16
}

/// A lazy view over the sample sizes of a ``CompactSampleSizeBox``.
///
/// Reference: ISO/IEC 14496-12 §8.7.3.3.
///
/// `CompactSampleSizeTable` conforms to `RandomAccessCollection` and is
/// backed directly by the packed on-wire byte slice. Sample sizes are
/// always exposed as `UInt32`; the nibble / byte / word packing is
/// handled internally based on ``fieldSize``. Round-trip re-emits the
/// raw packed bytes verbatim, including the zero-padding nibble produced
/// when `fieldSize == .fourBits` and `count` is odd.
public struct CompactSampleSizeTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data
    public let fieldSize: CompactSampleSizeFieldSize

    public typealias Index = Int
    public typealias Element = UInt32

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> UInt32 {
        precondition(
            position >= 0 && position < count,
            "CompactSampleSizeTable: index \(position) out of range 0..<\(count)"
        )
        switch fieldSize {
        case .fourBits:
            let byteIndex = position / 2
            let byte = rawEntries.readUInt8(at: byteIndex)
            if position & 1 == 0 {
                return UInt32((byte >> 4) & 0x0F)
            } else {
                return UInt32(byte & 0x0F)
            }
        case .eightBits:
            return UInt32(rawEntries.readUInt8(at: position))
        case .sixteenBits:
            return UInt32(rawEntries.readUInt16BigEndian(at: position * 2))
        }
    }

    internal init(count: Int, rawEntries: Data, fieldSize: CompactSampleSizeFieldSize) {
        self.count = count
        self.rawEntries = rawEntries
        self.fieldSize = fieldSize
    }

    /// Construct from an array of sample sizes. Every size must fit in the
    /// declared `fieldSize`.
    public init(sizes: [UInt32], fieldSize: CompactSampleSizeFieldSize) {
        let maxAllowed: UInt32 = {
            switch fieldSize {
            case .fourBits: return 0x0F
            case .eightBits: return 0xFF
            case .sixteenBits: return 0xFFFF
            }
        }()
        precondition(
            sizes.allSatisfy { $0 <= maxAllowed },
            "CompactSampleSizeTable: a size exceeds the max representable in fieldSize \(fieldSize.rawValue) bits"
        )

        var bytes = Data()
        switch fieldSize {
        case .fourBits:
            bytes.reserveCapacity((sizes.count + 1) / 2)
            var index = 0
            while index < sizes.count {
                let high = UInt8(sizes[index] & 0x0F)
                let low: UInt8 = (index + 1 < sizes.count) ? UInt8(sizes[index + 1] & 0x0F) : 0
                bytes.append((high << 4) | low)
                index += 2
            }
        case .eightBits:
            bytes.reserveCapacity(sizes.count)
            for size in sizes {
                bytes.append(UInt8(size & 0xFF))
            }
        case .sixteenBits:
            bytes.reserveCapacity(sizes.count * 2)
            for size in sizes {
                bytes.appendUInt16BigEndian(UInt16(size & 0xFFFF))
            }
        }
        self.init(count: sizes.count, rawEntries: bytes, fieldSize: fieldSize)
    }
}

extension CompactSampleSizeTable: LazyTableData {
    /// Reported as 1 for protocol uniformity; the parser computes the
    /// effective byte count from `fieldSize` and `count`.
    internal static var entryStride: Int { 1 }
}

/// Compact sample size box.
public struct CompactSampleSizeBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "stz2"

    public let version: UInt8
    public let flags: UInt32
    public let table: CompactSampleSizeTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        table: CompactSampleSizeTable
    ) {
        self.version = version
        self.flags = flags
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> CompactSampleSizeBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        try reader.skip(3)  // reserved
        let fieldSizeRaw = try reader.readUInt8()
        guard let fieldSize = CompactSampleSizeFieldSize(rawValue: fieldSizeRaw) else {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: fieldSizeRaw)
        }
        let sampleCount = try reader.readUInt32()

        let byteCount: Int
        switch fieldSize {
        case .fourBits: byteCount = (Int(sampleCount) + 1) / 2
        case .eightBits: byteCount = Int(sampleCount)
        case .sixteenBits: byteCount = Int(sampleCount) * 2
        }
        guard reader.remaining >= byteCount else {
            throw BinaryIOError.insufficientData(
                expected: byteCount,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: byteCount)
        let table = CompactSampleSizeTable(
            count: Int(sampleCount),
            rawEntries: rawEntries,
            fieldSize: fieldSize
        )
        return CompactSampleSizeBox(version: version, flags: flags, table: table)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeZeros(3)  // reserved
            body.writeUInt8(table.fieldSize.rawValue)
            body.writeUInt32(UInt32(table.count))
            body.writeData(table.rawEntries)
        }
    }
}

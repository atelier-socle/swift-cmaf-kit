// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TrackFragmentRandomAccessBox (tfra)
//
// Reference: ISO/IEC 14496-12 §8.8.10 (track fragment random access box).
//
// Per-track table of random-access entries. Each entry locates a
// fragment containing a random-access point via three variable-width
// fields whose sizes are declared in the box header (length-minus-one
// encoding in the lower 6 bits of a 32-bit word).

import Foundation

/// One random-access entry in a ``TrackFragmentRandomAccessBox``.
public struct TrackFragmentRandomAccessEntry: Sendable, Hashable {
    /// Decode time of the random-access sample in the track's timescale.
    public let time: UInt64
    /// Byte offset from the start of the file to the containing `moof`.
    public let moofOffset: UInt64
    /// 1-based index of the `traf` within that `moof`.
    public let trafNumber: UInt32
    /// 1-based index of the `trun` within the `traf`.
    public let trunNumber: UInt32
    /// 1-based index of the sample within the `trun`.
    public let sampleNumber: UInt32

    public init(
        time: UInt64,
        moofOffset: UInt64,
        trafNumber: UInt32,
        trunNumber: UInt32,
        sampleNumber: UInt32
    ) {
        self.time = time
        self.moofOffset = moofOffset
        self.trafNumber = trafNumber
        self.trunNumber = trunNumber
        self.sampleNumber = sampleNumber
    }
}

/// A lazy view over the entries of a ``TrackFragmentRandomAccessBox``.
///
/// Reference: ISO/IEC 14496-12 §8.8.10.
///
/// `TrackFragmentRandomAccessTable` conforms to `RandomAccessCollection`
/// and is backed directly by the on-wire byte slice. The per-entry stride
/// varies with the box version (8 or 4 bytes for `time` and `moofOffset`)
/// and with three independent width fields (1, 2, 3, or 4 bytes for each
/// of `trafNumber`, `trunNumber`, `sampleNumber`).
public struct TrackFragmentRandomAccessTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data
    /// Box version (0 = 32-bit time/offset, 1 = 64-bit).
    public let version: UInt8
    /// Width in bytes of the `trafNumber` field on the wire (1..4).
    public let trafNumberWidth: UInt8
    /// Width in bytes of the `trunNumber` field on the wire (1..4).
    public let trunNumberWidth: UInt8
    /// Width in bytes of the `sampleNumber` field on the wire (1..4).
    public let sampleNumberWidth: UInt8

    public typealias Index = Int
    public typealias Element = TrackFragmentRandomAccessEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    /// Per-entry byte stride.
    public var entryStride: Int {
        let timeWidth = (version == 1) ? 8 : 4
        let offsetWidth = (version == 1) ? 8 : 4
        return timeWidth + offsetWidth
            + Int(trafNumberWidth) + Int(trunNumberWidth) + Int(sampleNumberWidth)
    }

    public subscript(position: Int) -> TrackFragmentRandomAccessEntry {
        precondition(
            position >= 0 && position < count,
            "TrackFragmentRandomAccessTable: index \(position) out of range 0..<\(count)"
        )
        let stride = entryStride
        var offset = position * stride

        let time: UInt64
        if version == 1 {
            time = rawEntries.readUInt64BigEndian(at: offset)
            offset += 8
        } else {
            time = UInt64(rawEntries.readUInt32BigEndian(at: offset))
            offset += 4
        }

        let moofOffset: UInt64
        if version == 1 {
            moofOffset = rawEntries.readUInt64BigEndian(at: offset)
            offset += 8
        } else {
            moofOffset = UInt64(rawEntries.readUInt32BigEndian(at: offset))
            offset += 4
        }

        let trafNumber = Self.readVariableWidth(
            data: rawEntries, offset: offset, width: Int(trafNumberWidth))
        offset += Int(trafNumberWidth)
        let trunNumber = Self.readVariableWidth(
            data: rawEntries, offset: offset, width: Int(trunNumberWidth))
        offset += Int(trunNumberWidth)
        let sampleNumber = Self.readVariableWidth(
            data: rawEntries, offset: offset, width: Int(sampleNumberWidth))

        return TrackFragmentRandomAccessEntry(
            time: time,
            moofOffset: moofOffset,
            trafNumber: trafNumber,
            trunNumber: trunNumber,
            sampleNumber: sampleNumber
        )
    }

    private static func readVariableWidth(data: Data, offset: Int, width: Int) -> UInt32 {
        switch width {
        case 1: return UInt32(data.readUInt8(at: offset))
        case 2: return UInt32(data.readUInt16BigEndian(at: offset))
        case 3: return data.readUInt24BigEndian(at: offset)
        case 4: return data.readUInt32BigEndian(at: offset)
        default:
            preconditionFailure("Invalid variable width: \(width)")
        }
    }

    private static func writeVariableWidth(
        value: UInt32, width: Int, into bytes: inout Data
    ) {
        switch width {
        case 1: bytes.appendUInt8(UInt8(value & 0xFF))
        case 2: bytes.appendUInt16BigEndian(UInt16(value & 0xFFFF))
        case 3: bytes.appendUInt24BigEndian(value & 0x00FF_FFFF)
        case 4: bytes.appendUInt32BigEndian(value)
        default:
            preconditionFailure("Invalid variable width: \(width)")
        }
    }

    internal init(
        count: Int,
        rawEntries: Data,
        version: UInt8,
        trafNumberWidth: UInt8,
        trunNumberWidth: UInt8,
        sampleNumberWidth: UInt8
    ) {
        precondition(
            (1...4).contains(trafNumberWidth),
            "trafNumberWidth must be in 1...4"
        )
        precondition(
            (1...4).contains(trunNumberWidth),
            "trunNumberWidth must be in 1...4"
        )
        precondition(
            (1...4).contains(sampleNumberWidth),
            "sampleNumberWidth must be in 1...4"
        )
        self.count = count
        self.rawEntries = rawEntries
        self.version = version
        self.trafNumberWidth = trafNumberWidth
        self.trunNumberWidth = trunNumberWidth
        self.sampleNumberWidth = sampleNumberWidth
    }

    /// Construct from an entries array. Each variable-width field must
    /// fit in its declared width; values exceeding the width trigger a
    /// precondition failure.
    public init(
        entries: [TrackFragmentRandomAccessEntry],
        version: UInt8 = 1,
        trafNumberWidth: UInt8 = 4,
        trunNumberWidth: UInt8 = 4,
        sampleNumberWidth: UInt8 = 4
    ) {
        precondition(
            (1...4).contains(trafNumberWidth)
                && (1...4).contains(trunNumberWidth)
                && (1...4).contains(sampleNumberWidth),
            "Variable widths must be in 1...4"
        )
        let trafMax = Self.maxValue(width: Int(trafNumberWidth))
        let trunMax = Self.maxValue(width: Int(trunNumberWidth))
        let sampleMax = Self.maxValue(width: Int(sampleNumberWidth))
        for entry in entries {
            precondition(
                entry.trafNumber <= trafMax,
                "trafNumber \(entry.trafNumber) exceeds \(trafNumberWidth)-byte width"
            )
            precondition(
                entry.trunNumber <= trunMax,
                "trunNumber \(entry.trunNumber) exceeds \(trunNumberWidth)-byte width"
            )
            precondition(
                entry.sampleNumber <= sampleMax,
                "sampleNumber \(entry.sampleNumber) exceeds \(sampleNumberWidth)-byte width"
            )
        }

        let timeWidth = (version == 1) ? 8 : 4
        let offsetWidth = (version == 1) ? 8 : 4
        let stride =
            timeWidth + offsetWidth
            + Int(trafNumberWidth) + Int(trunNumberWidth) + Int(sampleNumberWidth)

        var bytes = Data()
        bytes.reserveCapacity(entries.count * stride)
        for entry in entries {
            if version == 1 {
                bytes.appendUInt64BigEndian(entry.time)
                bytes.appendUInt64BigEndian(entry.moofOffset)
            } else {
                bytes.appendUInt32BigEndian(UInt32(entry.time))
                bytes.appendUInt32BigEndian(UInt32(entry.moofOffset))
            }
            Self.writeVariableWidth(value: entry.trafNumber, width: Int(trafNumberWidth), into: &bytes)
            Self.writeVariableWidth(value: entry.trunNumber, width: Int(trunNumberWidth), into: &bytes)
            Self.writeVariableWidth(value: entry.sampleNumber, width: Int(sampleNumberWidth), into: &bytes)
        }

        self.init(
            count: entries.count,
            rawEntries: bytes,
            version: version,
            trafNumberWidth: trafNumberWidth,
            trunNumberWidth: trunNumberWidth,
            sampleNumberWidth: sampleNumberWidth
        )
    }

    private static func maxValue(width: Int) -> UInt32 {
        switch width {
        case 1: return 0xFF
        case 2: return 0xFFFF
        case 3: return 0x00FF_FFFF
        case 4: return UInt32.max
        default:
            preconditionFailure("Invalid width: \(width)")
        }
    }
}

/// Track-fragment random access box.
public struct TrackFragmentRandomAccessBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "tfra"

    public let version: UInt8
    public let flags: UInt32
    public let trackID: UInt32
    public let table: TrackFragmentRandomAccessTable

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        trackID: UInt32,
        table: TrackFragmentRandomAccessTable
    ) {
        precondition(
            version == table.version,
            "TrackFragmentRandomAccessBox version must match its table's version"
        )
        self.version = version
        self.flags = flags
        self.trackID = trackID
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> TrackFragmentRandomAccessBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let trackID = try reader.readUInt32()
        let lengths = try reader.readUInt32()
        // 26 bits reserved; lower 6 bits are 3 × 2-bit length-minus-one fields.
        let trafLenMinusOne = UInt8((lengths >> 4) & 0x03)
        let trunLenMinusOne = UInt8((lengths >> 2) & 0x03)
        let sampleLenMinusOne = UInt8(lengths & 0x03)
        let trafWidth = trafLenMinusOne + 1
        let trunWidth = trunLenMinusOne + 1
        let sampleWidth = sampleLenMinusOne + 1
        let entryCount = try reader.readUInt32()

        let timeWidth = (version == 1) ? 8 : 4
        let offsetWidth = (version == 1) ? 8 : 4
        let stride = timeWidth + offsetWidth + Int(trafWidth) + Int(trunWidth) + Int(sampleWidth)
        let expectedBytes = Int(entryCount) * stride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = TrackFragmentRandomAccessTable(
            count: Int(entryCount),
            rawEntries: rawEntries,
            version: version,
            trafNumberWidth: trafWidth,
            trunNumberWidth: trunWidth,
            sampleNumberWidth: sampleWidth
        )
        return TrackFragmentRandomAccessBox(
            version: version,
            flags: flags,
            trackID: trackID,
            table: table
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeUInt32(trackID)
            let trafBits = UInt32(table.trafNumberWidth - 1) & 0x03
            let trunBits = UInt32(table.trunNumberWidth - 1) & 0x03
            let sampleBits = UInt32(table.sampleNumberWidth - 1) & 0x03
            let lengths = (trafBits << 4) | (trunBits << 2) | sampleBits
            body.writeUInt32(lengths)
            body.writeUInt32(UInt32(table.count))
            body.writeData(table.rawEntries)
        }
    }
}

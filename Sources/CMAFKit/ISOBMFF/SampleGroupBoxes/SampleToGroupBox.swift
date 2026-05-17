// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleToGroupBox (sbgp)
//
// Reference: ISO/IEC 14496-12 §8.9.2 (sample to group box).
//
// Maps runs of consecutive samples to entries of a `sgpd` box with
// matching `grouping_type`.

import Foundation

/// One run of samples mapped to a single sample-group description index.
public struct SampleToGroupEntry: Sendable, Hashable {
    /// Number of consecutive samples sharing the same group-description index.
    public let sampleCount: UInt32
    /// 1-based index into the matching `sgpd` entries. Index 0 means
    /// "no group" (the sample belongs to no group of this type).
    public let groupDescriptionIndex: UInt32

    public init(sampleCount: UInt32, groupDescriptionIndex: UInt32) {
        self.sampleCount = sampleCount
        self.groupDescriptionIndex = groupDescriptionIndex
    }
}

/// A lazy view over the entries of a ``SampleToGroupBox``.
///
/// Reference: ISO/IEC 14496-12 §8.9.2.
///
/// `SampleToGroupTable` conforms to `RandomAccessCollection` and is backed
/// directly by the on-wire byte slice (`count * 8` bytes). Entries are
/// decoded on demand at O(1) cost per index. Round-trip re-emits the raw
/// bytes verbatim.
public struct SampleToGroupTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = SampleToGroupEntry

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> SampleToGroupEntry {
        precondition(
            position >= 0 && position < count,
            "SampleToGroupTable: index \(position) out of range 0..<\(count)"
        )
        let base = position * 8
        let sampleCount = rawEntries.readUInt32BigEndian(at: base)
        let index = rawEntries.readUInt32BigEndian(at: base + 4)
        return SampleToGroupEntry(sampleCount: sampleCount, groupDescriptionIndex: index)
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    public init(entries: [SampleToGroupEntry]) {
        var bytes = Data()
        bytes.reserveCapacity(entries.count * 8)
        for entry in entries {
            bytes.appendUInt32BigEndian(entry.sampleCount)
            bytes.appendUInt32BigEndian(entry.groupDescriptionIndex)
        }
        self.init(count: entries.count, rawEntries: bytes)
    }
}

extension SampleToGroupTable: LazyTableData {
    internal static var entryStride: Int { 8 }
}

/// Sample-to-group box.
///
/// Version 0 carries no `grouping_type_parameter`; version 1 adds one
/// after the `grouping_type` FourCC. The public initialiser enforces this
/// version ↔ parameter consistency.
public struct SampleToGroupBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "sbgp"

    public let version: UInt8
    public let flags: UInt32
    /// FourCC of the matching `sgpd` box.
    public let groupingType: FourCC
    /// Optional grouping-type parameter (version 1 only). `nil` for v0.
    public let groupingTypeParameter: UInt32?
    public let table: SampleToGroupTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        groupingType: FourCC,
        groupingTypeParameter: UInt32? = nil,
        table: SampleToGroupTable
    ) {
        precondition(
            (version == 1) == (groupingTypeParameter != nil),
            "SampleToGroupBox v1 requires groupingTypeParameter; v0 forbids it"
        )
        self.version = version
        self.flags = flags
        self.groupingType = groupingType
        self.groupingTypeParameter = groupingTypeParameter
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SampleToGroupBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let groupingType = try reader.readFourCC()
        var groupingTypeParameter: UInt32?
        if version == 1 {
            groupingTypeParameter = try reader.readUInt32()
        } else if version != 0 {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }
        let entryCount = try reader.readUInt32()
        let expectedBytes = Int(entryCount) * SampleToGroupTable.entryStride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = SampleToGroupTable(count: Int(entryCount), rawEntries: rawEntries)
        return SampleToGroupBox(
            version: version,
            flags: flags,
            groupingType: groupingType,
            groupingTypeParameter: groupingTypeParameter,
            table: table
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeFourCC(groupingType)
            if let param = groupingTypeParameter {
                body.writeUInt32(param)
            }
            body.writeUInt32(UInt32(table.count))
            body.writeData(table.rawEntries)
        }
    }
}

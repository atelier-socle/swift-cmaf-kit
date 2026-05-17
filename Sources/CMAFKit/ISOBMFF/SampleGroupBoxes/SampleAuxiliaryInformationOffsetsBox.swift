// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleAuxiliaryInformationOffsetsBox (saio)
//
// Reference: ISO/IEC 14496-12 §8.7.9 (sample auxiliary information offsets
// box).
//
// Locates per-sample auxiliary information inside the media data. Used
// jointly with ``SampleAuxiliaryInformationSizesBox`` to read that
// information. Version 0 stores 32-bit offsets; version 1 stores 64-bit
// offsets.

import Foundation

/// Lazy view over the file/segment-relative offsets to the auxiliary
/// information chunks.
///
/// Offsets are stored as 4 bytes per entry in version 0 and 8 bytes per
/// entry in version 1; ``stride`` reflects that. Subscript access returns
/// the value as a `UInt64` regardless of version.
public struct AuxInfoOffsetsTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data
    /// Box version (0 = 32-bit offsets, 1 = 64-bit offsets).
    public let version: UInt8

    public typealias Index = Int
    public typealias Element = UInt64

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    /// Per-entry byte stride. 4 for version 0, 8 for version 1.
    public var stride: Int { version == 1 ? 8 : 4 }

    public subscript(position: Int) -> UInt64 {
        precondition(
            position >= 0 && position < count,
            "AuxInfoOffsetsTable: index \(position) out of range 0..<\(count)"
        )
        let base = position * stride
        if version == 1 {
            return rawEntries.readUInt64BigEndian(at: base)
        }
        return UInt64(rawEntries.readUInt32BigEndian(at: base))
    }

    internal init(count: Int, rawEntries: Data, version: UInt8) {
        precondition(
            version == 0 || version == 1,
            "AuxInfoOffsetsTable: only versions 0 and 1 are supported"
        )
        self.count = count
        self.rawEntries = rawEntries
        self.version = version
    }

    /// Construct from an array of offsets. When ``version`` is 0, every
    /// offset must fit in a `UInt32`; values exceeding that range trigger
    /// a precondition failure.
    public init(offsets: [UInt64], version: UInt8 = 1) {
        precondition(
            version == 0 || version == 1,
            "AuxInfoOffsetsTable: only versions 0 and 1 are supported"
        )
        var bytes = Data()
        let entryStride = (version == 1) ? 8 : 4
        bytes.reserveCapacity(offsets.count * entryStride)
        for o in offsets {
            if version == 1 {
                bytes.appendUInt64BigEndian(o)
            } else {
                precondition(
                    o <= UInt64(UInt32.max),
                    "AuxInfoOffsetsTable v0: offset \(o) exceeds UInt32.max"
                )
                bytes.appendUInt32BigEndian(UInt32(o))
            }
        }
        self.init(count: offsets.count, rawEntries: bytes, version: version)
    }
}

/// Sample-auxiliary-information offsets box.
public struct SampleAuxiliaryInformationOffsetsBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "saio"

    /// Flag bit signalling presence of `aux_info_type` and
    /// `aux_info_type_parameter`.
    public static let flagInfoTypePresent: UInt32 = 0x000001

    public let version: UInt8
    public let flags: UInt32
    /// Auxiliary information type FourCC. Present iff
    /// ``flagInfoTypePresent`` is set in ``flags``.
    public let auxInfoType: FourCC?
    /// Auxiliary information type parameter. Present iff
    /// ``flagInfoTypePresent`` is set in ``flags``.
    public let auxInfoTypeParameter: UInt32?
    public let table: AuxInfoOffsetsTable

    public init(
        version: UInt8 = 1,
        flags: UInt32 = 0,
        auxInfoType: FourCC? = nil,
        auxInfoTypeParameter: UInt32? = nil,
        table: AuxInfoOffsetsTable
    ) {
        let infoTypePresent = (flags & Self.flagInfoTypePresent) != 0
        precondition(
            infoTypePresent == (auxInfoType != nil),
            "SampleAuxiliaryInformationOffsetsBox: auxInfoType presence must match flagInfoTypePresent"
        )
        precondition(
            infoTypePresent == (auxInfoTypeParameter != nil),
            "SampleAuxiliaryInformationOffsetsBox: auxInfoTypeParameter presence must match flagInfoTypePresent"
        )
        precondition(
            version == table.version,
            "SampleAuxiliaryInformationOffsetsBox: version must match its table's version"
        )
        self.version = version
        self.flags = flags
        self.auxInfoType = auxInfoType
        self.auxInfoTypeParameter = auxInfoTypeParameter
        self.table = table
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SampleAuxiliaryInformationOffsetsBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        if version != 0 && version != 1 {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }
        var auxInfoType: FourCC?
        var auxInfoTypeParameter: UInt32?
        if (flags & Self.flagInfoTypePresent) != 0 {
            auxInfoType = try reader.readFourCC()
            auxInfoTypeParameter = try reader.readUInt32()
        }
        let entryCount = try reader.readUInt32()
        let entryStride = (version == 1) ? 8 : 4
        let expectedBytes = Int(entryCount) * entryStride
        guard reader.remaining >= expectedBytes else {
            throw BinaryIOError.insufficientData(
                expected: expectedBytes,
                available: reader.remaining
            )
        }
        let rawEntries = try reader.readData(count: expectedBytes)
        let table = AuxInfoOffsetsTable(
            count: Int(entryCount),
            rawEntries: rawEntries,
            version: version
        )
        return SampleAuxiliaryInformationOffsetsBox(
            version: version,
            flags: flags,
            auxInfoType: auxInfoType,
            auxInfoTypeParameter: auxInfoTypeParameter,
            table: table
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            if let t = auxInfoType {
                body.writeFourCC(t)
            }
            if let p = auxInfoTypeParameter {
                body.writeUInt32(p)
            }
            body.writeUInt32(UInt32(table.count))
            body.writeData(table.rawEntries)
        }
    }
}

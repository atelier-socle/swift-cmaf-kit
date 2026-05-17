// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleAuxiliaryInformationSizesBox (saiz)
//
// Reference: ISO/IEC 14496-12 §8.7.8 (sample auxiliary information sizes
// box).
//
// Declares the size in bytes of the per-sample auxiliary information for
// a track or fragment. Used jointly with ``SampleAuxiliaryInformationOffsetsBox``
// to locate that information inside the media data.

import Foundation

/// Lazy view over the per-sample auxiliary information sizes.
///
/// `SampleInfoSizeTable` conforms to `RandomAccessCollection` and is
/// backed directly by the on-wire byte slice (one byte per sample).
public struct SampleInfoSizeTable: RandomAccessCollection, Sendable, Equatable {

    public let count: Int
    public let rawEntries: Data

    public typealias Index = Int
    public typealias Element = UInt8

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> UInt8 {
        precondition(
            position >= 0 && position < count,
            "SampleInfoSizeTable: index \(position) out of range 0..<\(count)"
        )
        return rawEntries.readUInt8(at: position)
    }

    internal init(count: Int, rawEntries: Data) {
        self.count = count
        self.rawEntries = rawEntries
    }

    public init(sizes: [UInt8]) {
        self.init(count: sizes.count, rawEntries: Data(sizes))
    }
}

extension SampleInfoSizeTable: LazyTableData {
    internal static var entryStride: Int { 1 }
}

/// Sample-auxiliary-information sizes box.
///
/// When ``constantSize`` is non-`nil`, every sample's auxiliary
/// information has that fixed size in bytes and ``perSampleSizes`` is
/// empty. When ``constantSize`` is `nil`, ``perSampleSizes`` carries one
/// byte per sample (size of that sample's auxiliary information) and its
/// ``count`` equals ``sampleCount``.
public struct SampleAuxiliaryInformationSizesBox: ISOFullBox, Sendable, Equatable {
    public static let boxType: FourCC = "saiz"

    /// Flag bit signalling presence of `aux_info_type` and
    /// `aux_info_type_parameter`.
    public static let flagInfoTypePresent: UInt32 = 0x000001

    public let version: UInt8
    public let flags: UInt32
    /// Auxiliary information type FourCC (e.g. `"cenc"` for CENC encryption).
    /// Present iff ``flagInfoTypePresent`` is set in ``flags``.
    public let auxInfoType: FourCC?
    /// Auxiliary information type parameter. Present iff
    /// ``flagInfoTypePresent`` is set in ``flags``.
    public let auxInfoTypeParameter: UInt32?
    /// Shared size for every sample's auxiliary information, when set.
    /// `nil` means each sample carries its own size in ``perSampleSizes``.
    public let constantSize: UInt8?
    /// Number of samples covered by this box. Independent of whether
    /// ``constantSize`` is set.
    public let sampleCount: UInt32
    /// Per-sample auxiliary information sizes. Empty when ``constantSize``
    /// is non-`nil`; otherwise carries exactly ``sampleCount`` bytes.
    public let perSampleSizes: SampleInfoSizeTable

    public init(
        version: UInt8 = 0,
        flags: UInt32 = 0,
        auxInfoType: FourCC? = nil,
        auxInfoTypeParameter: UInt32? = nil,
        constantSize: UInt8?,
        sampleCount: UInt32,
        perSampleSizes: SampleInfoSizeTable
    ) {
        let infoTypePresent = (flags & Self.flagInfoTypePresent) != 0
        precondition(
            infoTypePresent == (auxInfoType != nil),
            "SampleAuxiliaryInformationSizesBox: auxInfoType presence must match flagInfoTypePresent"
        )
        precondition(
            infoTypePresent == (auxInfoTypeParameter != nil),
            "SampleAuxiliaryInformationSizesBox: auxInfoTypeParameter presence must match flagInfoTypePresent"
        )
        if constantSize == nil {
            precondition(
                UInt32(perSampleSizes.count) == sampleCount,
                "SampleAuxiliaryInformationSizesBox: perSampleSizes count must equal sampleCount when constantSize is nil"
            )
        } else {
            precondition(
                perSampleSizes.count == 0,
                "SampleAuxiliaryInformationSizesBox: perSampleSizes must be empty when constantSize is non-nil"
            )
        }
        self.version = version
        self.flags = flags
        self.auxInfoType = auxInfoType
        self.auxInfoTypeParameter = auxInfoTypeParameter
        self.constantSize = constantSize
        self.sampleCount = sampleCount
        self.perSampleSizes = perSampleSizes
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SampleAuxiliaryInformationSizesBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        if version != 0 {
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }
        var auxInfoType: FourCC?
        var auxInfoTypeParameter: UInt32?
        if (flags & Self.flagInfoTypePresent) != 0 {
            auxInfoType = try reader.readFourCC()
            auxInfoTypeParameter = try reader.readUInt32()
        }
        let rawDefaultSize = try reader.readUInt8()
        let sampleCount = try reader.readUInt32()
        let constantSize: UInt8? = (rawDefaultSize == 0) ? nil : rawDefaultSize
        let perSampleSizes: SampleInfoSizeTable
        if constantSize == nil {
            let byteCount = Int(sampleCount)
            guard reader.remaining >= byteCount else {
                throw BinaryIOError.insufficientData(
                    expected: byteCount,
                    available: reader.remaining
                )
            }
            let raw = try reader.readData(count: byteCount)
            perSampleSizes = SampleInfoSizeTable(count: byteCount, rawEntries: raw)
        } else {
            perSampleSizes = SampleInfoSizeTable(count: 0, rawEntries: Data())
        }
        return SampleAuxiliaryInformationSizesBox(
            version: version,
            flags: flags,
            auxInfoType: auxInfoType,
            auxInfoTypeParameter: auxInfoTypeParameter,
            constantSize: constantSize,
            sampleCount: sampleCount,
            perSampleSizes: perSampleSizes
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
            body.writeUInt8(constantSize ?? 0)
            body.writeUInt32(sampleCount)
            if constantSize == nil {
                body.writeData(perSampleSizes.rawEntries)
            }
        }
    }
}

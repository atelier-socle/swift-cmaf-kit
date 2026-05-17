// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleGroupDescriptionBox (sgpd)
//
// Reference: ISO/IEC 14496-12 §8.9.3 (sample group description box).
//
// Holds one or more sample-group description entries for a given
// grouping_type. Each entry is parsed into a typed conformer of
// ``SampleGroupDescription`` when CMAFKit recognises the grouping_type;
// otherwise the entry is captured verbatim in
// ``RawSampleGroupDescription`` so the box round-trips losslessly.

import Foundation

/// Sample-group description box.
///
/// Version 1 stores an optional per-entry length prefix when
/// ``defaultLength`` is `0`; in that mode each entry's serialised size
/// may differ. Version 2 instead carries
/// ``defaultSampleDescriptionIndex`` and requires entries to share a
/// fixed implicit size determined by the `grouping_type`. New writers
/// default to version 2 because it is the form CMAF (ISO/IEC 23000-19)
/// recommends.
public struct SampleGroupDescriptionBox: ISOFullBox, Sendable {
    public static let boxType: FourCC = "sgpd"

    public let version: UInt8
    public let flags: UInt32
    /// The grouping type FourCC the entries apply to. Routes typed dispatch.
    public let groupingType: FourCC
    /// Version-1 only. `0` means each entry carries its own 4-byte
    /// length prefix; non-zero gives the common per-entry length in bytes.
    public let defaultLength: UInt32?
    /// Version-2 only. Index in the matching `sgpd` of the default entry
    /// for samples that are not mapped by any `sbgp` of this grouping
    /// type. `0` means "no default" (samples are unmapped).
    public let defaultSampleDescriptionIndex: UInt32?
    /// Parsed entries. Each element is either one of the typed conformers
    /// CMAFKit recognises for the matching ``groupingType``, or a
    /// ``RawSampleGroupDescription`` carrying the entry payload verbatim.
    public let entries: [any SampleGroupDescription]

    public init(
        version: UInt8 = 2,
        flags: UInt32 = 0,
        groupingType: FourCC,
        defaultLength: UInt32? = nil,
        defaultSampleDescriptionIndex: UInt32? = nil,
        entries: [any SampleGroupDescription]
    ) {
        precondition(
            version == 1 || version == 2,
            "SampleGroupDescriptionBox: only versions 1 and 2 are supported"
        )
        precondition(
            (version == 1) == (defaultLength != nil),
            "SampleGroupDescriptionBox v1 requires defaultLength; v2 forbids it"
        )
        precondition(
            (version == 2) == (defaultSampleDescriptionIndex != nil),
            "SampleGroupDescriptionBox v2 requires defaultSampleDescriptionIndex; v1 forbids it"
        )
        self.version = version
        self.flags = flags
        self.groupingType = groupingType
        self.defaultLength = defaultLength
        self.defaultSampleDescriptionIndex = defaultSampleDescriptionIndex
        self.entries = entries
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> SampleGroupDescriptionBox {
        let version = try reader.readUInt8()
        let flags = try reader.readUInt24()
        let groupingType = try reader.readFourCC()
        var defaultLength: UInt32?
        var defaultSampleDescriptionIndex: UInt32?
        switch version {
        case 1:
            defaultLength = try reader.readUInt32()
        case 2:
            defaultSampleDescriptionIndex = try reader.readUInt32()
        default:
            throw ISOBoxError.unsupportedVersion(type: Self.boxType, version: version)
        }
        let entryCount = try reader.readUInt32()

        // For v2 with an unknown grouping_type, all entries share an
        // implicit fixed size. The wire format does not carry it
        // explicitly, so derive it from (remaining body bytes) / count.
        let implicitV2EntrySize: Int? = {
            guard version == 2, entryCount > 0 else { return nil }
            let bytes = reader.remaining
            return bytes / Int(entryCount)
        }()

        var entries: [any SampleGroupDescription] = []
        entries.reserveCapacity(Int(entryCount))
        for _ in 0..<Int(entryCount) {
            // Determine the raw fallback byte budget for this entry.
            let rawByteBudget: Int? = try Self.rawByteBudget(
                version: version,
                defaultLength: defaultLength,
                implicitV2EntrySize: implicitV2EntrySize,
                reader: &reader
            )
            let entry = try Self.parseEntry(
                version: version,
                groupingType: groupingType,
                rawByteBudget: rawByteBudget,
                reader: &reader
            )
            entries.append(entry)
        }

        return SampleGroupDescriptionBox(
            version: version,
            flags: flags,
            groupingType: groupingType,
            defaultLength: defaultLength,
            defaultSampleDescriptionIndex: defaultSampleDescriptionIndex,
            entries: entries
        )
    }

    /// Dispatches to the typed conformer that matches `groupingType`, or
    /// falls back to ``RawSampleGroupDescription`` when the grouping type
    /// is unrecognised by CMAFKit.
    private static func parseEntry(
        version: UInt8,
        groupingType: FourCC,
        rawByteBudget: Int?,
        reader: inout BinaryReader
    ) throws -> any SampleGroupDescription {
        switch groupingType {
        case RollSampleGroupDescription.groupingType:
            return try RollSampleGroupDescription.parse(reader: &reader)
        case AudioPreRollSampleGroupDescription.groupingType:
            return try AudioPreRollSampleGroupDescription.parse(reader: &reader)
        case RandomAccessPointSampleGroupDescription.groupingType:
            return try RandomAccessPointSampleGroupDescription.parse(reader: &reader)
        case CENCSampleGroupDescription.groupingType:
            return try CENCSampleGroupDescription.parse(reader: &reader)
        default:
            // Invariant: rawByteBudget is non-nil here. The loop only
            // runs when entryCount > 0; in version 1 defaultLength is
            // always set on the wire (consumed unconditionally during
            // header parsing); in version 2 implicitV2EntrySize is
            // computed whenever entryCount > 0. A nil result at this
            // point would indicate a structural inconsistency in the
            // box body that must be surfaced rather than silently
            // producing an empty payload.
            guard let budget = rawByteBudget else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: """
                        Could not determine raw entry size for unknown \
                        grouping_type \(groupingType) at version \(version)
                        """
                )
            }
            let payload = try reader.readData(count: budget)
            return RawSampleGroupDescription(payload: payload)
        }
    }

    /// Computes the byte budget that a ``RawSampleGroupDescription`` may
    /// consume for the next entry. Returns `nil` only when the byte
    /// budget cannot be determined from the wire form (v2 unknown
    /// grouping_type with no entries to divide).
    private static func rawByteBudget(
        version: UInt8,
        defaultLength: UInt32?,
        implicitV2EntrySize: Int?,
        reader: inout BinaryReader
    ) throws -> Int? {
        if version == 1 {
            // v1: defaultLength == 0 means the per-entry description_length
            // prefix is present; otherwise defaultLength is the fixed budget.
            guard let dl = defaultLength else { return nil }
            if dl == 0 {
                return Int(try reader.readUInt32())
            }
            return Int(dl)
        }
        // v2: no on-wire length; use the implicit size derived from the
        // remaining bytes at the start of the entry list.
        return implicitV2EntrySize
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeFullBox(
            type: Self.boxType,
            version: version,
            flags: flags
        ) { body in
            body.writeFourCC(groupingType)
            if version == 1, let dl = defaultLength {
                body.writeUInt32(dl)
            } else if version == 2, let dsdi = defaultSampleDescriptionIndex {
                body.writeUInt32(dsdi)
            }
            body.writeUInt32(UInt32(entries.count))
            for entry in entries {
                if version == 1, let dl = defaultLength, dl == 0 {
                    // Each entry carries an explicit 4-byte length prefix.
                    var entryWriter = BinaryWriter()
                    entry.encode(to: &entryWriter)
                    let entryBytes = entryWriter.data
                    body.writeUInt32(UInt32(entryBytes.count))
                    body.writeData(entryBytes)
                } else {
                    entry.encode(to: &body)
                }
            }
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SampleEntry
//
// Reference: ISO/IEC 14496-12 §8.5.2.2 (sample entry).
//
// Every entry of a SampleDescriptionBox is a "sample entry": a box whose
// body begins with a 6-byte reserved area and a 2-byte data_reference_index,
// followed by codec-specific or media-specific fields. This file declares
// the SampleEntry protocol plus the RawSampleEntry fallback used when no
// typed parser is registered for an entry's FourCC.

import Foundation

/// A sample-table entry box.
///
/// Sample entries are the children of ``SampleDescriptionBox`` (`stsd`).
/// Each conformer represents either a codec's sample-entry layout (such as
/// `avc1`, `hvc1`, `mp4a`, `stpp`, `vp09`, `av01`) or the byte-perfect
/// fallback ``RawSampleEntry`` for FourCCs whose typed implementation is
/// not yet shipped.
///
/// Sample entries differ from ordinary ``ISOBox`` instances by the
/// presence of an 8-byte common preamble after the box header:
///   - 6 bytes reserved (must be zero on encode, ignored on decode);
///   - 2-byte ``dataReferenceIndex`` that indexes into the track's
///     `dref` entries.
///
/// Codec-specific conformers decode their payload after the preamble.
/// ``RawSampleEntry`` preserves the payload verbatim and is the documented,
/// permanent public surface for FourCCs CMAFKit does not natively type.
public protocol SampleEntry: ISOBox {
    /// 1-based index into the containing track's data reference table.
    var dataReferenceIndex: UInt16 { get }
}

/// Fallback sample-entry representation for FourCCs whose typed parser is
/// not registered.
///
/// ``RawSampleEntry`` preserves the entry's payload bytes verbatim and
/// therefore round-trips byte-for-byte. CMAFKit ships typed sample entries
/// for the codecs it supports natively; entries with other FourCCs
/// (proprietary, future, or out-of-scope codecs) are surfaced as
/// `RawSampleEntry` so that parse-then-encode never corrupts the file.
///
/// This type is part of the stable 0.1.0 public API and **remains
/// reachable** even as typed sample entries land for additional codecs.
/// Typed sample entries are additive; consumers may rely on
/// `RawSampleEntry` as the permanent fallback for any unrecognised codec
/// FourCC.
public struct RawSampleEntry: SampleEntry, Sendable, Equatable {
    /// Sentinel `boxType`. Instances carry their actual on-wire FourCC in
    /// ``format``; this constant is required by the ``ISOBox`` protocol
    /// but is not used at parse-time dispatch.
    public static let boxType: FourCC = FourCC(0)

    /// The on-wire FourCC of this entry (`avc1`, `hvc1`, `mp4a`, …).
    public let format: FourCC

    /// 1-based index into the track's data reference table.
    public let dataReferenceIndex: UInt16

    /// The codec-specific payload — everything after the 8-byte preamble.
    public let payload: Data

    public init(format: FourCC, dataReferenceIndex: UInt16, payload: Data) {
        self.format = format
        self.dataReferenceIndex = dataReferenceIndex
        self.payload = payload
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: format) { body in
            body.writeZeros(6)  // reserved
            body.writeUInt16(dataReferenceIndex)
            body.writeData(payload)
        }
    }

    /// Parse a `RawSampleEntry` from a reader positioned at the start of
    /// the entry body (after the box header).
    internal static func parse(
        format: FourCC,
        reader: inout BinaryReader
    ) throws -> RawSampleEntry {
        try reader.skip(6)  // reserved
        let dataReferenceIndex = try reader.readUInt16()
        let payload = reader.readToEnd()
        return RawSampleEntry(
            format: format,
            dataReferenceIndex: dataReferenceIndex,
            payload: payload
        )
    }
}

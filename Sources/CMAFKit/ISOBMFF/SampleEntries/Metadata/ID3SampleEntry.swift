// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ID3SampleEntry (id3 )
//
// Reference: ISO/IEC 14496-12 §8.5.2.1 (TextMetaDataSampleEntry
// pattern reused) and the HLS-adopted convention of using the
// FourCC `i d 3 0x20` (with trailing ASCII space) for ID3v2-in-CMAF
// metadata tracks.
//
// The on-wire layout mirrors `mett`: two null-terminated UTF-8
// strings (`content_encoding`, `mime_format`) and an optional `btrt`.

import Foundation

/// ID3 timed-metadata sample entry (`id3 `, with trailing space) per
/// the HLS-adopted convention.
public struct ID3SampleEntry: SampleEntry, Sendable, Equatable, Hashable {
    /// The on-wire FourCC `i d 3 0x20` (ASCII `"id3 "` with a
    /// trailing space). Encoding the trailing space is mandatory.
    public static let boxType: FourCC = "id3 "

    public let dataReferenceIndex: UInt16
    /// `content_encoding` — typically the empty string for raw
    /// ID3v2 payloads.
    public let contentEncoding: String
    /// `mime_format` — typically `"application/x-id3"`.
    public let mimeFormat: String
    /// Optional bit-rate hint.
    public let bitRate: BitRateBox?

    public init(
        dataReferenceIndex: UInt16 = 1,
        contentEncoding: String = "",
        mimeFormat: String = "application/x-id3",
        bitRate: BitRateBox? = nil
    ) {
        self.dataReferenceIndex = dataReferenceIndex
        self.contentEncoding = contentEncoding
        self.mimeFormat = mimeFormat
        self.bitRate = bitRate
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> ID3SampleEntry {
        try reader.skip(6)  // reserved
        let dataRefIdx = try reader.readUInt16()
        let contentEncoding = try reader.readNullTerminatedString()
        let mimeFormat = try reader.readNullTerminatedString()

        var bitRate: BitRateBox?
        let isoBoxReader = ISOBoxReader()
        while reader.remaining >= 8 {
            let childHeader = try isoBoxReader.parseBoxHeader(&reader)
            switch childHeader.type {
            case BitRateBox.boxType:
                bitRate = try await BitRateBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            default:
                _ = try ISOBoxOpaque.parse(reader: &reader)
            }
        }
        return ID3SampleEntry(
            dataReferenceIndex: dataRefIdx,
            contentEncoding: contentEncoding,
            mimeFormat: mimeFormat,
            bitRate: bitRate
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeZeros(6)  // reserved
            body.writeUInt16(dataReferenceIndex)
            body.writeNullTerminatedString(contentEncoding)
            body.writeNullTerminatedString(mimeFormat)
            bitRate?.encode(to: &body)
        }
    }
}

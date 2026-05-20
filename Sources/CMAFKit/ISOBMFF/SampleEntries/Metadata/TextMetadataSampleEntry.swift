// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TextMetadataSampleEntry (mett)
//
// Reference: ISO/IEC 14496-12 §8.5.2.1 (TextMetaDataSampleEntry).
//
// Plain sample entry carrying two null-terminated UTF-8 strings —
// `content_encoding` and `mime_format` — followed by an optional
// `btrt` (BitRateBox).

import Foundation

/// Text metadata sample entry (`mett`) per ISO/IEC 14496-12 §8.5.2.1.
public struct TextMetadataSampleEntry: SampleEntry, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "mett"

    public let dataReferenceIndex: UInt16
    /// `content_encoding` — e.g., `"gzip"` for gzipped payloads or
    /// the empty string when the bytes are raw.
    public let contentEncoding: String
    /// `mime_format` — e.g., `"application/x-id3"`, `"text/plain"`.
    public let mimeFormat: String
    /// Optional bit-rate hint.
    public let bitRate: BitRateBox?

    public init(
        dataReferenceIndex: UInt16 = 1,
        contentEncoding: String = "",
        mimeFormat: String,
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
    ) async throws -> TextMetadataSampleEntry {
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
        return TextMetadataSampleEntry(
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

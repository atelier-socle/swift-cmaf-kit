// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - XMLSubtitleSampleEntry (stpp)
//
// Reference: ISO/IEC 14496-30 §7.4 (XML subtitle in ISO Base Media
// File Format). The `stpp` sample entry carries XML-formatted
// subtitle samples — typically IMSC1 TTML2 text or image profile per
// W3C TTML2 IMSC1.
//
// Layout (after the 8-byte preamble):
//   - namespace: null-terminated UTF-8 string
//   - schema_location: null-terminated UTF-8 string
//   - auxiliary_mime_types: null-terminated UTF-8 string
//   - optional BitRateBox (`btrt`) child

import Foundation

/// XML-based subtitle sample entry (`stpp`) per ISO/IEC 14496-30 §7.4.
public struct XMLSubtitleSampleEntry: SampleEntry, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "stpp"

    public let dataReferenceIndex: UInt16
    /// XML namespace (TTML2 / IMSC1 typically uses
    /// `"http://www.w3.org/ns/ttml"`).
    public let namespace: String
    /// Schema-location string. May be empty.
    public let schemaLocation: String
    /// Auxiliary MIME types — comma-separated MIME identifiers
    /// (e.g., `"image/png"` for IMSC1 image profile).
    public let auxiliaryMIMETypes: String
    /// Optional bit-rate hint.
    public let bitRate: BitRateBox?

    public init(
        dataReferenceIndex: UInt16 = 1,
        namespace: String,
        schemaLocation: String = "",
        auxiliaryMIMETypes: String = "",
        bitRate: BitRateBox? = nil
    ) {
        self.dataReferenceIndex = dataReferenceIndex
        self.namespace = namespace
        self.schemaLocation = schemaLocation
        self.auxiliaryMIMETypes = auxiliaryMIMETypes
        self.bitRate = bitRate
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> XMLSubtitleSampleEntry {
        try reader.skip(6)  // reserved
        let dataRefIdx = try reader.readUInt16()
        let namespace = try reader.readNullTerminatedString()
        let schemaLocation = try reader.readNullTerminatedString()
        let auxiliaryMIMETypes = try reader.readNullTerminatedString()

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
        return XMLSubtitleSampleEntry(
            dataReferenceIndex: dataRefIdx,
            namespace: namespace,
            schemaLocation: schemaLocation,
            auxiliaryMIMETypes: auxiliaryMIMETypes,
            bitRate: bitRate
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeZeros(6)  // reserved
            body.writeUInt16(dataReferenceIndex)
            body.writeNullTerminatedString(namespace)
            body.writeNullTerminatedString(schemaLocation)
            body.writeNullTerminatedString(auxiliaryMIMETypes)
            bitRate?.encode(to: &body)
        }
    }
}

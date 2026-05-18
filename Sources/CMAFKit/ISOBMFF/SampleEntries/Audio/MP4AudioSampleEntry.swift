// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MP4AudioSampleEntry (mp4a)
//
// Reference: ISO/IEC 14496-14 §5.6 (MPEG-4 audio sample entry) +
// ISO/IEC 14496-1 §8.6.6 (ES descriptor in MP4 file format).

import Foundation

/// MPEG-4 audio sample entry (`mp4a`).
public struct MP4AudioSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "mp4a"

    public let audioFields: AudioSampleEntryFields
    public let elementaryStreamDescriptor: ElementaryStreamDescriptor
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        elementaryStreamDescriptor: ElementaryStreamDescriptor,
        extensions: AudioSampleEntryExtensions = AudioSampleEntryExtensions()
    ) {
        self.audioFields = audioFields
        self.elementaryStreamDescriptor = elementaryStreamDescriptor
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MP4AudioSampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let esdsHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard esdsHeader.type == ElementaryStreamDescriptor.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Expected esds child, got \(esdsHeader.type)"
            )
        }
        let esds = try await ElementaryStreamDescriptor.parse(
            reader: &reader, header: esdsHeader, registry: registry
        )
        let (exts, _) = try await AudioSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return MP4AudioSampleEntry(
            audioFields: fields,
            elementaryStreamDescriptor: esds,
            extensions: exts
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            audioFields.encode(to: &body)
            elementaryStreamDescriptor.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MP4VisualSampleEntry (mp4v)
//
// Reference: ISO/IEC 14496-14 §5.6 + ISO/IEC 14496-1 §8.6.6 (ES
// descriptor in MP4 file format).

import Foundation

/// MPEG-4 Visual sample entry carrying an `esds` configuration child.
public struct MP4VisualSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "mp4v"

    public let visualFields: VisualSampleEntryFields
    public let elementaryStreamDescriptor: ElementaryStreamDescriptor
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        elementaryStreamDescriptor: ElementaryStreamDescriptor,
        extensions: VideoSampleEntryExtensions = VideoSampleEntryExtensions()
    ) {
        self.visualFields = visualFields
        self.elementaryStreamDescriptor = elementaryStreamDescriptor
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MP4VisualSampleEntry {
        let fields = try VisualSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == ElementaryStreamDescriptor.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Expected esds child, got \(configHeader.type)"
            )
        }
        let esds = try await ElementaryStreamDescriptor.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        let (exts, _) = try await VideoSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return MP4VisualSampleEntry(
            visualFields: fields,
            elementaryStreamDescriptor: esds,
            extensions: exts
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            visualFields.encode(to: &body)
            elementaryStreamDescriptor.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

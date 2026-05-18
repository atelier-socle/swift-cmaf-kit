// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AV1SampleEntry (av01)
//
// Reference: AOMedia AV1 ISO Media File Format Binding v1.2.0 §2.2.

import Foundation

/// AV1 sample entry (`av01`).
public struct AV1SampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "av01"

    public let visualFields: VisualSampleEntryFields
    public let configuration: AV1CodecConfigurationRecord
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        configuration: AV1CodecConfigurationRecord,
        extensions: VideoSampleEntryExtensions = VideoSampleEntryExtensions()
    ) {
        self.visualFields = visualFields
        self.configuration = configuration
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> AV1SampleEntry {
        let fields = try VisualSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == AV1CodecConfigurationRecord.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Expected av1C child, got \(configHeader.type)"
            )
        }
        // av1C body length is variable (configOBUs runs to the end of
        // the box); slice the reader to honour the declared box size so
        // the av1C parser does not over-read into the extensions tail.
        let configBodySize = Int(configHeader.size) - configHeader.headerSize
        let configBytes = try reader.readData(count: configBodySize)
        var configReader = BinaryReader(configBytes)
        let config = try await AV1CodecConfigurationRecord.parse(
            reader: &configReader, header: configHeader, registry: registry
        )
        let (exts, _) = try await VideoSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return AV1SampleEntry(
            visualFields: fields,
            configuration: config,
            extensions: exts
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            visualFields.encode(to: &body)
            configuration.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

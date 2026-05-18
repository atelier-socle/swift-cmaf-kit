// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - VP8SampleEntry (vp08) + VP9SampleEntry (vp09)
//
// Reference: VP Codec ISO Media File Format Binding v1.0.

import Foundation

/// VP8 sample entry (`vp08`).
public struct VP8SampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "vp08"

    public let visualFields: VisualSampleEntryFields
    public let configuration: VPCodecConfigurationRecord
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        configuration: VPCodecConfigurationRecord,
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
    ) async throws -> VP8SampleEntry {
        let (fields, config, exts) = try await VPSampleEntryParsing.parse(
            reader: &reader,
            header: header,
            registry: registry,
            boxType: Self.boxType
        )
        return VP8SampleEntry(
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

/// VP9 sample entry (`vp09`).
public struct VP9SampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "vp09"

    public let visualFields: VisualSampleEntryFields
    public let configuration: VPCodecConfigurationRecord
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        configuration: VPCodecConfigurationRecord,
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
    ) async throws -> VP9SampleEntry {
        let (fields, config, exts) = try await VPSampleEntryParsing.parse(
            reader: &reader,
            header: header,
            registry: registry,
            boxType: Self.boxType
        )
        return VP9SampleEntry(
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

internal enum VPSampleEntryParsing {
    static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry,
        boxType: FourCC
    ) async throws -> (
        VisualSampleEntryFields,
        VPCodecConfigurationRecord,
        VideoSampleEntryExtensions
    ) {
        let fields = try VisualSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == VPCodecConfigurationRecord.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: boxType,
                reason: "Expected vpcC child, got \(configHeader.type)"
            )
        }
        let config = try await VPCodecConfigurationRecord.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        let (exts, _) = try await VideoSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return (fields, config, exts)
    }
}

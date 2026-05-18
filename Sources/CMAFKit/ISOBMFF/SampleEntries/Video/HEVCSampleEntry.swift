// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCSampleEntry (hvc1) + HEVCSampleEntryInband (hev1)
//
// Reference: ISO/IEC 14496-15 §8.4.1 (HEVC sample entry).
//
// `hvc1` carries an HEVC stream whose parameter sets reside only in the
// `hvcC` configuration record. `hev1` permits the same parameter sets to
// be repeated inband at random-access points within the sample data.
// The two FourCCs share the same wire layout.

import Foundation

/// HEVC sample entry with parameter sets in the configuration record only.
public struct HEVCSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "hvc1"

    public let visualFields: VisualSampleEntryFields
    public let configuration: HEVCDecoderConfigurationRecord
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        configuration: HEVCDecoderConfigurationRecord,
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
    ) async throws -> HEVCSampleEntry {
        let (fields, config, exts) = try await HEVCSampleEntryParsing.parse(
            reader: &reader,
            header: header,
            registry: registry,
            boxType: Self.boxType
        )
        return HEVCSampleEntry(
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

/// HEVC sample entry with inband-permitted parameter sets (`hev1`).
public struct HEVCSampleEntryInband: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "hev1"

    public let visualFields: VisualSampleEntryFields
    public let configuration: HEVCDecoderConfigurationRecord
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        configuration: HEVCDecoderConfigurationRecord,
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
    ) async throws -> HEVCSampleEntryInband {
        let (fields, config, exts) = try await HEVCSampleEntryParsing.parse(
            reader: &reader,
            header: header,
            registry: registry,
            boxType: Self.boxType
        )
        return HEVCSampleEntryInband(
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

internal enum HEVCSampleEntryParsing {
    static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry,
        boxType: FourCC
    ) async throws -> (
        VisualSampleEntryFields,
        HEVCDecoderConfigurationRecord,
        VideoSampleEntryExtensions
    ) {
        let fields = try VisualSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == HEVCDecoderConfigurationRecord.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: boxType,
                reason: "Expected hvcC child, got \(configHeader.type)"
            )
        }
        let config = try await HEVCDecoderConfigurationRecord.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        let (exts, _) = try await VideoSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return (fields, config, exts)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCSampleEntry (avc1) + AVCSampleEntryInband (avc3)
//
// Reference: ISO/IEC 14496-15 §5.3.4 (AVC sample entry).
//
// The `avc1` sample entry contains an inband-parameter-set-prohibited AVC
// stream whose SPS/PPS reside in the `avcC` configuration record. The
// `avc3` variant permits the same parameter sets to be repeated inband
// at IDR or random-access points within the sample data. The two FourCCs
// share an identical wire layout (78-byte VisualSampleEntry prefix plus
// the same `avcC` configuration plus the optional extension boxes).

import Foundation

/// AVC sample entry with parameter sets in the configuration record only.
public struct AVCSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "avc1"

    public let visualFields: VisualSampleEntryFields
    public let configuration: AVCDecoderConfigurationRecord
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        configuration: AVCDecoderConfigurationRecord,
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
    ) async throws -> AVCSampleEntry {
        let (fields, config, exts) = try await AVCSampleEntryParsing.parse(
            reader: &reader,
            header: header,
            registry: registry,
            boxType: Self.boxType
        )
        return AVCSampleEntry(
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

/// AVC sample entry with inband-permitted parameter sets at random-access
/// points (`avc3`). Wire layout matches ``AVCSampleEntry`` except for the
/// FourCC.
public struct AVCSampleEntryInband: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "avc3"

    public let visualFields: VisualSampleEntryFields
    public let configuration: AVCDecoderConfigurationRecord
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        configuration: AVCDecoderConfigurationRecord,
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
    ) async throws -> AVCSampleEntryInband {
        let (fields, config, exts) = try await AVCSampleEntryParsing.parse(
            reader: &reader,
            header: header,
            registry: registry,
            boxType: Self.boxType
        )
        return AVCSampleEntryInband(
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

/// Shared parse helper for `avc1` and `avc3`.
internal enum AVCSampleEntryParsing {
    static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry,
        boxType: FourCC
    ) async throws -> (
        VisualSampleEntryFields,
        AVCDecoderConfigurationRecord,
        VideoSampleEntryExtensions
    ) {
        let fields = try VisualSampleEntryFields.parse(reader: &reader)
        // The avcC configuration record is a normal child box.
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == AVCDecoderConfigurationRecord.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: boxType,
                reason: "Expected avcC child, got \(configHeader.type)"
            )
        }
        let config = try await AVCDecoderConfigurationRecord.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        let (exts, _) = try await VideoSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return (fields, config, exts)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DolbyVisionHEVCSampleEntry (dvh1) +
//         DolbyVisionHEVCSampleEntryInband (dvhe)
//
// Reference: Dolby Vision Streams Within the ISO Base Media File Format
// (Dolby public specification), section "Sample Entry".
//
// A Dolby Vision sample entry over HEVC is structurally identical to its
// underlying codec sample entry but uses a Dolby-Vision-specific FourCC.
// It carries an HEVC `hvcC` configuration record plus a mandatory `dvcC`
// (base Dolby Vision configuration) and an optional `dvvC` (enhancement-
// layer configuration, present for dual-layer profile 7).

import Foundation

/// Dolby Vision HEVC sample entry with parameter sets in the
/// configuration record only.
public struct DolbyVisionHEVCSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "dvh1"

    public let visualFields: VisualSampleEntryFields
    public let hevcConfiguration: HEVCDecoderConfigurationRecord
    public let dolbyVisionConfiguration: DolbyVisionConfiguration
    public let dolbyVisionELConfiguration: DolbyVisionELConfiguration?
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        hevcConfiguration: HEVCDecoderConfigurationRecord,
        dolbyVisionConfiguration: DolbyVisionConfiguration,
        dolbyVisionELConfiguration: DolbyVisionELConfiguration? = nil,
        extensions: VideoSampleEntryExtensions = VideoSampleEntryExtensions()
    ) {
        self.visualFields = visualFields
        self.hevcConfiguration = hevcConfiguration
        self.dolbyVisionConfiguration = dolbyVisionConfiguration
        self.dolbyVisionELConfiguration = dolbyVisionELConfiguration
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> DolbyVisionHEVCSampleEntry {
        let parsed = try await DolbyVisionHEVCSampleEntryParsing.parse(
            reader: &reader,
            header: header,
            registry: registry,
            boxType: Self.boxType
        )
        return DolbyVisionHEVCSampleEntry(
            visualFields: parsed.fields,
            hevcConfiguration: parsed.hevcConfig,
            dolbyVisionConfiguration: parsed.dvConfig,
            dolbyVisionELConfiguration: parsed.dvELConfig,
            extensions: parsed.extensions
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            visualFields.encode(to: &body)
            hevcConfiguration.encode(to: &body)
            DolbyVisionConfigurationBox(configuration: dolbyVisionConfiguration)
                .encode(to: &body)
            if let elConfig = dolbyVisionELConfiguration {
                DolbyVisionELConfigurationBox(elConfiguration: elConfig)
                    .encode(to: &body)
            }
            extensions.encode(to: &body)
        }
    }
}

/// Dolby Vision HEVC sample entry with inband-permitted parameter sets.
public struct DolbyVisionHEVCSampleEntryInband: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "dvhe"

    public let visualFields: VisualSampleEntryFields
    public let hevcConfiguration: HEVCDecoderConfigurationRecord
    public let dolbyVisionConfiguration: DolbyVisionConfiguration
    public let dolbyVisionELConfiguration: DolbyVisionELConfiguration?
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        hevcConfiguration: HEVCDecoderConfigurationRecord,
        dolbyVisionConfiguration: DolbyVisionConfiguration,
        dolbyVisionELConfiguration: DolbyVisionELConfiguration? = nil,
        extensions: VideoSampleEntryExtensions = VideoSampleEntryExtensions()
    ) {
        self.visualFields = visualFields
        self.hevcConfiguration = hevcConfiguration
        self.dolbyVisionConfiguration = dolbyVisionConfiguration
        self.dolbyVisionELConfiguration = dolbyVisionELConfiguration
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> DolbyVisionHEVCSampleEntryInband {
        let parsed = try await DolbyVisionHEVCSampleEntryParsing.parse(
            reader: &reader,
            header: header,
            registry: registry,
            boxType: Self.boxType
        )
        return DolbyVisionHEVCSampleEntryInband(
            visualFields: parsed.fields,
            hevcConfiguration: parsed.hevcConfig,
            dolbyVisionConfiguration: parsed.dvConfig,
            dolbyVisionELConfiguration: parsed.dvELConfig,
            extensions: parsed.extensions
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            visualFields.encode(to: &body)
            hevcConfiguration.encode(to: &body)
            DolbyVisionConfigurationBox(configuration: dolbyVisionConfiguration)
                .encode(to: &body)
            if let elConfig = dolbyVisionELConfiguration {
                DolbyVisionELConfigurationBox(elConfiguration: elConfig)
                    .encode(to: &body)
            }
            extensions.encode(to: &body)
        }
    }
}

internal struct DolbyVisionHEVCSampleEntryParsedBody {
    let fields: VisualSampleEntryFields
    let hevcConfig: HEVCDecoderConfigurationRecord
    let dvConfig: DolbyVisionConfiguration
    let dvELConfig: DolbyVisionELConfiguration?
    let extensions: VideoSampleEntryExtensions
}

internal enum DolbyVisionHEVCSampleEntryParsing {
    static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry,
        boxType: FourCC
    ) async throws -> DolbyVisionHEVCSampleEntryParsedBody {
        let fields = try VisualSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let hevcHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard hevcHeader.type == HEVCDecoderConfigurationRecord.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: boxType,
                reason: "Expected hvcC child, got \(hevcHeader.type)"
            )
        }
        let hevcConfig = try await HEVCDecoderConfigurationRecord.parse(
            reader: &reader, header: hevcHeader, registry: registry
        )

        // Parse the extensions tail; dvcC/dvvC live inside the typed
        // extensions container.
        let (exts, _) = try await VideoSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )

        guard let dvBox = exts.dolbyVisionConfiguration else {
            throw ISOBoxError.malformedFullBox(
                type: boxType,
                reason: "Dolby Vision sample entry missing mandatory dvcC"
            )
        }

        // Reconstitute extensions without the Dolby Vision boxes; they
        // are surfaced as first-class fields on the sample entry.
        let strippedExts = VideoSampleEntryExtensions(
            colorInformation: exts.colorInformation,
            masteringDisplay: exts.masteringDisplay,
            contentLightLevel: exts.contentLightLevel,
            dolbyVisionConfiguration: nil,
            dolbyVisionELConfiguration: nil,
            pixelAspectRatio: exts.pixelAspectRatio,
            cleanAperture: exts.cleanAperture,
            bitRate: exts.bitRate
        )

        return DolbyVisionHEVCSampleEntryParsedBody(
            fields: fields,
            hevcConfig: hevcConfig,
            dvConfig: dvBox.configuration,
            dvELConfig: exts.dolbyVisionELConfiguration?.elConfiguration,
            extensions: strippedExts
        )
    }
}

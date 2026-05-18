// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MPEGHAudioSampleEntry (mhm1) + MPEGHAudioSampleEntryMultiStream (mhm2)
//
// Reference: ISO/IEC 23008-3 §20.
//
// `mhm1` and `mhm2` share the same wire layout; the FourCC distinguishes
// the streaming mode: single MPEG-H stream vs. multi-stream.

import Foundation

/// MPEG-H 3D Audio sample entry, single stream (`mhm1`).
public struct MPEGHAudioSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "mhm1"

    public let audioFields: AudioSampleEntryFields
    public let configuration: MPEGHConfigurationBox
    public let compatibilitySet: MPEGHProfileLevelCompatibilitySetBox?
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        configuration: MPEGHConfigurationBox,
        compatibilitySet: MPEGHProfileLevelCompatibilitySetBox? = nil,
        extensions: AudioSampleEntryExtensions = AudioSampleEntryExtensions()
    ) {
        self.audioFields = audioFields
        self.configuration = configuration
        self.compatibilitySet = compatibilitySet
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MPEGHAudioSampleEntry {
        let parsed = try await MPEGHParsing.parseBody(
            reader: &reader,
            header: header,
            registry: registry,
            boxType: Self.boxType
        )
        return MPEGHAudioSampleEntry(
            audioFields: parsed.fields,
            configuration: parsed.configuration,
            compatibilitySet: parsed.compatibilitySet,
            extensions: parsed.extensions
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            audioFields.encode(to: &body)
            configuration.encode(to: &body)
            compatibilitySet?.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

/// MPEG-H 3D Audio sample entry, multi-stream (`mhm2`).
public struct MPEGHAudioSampleEntryMultiStream: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "mhm2"

    public let audioFields: AudioSampleEntryFields
    public let configuration: MPEGHConfigurationBox
    public let compatibilitySet: MPEGHProfileLevelCompatibilitySetBox?
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        configuration: MPEGHConfigurationBox,
        compatibilitySet: MPEGHProfileLevelCompatibilitySetBox? = nil,
        extensions: AudioSampleEntryExtensions = AudioSampleEntryExtensions()
    ) {
        self.audioFields = audioFields
        self.configuration = configuration
        self.compatibilitySet = compatibilitySet
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MPEGHAudioSampleEntryMultiStream {
        let parsed = try await MPEGHParsing.parseBody(
            reader: &reader,
            header: header,
            registry: registry,
            boxType: Self.boxType
        )
        return MPEGHAudioSampleEntryMultiStream(
            audioFields: parsed.fields,
            configuration: parsed.configuration,
            compatibilitySet: parsed.compatibilitySet,
            extensions: parsed.extensions
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            audioFields.encode(to: &body)
            configuration.encode(to: &body)
            compatibilitySet?.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

/// Parsed MPEG-H sample-entry body shared by `mhm1` and `mhm2`.
internal struct MPEGHParsedBody {
    let fields: AudioSampleEntryFields
    let configuration: MPEGHConfigurationBox
    let compatibilitySet: MPEGHProfileLevelCompatibilitySetBox?
    let extensions: AudioSampleEntryExtensions
}

internal enum MPEGHParsing {
    static func parseBody(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry,
        boxType: FourCC
    ) async throws -> MPEGHParsedBody {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == MPEGHConfigurationBox.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: boxType,
                reason: "Expected mhaC child, got \(configHeader.type)"
            )
        }
        let configuration = try await MPEGHConfigurationBox.parse(
            reader: &reader, header: configHeader, registry: registry
        )

        var compatibilitySet: MPEGHProfileLevelCompatibilitySetBox?
        if reader.remaining >= 8 {
            var peek = reader
            let nextHeader = try isoBoxReader.parseBoxHeader(&peek)
            if nextHeader.type == MPEGHProfileLevelCompatibilitySetBox.boxType {
                _ = try isoBoxReader.parseBoxHeader(&reader)
                compatibilitySet = try await MPEGHProfileLevelCompatibilitySetBox.parse(
                    reader: &reader, header: nextHeader, registry: registry
                )
            }
        }

        let (exts, _) = try await AudioSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return MPEGHParsedBody(
            fields: fields,
            configuration: configuration,
            compatibilitySet: compatibilitySet,
            extensions: exts
        )
    }
}

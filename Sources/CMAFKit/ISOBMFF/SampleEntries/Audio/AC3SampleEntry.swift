// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AC3SampleEntry (ac-3) + EC3SampleEntry (ec-3)
//
// Reference: ETSI TS 102 366 Annex F.4 (`ac-3`) + Annex F.6 (`ec-3`).

import Foundation

/// AC-3 audio sample entry (`ac-3`).
public struct AC3SampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "ac-3"

    public let audioFields: AudioSampleEntryFields
    public let specificBox: AC3SpecificBox
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        specificBox: AC3SpecificBox,
        extensions: AudioSampleEntryExtensions = AudioSampleEntryExtensions()
    ) {
        self.audioFields = audioFields
        self.specificBox = specificBox
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> AC3SampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == AC3SpecificBox.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Expected dac3 child, got \(configHeader.type)"
            )
        }
        let specific = try await AC3SpecificBox.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        let (exts, _) = try await AudioSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return AC3SampleEntry(
            audioFields: fields,
            specificBox: specific,
            extensions: exts
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            audioFields.encode(to: &body)
            specificBox.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

/// E-AC-3 audio sample entry (`ec-3`).
public struct EC3SampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "ec-3"

    public let audioFields: AudioSampleEntryFields
    public let specificBox: EC3SpecificBox
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        specificBox: EC3SpecificBox,
        extensions: AudioSampleEntryExtensions = AudioSampleEntryExtensions()
    ) {
        self.audioFields = audioFields
        self.specificBox = specificBox
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> EC3SampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == EC3SpecificBox.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Expected dec3 child, got \(configHeader.type)"
            )
        }
        let specific = try await EC3SpecificBox.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        let (exts, _) = try await AudioSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return EC3SampleEntry(
            audioFields: fields,
            specificBox: specific,
            extensions: exts
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            audioFields.encode(to: &body)
            specificBox.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

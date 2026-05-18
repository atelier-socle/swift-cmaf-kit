// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AC4SampleEntry (ac-4)
//
// Reference: ETSI TS 103 190-1 Annex E.

import Foundation

/// AC-4 audio sample entry (`ac-4`).
public struct AC4SampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "ac-4"

    public let audioFields: AudioSampleEntryFields
    public let specificBox: AC4SpecificBox
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        specificBox: AC4SpecificBox,
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
    ) async throws -> AC4SampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == AC4SpecificBox.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Expected dac4 child, got \(configHeader.type)"
            )
        }
        let specific = try await AC4SpecificBox.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        let (exts, _) = try await AudioSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return AC4SampleEntry(
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

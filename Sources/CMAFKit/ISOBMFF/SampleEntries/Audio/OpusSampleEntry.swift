// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - OpusSampleEntry (Opus)
//
// Reference: IETF "Encapsulation of Opus in ISO Base Media File Format"
// v1.0.0 §4.3.

import Foundation

/// Opus audio sample entry (`Opus`).
public struct OpusSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "Opus"

    public let audioFields: AudioSampleEntryFields
    public let specificBox: OpusSpecificBox
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        specificBox: OpusSpecificBox,
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
    ) async throws -> OpusSampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == OpusSpecificBox.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Expected dOps child, got \(configHeader.type)"
            )
        }
        let specific = try await OpusSpecificBox.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        let (exts, _) = try await AudioSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return OpusSampleEntry(
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

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FLACSampleEntry (fLaC)
//
// Reference: Xiph "Encapsulation of FLAC in ISO Base Media File Format".

import Foundation

/// FLAC audio sample entry (`fLaC`).
public struct FLACSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "fLaC"

    public let audioFields: AudioSampleEntryFields
    public let specificBox: FLACSpecificBox
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        specificBox: FLACSpecificBox,
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
    ) async throws -> FLACSampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == FLACSpecificBox.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Expected dfLa child, got \(configHeader.type)"
            )
        }
        let specific = try await FLACSpecificBox.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        let (exts, _) = try await AudioSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return FLACSampleEntry(
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

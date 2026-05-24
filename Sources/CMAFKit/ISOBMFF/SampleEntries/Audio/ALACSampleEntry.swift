// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ALACSampleEntry (alac)
//
// References:
// - Apple ALAC public specification (open-sourced 2011)
// - ISO/IEC 14496-12 §12.2 — Audio Sample Entry
// - Apple QuickTime File Format Specification — `alac` historical
//
// fourCC collision: the sample entry fourCC is `alac` AND the child
// config box fourCC is also `alac`. The collision is resolved by
// NOT registering `ALACSpecificBox` at the global registry level —
// `ALACSampleEntry.parse` reads the inner `alac` box manually
// (mirroring `FLACSampleEntry.parse` which reads its `dfLa` child
// manually).

import Foundation

/// Apple Lossless Audio Codec sample entry (`alac`).
///
/// Wraps the standard ``AudioSampleEntryFields`` (reused from v0.1.0)
/// + the Apple ``ALACSpecificBox`` magic-cookie child + the standard
/// ``AudioSampleEntryExtensions`` (`chnl` / `srat` / `btrt`).
///
/// References:
/// - Apple ALAC public specification
/// - ISO/IEC 14496-12 §12.2 — Audio Sample Entry
/// - Apple QuickTime File Format Specification
public struct ALACSampleEntry: ISOBox, Sendable, Equatable, Hashable {

    public static let boxType: FourCC = "alac"

    /// Standard audio sample entry header (v0).
    public let audioFields: AudioSampleEntryFields
    /// ALAC magic cookie — required.
    public let specificBox: ALACSpecificBox
    /// Optional `chnl` / `srat` / `btrt` extension boxes.
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        specificBox: ALACSpecificBox,
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
    ) async throws -> ALACSampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        // The mandatory child config box also has fourCC "alac". It is
        // dispatched manually here — `ALACSpecificBox` is intentionally
        // NOT registered globally to avoid collision with the parent.
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == ALACSpecificBox.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason:
                    "Expected alac magic-cookie child, got \(configHeader.type)"
            )
        }
        let specific = try await ALACSpecificBox.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        let (exts, _) = try await AudioSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return ALACSampleEntry(
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

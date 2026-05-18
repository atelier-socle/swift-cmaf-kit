// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EncryptedAudioSampleEntry (enca)
//
// Reference: ISO/IEC 23001-7 §4 (Common Encryption original sample-
// entry preservation pattern).
//
// `enca` replaces the original audio codec FourCC for protected
// content. The original codec's configuration record and the
// encryption `sinf` subtree are preserved opaquely in this release
// (the `sinf` family is delivered by a later encryption-box checkpoint)
// while keeping a byte-perfect round-trip.

import Foundation

/// Encrypted audio sample entry (`enca`).
public struct EncryptedAudioSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "enca"

    public let audioFields: AudioSampleEntryFields
    /// Children (sinf, original codec configuration record, etc.)
    /// preserved opaquely. Typed wrappers land in a later checkpoint.
    public let opaqueChildren: [ISOBoxOpaque]
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        opaqueChildren: [ISOBoxOpaque],
        extensions: AudioSampleEntryExtensions = AudioSampleEntryExtensions()
    ) {
        self.audioFields = audioFields
        self.opaqueChildren = opaqueChildren
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> EncryptedAudioSampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)

        var opaqueChildren: [ISOBoxOpaque] = []
        var channelLayout: ChannelLayoutBox?
        var samplingRate: SamplingRateBox?
        var bitRate: BitRateBox?

        let isoBoxReader = ISOBoxReader()
        while reader.remaining >= 8 {
            var peek = reader
            let childHeader = try isoBoxReader.parseBoxHeader(&peek)
            switch childHeader.type {
            case ChannelLayoutBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                channelLayout = try await ChannelLayoutBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case SamplingRateBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                samplingRate = try await SamplingRateBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case BitRateBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                bitRate = try await BitRateBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            default:
                opaqueChildren.append(try ISOBoxOpaque.parse(reader: &reader))
            }
        }

        let exts = AudioSampleEntryExtensions(
            channelLayout: channelLayout,
            samplingRate: samplingRate,
            bitRate: bitRate
        )
        return EncryptedAudioSampleEntry(
            audioFields: fields,
            opaqueChildren: opaqueChildren,
            extensions: exts
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            audioFields.encode(to: &body)
            for child in opaqueChildren {
                child.writeRaw(to: &body)
            }
            extensions.encode(to: &body)
        }
    }
}

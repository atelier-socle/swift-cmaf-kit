// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - LegacyPCMSampleEntry (lpcm)
//
// References:
// - ISO/IEC 14496-12 §12.2.3 — Audio Sample Entry
// - ISO/IEC 14496-12 §12.2.3.2 / §8.5.2.2 — Version 1 audio sample
//   entry (the lpcm version-1 fields)
// - Apple QuickTime File Format Specification — lpcm historical
//
// Unlike `ipcm` / `fpcm` (which use version 0 AudioSampleEntry + a
// `pcmC` child config box), `lpcm` uses **version 1 AudioSampleEntry**
// with the legacy fields inline (`outChannelCount`, `outSampleSize`,
// `outSampleRate`, `constBytesPerAudioSample`, `samplesPerFrame`).
//
// Out-of-scope and documented: `sowt` (signed-int little-endian
// 16-bit) and `twos` (signed-int big-endian 16-bit) — QuickTime-only
// 16-bit-fixed legacy variants. The `lpcm` v1 form covers all
// bit-depths uniformly.

import Foundation

/// Legacy QuickTime PCM sample entry (`lpcm`) per ISO/IEC 14496-12
/// §12.2.3 + §12.2.3.2 (version 1 audio sample entry).
///
/// Reuses the existing ``AudioSampleEntryFields`` with `version: .v1`
/// and a populated ``AudioSampleEntryFields/V1Fields`` carrying the
/// QuickTime-legacy fields inline. No separate config box.
///
/// References:
/// - ISO/IEC 14496-12 §12.2.3 — Audio Sample Entry
/// - ISO/IEC 14496-12 §12.2.3.2 / §8.5.2.2 — Version 1 AudioSampleEntry
/// - Apple QuickTime File Format Specification — lpcm historical
public struct LegacyPCMSampleEntry: ISOBox, Sendable, Equatable, Hashable {

    public static let boxType: FourCC = "lpcm"

    /// Audio sample entry header with `version == .v1` and a non-nil
    /// `v1Fields`. ``init(audioFields:extensions:)`` enforces this
    /// invariant via `precondition`.
    public let audioFields: AudioSampleEntryFields
    /// Optional `chnl` / `srat` / `btrt` extension boxes — multi-channel
    /// lpcm (above stereo) SHOULD carry a `chnl` for canonical layout
    /// signalling.
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        extensions: AudioSampleEntryExtensions = AudioSampleEntryExtensions()
    ) {
        precondition(
            audioFields.version == .v1 && audioFields.v1Fields != nil,
            "LegacyPCMSampleEntry requires version 1 audio sample entry"
        )
        self.audioFields = audioFields
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> LegacyPCMSampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        guard fields.version == .v1, fields.v1Fields != nil else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason:
                    "lpcm requires version 1 audio sample entry (got version \(fields.version.rawValue))"
            )
        }
        let (exts, _) = try await AudioSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return LegacyPCMSampleEntry(audioFields: fields, extensions: exts)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            audioFields.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

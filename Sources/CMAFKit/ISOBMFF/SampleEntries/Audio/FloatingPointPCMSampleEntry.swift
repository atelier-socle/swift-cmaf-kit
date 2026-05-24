// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FloatingPointPCMSampleEntry (fpcm)
//
// References:
// - ISO/IEC 23003-5 §4 — sample entry `fpcm`
// - ISO/IEC 23003-5 §5 — `PCMConfigurationBox` (pcmC) child
// - ISO/IEC 14496-12 §12.2 — AudioSampleEntry parent (version 0)
// - CMAF (ISO/IEC 23000-19) §7.5.2 — Uncompressed audio profile
// - DASH-IF Implementation Guidelines v5.0+ §6.3.7

import Foundation

/// Floating-point PCM sample entry (`fpcm`) per ISO/IEC 23003-5 §4.
///
/// Wraps the standard ``AudioSampleEntryFields`` (version 0) +
/// mandatory ``PCMConfigurationBox`` (`pcmC`) child + standard
/// ``AudioSampleEntryExtensions``.
///
/// Bit-depth constraints: `pcmConfiguration.pcmSampleSize ∈ {32, 64}`
/// (IEEE 754 binary32 / binary64) — enforced by
/// ``PCMConfigurationBox/validate(codecKind:)``. 16-bit half-precision
/// (IEEE 754 binary16) is not a CMAF-standard form and is rejected.
///
/// References:
/// - ISO/IEC 23003-5 §4 — fpcm
/// - ISO/IEC 23003-5 §5 — pcmC
/// - CMAF §7.5.2 — Uncompressed audio profile
public struct FloatingPointPCMSampleEntry: ISOBox, Sendable, Equatable, Hashable {

    public static let boxType: FourCC = "fpcm"

    public let audioFields: AudioSampleEntryFields
    public let pcmConfiguration: PCMConfigurationBox
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        pcmConfiguration: PCMConfigurationBox,
        extensions: AudioSampleEntryExtensions = AudioSampleEntryExtensions()
    ) {
        self.audioFields = audioFields
        self.pcmConfiguration = pcmConfiguration
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> FloatingPointPCMSampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        let isoBoxReader = ISOBoxReader()
        let configHeader = try isoBoxReader.parseBoxHeader(&reader)
        guard configHeader.type == PCMConfigurationBox.boxType else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Expected pcmC child, got \(configHeader.type)"
            )
        }
        let pcmConfig = try await PCMConfigurationBox.parse(
            reader: &reader, header: configHeader, registry: registry
        )
        try pcmConfig.validate(codecKind: .floatingPoint)
        let (exts, _) = try await AudioSampleEntryExtensions.parse(
            reader: &reader, registry: registry
        )
        return FloatingPointPCMSampleEntry(
            audioFields: fields,
            pcmConfiguration: pcmConfig,
            extensions: exts
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            audioFields.encode(to: &body)
            pcmConfiguration.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

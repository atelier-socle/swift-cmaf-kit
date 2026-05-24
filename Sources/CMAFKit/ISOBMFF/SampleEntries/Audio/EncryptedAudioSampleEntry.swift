// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EncryptedAudioSampleEntry (enca)
//
// Reference: ISO/IEC 23001-7 §4 (Common Encryption original sample-
// entry preservation pattern).
//
// `enca` replaces the original audio codec FourCC for protected
// content. The original codec's configuration record is preserved as
// a typed value alongside the mandatory `sinf` (ProtectionSchemeInfoBox)
// describing how the track is encrypted.

import Foundation

/// Typed original-codec configuration carried alongside an `enca`
/// sample entry.
public enum AudioCodecConfiguration: Sendable, Equatable, Hashable {
    case mp4Audio(ElementaryStreamDescriptor)
    case ac3(AC3SpecificBox)
    case ec3(EC3SpecificBox)
    case ac4(AC4SpecificBox)
    case opus(OpusSpecificBox)
    case flac(FLACSpecificBox)
    case mpegH(MPEGHConfigurationBox)
    case alac(ALACSpecificBox)
    case integerPCM(PCMConfigurationBox)
    case floatingPointPCM(PCMConfigurationBox)
    /// Legacy lpcm has no separate config box — the version-1 audio
    /// fields ARE the configuration. The associated value carries the
    /// V1 fields used by the composer to build the `lpcm` sample
    /// entry's audio header.
    case legacyPCM(v1Fields: AudioSampleEntryFields.V1Fields)

    public var boxType: FourCC {
        switch self {
        case .mp4Audio: return ElementaryStreamDescriptor.boxType
        case .ac3: return AC3SpecificBox.boxType
        case .ec3: return EC3SpecificBox.boxType
        case .ac4: return AC4SpecificBox.boxType
        case .opus: return OpusSpecificBox.boxType
        case .flac: return FLACSpecificBox.boxType
        case .mpegH: return MPEGHConfigurationBox.boxType
        case .alac: return ALACSpecificBox.boxType
        case .integerPCM, .floatingPointPCM: return PCMConfigurationBox.boxType
        case .legacyPCM: return "lpcm"
        }
    }

    fileprivate func encode(to writer: inout BinaryWriter) {
        switch self {
        case .mp4Audio(let r): r.encode(to: &writer)
        case .ac3(let r): r.encode(to: &writer)
        case .ec3(let r): r.encode(to: &writer)
        case .ac4(let r): r.encode(to: &writer)
        case .opus(let r): r.encode(to: &writer)
        case .flac(let r): r.encode(to: &writer)
        case .mpegH(let r): r.encode(to: &writer)
        case .alac(let r): r.encode(to: &writer)
        case .integerPCM(let r), .floatingPointPCM(let r): r.encode(to: &writer)
        case .legacyPCM:
            // lpcm has no separate config box — the v1 fields are
            // emitted by the parent AudioSampleEntryFields.
            break
        }
    }
}

/// Encrypted audio sample entry (`enca`).
public struct EncryptedAudioSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "enca"

    public let audioFields: AudioSampleEntryFields
    /// The original codec's configuration record.
    public let originalCodecConfiguration: AudioCodecConfiguration
    /// Mandatory protection-scheme info container.
    public let protectionSchemeInfo: ProtectionSchemeInfoBox
    public let extensions: AudioSampleEntryExtensions

    public init(
        audioFields: AudioSampleEntryFields,
        originalCodecConfiguration: AudioCodecConfiguration,
        protectionSchemeInfo: ProtectionSchemeInfoBox,
        extensions: AudioSampleEntryExtensions = AudioSampleEntryExtensions()
    ) {
        self.audioFields = audioFields
        self.originalCodecConfiguration = originalCodecConfiguration
        self.protectionSchemeInfo = protectionSchemeInfo
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> EncryptedAudioSampleEntry {
        let fields = try AudioSampleEntryFields.parse(reader: &reader)
        var codecConfig: AudioCodecConfiguration?
        var sinf: ProtectionSchemeInfoBox?
        var channelLayout: ChannelLayoutBox?
        var samplingRate: SamplingRateBox?
        var bitRate: BitRateBox?
        let isoBoxReader = ISOBoxReader()
        while reader.remaining >= 8 {
            var peek = reader
            let childHeader = try isoBoxReader.parseBoxHeader(&peek)
            switch childHeader.type {
            case ElementaryStreamDescriptor.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .mp4Audio(
                    try await ElementaryStreamDescriptor.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case AC3SpecificBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .ac3(
                    try await AC3SpecificBox.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case EC3SpecificBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .ec3(
                    try await EC3SpecificBox.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case AC4SpecificBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .ac4(
                    try await AC4SpecificBox.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case OpusSpecificBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .opus(
                    try await OpusSpecificBox.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case FLACSpecificBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .flac(
                    try await FLACSpecificBox.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case MPEGHConfigurationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .mpegH(
                    try await MPEGHConfigurationBox.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case ALACSpecificBox.boxType
            where childHeader.size <= 48:
                // The `alac` fourCC collides with the parent
                // ALACSampleEntry; inside an enca context we
                // distinguish by size — the magic cookie is 36 / 40
                // bytes total whereas an ALACSampleEntry body is much
                // larger.
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .alac(
                    try await ALACSpecificBox.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case PCMConfigurationBox.boxType:
                // `pcmC` alone cannot distinguish integer vs float —
                // the original format (preserved in sinf.originalFormat)
                // disambiguates. Default to .integerPCM here; the
                // resolver fixes the discriminator using the original
                // format fourCC.
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .integerPCM(
                    try await PCMConfigurationBox.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case ProtectionSchemeInfoBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                sinf = try await ProtectionSchemeInfoBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
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
                _ = try ISOBoxOpaque.parse(reader: &reader)
            }
        }
        guard let resolvedSinf = sinf else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "enca missing mandatory sinf child"
            )
        }
        // Rewire the codec configuration using the original-format
        // fourCC carried in sinf:
        // - pcmC + originalFormat == "fpcm" → reclassify as
        //   .floatingPointPCM (the inner box alone cannot
        //   discriminate integer vs float).
        // - originalFormat == "lpcm" + no inner config box → derive
        //   `.legacyPCM` from the audio sample entry's V1 fields.
        let originalFormat = resolvedSinf.originalFormat.dataFormat
        switch (codecConfig, originalFormat) {
        case (.some(.integerPCM(let pcm)), "fpcm"):
            codecConfig = .floatingPointPCM(pcm)
        case (nil, "lpcm"):
            if let v1 = fields.v1Fields {
                codecConfig = .legacyPCM(v1Fields: v1)
            }
        default:
            break
        }
        guard let resolvedCodec = codecConfig else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "enca missing original codec configuration child"
            )
        }
        let exts = AudioSampleEntryExtensions(
            channelLayout: channelLayout,
            samplingRate: samplingRate,
            bitRate: bitRate
        )
        return EncryptedAudioSampleEntry(
            audioFields: fields,
            originalCodecConfiguration: resolvedCodec,
            protectionSchemeInfo: resolvedSinf,
            extensions: exts
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            audioFields.encode(to: &body)
            originalCodecConfiguration.encode(to: &body)
            protectionSchemeInfo.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

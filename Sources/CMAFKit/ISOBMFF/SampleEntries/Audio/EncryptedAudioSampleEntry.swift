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

    public var boxType: FourCC {
        switch self {
        case .mp4Audio: return ElementaryStreamDescriptor.boxType
        case .ac3: return AC3SpecificBox.boxType
        case .ec3: return EC3SpecificBox.boxType
        case .ac4: return AC4SpecificBox.boxType
        case .opus: return OpusSpecificBox.boxType
        case .flac: return FLACSpecificBox.boxType
        case .mpegH: return MPEGHConfigurationBox.boxType
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

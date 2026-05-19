// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - EncryptedVideoSampleEntry (encv)
//
// Reference: ISO/IEC 23001-7 §4 (Common Encryption original sample-
// entry preservation pattern).
//
// `encv` replaces the original codec FourCC for protected content. The
// original codec's configuration record is preserved as a typed value
// alongside the mandatory `sinf` (ProtectionSchemeInfoBox) describing
// how the track is encrypted.

import Foundation

/// Typed original-codec configuration carried alongside an `encv`
/// sample entry. Each case wraps the configuration record the original
/// (unencrypted) sample entry would have carried, so consumers recover
/// full codec semantics after decryption.
public enum VideoCodecConfiguration: Sendable, Equatable, Hashable {
    case avc(AVCDecoderConfigurationRecord)
    case hevc(HEVCDecoderConfigurationRecord)
    case vp(VPCodecConfigurationRecord)
    case av1(AV1CodecConfigurationRecord)
    case mp4Visual(ElementaryStreamDescriptor)

    /// The FourCC that would identify this configuration as a child
    /// of the unencrypted sample entry (e.g., `avcC` for AVC).
    public var boxType: FourCC {
        switch self {
        case .avc: return AVCDecoderConfigurationRecord.boxType
        case .hevc: return HEVCDecoderConfigurationRecord.boxType
        case .vp: return VPCodecConfigurationRecord.boxType
        case .av1: return AV1CodecConfigurationRecord.boxType
        case .mp4Visual: return ElementaryStreamDescriptor.boxType
        }
    }

    fileprivate func encode(to writer: inout BinaryWriter) {
        switch self {
        case .avc(let r): r.encode(to: &writer)
        case .hevc(let r): r.encode(to: &writer)
        case .vp(let r): r.encode(to: &writer)
        case .av1(let r): r.encode(to: &writer)
        case .mp4Visual(let r): r.encode(to: &writer)
        }
    }
}

/// Encrypted video sample entry (`encv`).
public struct EncryptedVideoSampleEntry: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "encv"

    public let visualFields: VisualSampleEntryFields
    /// The original codec's configuration record.
    public let originalCodecConfiguration: VideoCodecConfiguration
    /// Mandatory protection-scheme info container.
    public let protectionSchemeInfo: ProtectionSchemeInfoBox
    public let extensions: VideoSampleEntryExtensions

    public init(
        visualFields: VisualSampleEntryFields,
        originalCodecConfiguration: VideoCodecConfiguration,
        protectionSchemeInfo: ProtectionSchemeInfoBox,
        extensions: VideoSampleEntryExtensions = VideoSampleEntryExtensions()
    ) {
        self.visualFields = visualFields
        self.originalCodecConfiguration = originalCodecConfiguration
        self.protectionSchemeInfo = protectionSchemeInfo
        self.extensions = extensions
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> EncryptedVideoSampleEntry {
        let fields = try VisualSampleEntryFields.parse(reader: &reader)
        var codecConfig: VideoCodecConfiguration?
        var sinf: ProtectionSchemeInfoBox?
        var color: ColorInformationBox?
        var mdcv: MasteringDisplayColourVolumeBox?
        var clli: ContentLightLevelBox?
        var dvcC: DolbyVisionConfigurationBox?
        var dvvC: DolbyVisionELConfigurationBox?
        var pasp: PixelAspectRatioBox?
        var clap: CleanApertureBox?
        var btrt: BitRateBox?
        let isoBoxReader = ISOBoxReader()
        while reader.remaining >= 8 {
            var peek = reader
            let childHeader = try isoBoxReader.parseBoxHeader(&peek)
            switch childHeader.type {
            case AVCDecoderConfigurationRecord.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .avc(
                    try await AVCDecoderConfigurationRecord.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case HEVCDecoderConfigurationRecord.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .hevc(
                    try await HEVCDecoderConfigurationRecord.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case VPCodecConfigurationRecord.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .vp(
                    try await VPCodecConfigurationRecord.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case AV1CodecConfigurationRecord.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .av1(
                    try await AV1CodecConfigurationRecord.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case ElementaryStreamDescriptor.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                codecConfig = .mp4Visual(
                    try await ElementaryStreamDescriptor.parse(
                        reader: &reader, header: childHeader, registry: registry
                    )
                )
            case ProtectionSchemeInfoBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                sinf = try await ProtectionSchemeInfoBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case ColorInformationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                color = try await ColorInformationBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case MasteringDisplayColourVolumeBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                mdcv = try await MasteringDisplayColourVolumeBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case ContentLightLevelBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                clli = try await ContentLightLevelBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case DolbyVisionConfigurationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                dvcC = try await DolbyVisionConfigurationBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case DolbyVisionELConfigurationBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                dvvC = try await DolbyVisionELConfigurationBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case PixelAspectRatioBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                pasp = try await PixelAspectRatioBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case CleanApertureBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                clap = try await CleanApertureBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            case BitRateBox.boxType:
                _ = try isoBoxReader.parseBoxHeader(&reader)
                btrt = try await BitRateBox.parse(
                    reader: &reader, header: childHeader, registry: registry
                )
            default:
                _ = try ISOBoxOpaque.parse(reader: &reader)
            }
        }
        guard let resolvedSinf = sinf else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "encv missing mandatory sinf child"
            )
        }
        guard let resolvedCodec = codecConfig else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "encv missing original codec configuration child"
            )
        }
        let exts = VideoSampleEntryExtensions(
            colorInformation: color,
            masteringDisplay: mdcv,
            contentLightLevel: clli,
            dolbyVisionConfiguration: dvcC,
            dolbyVisionELConfiguration: dvvC,
            pixelAspectRatio: pasp,
            cleanAperture: clap,
            bitRate: btrt
        )
        return EncryptedVideoSampleEntry(
            visualFields: fields,
            originalCodecConfiguration: resolvedCodec,
            protectionSchemeInfo: resolvedSinf,
            extensions: exts
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            visualFields.encode(to: &body)
            originalCodecConfiguration.encode(to: &body)
            protectionSchemeInfo.encode(to: &body)
            extensions.encode(to: &body)
        }
    }
}

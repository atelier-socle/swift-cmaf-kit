// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - VideoSampleEntryResolver (internal)
//
// Reference: ISO/IEC 14496-12 §8.5.2.2 (SampleEntry) and ISO/IEC
// 14496-15 §5, §8 (AVC, HEVC sample entries).
//
// Inverts ``SampleEntryComposer.makeVideoSampleEntry`` from the
// writer. Given a parsed video sample entry (any of the 10 codec
// arms, encrypted or not), surface the typed ``VideoCodec``, the
// typed ``VideoCodecConfiguration``, and the extension boxes the
// composer carried inside ``VideoSampleEntryExtensions``.

import Foundation

internal struct ResolvedVideoEntry: Sendable {
    let codec: VideoCodec
    let codecConfiguration: VideoCodecConfiguration
    let colorInformation: ColorInformationBox?
    let masteringDisplay: MasteringDisplayColourVolumeBox?
    let contentLightLevel: ContentLightLevelBox?
    let dolbyVisionConfiguration: DolbyVisionConfigurationBox?
    let dolbyVisionELConfiguration: DolbyVisionELConfigurationBox?
    let pixelAspectRatio: PixelAspectRatioBox?
    let cleanAperture: CleanApertureBox?
    let bitRate: BitRateBox?
    /// `sinf` carried by an encrypted entry (`encv`); nil for plain
    /// codec entries.
    let protectionSchemeInfo: ProtectionSchemeInfoBox?

    func encryptionParameters(
        psshBoxes: [ProtectionSystemSpecificHeaderBox]
    ) -> CMAFEncryptionParameters? {
        guard let sinf = protectionSchemeInfo,
            let schm = sinf.schemeType,
            let tenc = sinf.schemeInformation?.trackEncryption
        else { return nil }
        return CMAFEncryptionParameters(
            scheme: schm.schemeType,
            defaultKID: tenc.defaultKID,
            defaultPerSampleIVSize: tenc.defaultPerSampleIVSize,
            defaultConstantIV: tenc.defaultConstantIV,
            defaultCryptByteBlock: tenc.defaultCryptByteBlock,
            defaultSkipByteBlock: tenc.defaultSkipByteBlock,
            psshBoxes: psshBoxes
        )
    }
}

internal enum VideoSampleEntryResolver {

    static func resolve(entry: any SampleEntry) throws -> ResolvedVideoEntry {
        switch entry {
        case let e as AVCSampleEntry:
            return base(
                codec: .avc1,
                config: .avc(e.configuration),
                extensions: e.extensions,
                sinf: nil
            )
        case let e as AVCSampleEntryInband:
            return base(
                codec: .avc3,
                config: .avc(e.configuration),
                extensions: e.extensions,
                sinf: nil
            )
        case let e as HEVCSampleEntry:
            return base(
                codec: .hvc1,
                config: .hevc(e.configuration),
                extensions: e.extensions,
                sinf: nil
            )
        case let e as HEVCSampleEntryInband:
            return base(
                codec: .hev1,
                config: .hevc(e.configuration),
                extensions: e.extensions,
                sinf: nil
            )
        case let e as DolbyVisionHEVCSampleEntry:
            return base(
                codec: .dvh1,
                config: .hevc(e.hevcConfiguration),
                extensions: e.extensions,
                sinf: nil,
                dolbyVision: e.dolbyVisionConfiguration,
                dolbyVisionEL: e.dolbyVisionELConfiguration
            )
        case let e as DolbyVisionHEVCSampleEntryInband:
            return base(
                codec: .dvhe,
                config: .hevc(e.hevcConfiguration),
                extensions: e.extensions,
                sinf: nil,
                dolbyVision: e.dolbyVisionConfiguration,
                dolbyVisionEL: e.dolbyVisionELConfiguration
            )
        case let e as VP8SampleEntry:
            return base(
                codec: .vp08,
                config: .vp(e.configuration),
                extensions: e.extensions,
                sinf: nil
            )
        case let e as VP9SampleEntry:
            return base(
                codec: .vp09,
                config: .vp(e.configuration),
                extensions: e.extensions,
                sinf: nil
            )
        case let e as AV1SampleEntry:
            return base(
                codec: .av01,
                config: .av1(e.configuration),
                extensions: e.extensions,
                sinf: nil
            )
        case let e as MP4VisualSampleEntry:
            return base(
                codec: .mp4v,
                config: .mp4Visual(e.elementaryStreamDescriptor),
                extensions: e.extensions,
                sinf: nil
            )
        case let e as EncryptedVideoSampleEntry:
            let codec = codecFromOriginalFormat(
                e.protectionSchemeInfo.originalFormat.dataFormat,
                isEncrypted: true
            )
            return base(
                codec: codec,
                config: e.originalCodecConfiguration,
                extensions: e.extensions,
                sinf: e.protectionSchemeInfo
            )
        default:
            throw CMAFReaderError.unexpectedBoxAtLevel(
                parent: "stsd",
                found: type(of: entry).boxType
            )
        }
    }

    private static func base(
        codec: VideoCodec,
        config: VideoCodecConfiguration,
        extensions: VideoSampleEntryExtensions,
        sinf: ProtectionSchemeInfoBox?,
        dolbyVision: DolbyVisionConfiguration? = nil,
        dolbyVisionEL: DolbyVisionELConfiguration? = nil
    ) -> ResolvedVideoEntry {
        let dvBox =
            dolbyVision.map { DolbyVisionConfigurationBox(configuration: $0) }
            ?? extensions.dolbyVisionConfiguration
        let dvELBox =
            dolbyVisionEL.map { DolbyVisionELConfigurationBox(elConfiguration: $0) }
            ?? extensions.dolbyVisionELConfiguration
        return ResolvedVideoEntry(
            codec: codec,
            codecConfiguration: config,
            colorInformation: extensions.colorInformation,
            masteringDisplay: extensions.masteringDisplay,
            contentLightLevel: extensions.contentLightLevel,
            dolbyVisionConfiguration: dvBox,
            dolbyVisionELConfiguration: dvELBox,
            pixelAspectRatio: extensions.pixelAspectRatio,
            cleanAperture: extensions.cleanAperture,
            bitRate: extensions.bitRate,
            protectionSchemeInfo: sinf
        )
    }

    /// Map a `frma.dataFormat` FourCC back to ``VideoCodec``.
    private static func codecFromOriginalFormat(
        _ fourCC: FourCC,
        isEncrypted: Bool
    ) -> VideoCodec {
        switch fourCC {
        case "avc1": return .avc1
        case "avc3": return .avc3
        case "hvc1": return .hvc1
        case "hev1": return .hev1
        case "dvh1": return .dvh1
        case "dvhe": return .dvhe
        case "vp08": return .vp08
        case "vp09": return .vp09
        case "av01": return .av01
        case "mp4v": return .mp4v
        default: return .avc1  // unreachable for well-formed encrypted entries
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AudioSampleEntryResolver (internal)
//
// Reference: ISO/IEC 14496-12 §8.5.2.2 (SampleEntry) and ETSI TS
// 102 366 Annex F (AC-3, E-AC-3 sample entries), ETSI TS 103 190
// (AC-4), RFC 8916 (Opus in MP4), draft-ietf-cellar-flac §6
// (FLAC in ISOBMFF), ISO/IEC 23008-3 (MPEG-H 3D Audio).
//
// Inverts ``SampleEntryComposer.makeAudioSampleEntry``.

import Foundation

internal struct ResolvedAudioEntry: Sendable {
    let codec: AudioCodec
    let codecConfiguration: AudioCodecConfiguration
    let channelCount: UInt16
    let sampleRate: UInt32
    let sampleSize: UInt16
    let channelLayout: ChannelLayoutBox?
    let preciseSamplingRate: SamplingRateBox?
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

internal enum AudioSampleEntryResolver {

    static func resolve(entry: any SampleEntry) throws -> ResolvedAudioEntry {
        switch entry {
        case let e as MP4AudioSampleEntry:
            return base(
                codec: .mp4a,
                config: .mp4Audio(e.elementaryStreamDescriptor),
                fields: e.audioFields,
                extensions: e.extensions,
                sinf: nil
            )
        case let e as AC3SampleEntry:
            return base(
                codec: .ac3,
                config: .ac3(e.specificBox),
                fields: e.audioFields,
                extensions: e.extensions,
                sinf: nil
            )
        case let e as EC3SampleEntry:
            return base(
                codec: .ec3,
                config: .ec3(e.specificBox),
                fields: e.audioFields,
                extensions: e.extensions,
                sinf: nil
            )
        case let e as AC4SampleEntry:
            return base(
                codec: .ac4,
                config: .ac4(e.specificBox),
                fields: e.audioFields,
                extensions: e.extensions,
                sinf: nil
            )
        case let e as OpusSampleEntry:
            return base(
                codec: .opus,
                config: .opus(e.specificBox),
                fields: e.audioFields,
                extensions: e.extensions,
                sinf: nil
            )
        case let e as FLACSampleEntry:
            return base(
                codec: .flac,
                config: .flac(e.specificBox),
                fields: e.audioFields,
                extensions: e.extensions,
                sinf: nil
            )
        case let e as MPEGHAudioSampleEntry:
            return base(
                codec: .mpegHMain,
                config: .mpegH(e.configuration),
                fields: e.audioFields,
                extensions: e.extensions,
                sinf: nil
            )
        case let e as MPEGHAudioSampleEntryMultiStream:
            return base(
                codec: .mpegHMultiStream,
                config: .mpegH(e.configuration),
                fields: e.audioFields,
                extensions: e.extensions,
                sinf: nil
            )
        case let e as EncryptedAudioSampleEntry:
            let codec = codecFromOriginalFormat(
                e.protectionSchemeInfo.originalFormat.dataFormat
            )
            return base(
                codec: codec,
                config: e.originalCodecConfiguration,
                fields: e.audioFields,
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
        codec: AudioCodec,
        config: AudioCodecConfiguration,
        fields: AudioSampleEntryFields,
        extensions: AudioSampleEntryExtensions,
        sinf: ProtectionSchemeInfoBox?
    ) -> ResolvedAudioEntry {
        ResolvedAudioEntry(
            codec: codec,
            codecConfiguration: config,
            channelCount: fields.channelCount,
            sampleRate: fields.sampleRate,
            sampleSize: fields.sampleSize,
            channelLayout: extensions.channelLayout,
            preciseSamplingRate: extensions.samplingRate,
            protectionSchemeInfo: sinf
        )
    }

    private static func codecFromOriginalFormat(_ fourCC: FourCC) -> AudioCodec {
        switch fourCC {
        case "mp4a": return .mp4a
        case "ac-3": return .ac3
        case "ec-3": return .ec3
        case "ac-4": return .ac4
        case "Opus": return .opus
        case "fLaC": return .flac
        case "mhm1": return .mpegHMain
        case "mhm2": return .mpegHMultiStream
        default: return .mp4a
        }
    }
}

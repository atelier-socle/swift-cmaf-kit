// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AudioSpecificConfig
//
// Reference: ISO/IEC 14496-3 §1.6.2.1 (AudioSpecificConfig).
//
// Carried as the `decoderSpecificInfo` payload of `esds` for AAC and
// related General Audio family streams.

import Foundation

/// AAC AudioSpecificConfig per ISO/IEC 14496-3 §1.6.2.1.
public struct AudioSpecificConfig: Sendable, Hashable, Equatable {

    /// Sampling frequency: either an index into the standard table or
    /// an explicit Hz value when the table-escape code is used.
    public enum SamplingFrequency: Sendable, Hashable, Equatable {
        case indexed(MPEG4AudioSamplingFrequencyIndex)
        case explicit(rate: UInt32)
    }

    public let audioObjectType: MPEG4AudioObjectType
    public let samplingFrequency: SamplingFrequency
    public let channelConfiguration: MPEG4ChannelConfiguration
    /// Hierarchical signalling: present iff `audioObjectType` is `.sbr`
    /// or `.ps` (explicit hierarchical signalling).
    public let extensionAudioObjectType: MPEG4AudioObjectType?
    public let sbrPresentFlag: Bool?
    public let psPresentFlag: Bool?
    public let extensionSamplingFrequency: SamplingFrequency?
    public let gaSpecificConfig: GASpecificConfig?

    public init(
        audioObjectType: MPEG4AudioObjectType,
        samplingFrequency: SamplingFrequency,
        channelConfiguration: MPEG4ChannelConfiguration,
        extensionAudioObjectType: MPEG4AudioObjectType? = nil,
        sbrPresentFlag: Bool? = nil,
        psPresentFlag: Bool? = nil,
        extensionSamplingFrequency: SamplingFrequency? = nil,
        gaSpecificConfig: GASpecificConfig? = nil
    ) {
        self.audioObjectType = audioObjectType
        self.samplingFrequency = samplingFrequency
        self.channelConfiguration = channelConfiguration
        self.extensionAudioObjectType = extensionAudioObjectType
        self.sbrPresentFlag = sbrPresentFlag
        self.psPresentFlag = psPresentFlag
        self.extensionSamplingFrequency = extensionSamplingFrequency
        self.gaSpecificConfig = gaSpecificConfig
    }

    /// AOTs that require a `GASpecificConfig` subsidiary block per
    /// ISO/IEC 14496-3 Table 1.15.
    private static let gaSpecificConfigAOTs: Set<MPEG4AudioObjectType> = [
        .aacMain, .aacLC, .aacSSR, .aacLTP, .aacScalable,
        .erAACLC, .erAACLTP, .erAACScalable, .erAACLD, .erAACELD
    ]

    public static func parse(bitstream: Data) throws -> AudioSpecificConfig {
        var reader = BitReader(bitstream)
        let audioObjectType = try Self.readAudioObjectType(reader: &reader)
        let samplingFrequency = try Self.readSamplingFrequency(reader: &reader)
        let channelCfgRaw = UInt8(try reader.readBits(4))
        guard let channelConfiguration = MPEG4ChannelConfiguration(rawValue: channelCfgRaw) else {
            throw BitstreamError.unsupportedValue(
                codec: "AAC", field: "channelConfiguration", value: UInt64(channelCfgRaw)
            )
        }
        var extensionAOT: MPEG4AudioObjectType?
        var extensionSF: SamplingFrequency?
        if audioObjectType == .sbr || audioObjectType == .ps {
            extensionAOT = audioObjectType
            extensionSF = try Self.readSamplingFrequency(reader: &reader)
        }
        // Switch to the "actual" AOT for the GASpecificConfig presence
        // check (if SBR-explicit, the underlying AOT follows).
        let effectiveAOT: MPEG4AudioObjectType
        if extensionAOT != nil {
            effectiveAOT = try Self.readAudioObjectType(reader: &reader)
        } else {
            effectiveAOT = audioObjectType
        }
        var ga: GASpecificConfig?
        if gaSpecificConfigAOTs.contains(effectiveAOT) {
            ga = try GASpecificConfig.parse(
                reader: &reader,
                audioObjectType: effectiveAOT,
                channelConfiguration: channelConfiguration
            )
        }
        return AudioSpecificConfig(
            audioObjectType: extensionAOT == nil ? audioObjectType : effectiveAOT,
            samplingFrequency: samplingFrequency,
            channelConfiguration: channelConfiguration,
            extensionAudioObjectType: extensionAOT,
            sbrPresentFlag: nil,
            psPresentFlag: nil,
            extensionSamplingFrequency: extensionSF,
            gaSpecificConfig: ga
        )
    }

    public func encode() -> Data {
        var writer = BitWriter()
        // If extensionAudioObjectType is set, we emit the wrapper first.
        let outerAOT = extensionAudioObjectType ?? audioObjectType
        Self.writeAudioObjectType(outerAOT, to: &writer)
        Self.writeSamplingFrequency(samplingFrequency, to: &writer)
        writer.writeBits(UInt64(channelConfiguration.rawValue & 0x0F), count: 4)
        if let extSF = extensionSamplingFrequency {
            Self.writeSamplingFrequency(extSF, to: &writer)
            Self.writeAudioObjectType(audioObjectType, to: &writer)
        }
        gaSpecificConfig?.encode(to: &writer, audioObjectType: audioObjectType)
        writer.byteAlign()
        return writer.data
    }

    private static func readAudioObjectType(reader: inout BitReader) throws -> MPEG4AudioObjectType {
        let firstFive = UInt8(try reader.readBits(5))
        let raw: UInt8
        if firstFive == 31 {
            // Escape: read 6 more bits and add 32 → AOT range 32..95.
            let escape = UInt8(try reader.readBits(6))
            raw = escape + 32
        } else {
            raw = firstFive
        }
        guard let aot = MPEG4AudioObjectType(rawValue: raw) else {
            throw BitstreamError.unsupportedValue(
                codec: "AAC", field: "audioObjectType", value: UInt64(raw)
            )
        }
        return aot
    }

    private static func writeAudioObjectType(_ aot: MPEG4AudioObjectType, to writer: inout BitWriter) {
        let raw = aot.rawValue
        if raw < 31 {
            writer.writeBits(UInt64(raw & 0x1F), count: 5)
        } else {
            writer.writeBits(31, count: 5)
            writer.writeBits(UInt64((raw - 32) & 0x3F), count: 6)
        }
    }

    private static func readSamplingFrequency(reader: inout BitReader) throws -> SamplingFrequency {
        let idxRaw = UInt8(try reader.readBits(4))
        guard let idx = MPEG4AudioSamplingFrequencyIndex(rawValue: idxRaw) else {
            throw BitstreamError.unsupportedValue(
                codec: "AAC", field: "samplingFrequencyIndex", value: UInt64(idxRaw)
            )
        }
        if idx == .escape {
            let rate = UInt32(try reader.readBits(24))
            return .explicit(rate: rate)
        }
        return .indexed(idx)
    }

    private static func writeSamplingFrequency(_ sf: SamplingFrequency, to writer: inout BitWriter) {
        switch sf {
        case .indexed(let idx):
            writer.writeBits(UInt64(idx.rawValue & 0x0F), count: 4)
        case .explicit(let rate):
            writer.writeBits(UInt64(MPEG4AudioSamplingFrequencyIndex.escape.rawValue), count: 4)
            writer.writeBits(UInt64(rate & 0x00FF_FFFF), count: 24)
        }
    }
}

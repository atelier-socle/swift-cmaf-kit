// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AV1CodecConfigurationRecord (av1C)
//
// Reference: AOMedia AV1 ISO Media File Format Binding v1.2.0 §2.3.1.
//
// On-wire layout (after the 8-byte box header, raw box — NOT a full box):
//   UInt8 (marker: 1 = 1 | version: 7 = 1)
//   UInt8 (seq_profile: 3 | seq_level_idx_0: 5)
//   UInt8 (seq_tier_0: 1 | high_bitdepth: 1 | twelve_bit: 1 |
//          monochrome: 1 | chroma_subsampling_x: 1 |
//          chroma_subsampling_y: 1 | chroma_sample_position: 2)
//   UInt8 (reserved: 3 = 0 | initial_presentation_delay_present: 1 |
//          initial_presentation_delay_minus_one: 4)
//   variable-length configOBUs

import Foundation

/// AV1 codec configuration record carried by the `av1C` box.
///
/// Reference: AOMedia AV1 ISO Media File Format Binding §2.3.1.
public struct AV1CodecConfigurationRecord: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "av1C"

    public let marker: Bool
    public let version: UInt8
    public let seqProfile: AV1Profile
    public let seqLevelIdx0: AV1Level
    public let seqTier0: AV1Tier
    public let highBitdepth: Bool
    public let twelveBit: Bool
    public let monochrome: Bool
    public let chromaSubsamplingX: Bool
    public let chromaSubsamplingY: Bool
    public let chromaSamplePosition: AV1ChromaSamplePosition
    public let initialPresentationDelayMinusOne: UInt8?
    public let configOBUs: Data

    public init(
        marker: Bool = true,
        version: UInt8 = 1,
        seqProfile: AV1Profile,
        seqLevelIdx0: AV1Level,
        seqTier0: AV1Tier,
        highBitdepth: Bool,
        twelveBit: Bool,
        monochrome: Bool,
        chromaSubsamplingX: Bool,
        chromaSubsamplingY: Bool,
        chromaSamplePosition: AV1ChromaSamplePosition,
        initialPresentationDelayMinusOne: UInt8? = nil,
        configOBUs: Data = Data()
    ) {
        precondition(
            version <= 0x7F,
            "AV1CodecConfigurationRecord version must fit in 7 bits"
        )
        if let delay = initialPresentationDelayMinusOne {
            precondition(
                delay <= 0x0F,
                "AV1 initialPresentationDelayMinusOne must fit in 4 bits"
            )
        }
        self.marker = marker
        self.version = version
        self.seqProfile = seqProfile
        self.seqLevelIdx0 = seqLevelIdx0
        self.seqTier0 = seqTier0
        self.highBitdepth = highBitdepth
        self.twelveBit = twelveBit
        self.monochrome = monochrome
        self.chromaSubsamplingX = chromaSubsamplingX
        self.chromaSubsamplingY = chromaSubsamplingY
        self.chromaSamplePosition = chromaSamplePosition
        self.initialPresentationDelayMinusOne = initialPresentationDelayMinusOne
        self.configOBUs = configOBUs
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> AV1CodecConfigurationRecord {
        let markerVersion = try reader.readUInt8()
        let marker = (markerVersion & 0x80) != 0
        let version = markerVersion & 0x7F
        guard marker, version == 1 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "AV1 av1C marker/version invalid (marker=\(marker) version=\(version))"
            )
        }
        let profileLevel = try reader.readUInt8()
        let profileRaw = (profileLevel >> 5) & 0x07
        guard let profile = AV1Profile(rawValue: profileRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown AV1 seq_profile \(profileRaw)"
            )
        }
        let levelRaw = profileLevel & 0x1F
        guard let level = AV1Level(rawValue: levelRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown AV1 seq_level_idx_0 \(levelRaw)"
            )
        }
        let flagsByte = try reader.readUInt8()
        let tierRaw = (flagsByte >> 7) & 0x01
        guard let tier = AV1Tier(rawValue: tierRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown AV1 seq_tier_0 \(tierRaw)"
            )
        }
        let highBitdepth = ((flagsByte >> 6) & 0x01) == 1
        let twelveBit = ((flagsByte >> 5) & 0x01) == 1
        let monochrome = ((flagsByte >> 4) & 0x01) == 1
        let chromaSubX = ((flagsByte >> 3) & 0x01) == 1
        let chromaSubY = ((flagsByte >> 2) & 0x01) == 1
        let chromaPosRaw = flagsByte & 0x03
        guard let chromaPos = AV1ChromaSamplePosition(rawValue: chromaPosRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown AV1 chroma_sample_position \(chromaPosRaw)"
            )
        }
        let delayByte = try reader.readUInt8()
        let delayPresent = ((delayByte >> 4) & 0x01) == 1
        let delayValue = delayByte & 0x0F
        let initialPresentationDelayMinusOne: UInt8? = delayPresent ? delayValue : nil

        let remaining = reader.remaining
        let configOBUs = try reader.readData(count: remaining)

        return AV1CodecConfigurationRecord(
            marker: marker,
            version: version,
            seqProfile: profile,
            seqLevelIdx0: level,
            seqTier0: tier,
            highBitdepth: highBitdepth,
            twelveBit: twelveBit,
            monochrome: monochrome,
            chromaSubsamplingX: chromaSubX,
            chromaSubsamplingY: chromaSubY,
            chromaSamplePosition: chromaPos,
            initialPresentationDelayMinusOne: initialPresentationDelayMinusOne,
            configOBUs: configOBUs
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            var markerByte: UInt8 = version & 0x7F
            if marker { markerByte |= 0x80 }
            body.writeUInt8(markerByte)
            var profileLevel: UInt8 = (seqProfile.rawValue & 0x07) << 5
            profileLevel |= seqLevelIdx0.rawValue & 0x1F
            body.writeUInt8(profileLevel)
            var flagsByte: UInt8 = (seqTier0.rawValue & 0x01) << 7
            if highBitdepth { flagsByte |= 0x40 }
            if twelveBit { flagsByte |= 0x20 }
            if monochrome { flagsByte |= 0x10 }
            if chromaSubsamplingX { flagsByte |= 0x08 }
            if chromaSubsamplingY { flagsByte |= 0x04 }
            flagsByte |= chromaSamplePosition.rawValue & 0x03
            body.writeUInt8(flagsByte)
            var delayByte: UInt8 = 0
            if let delay = initialPresentationDelayMinusOne {
                delayByte = 0x10 | (delay & 0x0F)
            }
            body.writeUInt8(delayByte)
            body.writeData(configOBUs)
        }
    }
}

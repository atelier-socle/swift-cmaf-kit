// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCDecoderConfigurationRecord (avcC)
//
// Reference: ISO/IEC 14496-15 §5.3.3 (AVCDecoderConfigurationRecord).
//
// On-wire layout (after the 8-byte box header):
//   UInt8 configurationVersion (= 1)
//   UInt8 AVCProfileIndication
//   UInt8 profile_compatibility
//   UInt8 AVCLevelIndication
//   UInt8 reserved(6=0b111111) + lengthSizeMinusOne(2)
//   UInt8 reserved(3=0b111) + numOfSequenceParameterSets(5)
//   numSPS × (UInt16 spsLength + spsLength bytes spsNALUnit)
//   UInt8 numOfPictureParameterSets
//   numPPS × (UInt16 ppsLength + ppsLength bytes ppsNALUnit)
//
//   if profileRequiresHighProfileFields:
//     UInt8 reserved(6=0b111111) + chroma_format(2)
//     UInt8 reserved(5=0b11111) + bit_depth_luma_minus8(3)
//     UInt8 reserved(5=0b11111) + bit_depth_chroma_minus8(3)
//     UInt8 numOfSequenceParameterSetExt
//     numSPSExt × (UInt16 spsExtLength + spsExtLength bytes spsExtNALUnit)

import Foundation

/// AVC decoder configuration record carried by the `avcC` box.
///
/// Reference: ISO/IEC 14496-15 §5.3.3.
public struct AVCDecoderConfigurationRecord: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "avcC"

    public let configurationVersion: UInt8
    public let profileIndication: AVCProfileIndication
    public let profileCompatibility: AVCProfileCompatibility
    public let levelIndication: AVCLevelIndication
    public let lengthSize: NALLengthSize
    public let sequenceParameterSets: [AVCParameterSet]
    public let pictureParameterSets: [AVCParameterSet]
    public let highProfileFields: HighProfileFields?

    /// High-profile-only fields, present when
    /// ``AVCProfileIndication/requiresHighProfileFields`` is true.
    public struct HighProfileFields: Sendable, Equatable, Hashable {
        public let chromaFormat: AVCChromaFormat
        public let bitDepthLuma: UInt8
        public let bitDepthChroma: UInt8
        public let sequenceParameterSetExtensions: [AVCParameterSet]

        public init(
            chromaFormat: AVCChromaFormat,
            bitDepthLuma: UInt8,
            bitDepthChroma: UInt8,
            sequenceParameterSetExtensions: [AVCParameterSet]
        ) {
            precondition(
                bitDepthLuma >= 8 && bitDepthLuma <= 15,
                "AVC bitDepthLuma must be in 8...15"
            )
            precondition(
                bitDepthChroma >= 8 && bitDepthChroma <= 15,
                "AVC bitDepthChroma must be in 8...15"
            )
            self.chromaFormat = chromaFormat
            self.bitDepthLuma = bitDepthLuma
            self.bitDepthChroma = bitDepthChroma
            self.sequenceParameterSetExtensions = sequenceParameterSetExtensions
        }
    }

    public init(
        configurationVersion: UInt8 = 1,
        profileIndication: AVCProfileIndication,
        profileCompatibility: AVCProfileCompatibility,
        levelIndication: AVCLevelIndication,
        lengthSize: NALLengthSize,
        sequenceParameterSets: [AVCParameterSet],
        pictureParameterSets: [AVCParameterSet],
        highProfileFields: HighProfileFields? = nil
    ) {
        precondition(
            configurationVersion == 1,
            "AVCDecoderConfigurationRecord configurationVersion must be 1"
        )
        precondition(
            sequenceParameterSets.count <= 31,
            "AVC numOfSequenceParameterSets must fit in 5 bits"
        )
        precondition(
            pictureParameterSets.count <= 255,
            "AVC numOfPictureParameterSets must fit in 8 bits"
        )
        precondition(
            profileIndication.requiresHighProfileFields == (highProfileFields != nil),
            "AVCDecoderConfigurationRecord: highProfileFields presence must match profile"
        )
        self.configurationVersion = configurationVersion
        self.profileIndication = profileIndication
        self.profileCompatibility = profileCompatibility
        self.levelIndication = levelIndication
        self.lengthSize = lengthSize
        self.sequenceParameterSets = sequenceParameterSets
        self.pictureParameterSets = pictureParameterSets
        self.highProfileFields = highProfileFields
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> AVCDecoderConfigurationRecord {
        let version = try reader.readUInt8()
        guard version == 1 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "AVCDecoderConfigurationRecord version must be 1, got \(version)"
            )
        }
        let profileRaw = try reader.readUInt8()
        guard let profile = AVCProfileIndication(rawValue: profileRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown AVC profile_indication \(profileRaw)"
            )
        }
        let profileCompatibility = AVCProfileCompatibility(rawValue: try reader.readUInt8())
        let levelRaw = try reader.readUInt8()
        guard let level = AVCLevelIndication(rawValue: levelRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown AVC level_indication \(levelRaw)"
            )
        }
        let lengthByte = try reader.readUInt8()
        let lengthSize = try NALLengthSize(lengthSizeMinusOne: lengthByte & 0x03)

        let spsCountByte = try reader.readUInt8()
        let spsCount = Int(spsCountByte & 0x1F)
        var sps: [AVCParameterSet] = []
        sps.reserveCapacity(spsCount)
        for _ in 0..<spsCount {
            let length = Int(try reader.readUInt16())
            let bytes = try reader.readData(count: length)
            sps.append(AVCParameterSet(rbspBytes: bytes))
        }

        let ppsCount = Int(try reader.readUInt8())
        var pps: [AVCParameterSet] = []
        pps.reserveCapacity(ppsCount)
        for _ in 0..<ppsCount {
            let length = Int(try reader.readUInt16())
            let bytes = try reader.readData(count: length)
            pps.append(AVCParameterSet(rbspBytes: bytes))
        }

        var hpf: HighProfileFields?
        if profile.requiresHighProfileFields, reader.remaining > 0 {
            let chromaByte = try reader.readUInt8()
            guard let chroma = AVCChromaFormat(rawValue: chromaByte & 0x03) else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "Unknown AVC chroma_format \(chromaByte & 0x03)"
                )
            }
            let bitDepthLumaByte = try reader.readUInt8()
            let bitDepthLuma = (bitDepthLumaByte & 0x07) + 8
            let bitDepthChromaByte = try reader.readUInt8()
            let bitDepthChroma = (bitDepthChromaByte & 0x07) + 8
            let spsExtCount = Int(try reader.readUInt8())
            var spsExt: [AVCParameterSet] = []
            spsExt.reserveCapacity(spsExtCount)
            for _ in 0..<spsExtCount {
                let length = Int(try reader.readUInt16())
                let bytes = try reader.readData(count: length)
                spsExt.append(AVCParameterSet(rbspBytes: bytes))
            }
            hpf = HighProfileFields(
                chromaFormat: chroma,
                bitDepthLuma: bitDepthLuma,
                bitDepthChroma: bitDepthChroma,
                sequenceParameterSetExtensions: spsExt
            )
        }

        return AVCDecoderConfigurationRecord(
            configurationVersion: version,
            profileIndication: profile,
            profileCompatibility: profileCompatibility,
            levelIndication: level,
            lengthSize: lengthSize,
            sequenceParameterSets: sps,
            pictureParameterSets: pps,
            highProfileFields: hpf
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt8(configurationVersion)
            body.writeUInt8(profileIndication.rawValue)
            body.writeUInt8(profileCompatibility.rawValue)
            body.writeUInt8(levelIndication.rawValue)
            body.writeUInt8(0xFC | (lengthSize.lengthSizeMinusOne & 0x03))
            body.writeUInt8(0xE0 | (UInt8(sequenceParameterSets.count) & 0x1F))
            for sps in sequenceParameterSets {
                body.writeUInt16(UInt16(sps.rbspBytes.count))
                body.writeData(sps.rbspBytes)
            }
            body.writeUInt8(UInt8(pictureParameterSets.count))
            for pps in pictureParameterSets {
                body.writeUInt16(UInt16(pps.rbspBytes.count))
                body.writeData(pps.rbspBytes)
            }
            if let hpf = highProfileFields {
                body.writeUInt8(0xFC | (hpf.chromaFormat.rawValue & 0x03))
                body.writeUInt8(0xF8 | ((hpf.bitDepthLuma - 8) & 0x07))
                body.writeUInt8(0xF8 | ((hpf.bitDepthChroma - 8) & 0x07))
                body.writeUInt8(UInt8(hpf.sequenceParameterSetExtensions.count))
                for spsExt in hpf.sequenceParameterSetExtensions {
                    body.writeUInt16(UInt16(spsExt.rbspBytes.count))
                    body.writeData(spsExt.rbspBytes)
                }
            }
        }
    }
}

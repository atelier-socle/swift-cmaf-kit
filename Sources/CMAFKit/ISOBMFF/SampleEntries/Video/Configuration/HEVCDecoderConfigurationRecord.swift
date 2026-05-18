// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCDecoderConfigurationRecord (hvcC)
//
// Reference: ISO/IEC 14496-15 §8.3.3 (HEVCDecoderConfigurationRecord).
//
// On-wire layout (after the 8-byte box header):
//   UInt8 configurationVersion (= 1)
//   UInt8 (general_profile_space: 2 | general_tier_flag: 1 | general_profile_idc: 5)
//   UInt32 general_profile_compatibility_flags
//   6 bytes general_constraint_indicator_flags
//   UInt8 general_level_idc
//   UInt16 (reserved: 4 = 0b1111 | min_spatial_segmentation_idc: 12)
//   UInt8 (reserved: 6 = 0b111111 | parallelismType: 2)
//   UInt8 (reserved: 6 = 0b111111 | chromaFormat: 2)
//   UInt8 (reserved: 5 = 0b11111 | bitDepthLumaMinus8: 3)
//   UInt8 (reserved: 5 = 0b11111 | bitDepthChromaMinus8: 3)
//   UInt16 avgFrameRate
//   UInt8 (constantFrameRate: 2 | numTemporalLayers: 3 |
//          temporalIdNested: 1 | lengthSizeMinusOne: 2)
//   UInt8 numOfArrays
//   numOfArrays × HEVCParameterSetArray
//
// HEVCParameterSetArray:
//   UInt8 (array_completeness: 1 | reserved: 1 = 0 | NAL_unit_type: 6)
//   UInt16 numNalus
//   numNalus × (UInt16 nalUnitLength + nalUnitLength bytes nalUnit)

import Foundation

/// HEVC decoder configuration record carried by the `hvcC` box.
///
/// Reference: ISO/IEC 14496-15 §8.3.3.
public struct HEVCDecoderConfigurationRecord: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "hvcC"

    public let configurationVersion: UInt8
    public let profileSpace: HEVCProfileSpace
    public let tierFlag: HEVCTierFlag
    public let profileIDC: HEVCProfileIDC
    public let profileCompatibilityFlags: HEVCProfileCompatibilityFlags
    public let constraintIndicatorFlags: HEVCConstraintIndicatorFlags
    public let levelIDC: HEVCLevelIDC
    public let minSpatialSegmentationIDC: UInt16
    public let parallelismType: HEVCParallelismType
    public let chromaFormat: HEVCChromaFormatIDC
    public let bitDepthLuma: UInt8
    public let bitDepthChroma: UInt8
    public let avgFrameRate: UInt16
    public let constantFrameRate: HEVCConstantFrameRate
    public let numTemporalLayers: UInt8
    public let temporalIdNested: Bool
    public let lengthSize: NALLengthSize
    public let parameterSetArrays: [HEVCParameterSetArray]

    public init(
        configurationVersion: UInt8 = 1,
        profileSpace: HEVCProfileSpace,
        tierFlag: HEVCTierFlag,
        profileIDC: HEVCProfileIDC,
        profileCompatibilityFlags: HEVCProfileCompatibilityFlags,
        constraintIndicatorFlags: HEVCConstraintIndicatorFlags,
        levelIDC: HEVCLevelIDC,
        minSpatialSegmentationIDC: UInt16,
        parallelismType: HEVCParallelismType,
        chromaFormat: HEVCChromaFormatIDC,
        bitDepthLuma: UInt8,
        bitDepthChroma: UInt8,
        avgFrameRate: UInt16,
        constantFrameRate: HEVCConstantFrameRate,
        numTemporalLayers: UInt8,
        temporalIdNested: Bool,
        lengthSize: NALLengthSize,
        parameterSetArrays: [HEVCParameterSetArray]
    ) {
        precondition(
            configurationVersion == 1,
            "HEVCDecoderConfigurationRecord configurationVersion must be 1"
        )
        precondition(
            minSpatialSegmentationIDC <= 0x0FFF,
            "HEVC min_spatial_segmentation_idc must fit in 12 bits"
        )
        precondition(
            (8...16).contains(bitDepthLuma),
            "HEVC bitDepthLuma must be in 8...16"
        )
        precondition(
            (8...16).contains(bitDepthChroma),
            "HEVC bitDepthChroma must be in 8...16"
        )
        precondition(
            numTemporalLayers <= 7,
            "HEVC numTemporalLayers must fit in 3 bits"
        )
        self.configurationVersion = configurationVersion
        self.profileSpace = profileSpace
        self.tierFlag = tierFlag
        self.profileIDC = profileIDC
        self.profileCompatibilityFlags = profileCompatibilityFlags
        self.constraintIndicatorFlags = constraintIndicatorFlags
        self.levelIDC = levelIDC
        self.minSpatialSegmentationIDC = minSpatialSegmentationIDC
        self.parallelismType = parallelismType
        self.chromaFormat = chromaFormat
        self.bitDepthLuma = bitDepthLuma
        self.bitDepthChroma = bitDepthChroma
        self.avgFrameRate = avgFrameRate
        self.constantFrameRate = constantFrameRate
        self.numTemporalLayers = numTemporalLayers
        self.temporalIdNested = temporalIdNested
        self.lengthSize = lengthSize
        self.parameterSetArrays = parameterSetArrays
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> HEVCDecoderConfigurationRecord {
        let version = try reader.readUInt8()
        guard version == 1 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "HEVCDecoderConfigurationRecord version must be 1, got \(version)"
            )
        }
        let profileByte = try reader.readUInt8()
        let psRaw = (profileByte >> 6) & 0x03
        guard let profileSpace = HEVCProfileSpace(rawValue: psRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown HEVC profile_space \(psRaw)"
            )
        }
        let tierRaw = (profileByte >> 5) & 0x01
        guard let tierFlag = HEVCTierFlag(rawValue: tierRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown HEVC tier_flag \(tierRaw)"
            )
        }
        let pIDCRaw = profileByte & 0x1F
        guard let profileIDC = HEVCProfileIDC(rawValue: pIDCRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown HEVC profile_idc \(pIDCRaw)"
            )
        }
        let pcFlags = HEVCProfileCompatibilityFlags(rawValue: try reader.readUInt32())
        // 6-byte constraint indicator flags.
        let ciHi = UInt64(try reader.readUInt16())
        let ciLo = UInt64(try reader.readUInt32())
        let ciRaw = (ciHi << 32) | ciLo
        let ciFlags = HEVCConstraintIndicatorFlags(rawValueBigEndian: ciRaw)
        let levelRaw = try reader.readUInt8()
        guard let levelIDC = HEVCLevelIDC(rawValue: levelRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown HEVC level_idc \(levelRaw)"
            )
        }
        let mssIDC = try reader.readUInt16() & 0x0FFF
        let parallelismByte = try reader.readUInt8()
        guard let parallelism = HEVCParallelismType(rawValue: parallelismByte & 0x03) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown HEVC parallelismType \(parallelismByte & 0x03)"
            )
        }
        let chromaByte = try reader.readUInt8()
        guard let chromaFormat = HEVCChromaFormatIDC(rawValue: chromaByte & 0x03) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown HEVC chroma_format_idc \(chromaByte & 0x03)"
            )
        }
        let lumaByte = try reader.readUInt8()
        let bitDepthLuma = (lumaByte & 0x07) + 8
        let chromaDepthByte = try reader.readUInt8()
        let bitDepthChroma = (chromaDepthByte & 0x07) + 8
        let avgFrameRate = try reader.readUInt16()
        let frControlByte = try reader.readUInt8()
        let cfrRaw = (frControlByte >> 6) & 0x03
        guard let cfr = HEVCConstantFrameRate(rawValue: cfrRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown HEVC constantFrameRate \(cfrRaw)"
            )
        }
        let numTemporalLayers = (frControlByte >> 3) & 0x07
        let temporalIdNested = ((frControlByte >> 2) & 0x01) == 1
        let lengthSize = try NALLengthSize(lengthSizeMinusOne: frControlByte & 0x03)

        let numOfArrays = try reader.readUInt8()
        var arrays: [HEVCParameterSetArray] = []
        arrays.reserveCapacity(Int(numOfArrays))
        for _ in 0..<numOfArrays {
            let firstByte = try reader.readUInt8()
            let arrayCompleteness = (firstByte & 0x80) != 0
            let nalTypeRaw = firstByte & 0x3F
            guard let nalType = HEVCNALUnitType(rawValue: nalTypeRaw) else {
                throw ISOBoxError.malformedFullBox(
                    type: Self.boxType,
                    reason: "Unknown HEVC NAL unit type \(nalTypeRaw)"
                )
            }
            let numNalus = try reader.readUInt16()
            var sets: [HEVCParameterSet] = []
            sets.reserveCapacity(Int(numNalus))
            for _ in 0..<numNalus {
                let length = Int(try reader.readUInt16())
                let bytes = try reader.readData(count: length)
                sets.append(HEVCParameterSet(rbspBytes: bytes))
            }
            arrays.append(
                HEVCParameterSetArray(
                    arrayCompleteness: arrayCompleteness,
                    nalUnitType: nalType,
                    parameterSets: sets
                )
            )
        }

        return HEVCDecoderConfigurationRecord(
            configurationVersion: version,
            profileSpace: profileSpace,
            tierFlag: tierFlag,
            profileIDC: profileIDC,
            profileCompatibilityFlags: pcFlags,
            constraintIndicatorFlags: ciFlags,
            levelIDC: levelIDC,
            minSpatialSegmentationIDC: mssIDC,
            parallelismType: parallelism,
            chromaFormat: chromaFormat,
            bitDepthLuma: bitDepthLuma,
            bitDepthChroma: bitDepthChroma,
            avgFrameRate: avgFrameRate,
            constantFrameRate: cfr,
            numTemporalLayers: numTemporalLayers,
            temporalIdNested: temporalIdNested,
            lengthSize: lengthSize,
            parameterSetArrays: arrays
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt8(configurationVersion)
            let profileByte: UInt8 =
                ((profileSpace.rawValue & 0x03) << 6)
                | ((tierFlag.rawValue & 0x01) << 5)
                | (profileIDC.rawValue & 0x1F)
            body.writeUInt8(profileByte)
            body.writeUInt32(profileCompatibilityFlags.rawValue)
            let ci = constraintIndicatorFlags.rawValueBigEndian
            body.writeUInt16(UInt16((ci >> 32) & 0xFFFF))
            body.writeUInt32(UInt32(ci & 0xFFFF_FFFF))
            body.writeUInt8(levelIDC.rawValue)
            body.writeUInt16(0xF000 | (minSpatialSegmentationIDC & 0x0FFF))
            body.writeUInt8(0xFC | (parallelismType.rawValue & 0x03))
            body.writeUInt8(0xFC | (chromaFormat.rawValue & 0x03))
            body.writeUInt8(0xF8 | ((bitDepthLuma - 8) & 0x07))
            body.writeUInt8(0xF8 | ((bitDepthChroma - 8) & 0x07))
            body.writeUInt16(avgFrameRate)
            var frControl: UInt8 = (constantFrameRate.rawValue & 0x03) << 6
            frControl |= (numTemporalLayers & 0x07) << 3
            if temporalIdNested { frControl |= 0x04 }
            frControl |= lengthSize.lengthSizeMinusOne & 0x03
            body.writeUInt8(frControl)

            body.writeUInt8(UInt8(parameterSetArrays.count))
            for array in parameterSetArrays {
                var firstByte: UInt8 = 0
                if array.arrayCompleteness { firstByte |= 0x80 }
                firstByte |= (array.nalUnitType.rawValue & 0x3F)
                body.writeUInt8(firstByte)
                body.writeUInt16(UInt16(array.parameterSets.count))
                for set in array.parameterSets {
                    body.writeUInt16(UInt16(set.rbspBytes.count))
                    body.writeData(set.rbspBytes)
                }
            }
        }
    }
}

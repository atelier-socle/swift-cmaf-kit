// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCProfileTierLevel
//
// Reference: ITU-T H.265 §7.3.3 (profile_tier_level).
//
// The profile / tier / level subtree carries the general layer's
// profile signalling plus an optional series of sub-layer profile /
// level fields. CMAFKit reuses Session 6's `HEVCProfileSpace`,
// `HEVCTierFlag`, `HEVCProfileIDC`, `HEVCProfileCompatibilityFlags`,
// `HEVCConstraintIndicatorFlags`, and `HEVCLevelIDC` enums for the
// typed fields.

import Foundation

/// HEVC profile / tier / level subtree per ITU-T H.265 §7.3.3.
public struct HEVCProfileTierLevel: Sendable, Hashable, Equatable {

    /// 88-bit "profile signalling" block, shared by the general layer
    /// and any present sub-layer.
    public struct ProfileBlock: Sendable, Hashable, Equatable {
        public let profileSpace: HEVCProfileSpace
        public let tierFlag: HEVCTierFlag
        public let profileIDC: HEVCProfileIDC
        public let compatibilityFlags: HEVCProfileCompatibilityFlags
        public let constraintFlags: HEVCConstraintIndicatorFlags

        public init(
            profileSpace: HEVCProfileSpace,
            tierFlag: HEVCTierFlag,
            profileIDC: HEVCProfileIDC,
            compatibilityFlags: HEVCProfileCompatibilityFlags,
            constraintFlags: HEVCConstraintIndicatorFlags
        ) {
            self.profileSpace = profileSpace
            self.tierFlag = tierFlag
            self.profileIDC = profileIDC
            self.compatibilityFlags = compatibilityFlags
            self.constraintFlags = constraintFlags
        }

        fileprivate static func parse(reader: inout BitReader) throws -> ProfileBlock {
            let psRaw = UInt8(try reader.readBits(2))
            guard let ps = HEVCProfileSpace(rawValue: psRaw) else {
                throw BitstreamError.unsupportedValue(
                    codec: "HEVC", field: "general_profile_space", value: UInt64(psRaw)
                )
            }
            let tierRaw = UInt8(try reader.readBits(1))
            guard let tier = HEVCTierFlag(rawValue: tierRaw) else {
                throw BitstreamError.unsupportedValue(
                    codec: "HEVC", field: "general_tier_flag", value: UInt64(tierRaw)
                )
            }
            let idcRaw = UInt8(try reader.readBits(5))
            guard let idc = HEVCProfileIDC(rawValue: idcRaw) else {
                throw BitstreamError.unsupportedValue(
                    codec: "HEVC", field: "general_profile_idc", value: UInt64(idcRaw)
                )
            }
            let compatRaw = UInt32(try reader.readBits(32))
            let compat = HEVCProfileCompatibilityFlags(rawValue: compatRaw)
            let constraintRaw = try reader.readBits(48)
            let constraint = HEVCConstraintIndicatorFlags(rawValueBigEndian: constraintRaw)
            return ProfileBlock(
                profileSpace: ps,
                tierFlag: tier,
                profileIDC: idc,
                compatibilityFlags: compat,
                constraintFlags: constraint
            )
        }

        fileprivate func encode(to writer: inout BitWriter) {
            writer.writeBits(UInt64(profileSpace.rawValue & 0x03), count: 2)
            writer.writeBits(UInt64(tierFlag.rawValue & 0x01), count: 1)
            writer.writeBits(UInt64(profileIDC.rawValue & 0x1F), count: 5)
            writer.writeBits(UInt64(compatibilityFlags.rawValue), count: 32)
            writer.writeBits(constraintFlags.rawValueBigEndian, count: 48)
        }
    }

    /// Per-sub-layer entry; either or both of profile / level may be
    /// present.
    public struct SubLayerEntry: Sendable, Hashable, Equatable {
        public let profileBlock: ProfileBlock?
        public let levelIDC: HEVCLevelIDC?

        public init(profileBlock: ProfileBlock? = nil, levelIDC: HEVCLevelIDC? = nil) {
            self.profileBlock = profileBlock
            self.levelIDC = levelIDC
        }
    }

    /// General profile signalling. Present when the caller's
    /// `profilePresentFlag` is true; absent for SPS where the VPS
    /// already carried it.
    public let generalProfile: ProfileBlock?
    public let generalLevel: HEVCLevelIDC
    public let subLayers: [SubLayerEntry]

    public init(
        generalProfile: ProfileBlock?,
        generalLevel: HEVCLevelIDC,
        subLayers: [SubLayerEntry] = []
    ) {
        self.generalProfile = generalProfile
        self.generalLevel = generalLevel
        self.subLayers = subLayers
    }

    public static func parse(
        reader: inout BitReader,
        profilePresentFlag: Bool,
        maxNumSubLayersMinus1: UInt8
    ) throws -> HEVCProfileTierLevel {
        let generalProfile: ProfileBlock?
        if profilePresentFlag {
            generalProfile = try ProfileBlock.parse(reader: &reader)
        } else {
            generalProfile = nil
        }
        let levelRaw = UInt8(try reader.readBits(8))
        guard let level = HEVCLevelIDC(rawValue: levelRaw) else {
            throw BitstreamError.unsupportedValue(
                codec: "HEVC", field: "general_level_idc", value: UInt64(levelRaw)
            )
        }
        var profilePresent: [Bool] = []
        var levelPresent: [Bool] = []
        for _ in 0..<maxNumSubLayersMinus1 {
            profilePresent.append(try reader.readBool())
            levelPresent.append(try reader.readBool())
        }
        if maxNumSubLayersMinus1 > 0 {
            for _ in maxNumSubLayersMinus1..<8 {
                let reserved = try reader.readBits(2)
                guard reserved == 0 else {
                    throw BitstreamError.reservedBitsNonZero(
                        codec: "HEVC", field: "ptl_reserved_zero_2bits"
                    )
                }
            }
        }
        var subLayers: [SubLayerEntry] = []
        for i in 0..<Int(maxNumSubLayersMinus1) {
            let block: ProfileBlock? =
                profilePresent[i]
                ? try ProfileBlock.parse(reader: &reader)
                : nil
            var subLevel: HEVCLevelIDC?
            if levelPresent[i] {
                let raw = UInt8(try reader.readBits(8))
                guard let l = HEVCLevelIDC(rawValue: raw) else {
                    throw BitstreamError.unsupportedValue(
                        codec: "HEVC", field: "sub_layer_level_idc", value: UInt64(raw)
                    )
                }
                subLevel = l
            }
            subLayers.append(SubLayerEntry(profileBlock: block, levelIDC: subLevel))
        }
        return HEVCProfileTierLevel(
            generalProfile: generalProfile,
            generalLevel: level,
            subLayers: subLayers
        )
    }

    public func encode(
        to writer: inout BitWriter,
        profilePresentFlag: Bool,
        maxNumSubLayersMinus1: UInt8
    ) {
        if profilePresentFlag, let block = generalProfile {
            block.encode(to: &writer)
        }
        writer.writeBits(UInt64(generalLevel.rawValue), count: 8)
        // Iterate exactly maxNumSubLayersMinus1 entries; pad with empty
        // SubLayerEntry if the caller's `subLayers` array is shorter.
        for i in 0..<Int(maxNumSubLayersMinus1) {
            let entry = i < subLayers.count ? subLayers[i] : SubLayerEntry()
            writer.writeBool(entry.profileBlock != nil)
            writer.writeBool(entry.levelIDC != nil)
        }
        if maxNumSubLayersMinus1 > 0 {
            for _ in maxNumSubLayersMinus1..<8 {
                writer.writeBits(0, count: 2)
            }
        }
        for i in 0..<Int(maxNumSubLayersMinus1) {
            let entry = i < subLayers.count ? subLayers[i] : SubLayerEntry()
            entry.profileBlock?.encode(to: &writer)
            if let l = entry.levelIDC {
                writer.writeBits(UInt64(l.rawValue), count: 8)
            }
        }
    }
}

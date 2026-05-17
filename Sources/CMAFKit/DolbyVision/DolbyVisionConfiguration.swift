// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DolbyVisionConfiguration
//
// Reference: Dolby Vision Streams Within the ISO Base Media File Format
// (Dolby public specification), section "Dolby Vision Configuration Box".
//
// On-wire layout (24 bytes total):
//   dv_version_major: UInt8
//   dv_version_minor: UInt8
//   byte 2: dv_profile (7 bits) + bit 0 of dv_level
//   byte 3: dv_level (5 bits, low 5) + rpu_present (1 bit) +
//           el_present (1 bit) + bl_present (1 bit)
//   byte 4: dv_bl_signal_compatibility_id (4 bits) + 4 reserved bits
//   bytes 5..23: reserved (19 bytes, must be zero on encode).

import Foundation

/// Dolby Vision configuration carried by ``DolbyVisionConfigurationBox`` (`dvcC`).
public struct DolbyVisionConfiguration: Sendable, Hashable, Equatable, Codable {
    public let versionMajor: UInt8
    public let versionMinor: UInt8
    public let profile: DolbyVisionProfile
    public let level: DolbyVisionLevel
    public let rpuPresent: Bool
    public let elPresent: Bool
    public let blPresent: Bool
    public let blSignalCompatibilityID: DolbyVisionBLSignalCompatibilityID

    public init(
        versionMajor: UInt8,
        versionMinor: UInt8,
        profile: DolbyVisionProfile,
        level: DolbyVisionLevel,
        rpuPresent: Bool,
        elPresent: Bool,
        blPresent: Bool,
        blSignalCompatibilityID: DolbyVisionBLSignalCompatibilityID
    ) {
        self.versionMajor = versionMajor
        self.versionMinor = versionMinor
        self.profile = profile
        self.level = level
        self.rpuPresent = rpuPresent
        self.elPresent = elPresent
        self.blPresent = blPresent
        self.blSignalCompatibilityID = blSignalCompatibilityID
    }

    public static func parse(reader: inout BinaryReader) throws -> DolbyVisionConfiguration {
        let versionMajor = try reader.readUInt8()
        let versionMinor = try reader.readUInt8()
        let profileLevelByte0 = try reader.readUInt8()
        let profileLevelByte1 = try reader.readUInt8()
        let compatFlagsByte = try reader.readUInt8()
        try reader.skip(19)

        let profileNumber = (profileLevelByte0 >> 1) & 0x7F
        let levelHighBit = profileLevelByte0 & 0x01
        let levelLowFiveBits = (profileLevelByte1 >> 3) & 0x1F
        let levelRaw = (levelHighBit << 5) | levelLowFiveBits
        let rpuPresent = ((profileLevelByte1 >> 2) & 0x01) == 1
        let elPresent = ((profileLevelByte1 >> 1) & 0x01) == 1
        let blPresent = (profileLevelByte1 & 0x01) == 1
        let compatRaw = (compatFlagsByte >> 4) & 0x0F

        guard let level = DolbyVisionLevel(rawValue: levelRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: DolbyVisionConfigurationBox.boxType,
                reason: "Unknown Dolby Vision level \(levelRaw)"
            )
        }
        guard let compat = DolbyVisionBLSignalCompatibilityID(rawValue: compatRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: DolbyVisionConfigurationBox.boxType,
                reason: "Unknown Dolby Vision cross-compatibility \(compatRaw)"
            )
        }
        let profile = try DolbyVisionProfile.make(
            wireProfileNumber: profileNumber,
            compatibilityID: compat
        )

        return DolbyVisionConfiguration(
            versionMajor: versionMajor,
            versionMinor: versionMinor,
            profile: profile,
            level: level,
            rpuPresent: rpuPresent,
            elPresent: elPresent,
            blPresent: blPresent,
            blSignalCompatibilityID: compat
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeUInt8(versionMajor)
        writer.writeUInt8(versionMinor)

        let profileNumber = profile.wireProfileNumber
        let levelRaw = level.rawValue
        let levelHighBit = (levelRaw >> 5) & 0x01
        let levelLowFiveBits = levelRaw & 0x1F

        let byte0 = ((profileNumber & 0x7F) << 1) | (levelHighBit & 0x01)
        var byte1 = (levelLowFiveBits & 0x1F) << 3
        if rpuPresent { byte1 |= 0x04 }
        if elPresent { byte1 |= 0x02 }
        if blPresent { byte1 |= 0x01 }
        let compatByte = (blSignalCompatibilityID.rawValue & 0x0F) << 4

        writer.writeUInt8(byte0)
        writer.writeUInt8(byte1)
        writer.writeUInt8(compatByte)
        writer.writeZeros(19)
    }
}

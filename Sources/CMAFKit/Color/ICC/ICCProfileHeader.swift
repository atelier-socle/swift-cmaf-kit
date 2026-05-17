// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCProfileHeader
//
// Reference: ICC.1:2022 §7.2 (profile header, 128 bytes total).
//
// On-wire layout:
//   profile size (UInt32)               — bytes 0..3
//   preferred CMM type (UInt32)         — bytes 4..7
//   profile version (4 bytes)           — bytes 8..11
//   profile/device class (UInt32)       — bytes 12..15
//   data color space (UInt32)           — bytes 16..19
//   PCS color space (UInt32)            — bytes 20..23
//   date/time created (dateTimeNumber)  — bytes 24..35
//   profile file signature (UInt32)     — bytes 36..39 ('acsp')
//   primary platform (UInt32)           — bytes 40..43
//   profile flags (UInt32)              — bytes 44..47
//   device manufacturer (UInt32)        — bytes 48..51
//   device model (UInt32)               — bytes 52..55
//   device attributes (UInt64)          — bytes 56..63
//   rendering intent (UInt32)           — bytes 64..67
//   illuminant XYZ (XYZNumber)          — bytes 68..79
//   profile creator (UInt32)            — bytes 80..83
//   profile ID (16 bytes MD5)           — bytes 84..99
//   reserved                            — bytes 100..127

import Foundation

/// ICC profile header per ICC.1:2022 §7.2.
public struct ICCProfileHeader: Sendable, Hashable, Codable {
    public let profileSize: UInt32
    public let preferredCMMType: UInt32
    /// Version encoded as 4 bytes: major.minor[lo nibble].patch[lo nibble].00.
    public let versionMajor: UInt8
    public let versionMinor: UInt8
    public let versionPatch: UInt8
    public let profileClass: ICCProfileClass
    public let colorSpace: ICCColorSpace
    public let pcsColorSpace: ICCColorSpace
    public let dateCreated: ICCDateTimeNumber
    /// 'acsp' (0x61637370). Required by the spec for valid profiles.
    public let fileSignature: UInt32
    public let primaryPlatform: ICCPrimaryPlatform
    public let flags: UInt32
    public let deviceManufacturer: UInt32
    public let deviceModel: UInt32
    public let deviceAttributes: UInt64
    public let renderingIntent: ICCRenderingIntent
    public let illuminantXYZ: ICCXYZNumber
    public let creator: UInt32
    /// Optional MD5 profile ID; all zeros if not computed.
    public let profileID: Data

    public init(
        profileSize: UInt32,
        preferredCMMType: UInt32,
        versionMajor: UInt8,
        versionMinor: UInt8,
        versionPatch: UInt8,
        profileClass: ICCProfileClass,
        colorSpace: ICCColorSpace,
        pcsColorSpace: ICCColorSpace,
        dateCreated: ICCDateTimeNumber,
        fileSignature: UInt32 = 0x6163_7370,
        primaryPlatform: ICCPrimaryPlatform,
        flags: UInt32,
        deviceManufacturer: UInt32,
        deviceModel: UInt32,
        deviceAttributes: UInt64,
        renderingIntent: ICCRenderingIntent,
        illuminantXYZ: ICCXYZNumber,
        creator: UInt32,
        profileID: Data
    ) {
        precondition(profileID.count == 16, "ICC profileID must be exactly 16 bytes")
        self.profileSize = profileSize
        self.preferredCMMType = preferredCMMType
        self.versionMajor = versionMajor
        self.versionMinor = versionMinor
        self.versionPatch = versionPatch
        self.profileClass = profileClass
        self.colorSpace = colorSpace
        self.pcsColorSpace = pcsColorSpace
        self.dateCreated = dateCreated
        self.fileSignature = fileSignature
        self.primaryPlatform = primaryPlatform
        self.flags = flags
        self.deviceManufacturer = deviceManufacturer
        self.deviceModel = deviceModel
        self.deviceAttributes = deviceAttributes
        self.renderingIntent = renderingIntent
        self.illuminantXYZ = illuminantXYZ
        self.creator = creator
        self.profileID = profileID
    }

    public static func parse(reader: inout BinaryReader) throws -> ICCProfileHeader {
        let profileSize = try reader.readUInt32()
        let cmmType = try reader.readUInt32()
        let versionBytes = try reader.readData(count: 4)
        let baseIndex = versionBytes.startIndex
        let versionMajor = versionBytes[baseIndex]
        let versionMinor = (versionBytes[baseIndex + 1] >> 4) & 0x0F
        let versionPatch = versionBytes[baseIndex + 1] & 0x0F
        // versionBytes[2..3] are reserved per ICC.1:2022.
        let classRaw = try reader.readUInt32()
        guard let profileClass = ICCProfileClass(rawValue: classRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC profile class 0x\(String(classRaw, radix: 16))"
            )
        }
        let csRaw = try reader.readUInt32()
        guard let colorSpace = ICCColorSpace(rawValue: csRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC color space 0x\(String(csRaw, radix: 16))"
            )
        }
        let pcsRaw = try reader.readUInt32()
        guard let pcsColorSpace = ICCColorSpace(rawValue: pcsRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC PCS color space 0x\(String(pcsRaw, radix: 16))"
            )
        }
        let dateCreated = try ICCDateTimeNumber.parse(reader: &reader)
        let fileSignature = try reader.readUInt32()
        guard fileSignature == 0x6163_7370 else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Invalid ICC file signature 0x\(String(fileSignature, radix: 16))"
            )
        }
        let platformRaw = try reader.readUInt32()
        guard let primaryPlatform = ICCPrimaryPlatform(rawValue: platformRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC primary platform 0x\(String(platformRaw, radix: 16))"
            )
        }
        let flags = try reader.readUInt32()
        let manufacturer = try reader.readUInt32()
        let model = try reader.readUInt32()
        let attributes = try reader.readUInt64()
        let intentRaw = try reader.readUInt32()
        guard let renderingIntent = ICCRenderingIntent(rawValue: intentRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC rendering intent \(intentRaw)"
            )
        }
        let illuminant = try ICCXYZNumber.parse(reader: &reader)
        let creator = try reader.readUInt32()
        let profileID = try reader.readData(count: 16)
        try reader.skip(28)  // reserved bytes 100..127

        return ICCProfileHeader(
            profileSize: profileSize,
            preferredCMMType: cmmType,
            versionMajor: versionMajor,
            versionMinor: versionMinor,
            versionPatch: versionPatch,
            profileClass: profileClass,
            colorSpace: colorSpace,
            pcsColorSpace: pcsColorSpace,
            dateCreated: dateCreated,
            fileSignature: fileSignature,
            primaryPlatform: primaryPlatform,
            flags: flags,
            deviceManufacturer: manufacturer,
            deviceModel: model,
            deviceAttributes: attributes,
            renderingIntent: renderingIntent,
            illuminantXYZ: illuminant,
            creator: creator,
            profileID: profileID
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeUInt32(profileSize)
        writer.writeUInt32(preferredCMMType)
        writer.writeUInt8(versionMajor)
        writer.writeUInt8(((versionMinor & 0x0F) << 4) | (versionPatch & 0x0F))
        writer.writeZeros(2)
        writer.writeUInt32(profileClass.rawValue)
        writer.writeUInt32(colorSpace.rawValue)
        writer.writeUInt32(pcsColorSpace.rawValue)
        dateCreated.encode(to: &writer)
        writer.writeUInt32(fileSignature)
        writer.writeUInt32(primaryPlatform.rawValue)
        writer.writeUInt32(flags)
        writer.writeUInt32(deviceManufacturer)
        writer.writeUInt32(deviceModel)
        writer.writeUInt64(deviceAttributes)
        writer.writeUInt32(renderingIntent.rawValue)
        illuminantXYZ.encode(to: &writer)
        writer.writeUInt32(creator)
        writer.writeData(profileID)
        writer.writeZeros(28)
    }
}

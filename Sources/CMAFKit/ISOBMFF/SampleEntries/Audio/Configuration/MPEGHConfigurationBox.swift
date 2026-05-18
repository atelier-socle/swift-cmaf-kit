// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MPEGHConfigurationBox (mhaC)
//
// Reference: ISO/IEC 23008-3 §20.4 (mpegh3daConfigBox).
//
// On-wire layout (after the box header):
//   UInt8  configurationVersion (always 1)
//   UInt8  mpegh3daProfileLevelIndication
//   UInt8  referenceChannelLayout
//   UInt16 mpegh3daConfigLength
//   mpegh3daConfigLength bytes mpegh3daConfig

import Foundation

/// MPEG-H 3D Audio configuration box (`mhaC`).
public struct MPEGHConfigurationBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "mhaC"

    /// Configuration version; always 1 per ISO/IEC 23008-3 §20.4.
    public let configurationVersion: UInt8
    public let profileLevelIndication: MPEGHProfileLevelIndication
    /// CICP channel-configuration value per ISO/IEC 23001-8 §8 Table 8.
    public let referenceChannelLayout: UInt8
    /// Raw mpegh3daConfig bitstream payload. Out-of-scope for this
    /// module; decoded by a future codec-bitstream parser.
    public let mpegh3daConfig: Data

    public init(
        configurationVersion: UInt8 = 1,
        profileLevelIndication: MPEGHProfileLevelIndication,
        referenceChannelLayout: UInt8,
        mpegh3daConfig: Data
    ) {
        precondition(
            configurationVersion == 1,
            "MPEGHConfigurationBox configurationVersion must be 1"
        )
        self.configurationVersion = configurationVersion
        self.profileLevelIndication = profileLevelIndication
        self.referenceChannelLayout = referenceChannelLayout
        self.mpegh3daConfig = mpegh3daConfig
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MPEGHConfigurationBox {
        let version = try reader.readUInt8()
        guard version == 1 else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "MPEGHConfigurationBox configurationVersion must be 1, got \(version)"
            )
        }
        let pliRaw = try reader.readUInt8()
        guard let pli = MPEGHProfileLevelIndication(rawValue: pliRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: Self.boxType,
                reason: "Unknown MPEG-H profileLevelIndication 0x\(String(pliRaw, radix: 16))"
            )
        }
        let referenceChannelLayout = try reader.readUInt8()
        let configLength = Int(try reader.readUInt16())
        let configBytes = try reader.readData(count: configLength)
        return MPEGHConfigurationBox(
            configurationVersion: version,
            profileLevelIndication: pli,
            referenceChannelLayout: referenceChannelLayout,
            mpegh3daConfig: configBytes
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt8(configurationVersion)
            body.writeUInt8(profileLevelIndication.rawValue)
            body.writeUInt8(referenceChannelLayout)
            body.writeUInt16(UInt16(mpegh3daConfig.count))
            body.writeData(mpegh3daConfig)
        }
    }
}

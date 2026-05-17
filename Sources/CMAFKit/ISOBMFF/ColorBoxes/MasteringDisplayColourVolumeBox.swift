// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MasteringDisplayColourVolumeBox (mdcv)
//
// Reference: ISO/IEC 14496-12 §12.1.6 + SMPTE ST 2086:2018.

import Foundation

/// Mastering-display colour-volume metadata box.
public struct MasteringDisplayColourVolumeBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "mdcv"

    public let metadata: MasteringDisplayColourVolume

    public init(metadata: MasteringDisplayColourVolume) {
        self.metadata = metadata
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> MasteringDisplayColourVolumeBox {
        let redX = try reader.readUInt16()
        let redY = try reader.readUInt16()
        let greenX = try reader.readUInt16()
        let greenY = try reader.readUInt16()
        let blueX = try reader.readUInt16()
        let blueY = try reader.readUInt16()
        let whitePointX = try reader.readUInt16()
        let whitePointY = try reader.readUInt16()
        let maxLumin = try reader.readUInt32()
        let minLumin = try reader.readUInt32()

        let metadata = MasteringDisplayColourVolume(
            displayPrimaryRedX: redX,
            displayPrimaryRedY: redY,
            displayPrimaryGreenX: greenX,
            displayPrimaryGreenY: greenY,
            displayPrimaryBlueX: blueX,
            displayPrimaryBlueY: blueY,
            whitePointX: whitePointX,
            whitePointY: whitePointY,
            maxDisplayMasteringLuminance: maxLumin,
            minDisplayMasteringLuminance: minLumin
        )
        return MasteringDisplayColourVolumeBox(metadata: metadata)
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt16(metadata.displayPrimaryRedX)
            body.writeUInt16(metadata.displayPrimaryRedY)
            body.writeUInt16(metadata.displayPrimaryGreenX)
            body.writeUInt16(metadata.displayPrimaryGreenY)
            body.writeUInt16(metadata.displayPrimaryBlueX)
            body.writeUInt16(metadata.displayPrimaryBlueY)
            body.writeUInt16(metadata.whitePointX)
            body.writeUInt16(metadata.whitePointY)
            body.writeUInt32(metadata.maxDisplayMasteringLuminance)
            body.writeUInt32(metadata.minDisplayMasteringLuminance)
        }
    }
}

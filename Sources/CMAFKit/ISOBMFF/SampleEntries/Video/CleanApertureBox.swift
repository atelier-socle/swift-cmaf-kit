// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CleanApertureBox (clap)
//
// Reference: ISO/IEC 14496-12 §12.1.4.

import Foundation

/// Clean aperture cropping rectangle.
///
/// Reference: ISO/IEC 14496-12 §12.1.4. The clean aperture defines a
/// rational sub-rectangle of the stored video frame that is meant to be
/// displayed without overscan.
public struct CleanApertureBox: ISOBox, Sendable, Equatable, Hashable {
    public static let boxType: FourCC = "clap"

    public let cleanApertureWidthN: UInt32
    public let cleanApertureWidthD: UInt32
    public let cleanApertureHeightN: UInt32
    public let cleanApertureHeightD: UInt32
    public let horizOffN: Int32
    public let horizOffD: UInt32
    public let vertOffN: Int32
    public let vertOffD: UInt32

    public init(
        cleanApertureWidthN: UInt32,
        cleanApertureWidthD: UInt32,
        cleanApertureHeightN: UInt32,
        cleanApertureHeightD: UInt32,
        horizOffN: Int32,
        horizOffD: UInt32,
        vertOffN: Int32,
        vertOffD: UInt32
    ) {
        self.cleanApertureWidthN = cleanApertureWidthN
        self.cleanApertureWidthD = cleanApertureWidthD
        self.cleanApertureHeightN = cleanApertureHeightN
        self.cleanApertureHeightD = cleanApertureHeightD
        self.horizOffN = horizOffN
        self.horizOffD = horizOffD
        self.vertOffN = vertOffN
        self.vertOffD = vertOffD
    }

    public static func parse(
        reader: inout BinaryReader,
        header: ISOBoxHeader,
        registry: BoxRegistry
    ) async throws -> CleanApertureBox {
        let cleanApertureWidthN = try reader.readUInt32()
        let cleanApertureWidthD = try reader.readUInt32()
        let cleanApertureHeightN = try reader.readUInt32()
        let cleanApertureHeightD = try reader.readUInt32()
        let horizOffN = try reader.readInt32()
        let horizOffD = try reader.readUInt32()
        let vertOffN = try reader.readInt32()
        let vertOffD = try reader.readUInt32()
        return CleanApertureBox(
            cleanApertureWidthN: cleanApertureWidthN,
            cleanApertureWidthD: cleanApertureWidthD,
            cleanApertureHeightN: cleanApertureHeightN,
            cleanApertureHeightD: cleanApertureHeightD,
            horizOffN: horizOffN,
            horizOffD: horizOffD,
            vertOffN: vertOffN,
            vertOffD: vertOffD
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeBox(type: Self.boxType) { body in
            body.writeUInt32(cleanApertureWidthN)
            body.writeUInt32(cleanApertureWidthD)
            body.writeUInt32(cleanApertureHeightN)
            body.writeUInt32(cleanApertureHeightD)
            body.writeInt32(horizOffN)
            body.writeUInt32(horizOffD)
            body.writeInt32(vertOffN)
            body.writeUInt32(vertOffD)
        }
    }
}

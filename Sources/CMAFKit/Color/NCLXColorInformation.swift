// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - NCLXColorInformation
//
// Reference: ISO/IEC 14496-12 §12.1.5 (colour information box, nclx
// variant). The on-wire layout is 4 bytes:
//   colour_primaries: UInt16
//   transfer_characteristics: UInt16
//   matrix_coefficients: UInt16
//   (full_range_flag: 1 bit) + 7 reserved bits

import Foundation

/// On-the-wire colour signalling for the `nclx` variant of the
/// `colr` box.
///
/// Reference: ISO/IEC 14496-12 §12.1.5. The three coding-independent
/// code points and the full-range flag are aligned with the values
/// defined in ISO/IEC 23001-8.
public struct NCLXColorInformation: Sendable, Hashable, Codable {
    public let colorPrimaries: ColorPrimaries
    public let transferCharacteristics: TransferCharacteristics
    public let matrixCoefficients: MatrixCoefficients
    public let fullRangeFlag: VideoFullRangeFlag

    public init(
        colorPrimaries: ColorPrimaries,
        transferCharacteristics: TransferCharacteristics,
        matrixCoefficients: MatrixCoefficients,
        fullRangeFlag: VideoFullRangeFlag
    ) {
        self.colorPrimaries = colorPrimaries
        self.transferCharacteristics = transferCharacteristics
        self.matrixCoefficients = matrixCoefficients
        self.fullRangeFlag = fullRangeFlag
    }

    /// Parse from the 4-byte payload of an `nclx`-variant `colr` box.
    public static func parse(reader: inout BinaryReader) throws -> NCLXColorInformation {
        let cpRaw = try reader.readUInt16()
        let tcRaw = try reader.readUInt16()
        let mcRaw = try reader.readUInt16()
        let frfByte = try reader.readUInt8()
        let frfRaw = (frfByte >> 7) & 0x01
        // 7 reserved bits ignored.

        guard cpRaw <= UInt16(UInt8.max),
            let colorPrimaries = ColorPrimaries(rawValue: UInt8(cpRaw))
        else {
            throw ISOBoxError.malformedFullBox(
                type: ColorInformationBox.boxType,
                reason: "Unknown colour_primaries value \(cpRaw)"
            )
        }
        guard tcRaw <= UInt16(UInt8.max),
            let transferCharacteristics = TransferCharacteristics(rawValue: UInt8(tcRaw))
        else {
            throw ISOBoxError.malformedFullBox(
                type: ColorInformationBox.boxType,
                reason: "Unknown transfer_characteristics value \(tcRaw)"
            )
        }
        guard mcRaw <= UInt16(UInt8.max),
            let matrixCoefficients = MatrixCoefficients(rawValue: UInt8(mcRaw))
        else {
            throw ISOBoxError.malformedFullBox(
                type: ColorInformationBox.boxType,
                reason: "Unknown matrix_coefficients value \(mcRaw)"
            )
        }
        guard let fullRangeFlag = VideoFullRangeFlag(rawValue: frfRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: ColorInformationBox.boxType,
                reason: "Unknown video_full_range_flag value \(frfRaw)"
            )
        }

        return NCLXColorInformation(
            colorPrimaries: colorPrimaries,
            transferCharacteristics: transferCharacteristics,
            matrixCoefficients: matrixCoefficients,
            fullRangeFlag: fullRangeFlag
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeUInt16(UInt16(colorPrimaries.rawValue))
        writer.writeUInt16(UInt16(transferCharacteristics.rawValue))
        writer.writeUInt16(UInt16(matrixCoefficients.rawValue))
        let frfByte: UInt8 = (fullRangeFlag.rawValue << 7) & 0x80
        writer.writeUInt8(frfByte)
    }
}

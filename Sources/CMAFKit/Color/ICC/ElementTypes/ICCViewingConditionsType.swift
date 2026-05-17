// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCViewingConditionsType
//
// Reference: ICC.1:2022 §10.31 (viewingConditionsType, signature 'view').
//
// Payload: two XYZNumber (illuminant + surround) + UInt32 illuminantType.

import Foundation

/// Viewing conditions type per ICC.1:2022 §10.31.
public struct ICCViewingConditionsType: Sendable, Hashable, Equatable, Codable {
    public let unconditionalIlluminant: ICCXYZNumber
    public let unconditionalSurround: ICCXYZNumber
    public let illuminantType: ICCMeasurementType.StandardIlluminant

    public init(
        unconditionalIlluminant: ICCXYZNumber,
        unconditionalSurround: ICCXYZNumber,
        illuminantType: ICCMeasurementType.StandardIlluminant
    ) {
        self.unconditionalIlluminant = unconditionalIlluminant
        self.unconditionalSurround = unconditionalSurround
        self.illuminantType = illuminantType
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCViewingConditionsType {
        let illuminant = try ICCXYZNumber.parse(reader: &reader)
        let surround = try ICCXYZNumber.parse(reader: &reader)
        let typeRaw = try reader.readUInt32()
        guard let type = ICCMeasurementType.StandardIlluminant(rawValue: typeRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC viewing condition illuminantType \(typeRaw)"
            )
        }
        return ICCViewingConditionsType(
            unconditionalIlluminant: illuminant,
            unconditionalSurround: surround,
            illuminantType: type
        )
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        unconditionalIlluminant.encode(to: &writer)
        unconditionalSurround.encode(to: &writer)
        writer.writeUInt32(illuminantType.rawValue)
    }
}

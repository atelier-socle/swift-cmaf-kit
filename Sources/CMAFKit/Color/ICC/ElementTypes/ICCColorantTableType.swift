// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCColorantTableType
//
// Reference: ICC.1:2022 §10.7 (colorantTableType, signature 'clrt').
//
// On-wire layout: UInt32 colorantCount + colorantCount × (32 bytes name
//   + 3 × UInt16 pcsCoord).

import Foundation

/// Colorant table type per ICC.1:2022 §10.7.
public struct ICCColorantTableType: Sendable, Hashable, Equatable, Codable {
    /// One colorant entry.
    public struct Colorant: Sendable, Hashable, Equatable, Codable {
        /// Colorant name, 32 bytes (null-padded ASCII or UTF-8).
        public let name: Data
        /// Three PCS coordinates (typically Lab or XYZ).
        public let pcsCoordinates: [UInt16]

        public init(name: Data, pcsCoordinates: [UInt16]) {
            precondition(name.count == 32, "ICC colorant name must be 32 bytes")
            precondition(pcsCoordinates.count == 3, "ICC colorant must have 3 PCS coordinates")
            self.name = name
            self.pcsCoordinates = pcsCoordinates
        }
    }

    public let colorants: [Colorant]

    public init(colorants: [Colorant]) {
        self.colorants = colorants
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCColorantTableType {
        let count = try reader.readUInt32()
        var colorants: [Colorant] = []
        colorants.reserveCapacity(Int(count))
        for _ in 0..<count {
            let name = try reader.readData(count: 32)
            let pcs0 = try reader.readUInt16()
            let pcs1 = try reader.readUInt16()
            let pcs2 = try reader.readUInt16()
            colorants.append(Colorant(name: name, pcsCoordinates: [pcs0, pcs1, pcs2]))
        }
        return ICCColorantTableType(colorants: colorants)
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt32(UInt32(colorants.count))
        for c in colorants {
            writer.writeData(c.name)
            for coord in c.pcsCoordinates {
                writer.writeUInt16(coord)
            }
        }
    }
}

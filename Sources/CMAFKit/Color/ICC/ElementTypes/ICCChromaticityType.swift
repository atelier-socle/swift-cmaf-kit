// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCChromaticityType
//
// Reference: ICC.1:2022 §10.5 (chromaticityType, signature 'chrm').
//
// On-wire layout: UInt16 channelCount + UInt16 phosphorOrColorant
//   + channelCount × (u16Fixed16 x + u16Fixed16 y).

import Foundation

/// Chromaticity type per ICC.1:2022 §10.5.
public struct ICCChromaticityType: Sendable, Hashable, Equatable, Codable {
    /// Phosphor or colorant code per ICC.1:2022 Table 36.
    public enum PhosphorOrColorant: UInt16, Sendable, Hashable, CaseIterable, Codable {
        case unknown = 0
        case itu_r_BT_709 = 1
        case smpte_RP_145_1994 = 2
        case ebu_Tech_3213_E = 3
        case p22 = 4
        case p3 = 5
        case itu_r_BT_2020 = 6
    }

    /// One chromaticity x/y coordinate pair.
    public struct ChromaticCoordinate: Sendable, Hashable, Equatable, Codable {
        public let x: ICCU16Fixed16Number
        public let y: ICCU16Fixed16Number
        public init(x: ICCU16Fixed16Number, y: ICCU16Fixed16Number) {
            self.x = x
            self.y = y
        }
    }

    public let phosphorOrColorant: PhosphorOrColorant
    public let coordinates: [ChromaticCoordinate]

    public init(phosphorOrColorant: PhosphorOrColorant, coordinates: [ChromaticCoordinate]) {
        self.phosphorOrColorant = phosphorOrColorant
        self.coordinates = coordinates
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCChromaticityType {
        let channelCount = try reader.readUInt16()
        let phosphorRaw = try reader.readUInt16()
        guard let phosphor = PhosphorOrColorant(rawValue: phosphorRaw) else {
            throw ISOBoxError.malformedFullBox(
                type: "colr",
                reason: "Unknown ICC chromaticity phosphorOrColorant \(phosphorRaw)"
            )
        }
        var coords: [ChromaticCoordinate] = []
        coords.reserveCapacity(Int(channelCount))
        for _ in 0..<channelCount {
            let x = try ICCU16Fixed16Number.parse(reader: &reader)
            let y = try ICCU16Fixed16Number.parse(reader: &reader)
            coords.append(ChromaticCoordinate(x: x, y: y))
        }
        return ICCChromaticityType(phosphorOrColorant: phosphor, coordinates: coords)
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt16(UInt16(coordinates.count))
        writer.writeUInt16(phosphorOrColorant.rawValue)
        for coord in coordinates {
            coord.x.encode(to: &writer)
            coord.y.encode(to: &writer)
        }
    }
}

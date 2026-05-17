// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCNamedColor2Type
//
// Reference: ICC.1:2022 §10.18 (namedColor2Type, signature 'ncl2').
//
// On-wire layout:
//   UInt32 vendorFlags
//   UInt32 colorCount
//   UInt32 deviceCoordinateCount
//   32 bytes prefix
//   32 bytes suffix
//   colorCount × (32 bytes name + 3 × UInt16 PCS + deviceCoordinateCount × UInt16)

import Foundation

/// Named colour 2 type per ICC.1:2022 §10.18.
public struct ICCNamedColor2Type: Sendable, Hashable, Equatable, Codable {
    /// One named-colour entry.
    public struct NamedColor: Sendable, Hashable, Equatable, Codable {
        /// 32-byte name suffix (null-padded ASCII).
        public let nameSuffix: Data
        /// Three PCS coordinates.
        public let pcsCoordinates: [UInt16]
        /// Device coordinates (length matches the outer
        /// ``ICCNamedColor2Type/deviceCoordinateCount``).
        public let deviceCoordinates: [UInt16]

        public init(nameSuffix: Data, pcsCoordinates: [UInt16], deviceCoordinates: [UInt16]) {
            precondition(nameSuffix.count == 32, "Named-color suffix must be 32 bytes")
            precondition(pcsCoordinates.count == 3, "Named-color requires 3 PCS coordinates")
            self.nameSuffix = nameSuffix
            self.pcsCoordinates = pcsCoordinates
            self.deviceCoordinates = deviceCoordinates
        }
    }

    public let vendorFlags: UInt32
    public let deviceCoordinateCount: UInt32
    /// 32-byte prefix shared by every named colour.
    public let prefix: Data
    /// 32-byte suffix shared by every named colour.
    public let suffix: Data
    public let colors: [NamedColor]

    public init(
        vendorFlags: UInt32,
        deviceCoordinateCount: UInt32,
        prefix: Data,
        suffix: Data,
        colors: [NamedColor]
    ) {
        precondition(prefix.count == 32, "Named-color prefix must be 32 bytes")
        precondition(suffix.count == 32, "Named-color suffix must be 32 bytes")
        self.vendorFlags = vendorFlags
        self.deviceCoordinateCount = deviceCoordinateCount
        self.prefix = prefix
        self.suffix = suffix
        self.colors = colors
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCNamedColor2Type {
        let vendorFlags = try reader.readUInt32()
        let colorCount = try reader.readUInt32()
        let deviceCoordinateCount = try reader.readUInt32()
        let prefix = try reader.readData(count: 32)
        let suffix = try reader.readData(count: 32)

        var colors: [NamedColor] = []
        colors.reserveCapacity(Int(colorCount))
        for _ in 0..<colorCount {
            let name = try reader.readData(count: 32)
            var pcs: [UInt16] = []
            pcs.reserveCapacity(3)
            for _ in 0..<3 {
                pcs.append(try reader.readUInt16())
            }
            var device: [UInt16] = []
            device.reserveCapacity(Int(deviceCoordinateCount))
            for _ in 0..<deviceCoordinateCount {
                device.append(try reader.readUInt16())
            }
            colors.append(
                NamedColor(
                    nameSuffix: name,
                    pcsCoordinates: pcs,
                    deviceCoordinates: device
                ))
        }
        return ICCNamedColor2Type(
            vendorFlags: vendorFlags,
            deviceCoordinateCount: deviceCoordinateCount,
            prefix: prefix,
            suffix: suffix,
            colors: colors
        )
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt32(vendorFlags)
        writer.writeUInt32(UInt32(colors.count))
        writer.writeUInt32(deviceCoordinateCount)
        writer.writeData(prefix)
        writer.writeData(suffix)
        for color in colors {
            writer.writeData(color.nameSuffix)
            for pcs in color.pcsCoordinates {
                writer.writeUInt16(pcs)
            }
            for device in color.deviceCoordinates {
                writer.writeUInt16(device)
            }
        }
    }
}

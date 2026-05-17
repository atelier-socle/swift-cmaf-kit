// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCResponse16Number
//
// Reference: ICC.1:2022 §4.18 (response16Number). 8 bytes: UInt16 device
// value + UInt16 reserved + s15Fixed16Number measurement value.

import Foundation

/// Device-measurement pair per ICC.1:2022 §4.18.
public struct ICCResponse16Number: Sendable, Hashable, Codable {
    /// Device value in 0..65535.
    public let deviceValue: UInt16
    /// Measurement value as s15Fixed16Number.
    public let measurementValue: ICCS15Fixed16Number

    public init(deviceValue: UInt16, measurementValue: ICCS15Fixed16Number) {
        self.deviceValue = deviceValue
        self.measurementValue = measurementValue
    }

    public static func parse(reader: inout BinaryReader) throws -> ICCResponse16Number {
        let deviceValue = try reader.readUInt16()
        try reader.skip(2)  // reserved
        let measurementValue = try ICCS15Fixed16Number.parse(reader: &reader)
        return ICCResponse16Number(
            deviceValue: deviceValue,
            measurementValue: measurementValue
        )
    }

    public func encode(to writer: inout BinaryWriter) {
        writer.writeUInt16(deviceValue)
        writer.writeZeros(2)
        measurementValue.encode(to: &writer)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCXYZNumber
//
// Reference: ICC.1:2022 §4.20 (XYZNumber). 12 bytes: three s15Fixed16Number.

import Foundation

/// CIE XYZ tristimulus value per ICC.1:2022 §4.20.
public struct ICCXYZNumber: Sendable, Hashable, Codable {
    public let x: ICCS15Fixed16Number
    public let y: ICCS15Fixed16Number
    public let z: ICCS15Fixed16Number

    public init(x: ICCS15Fixed16Number, y: ICCS15Fixed16Number, z: ICCS15Fixed16Number) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static func parse(reader: inout BinaryReader) throws -> ICCXYZNumber {
        let x = try ICCS15Fixed16Number.parse(reader: &reader)
        let y = try ICCS15Fixed16Number.parse(reader: &reader)
        let z = try ICCS15Fixed16Number.parse(reader: &reader)
        return ICCXYZNumber(x: x, y: y, z: z)
    }

    public func encode(to writer: inout BinaryWriter) {
        x.encode(to: &writer)
        y.encode(to: &writer)
        z.encode(to: &writer)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCCurveType
//
// Reference: ICC.1:2022 §10.6 (curveType, signature 'curv').
//
// On-wire layout: UInt32 count + count × UInt16. When count == 0 the
// curve is the identity; when count == 1 the single UInt16 is a u8.8
// gamma value; otherwise the values define a sampled tone-reproduction
// curve.

import Foundation

/// Curve type per ICC.1:2022 §10.6.
public struct ICCCurveType: Sendable, Hashable, Equatable, Codable {
    public let values: [UInt16]

    public init(values: [UInt16]) {
        self.values = values
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCCurveType {
        let count = try reader.readUInt32()
        var values: [UInt16] = []
        values.reserveCapacity(Int(count))
        for _ in 0..<count {
            values.append(try reader.readUInt16())
        }
        return ICCCurveType(values: values)
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        writer.writeUInt32(UInt32(values.count))
        for v in values { writer.writeUInt16(v) }
    }

    /// `true` when this curve represents the identity transformation
    /// (count == 0).
    public var isIdentity: Bool { values.isEmpty }

    /// When the curve is a single u8.8 gamma value, returns that gamma;
    /// `nil` for identity and sampled curves.
    public var gammaValue: Double? {
        guard values.count == 1 else { return nil }
        return Double(values[0]) / 256.0
    }
}

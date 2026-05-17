// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCXYZType
//
// Reference: ICC.1:2022 §10.31 (XYZType). Each entry is 12 bytes
// (XYZNumber). The payload may contain multiple XYZ values.

import Foundation

/// One or more CIE XYZ values per ICC.1:2022 §10.31.
public struct ICCXYZType: Sendable, Hashable, Equatable, Codable {
    public let values: [ICCXYZNumber]

    public init(values: [ICCXYZNumber]) {
        self.values = values
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCXYZType {
        let entryCount = byteCount / 12
        var values: [ICCXYZNumber] = []
        values.reserveCapacity(entryCount)
        for _ in 0..<entryCount {
            values.append(try ICCXYZNumber.parse(reader: &reader))
        }
        return ICCXYZType(values: values)
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        for v in values {
            v.encode(to: &writer)
        }
    }
}

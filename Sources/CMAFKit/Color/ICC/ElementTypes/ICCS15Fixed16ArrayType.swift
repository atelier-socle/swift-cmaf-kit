// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCS15Fixed16ArrayType
//
// Reference: ICC.1:2022 §10.21 (s15Fixed16ArrayType, signature 'sf32').
// Each entry is 4 bytes. Used by the chromatic adaptation tag and other
// places that need a packed array of signed 15.16 fixed-point numbers.

import Foundation

/// Array of `s15Fixed16Number` per ICC.1:2022 §10.21.
public struct ICCS15Fixed16ArrayType: Sendable, Hashable, Equatable, Codable {
    public let values: [ICCS15Fixed16Number]

    public init(values: [ICCS15Fixed16Number]) {
        self.values = values
    }

    public static func parsePayload(
        reader: inout BinaryReader,
        byteCount: Int
    ) throws -> ICCS15Fixed16ArrayType {
        let entryCount = byteCount / 4
        var values: [ICCS15Fixed16Number] = []
        values.reserveCapacity(entryCount)
        for _ in 0..<entryCount {
            values.append(try ICCS15Fixed16Number.parse(reader: &reader))
        }
        return ICCS15Fixed16ArrayType(values: values)
    }

    public func encodePayload(to writer: inout BinaryWriter) {
        for v in values {
            v.encode(to: &writer)
        }
    }
}

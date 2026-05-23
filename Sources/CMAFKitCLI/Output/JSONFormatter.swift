// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - JSONFormatter
//
// Reference: JSON output rendering for `cmafkit-cli` subcommands.
// Uses Foundation `JSONEncoder` with sorted keys and pretty
// printing so the output is deterministic and diff-friendly.

import Foundation

/// JSON rendering for cmafkit-cli output values.
public enum JSONFormatter {

    /// Encode an `Encodable` value as a UTF-8 JSON byte sequence.
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dataEncodingStrategy = .base64
        return try encoder.encode(value)
    }

    /// Encode an `Encodable` value as a UTF-8 String.
    public static func string<T: Encodable>(_ value: T) throws -> String {
        let bytes = try encode(value)
        return String(data: bytes, encoding: .utf8) ?? ""
    }
}

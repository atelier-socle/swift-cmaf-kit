// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TextFormatter
//
// Reference: plain-text rendering helpers shared across the
// cmafkit-cli subcommands.

import Foundation

/// Plain-text rendering helpers for cmafkit-cli output.
public enum TextFormatter {

    /// Render a `key: value` line with consistent spacing.
    public static func keyValue(_ key: String, _ value: String) -> String {
        "\(key): \(value)"
    }

    /// Render a header line followed by an underline of the same
    /// width.
    public static func header(_ title: String, underlineCharacter: Character = "─") -> String {
        let underline = String(repeating: String(underlineCharacter), count: title.count)
        return "\(title)\n\(underline)"
    }

    /// Render an array as a comma-separated list, or `(none)` when
    /// empty.
    public static func list(_ values: [String]) -> String {
        values.isEmpty ? "(none)" : values.joined(separator: ", ")
    }

    /// Render hex bytes as a lowercase string with no separator.
    public static func hex(_ bytes: Data) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

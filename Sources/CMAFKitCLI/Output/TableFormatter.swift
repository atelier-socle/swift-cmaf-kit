// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TableFormatter
//
// Reference: ASCII-table rendering shared across the cmafkit-cli
// subcommands. Columns are right-padded to the widest value in
// each column; separator is `|` with single-space gutters.

import Foundation

/// ASCII table rendering for cmafkit-cli output.
public enum TableFormatter {

    /// Render `headers` and `rows` as an ASCII table. Every row
    /// must have the same column count as `headers`.
    public static func render(headers: [String], rows: [[String]]) -> String {
        precondition(
            rows.allSatisfy { $0.count == headers.count },
            "Every table row must match the header column count"
        )
        let columnCount = headers.count
        var widths = headers.map { $0.count }
        for row in rows {
            for index in 0..<columnCount {
                widths[index] = max(widths[index], row[index].count)
            }
        }
        var lines: [String] = []
        lines.append(formatRow(headers, widths: widths))
        lines.append(separatorLine(widths: widths))
        for row in rows {
            lines.append(formatRow(row, widths: widths))
        }
        return lines.joined(separator: "\n")
    }

    private static func formatRow(_ cells: [String], widths: [Int]) -> String {
        var rendered = "| "
        for (index, cell) in cells.enumerated() {
            let padding = String(repeating: " ", count: widths[index] - cell.count)
            rendered += cell + padding
            if index < cells.count - 1 {
                rendered += " | "
            }
        }
        rendered += " |"
        return rendered
    }

    private static func separatorLine(widths: [Int]) -> String {
        var line = "|"
        for width in widths {
            line += String(repeating: "-", count: width + 2)
            line += "|"
        }
        return line
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CLIInput / CLIWrite
//
// Reference: shared I/O helpers across cmafkit-cli subcommands.
// `CLIInput` reads a file (or stdin via the `-` convention);
// `CLIWrite` renders typed values through the chosen output
// format.

import Foundation

/// Shared input reader for cmafkit-cli subcommands.
internal enum CLIInput {

    /// Read every byte from `path`. When `path == "-"` the bytes
    /// come from standard input.
    static func read(path: String) async throws -> Data {
        if path == "-" {
            return FileHandle.standardInput.readDataToEndOfFile()
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw CLIError.inputFileUnreadable(path: path)
        }
        return try Data(contentsOf: url)
    }
}

/// Shared writer for cmafkit-cli output rendering.
internal enum CLIWrite {

    /// Render a typed Codable report through the supplied output
    /// format and print it to standard output.
    static func render<T: Codable & TextRenderable>(
        report: T, format: OutputFormat
    ) throws {
        switch format {
        case .text:
            print(report.renderText())
        case .json:
            try print(JSONFormatter.string(report))
        case .table:
            print(report.renderTable())
        }
    }
}

/// Protocol implemented by every cmafkit-cli report value that
/// can render itself as text or as a table.
internal protocol TextRenderable {
    func renderText() -> String
    func renderTable() -> String
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - OutputFormat
//
// Reference: shared selector across every cmafkit-cli subcommand.
// The `--output` flag accepts one of these forms and the
// command's formatter renders the typed result accordingly.

import ArgumentParser

/// Output format selector for cmafkit-cli subcommands.
public enum OutputFormat: String, ExpressibleByArgument, Sendable, CaseIterable {
    /// Human-readable plain-text rendering.
    case text
    /// Newline-terminated JSON document (one record per stdout flush).
    case json
    /// ASCII table — columns separated by `|`, no styling.
    case table

    /// Default rendering when no `--output` flag is provided.
    public static let defaultFormat: OutputFormat = .text
}

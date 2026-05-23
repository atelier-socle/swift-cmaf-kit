// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CLIError
//
// Reference: cmafkit-cli operator-facing failures. Each case maps
// to a stable non-zero exit code so shell pipelines can branch on
// the failure class.

import ArgumentParser
import Foundation

/// Operator-facing failures surfaced by `cmafkit-cli` subcommands.
public enum CLIError: Error, Sendable, Equatable {
    /// The supplied input file path does not exist or cannot be read.
    case inputFileUnreadable(path: String)
    /// The supplied input bytes failed to parse as ISOBMFF / CMAF.
    case invalidInput(reason: String)
    /// A typed conformance validator reported one or more errors.
    case conformanceFailed(errorCount: Int)
    /// The supplied DRM system identifier is not recognised.
    case unknownDRMSystem(uuid: String)
    /// A typed DRM provider parser surfaced an error on the
    /// pssh.data bytes.
    case drmParseFailed(systemID: String, reason: String)
    /// The supplied output path already exists and `--force` was
    /// not specified.
    case outputExists(path: String)
}

extension CLIError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .inputFileUnreadable(let path):
            return "Cannot read input file: \(path)"
        case .invalidInput(let reason):
            return "Invalid CMAF / ISOBMFF input: \(reason)"
        case .conformanceFailed(let count):
            return "Conformance validator reported \(count) error\(count == 1 ? "" : "s")"
        case .unknownDRMSystem(let uuid):
            return "Unknown DRM system identifier: \(uuid)"
        case .drmParseFailed(let systemID, let reason):
            return "DRM parser (\(systemID)) failed: \(reason)"
        case .outputExists(let path):
            return "Output file already exists (use --force to overwrite): \(path)"
        }
    }
}

extension CLIError {
    /// Stable exit code per failure class.
    public var exitCode: Int32 {
        switch self {
        case .inputFileUnreadable: return 2
        case .invalidInput: return 3
        case .conformanceFailed: return 4
        case .unknownDRMSystem: return 5
        case .drmParseFailed: return 6
        case .outputExists: return 7
        }
    }
}

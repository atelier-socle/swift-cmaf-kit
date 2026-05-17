// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import CMAFKit

/// `cmafkit-cli` — command-line interface for CMAFKit.
///
/// Subcommands ship in the 0.1.0 release. The current binary prints its
/// version and exits; this stub will be replaced by the full subcommand
/// suite before tag.
@main
struct CMAFKitCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cmafkit-cli",
        abstract: "Inspect, validate, and operate on ISOBMFF / CMAF media.",
        version: CMAFKitVersion
    )

    func run() throws {
        print("cmafkit-cli \(CMAFKitVersion) — pre-release. Subcommands ship at 0.1.0.")
    }
}

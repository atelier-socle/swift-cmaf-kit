// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import CMAFKit

/// `cmafkit-cli` — command-line interface for CMAFKit.
///
/// Subcommands land in Session 12 per the primary spec §20.
@main
struct CMAFKitCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cmafkit-cli",
        abstract: "Inspect, validate, and operate on ISOBMFF / CMAF media.",
        version: CMAFKitVersion
    )

    func run() throws {
        print("cmafkit-cli \(CMAFKitVersion) — subcommands land in Session 12.")
    }
}

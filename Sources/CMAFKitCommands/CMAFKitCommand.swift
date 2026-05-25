// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - cmafkit-cli
//
// Reference: ArgumentParser AsyncParsableCommand root for the
// `cmafkit-cli` executable. Dispatches to four subcommands:
//   probe         — per-track metadata
//   validate      — conformance validator (cmaf / dash / llhls)
//   dump-tree     — ISOBMFF box hierarchy
//   decrypt-init  — typed DRM pssh init data (no decryption)
//
// The CLI is read-only by default: subcommands never modify their
// input file.

import ArgumentParser
import CMAFKit
import Foundation

/// Root command for `cmafkit-cli`.
public struct CMAFKitCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "cmafkit-cli",
        abstract: "Inspect, validate, and operate on ISOBMFF / CMAF media.",
        discussion: """
            cmafkit-cli ships four subcommands:
              probe         report per-track metadata for an init segment
              validate      run a CMAF / DASH / LL-HLS conformance validator
              dump-tree     print the ISOBMFF box hierarchy
              decrypt-init  decode typed DRM init data from pssh boxes

            Every subcommand is read-only and never modifies the input
            file. The CLI never handles decryption key material; the
            `decrypt-init` subcommand parses and prints initialisation
            data only.
            """,
        version: CMAFKitVersion,
        subcommands: [
            ProbeCommand.self,
            ValidateCommand.self,
            DumpTreeCommand.self,
            DecryptInitCommand.self
        ]
    )

    public init() {}
}

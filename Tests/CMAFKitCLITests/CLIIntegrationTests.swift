// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import Testing

@testable import CMAFKit
@testable import CMAFKitCLI

@Suite("CMAFKitCLI integration")
struct CLIIntegrationTests {

    @Test
    func rootCommandConfigurationCarriesVersion() {
        let config = CMAFKitCLI.configuration
        #expect(config.commandName == "cmafkit-cli")
        #expect(config.version == CMAFKitVersion)
    }

    @Test
    func rootCommandListsFourSubcommands() {
        let names = CMAFKitCLI.configuration.subcommands.map { $0._commandName }
        #expect(Set(names) == ["probe", "validate", "dump-tree", "decrypt-init"])
    }

    @Test
    func probeCommandAbstract() {
        #expect(ProbeCommand.configuration.abstract.contains("metadata"))
    }

    @Test
    func validateCommandAbstract() {
        #expect(ValidateCommand.configuration.abstract.contains("validator"))
    }

    @Test
    func dumpTreeCommandAbstract() {
        #expect(DumpTreeCommand.configuration.abstract.contains("hierarchy"))
    }

    @Test
    func decryptInitCommandAbstract() {
        #expect(DecryptInitCommand.configuration.abstract.contains("DRM"))
    }

    @Test
    func cliErrorDescriptionMentionsPath() {
        let error = CLIError.inputFileUnreadable(path: "/tmp/x.bin")
        #expect("\(error)".contains("/tmp/x.bin"))
    }

    @Test
    func cliErrorEqualityWorks() {
        let a = CLIError.invalidInput(reason: "x")
        let b = CLIError.invalidInput(reason: "x")
        let c = CLIError.invalidInput(reason: "y")
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func helpMessageForProbeIncludesUsage() {
        let help = ProbeCommand.helpMessage()
        #expect(help.contains("probe"))
    }

    @Test
    func helpMessageForValidateIncludesProfileOption() {
        let help = ValidateCommand.helpMessage()
        #expect(help.contains("--profile"))
    }
}

extension ParsableCommand {
    fileprivate static var _commandName: String {
        configuration.commandName ?? "\(self)".lowercased()
    }
}

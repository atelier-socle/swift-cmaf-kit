// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("Audio sample-entry registry integration")
struct AudioSampleEntryRegistryIntegrationTests {

    @Test
    func defaultRegistryDispatchesEverySampleEntry() async throws {
        let registry = await BoxRegistry.defaultRegistry()
        let types: [FourCC] = [
            "mp4a", "ac-3", "ec-3", "ac-4", "Opus", "fLaC",
            "mhm1", "mhm2", "enca"
        ]
        for type in types {
            let parser = await registry.parser(for: type)
            #expect(parser != nil, "Expected parser for \(type) in default registry")
        }
    }

    @Test
    func defaultRegistryDispatchesEveryConfigurationBox() async throws {
        let registry = await BoxRegistry.defaultRegistry()
        let types: [FourCC] = [
            "dac3", "dec3", "dac4", "dOps", "dfLa", "mhaC", "mhaP"
        ]
        for type in types {
            let parser = await registry.parser(for: type)
            #expect(parser != nil, "Expected parser for \(type) in default registry")
        }
    }

    @Test
    func defaultRegistryDispatchesAudioExtensions() async throws {
        let registry = await BoxRegistry.defaultRegistry()
        for type in (["chnl", "srat"] as [FourCC]) {
            let parser = await registry.parser(for: type)
            #expect(parser != nil, "Expected parser for \(type) in default registry")
        }
    }
}

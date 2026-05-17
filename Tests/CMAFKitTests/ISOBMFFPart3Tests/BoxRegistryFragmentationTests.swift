// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Verifies that the default BoxRegistry exposes all fragmentation,
// indexing, sample-group, sample-auxiliary, and edit-list parsers.

import Foundation
import Testing

@testable import CMAFKit

@Suite("BoxRegistry fragmentation built-ins")
struct BoxRegistryFragmentationTests {

    @Test
    func registryExposesMvexFamily() async {
        let registry = await BoxRegistry.defaultRegistry()
        for fourCC: FourCC in ["mvex", "mehd", "trex"] {
            let parser = await registry.parser(for: fourCC)
            #expect(parser != nil, "registry missing \(fourCC)")
        }
    }

    @Test
    func registryExposesMoofFamily() async {
        let registry = await BoxRegistry.defaultRegistry()
        for fourCC: FourCC in ["moof", "mfhd", "traf", "tfhd", "tfdt", "trun"] {
            let parser = await registry.parser(for: fourCC)
            #expect(parser != nil, "registry missing \(fourCC)")
        }
    }

    @Test
    func registryExposesIndexFamily() async {
        let registry = await BoxRegistry.defaultRegistry()
        for fourCC: FourCC in ["sidx", "ssix", "pdin"] {
            let parser = await registry.parser(for: fourCC)
            #expect(parser != nil, "registry missing \(fourCC)")
        }
    }

    @Test
    func registryExposesMfraFamily() async {
        let registry = await BoxRegistry.defaultRegistry()
        for fourCC: FourCC in ["mfra", "tfra", "mfro"] {
            let parser = await registry.parser(for: fourCC)
            #expect(parser != nil, "registry missing \(fourCC)")
        }
    }

    @Test
    func registryExposesSampleGroupAndAuxiliaryAndEdit() async {
        let registry = await BoxRegistry.defaultRegistry()
        for fourCC: FourCC in ["sbgp", "sgpd", "saiz", "saio", "elst"] {
            let parser = await registry.parser(for: fourCC)
            #expect(parser != nil, "registry missing \(fourCC)")
        }
    }
}

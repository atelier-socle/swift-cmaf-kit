// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for BoxRegistry — actor-isolated FourCC-to-parser map.

import Foundation
import Testing

@testable import CMAFKit

@Suite("BoxRegistry")
struct BoxRegistryTests {

    @Test
    func defaultRegistryHasAllSession2Boxes() async {
        let registry = await BoxRegistry.defaultRegistry()
        let registered = await registry.registeredFourCCs
        let expected: Set<FourCC> = [
            "ftyp", "styp", "free", "skip", "mdat", "uuid",
            "moov", "trak", "mdia", "minf", "dinf", "stbl", "edts", "udta",
            "sinf", "frma", "schm", "schi",
            "mvhd", "tkhd", "mdhd", "hdlr"
        ]
        let actual = Set(registered)
        for fourCC in expected {
            #expect(actual.contains(fourCC), "registry missing \(fourCC)")
        }
    }

    @Test
    func emptyRegistryHasNoParsers() async {
        let registry = BoxRegistry()
        let parser = await registry.parser(for: "ftyp")
        #expect(parser == nil)
    }

    @Test
    func registerByTypeAddsParser() async {
        let registry = BoxRegistry()
        await registry.register(FileTypeBox.self) { reader, header, registry in
            try await FileTypeBox.parse(reader: &reader, header: header, registry: registry)
        }
        let parser = await registry.parser(for: "ftyp")
        #expect(parser != nil)
    }

    @Test
    func registerByFourCCAddsParser() async {
        let registry = BoxRegistry()
        await registry.register("free") { reader, header, registry in
            try await FreeSpaceBox.parse(reader: &reader, header: header, registry: registry)
        }
        let parser = await registry.parser(for: "free")
        #expect(parser != nil)
    }

    @Test
    func reRegisteringOverrides() async {
        let registry = BoxRegistry()
        await registry.register("free") { _, header, _ in
            UnknownBox(actualType: "free", header: header, payload: Data([0xAA]))
        }
        await registry.register("free") { _, header, _ in
            UnknownBox(actualType: "free", header: header, payload: Data([0xBB]))
        }
        let count = await registry.registeredFourCCs.filter { $0 == "free" }.count
        #expect(count == 1)
    }

    @Test
    func defaultRegistryFreeAndSkipBothMapped() async {
        let registry = await BoxRegistry.defaultRegistry()
        let freeParser = await registry.parser(for: "free")
        let skipParser = await registry.parser(for: "skip")
        #expect(freeParser != nil)
        #expect(skipParser != nil)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("URIMetadataSampleEntry (urim)")
struct URIMetadataSampleEntryTests {

    private func roundTrip(
        _ box: URIMetadataSampleEntry
    ) async throws -> URIMetadataSampleEntry {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? URIMetadataSampleEntry)
    }

    @Test
    func simpleURIRoundTrip() async throws {
        let entry = URIMetadataSampleEntry(
            uri: URIBox(uri: "urn:scte:scte35:2013:bin")
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.uri.uri == "urn:scte:scte35:2013:bin")
    }

    @Test
    func uriWithInitDataRoundTrip() async throws {
        let entry = URIMetadataSampleEntry(
            uri: URIBox(uri: "urn:example:scheme"),
            uriInit: URIInitBox(initData: Data([0xCA, 0xFE, 0xBA, 0xBE]))
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.uriInit?.initData == Data([0xCA, 0xFE, 0xBA, 0xBE]))
    }

    @Test
    func boxType() {
        #expect(URIMetadataSampleEntry.boxType == "urim")
        #expect(URIBox.boxType == "uri ")
        #expect(URIInitBox.boxType == "uriI")
    }

    @Test
    func registryParsersRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        #expect(await registry.parser(for: "urim") != nil)
        #expect(await registry.parser(for: "uri ") != nil)
        #expect(await registry.parser(for: "uriI") != nil)
    }

    @Test
    func missingURIBoxRejects() async {
        var writer = BinaryWriter()
        writer.writeBox(type: "urim") { body in
            body.writeZeros(6)
            body.writeUInt16(1)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func longURIPreserved() async throws {
        let longURI = "https://example.org/" + String(repeating: "a", count: 500)
        let entry = URIMetadataSampleEntry(uri: URIBox(uri: longURI))
        let parsed = try await roundTrip(entry)
        #expect(parsed.uri.uri == longURI)
    }
}

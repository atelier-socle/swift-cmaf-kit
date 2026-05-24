// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ViewExtendedUsageBox")
struct ViewExtendedUsageBoxTests {

    @Test
    func fieldStorage() {
        let box = ViewExtendedUsageBox(
            viewIdentifier: 0x1234_5678,
            usageFlags: 0xDEAD_BEEF,
            extensionData: Data([0x01, 0x02])
        )
        #expect(box.viewIdentifier == 0x1234_5678)
        #expect(box.usageFlags == 0xDEAD_BEEF)
        #expect(box.extensionData == Data([0x01, 0x02]))
    }

    @Test
    func boxTypeIsVexu() {
        #expect(ViewExtendedUsageBox.boxType == "vexu")
    }

    @Test
    func roundTripLeftView() async throws {
        let box = ViewExtendedUsageBox(viewIdentifier: 0, usageFlags: 0x01)
        var writer = BinaryWriter()
        box.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry)
        let recovered = try #require(parsed.first as? ViewExtendedUsageBox)
        #expect(recovered == box)
    }

    @Test
    func roundTripRightView() async throws {
        let box = ViewExtendedUsageBox(viewIdentifier: 1, usageFlags: 0x02)
        var writer = BinaryWriter()
        box.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry)
        let recovered = try #require(parsed.first as? ViewExtendedUsageBox)
        #expect(recovered == box)
    }

    @Test
    func roundTripWithExtensionDataPreserved() async throws {
        let box = ViewExtendedUsageBox(
            viewIdentifier: 2,
            usageFlags: 0x04,
            extensionData: Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE])
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry)
        let recovered = try #require(parsed.first as? ViewExtendedUsageBox)
        #expect(recovered.extensionData == Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE]))
        #expect(recovered == box)
    }

    @Test
    func roundTripWithEmptyExtensionData() async throws {
        let box = ViewExtendedUsageBox(viewIdentifier: 3, usageFlags: 0x08)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // Body: 4-byte viewID + 4-byte usageFlags = 8 bytes. Plus 8-byte header.
        #expect(writer.data.count == 16)

        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry)
        let recovered = try #require(parsed.first as? ViewExtendedUsageBox)
        #expect(recovered.extensionData.isEmpty)
        #expect(recovered == box)
    }

    @Test
    func registryResolvesVexu() async throws {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "vexu")
        #expect(parser != nil)
    }

    @Test
    func parseRejectsBodySmallerThan8Bytes() async throws {
        // Forge a vexu box whose declared size is just the 8-byte header
        // (zero body). The parser should throw sizeSmallerThanHeader.
        let bytes = Data([
            0x00, 0x00, 0x00, 0x08,  // size = 8 (header only, no body)
            0x76, 0x65, 0x78, 0x75  // "vexu"
        ])
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func equatableAndHashable() {
        let a = ViewExtendedUsageBox(viewIdentifier: 0, usageFlags: 0x01)
        let b = ViewExtendedUsageBox(viewIdentifier: 0, usageFlags: 0x01)
        let c = ViewExtendedUsageBox(viewIdentifier: 1, usageFlags: 0x01)
        #expect(a == b)
        #expect(a != c)
        var ha = Hasher()
        a.hash(into: &ha)
        var hb = Hasher()
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
    }
}

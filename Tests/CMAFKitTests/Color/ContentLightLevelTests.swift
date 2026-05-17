// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ContentLightLevel")
struct ContentLightLevelTests {

    @Test
    func fieldStorage() {
        let clli = ContentLightLevel(
            maxContentLightLevel: 1000,
            maxPicAverageLightLevel: 400
        )
        #expect(clli.maxContentLightLevel == 1000)
        #expect(clli.maxPicAverageLightLevel == 400)
    }

    @Test
    func boxRoundTrip() async throws {
        let clli = ContentLightLevel(maxContentLightLevel: 4000, maxPicAverageLightLevel: 800)
        let box = ContentLightLevelBox(metadata: clli)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ContentLightLevelBox)
        #expect(parsed == box)
    }

    @Test
    func boxBodyIs4Bytes() {
        let clli = ContentLightLevel(maxContentLightLevel: 0, maxPicAverageLightLevel: 0)
        let box = ContentLightLevelBox(metadata: clli)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        #expect(writer.data.count == 12)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let clli = ContentLightLevel(maxContentLightLevel: 0x03E8, maxPicAverageLightLevel: 0x0190)
        let box = ContentLightLevelBox(metadata: clli)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(hex: "00 00 00 0C 63 6C 6C 69 03 E8 01 90")
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(hex: "00 00 00 0C 63 6C 6C 69 03 E8 01 90")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? ContentLightLevelBox)
        #expect(parsed.metadata.maxContentLightLevel == 1000)
        #expect(parsed.metadata.maxPicAverageLightLevel == 400)
    }

    @Test
    func hashableConformance() {
        let a = ContentLightLevel(maxContentLightLevel: 1000, maxPicAverageLightLevel: 400)
        let b = ContentLightLevel(maxContentLightLevel: 1000, maxPicAverageLightLevel: 400)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}

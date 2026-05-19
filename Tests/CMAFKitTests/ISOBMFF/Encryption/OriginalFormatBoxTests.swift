// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("OriginalFormatBox (frma)")
struct OriginalFormatBoxTests {

    private func roundTrip(_ box: OriginalFormatBox) async throws -> OriginalFormatBox {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? OriginalFormatBox)
    }

    @Test
    func avc1RoundTrip() async throws {
        let box = OriginalFormatBox(dataFormat: "avc1")
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func hvc1RoundTrip() async throws {
        let box = OriginalFormatBox(dataFormat: "hvc1")
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func mp4aRoundTrip() async throws {
        let box = OriginalFormatBox(dataFormat: "mp4a")
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func av01RoundTrip() async throws {
        let box = OriginalFormatBox(dataFormat: "av01")
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func vp09RoundTrip() async throws {
        let box = OriginalFormatBox(dataFormat: "vp09")
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func dtshRoundTrip() async throws {
        let box = OriginalFormatBox(dataFormat: "dtsh")
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func ac4RoundTrip() async throws {
        let box = OriginalFormatBox(dataFormat: "ac-4")
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func boxType() {
        #expect(OriginalFormatBox.boxType == "frma")
    }

    @Test
    func boxSizeIsTwelveBytes() async throws {
        let box = OriginalFormatBox(dataFormat: "avc1")
        var writer = BinaryWriter()
        box.encode(to: &writer)
        #expect(writer.data.count == 12)  // 8-byte header + 4-byte FourCC
    }

    @Test
    func registryParserIsRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "frma")
        #expect(parser != nil)
    }
}

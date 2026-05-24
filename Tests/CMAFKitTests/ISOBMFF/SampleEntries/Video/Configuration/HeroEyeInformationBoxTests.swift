// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HeroEyeInformationBox")
struct HeroEyeInformationBoxTests {

    @Test
    func boxTypeIsHero() {
        #expect(HeroEyeInformationBox.boxType == "hero")
    }

    @Test
    func roundTripNone() async throws {
        try await assertRoundTrip(HeroEyeInformationBox(heroEye: .none))
    }

    @Test
    func roundTripLeftEye() async throws {
        try await assertRoundTrip(HeroEyeInformationBox(heroEye: .leftEye))
    }

    @Test
    func roundTripRightEye() async throws {
        try await assertRoundTrip(HeroEyeInformationBox(heroEye: .rightEye))
    }

    @Test
    func boxBodyIs4BytesPlus8ByteHeader() {
        let box = HeroEyeInformationBox(heroEye: .leftEye)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        #expect(writer.data.count == 12)
    }

    @Test
    func registryResolvesHero() async throws {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "hero")
        #expect(parser != nil)
    }

    @Test
    func parseRejectsBodySmallerThan4Bytes() async throws {
        // Forge a hero box whose declared size is just the 8-byte header
        // (zero body). The parser requires ≥ 4 body bytes.
        let bytes = Data([
            0x00, 0x00, 0x00, 0x08,  // size = 8 (header only)
            0x68, 0x65, 0x72, 0x6F  // "hero"
        ])
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func parseRejectsUnknownHeroEyeValue() async throws {
        // size = 12, type = "hero", body = [0xFF, 0, 0, 0]. 0xFF is not
        // a defined HeroEye raw value (must be 0x00, 0x01, or 0x02).
        let bytes = Data([
            0x00, 0x00, 0x00, 0x0C,  // size = 12 (header + 4-byte body)
            0x68, 0x65, 0x72, 0x6F,  // "hero"
            0xFF, 0x00, 0x00, 0x00  // unknown heroEye value
        ])
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func equatableAndHashable() {
        let a = HeroEyeInformationBox(heroEye: .leftEye)
        let b = HeroEyeInformationBox(heroEye: .leftEye)
        let c = HeroEyeInformationBox(heroEye: .rightEye)
        #expect(a == b)
        #expect(a != c)
        var ha = Hasher()
        a.hash(into: &ha)
        var hb = Hasher()
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
    }

    @Test
    func allHeroEyeCases() {
        #expect(HeroEyeInformationBox.HeroEye.allCases.count == 3)
    }

    // MARK: - Helpers

    private func assertRoundTrip(
        _ box: HeroEyeInformationBox,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry)
        let recovered = try #require(
            parsed.first as? HeroEyeInformationBox,
            "parsed first box is not HeroEyeInformationBox",
            sourceLocation: sourceLocation
        )
        #expect(recovered == box, sourceLocation: sourceLocation)
    }
}

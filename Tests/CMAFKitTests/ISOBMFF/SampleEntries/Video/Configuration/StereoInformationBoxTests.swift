// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("StereoInformationBox")
struct StereoInformationBoxTests {

    @Test
    func boxTypeIsStri() {
        #expect(StereoInformationBox.boxType == "stri")
    }

    @Test
    func roundTripSideBySide() async throws {
        let box = StereoInformationBox(stereoArrangement: .sideBySide)
        try await assertRoundTrip(box)
    }

    @Test
    func roundTripTopBottom() async throws {
        let box = StereoInformationBox(stereoArrangement: .topBottom)
        try await assertRoundTrip(box)
    }

    @Test
    func roundTripFrameAlternating() async throws {
        let box = StereoInformationBox(stereoArrangement: .frameAlternating)
        try await assertRoundTrip(box)
    }

    @Test
    func roundTripStereoLayered() async throws {
        // Stereo-layered is the Apple Vision Pro Spatial Video arrangement.
        let box = StereoInformationBox(stereoArrangement: .stereoLayered)
        try await assertRoundTrip(box)
    }

    @Test
    func roundTripWithAllThreeDistances() async throws {
        let box = StereoInformationBox(
            stereoArrangement: .stereoLayered,
            interaxialDistanceMillimeters: 63.0,
            convergenceDistanceMillimeters: 2000.0,
            baselineDistanceMillimeters: 63.5
        )
        try await assertRoundTrip(box)
    }

    @Test
    func roundTripWithOnlyInteraxial() async throws {
        let box = StereoInformationBox(
            stereoArrangement: .sideBySide,
            interaxialDistanceMillimeters: 65.0
        )
        try await assertRoundTrip(box)
    }

    @Test
    func roundTripWithAllDistancesNil() async throws {
        let box = StereoInformationBox(stereoArrangement: .sideBySide)
        try await assertRoundTrip(box)
        #expect(box.interaxialDistanceMillimeters == nil)
        #expect(box.convergenceDistanceMillimeters == nil)
        #expect(box.baselineDistanceMillimeters == nil)
    }

    @Test
    func registryResolvesStri() async throws {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "stri")
        #expect(parser != nil)
    }

    @Test
    func parseRejectsBodySmallerThan4Bytes() async throws {
        let bytes = Data([
            0x00, 0x00, 0x00, 0x08,  // size = 8 (header only, no body)
            0x73, 0x74, 0x72, 0x69  // "stri"
        ])
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func parseRejectsUnknownStereoArrangement() async throws {
        // size = 12, type = "stri", body = [0xFF, 0, 0, 0]. 0xFF is not a
        // defined StereoArrangement raw value (must be 0x01..0x04).
        let bytes = Data([
            0x00, 0x00, 0x00, 0x0C,  // size = 12
            0x73, 0x74, 0x72, 0x69,  // "stri"
            0xFF, 0x00, 0x00, 0x00  // unknown arrangement
        ])
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func parseRejectsTruncatedDistanceWhenPresenceFlagSet() async throws {
        // Body declares interaxial flag set (0x01) but body is too short
        // to hold the 4-byte Float that should follow.
        let bytes = Data([
            0x00, 0x00, 0x00, 0x0C,  // size = 12 (header + 4 mandatory bytes)
            0x73, 0x74, 0x72, 0x69,  // "stri"
            0x01,  // arrangement = sideBySide
            0x01,  // presenceFlags = interaxial present
            0x00, 0x00  // reserved
            // ← 4-byte interaxial Float is missing
        ])
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func equatableAndHashable() {
        let a = StereoInformationBox(
            stereoArrangement: .stereoLayered,
            interaxialDistanceMillimeters: 63.0
        )
        let b = StereoInformationBox(
            stereoArrangement: .stereoLayered,
            interaxialDistanceMillimeters: 63.0
        )
        let c = StereoInformationBox(stereoArrangement: .sideBySide)
        #expect(a == b)
        #expect(a != c)
        var ha = Hasher()
        a.hash(into: &ha)
        var hb = Hasher()
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
    }

    @Test
    func allStereoArrangementCases() {
        #expect(StereoInformationBox.StereoArrangement.allCases.count == 4)
    }

    // MARK: - Helpers

    private func assertRoundTrip(
        _ box: StereoInformationBox,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let parsed = try await reader.readBoxes(from: writer.data, using: registry)
        let recovered = try #require(
            parsed.first as? StereoInformationBox,
            "parsed first box is not StereoInformationBox",
            sourceLocation: sourceLocation
        )
        #expect(recovered == box, sourceLocation: sourceLocation)
    }
}

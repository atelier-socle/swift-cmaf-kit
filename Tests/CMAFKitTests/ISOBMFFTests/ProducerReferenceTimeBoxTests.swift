// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ProducerReferenceTimeBox (prft)")
struct ProducerReferenceTimeBoxTests {

    private func roundTrip(
        _ box: ProducerReferenceTimeBox
    ) async throws -> ProducerReferenceTimeBox {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? ProducerReferenceTimeBox)
    }

    @Test
    func v1RoundTrip() async throws {
        let box = ProducerReferenceTimeBox(
            version: 1,
            referenceTrackID: 1,
            ntpTimestamp: 0xE93E_F36B_8000_0000,
            mediaDecodeTime: 90_000_000
        )
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func v0RoundTrip() async throws {
        let box = ProducerReferenceTimeBox(
            version: 0,
            referenceTrackID: 2,
            ntpTimestamp: 0xE93E_F36B_8000_0000,
            mediaDecodeTime: 12345
        )
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func unsupportedVersionRejected() async {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "prft", version: 2, flags: 0) { body in
            body.writeUInt32(1)
            body.writeUInt64(0)
            body.writeUInt64(0)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func boxType() {
        #expect(ProducerReferenceTimeBox.boxType == "prft")
    }

    @Test
    func registryParserIsRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "prft")
        #expect(parser != nil)
    }

    @Test
    func mediaDecodeTimeClampedFor32BitVersion() async throws {
        // Version 0 only has 32 bits — values above UInt32.max clamp.
        let box = ProducerReferenceTimeBox(
            version: 0,
            referenceTrackID: 1,
            ntpTimestamp: 0,
            mediaDecodeTime: UInt64(UInt32.max) + 100
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.mediaDecodeTime == UInt64(UInt32.max))
    }
}

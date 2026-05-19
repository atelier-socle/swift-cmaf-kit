// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("EventMessageBox (emsg)")
struct EventMessageBoxTests {

    private func roundTrip(_ box: EventMessageBox) async throws -> EventMessageBox {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? EventMessageBox)
    }

    @Test
    func v0RoundTrip() async throws {
        let box = EventMessageBox(
            schemeIDURI: "urn:mpeg:dash:event:2012",
            value: "1",
            timescale: 90_000,
            presentationTimeDelta: 0,
            eventDuration: 90_000,
            id: 42,
            messageData: Data([0xCA, 0xFE, 0xBA, 0xBE])
        )
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.version == 0)
    }

    @Test
    func v1RoundTrip() async throws {
        let box = EventMessageBox(
            timescale: 48_000,
            presentationTime: 1_440_000,
            eventDuration: 48_000,
            id: 100,
            schemeIDURI: "urn:ad-insertion:scte35:2025",
            value: "splice",
            messageData: Data([0x00, 0xFC, 0x00, 0x14])
        )
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.version == 1)
    }

    @Test
    func v0SchemePreservedExactly() async throws {
        let box = EventMessageBox(
            schemeIDURI: "https://example.org/event/2025",
            value: "",
            timescale: 1000,
            presentationTimeDelta: 0,
            eventDuration: 0,
            id: 1,
            messageData: Data()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.schemeIDURI == "https://example.org/event/2025")
        #expect(parsed.value.isEmpty)
    }

    @Test
    func v1WithEmptyMessageData() async throws {
        let box = EventMessageBox(
            timescale: 1000,
            presentationTime: 0,
            eventDuration: UInt32.max,
            id: 0,
            schemeIDURI: "urn:test",
            value: "v",
            messageData: Data()
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.messageData.isEmpty)
        #expect(parsed.eventDuration == UInt32.max)
    }

    @Test
    func unsupportedVersionRejected() async {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "emsg", version: 2, flags: 0) { _ in }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func boxType() {
        #expect(EventMessageBox.boxType == "emsg")
    }

    @Test
    func registryParserIsRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "emsg")
        #expect(parser != nil)
    }

    @Test
    func largeMessageDataPreserved() async throws {
        let payload = Data((0..<1024).map { UInt8($0 & 0xFF) })
        let box = EventMessageBox(
            timescale: 1000,
            presentationTime: 0,
            eventDuration: 1000,
            id: 1,
            schemeIDURI: "urn:test",
            value: "v",
            messageData: payload
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.messageData == payload)
    }

    @Test
    func v0AndV1ProduceDifferentBytes() {
        let v0 = EventMessageBox(
            schemeIDURI: "u",
            value: "v",
            timescale: 1,
            presentationTimeDelta: 0,
            eventDuration: 0,
            id: 0,
            messageData: Data()
        )
        let v1 = EventMessageBox(
            timescale: 1,
            presentationTime: 0,
            eventDuration: 0,
            id: 0,
            schemeIDURI: "u",
            value: "v",
            messageData: Data()
        )
        var w0 = BinaryWriter()
        v0.encode(to: &w0)
        var w1 = BinaryWriter()
        v1.encode(to: &w1)
        #expect(w0.data != w1.data)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CEA608SampleEntry + CEA708SampleEntry round-trip")
struct CCSampleEntryTests {

    private func roundTrip<E: SampleEntry>(_ entry: E) async throws -> E {
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? E)
    }

    @Test
    func cea608SingleChannelRoundTrip() async throws {
        let entry = CEA608SampleEntry(channels: [.cc1])
        let parsed = try await roundTrip(entry)
        #expect(parsed.channels == [.cc1])
    }

    @Test
    func cea608AllFourChannelsRoundTrip() async throws {
        let entry = CEA608SampleEntry(channels: [.cc1, .cc2, .cc3, .cc4])
        let parsed = try await roundTrip(entry)
        #expect(Set(parsed.channels) == [.cc1, .cc2, .cc3, .cc4])
    }

    @Test
    func cea608WithBitRateRoundTrip() async throws {
        let entry = CEA608SampleEntry(
            channels: [.cc1],
            bitRate: BitRateBox(bufferSizeDB: 100, maxBitrate: 100, avgBitrate: 50)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.bitRate?.avgBitrate == 50)
    }

    @Test
    func cea608BoxType() {
        #expect(CEA608SampleEntry.boxType == "c608")
    }

    @Test
    func cea608RegistryParserRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        #expect(await registry.parser(for: "c608") != nil)
    }

    @Test
    func cea708SingleServiceRoundTrip() async throws {
        let entry = CEA708SampleEntry(services: [.service1])
        let parsed = try await roundTrip(entry)
        #expect(parsed.services == [.service1])
    }

    @Test
    func cea708MultipleServicesRoundTrip() async throws {
        let entry = CEA708SampleEntry(
            services: [.service1, .service2, .service63]
        )
        let parsed = try await roundTrip(entry)
        #expect(Set(parsed.services) == [.service1, .service2, .service63])
    }

    @Test
    func cea708WithBitRateRoundTrip() async throws {
        let entry = CEA708SampleEntry(
            services: [.service1, .service2],
            bitRate: BitRateBox(bufferSizeDB: 200, maxBitrate: 4_000, avgBitrate: 2_000)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.bitRate?.maxBitrate == 4_000)
    }

    @Test
    func cea708BoxType() {
        #expect(CEA708SampleEntry.boxType == "c708")
    }

    @Test
    func cea708RegistryParserRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        #expect(await registry.parser(for: "c708") != nil)
    }

    @Test
    func cea608DataReferenceIndexExposed() {
        let entry = CEA608SampleEntry(
            visualFields: VisualSampleEntryFields(
                dataReferenceIndex: 7,
                width: 0,
                height: 0
            ),
            channels: [.cc1]
        )
        #expect(entry.dataReferenceIndex == 7)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("XMLSubtitleSampleEntry (stpp)")
struct XMLSubtitleSampleEntryTests {

    private func roundTrip(
        _ box: XMLSubtitleSampleEntry
    ) async throws -> XMLSubtitleSampleEntry {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? XMLSubtitleSampleEntry)
    }

    @Test
    func ttmlTextRoundTrip() async throws {
        let entry = XMLSubtitleSampleEntry(
            namespace: "http://www.w3.org/ns/ttml",
            schemaLocation: "",
            auxiliaryMIMETypes: "application/ttml+xml;codecs=\"im1t\""
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed == entry)
    }

    @Test
    func imsc1TextRoundTrip() async throws {
        let entry = XMLSubtitleSampleEntry(
            namespace: "http://www.w3.org/ns/ttml",
            schemaLocation: "",
            auxiliaryMIMETypes: "application/ttml+xml;codecs=\"im1t\""
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.namespace == "http://www.w3.org/ns/ttml")
    }

    @Test
    func imsc1ImageRoundTrip() async throws {
        let entry = XMLSubtitleSampleEntry(
            namespace: "http://www.w3.org/ns/ttml",
            schemaLocation: "",
            auxiliaryMIMETypes: "application/ttml+xml;codecs=\"im1i\";image/png"
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.auxiliaryMIMETypes.contains("image/png"))
    }

    @Test
    func schemaLocationPreservedExactly() async throws {
        let entry = XMLSubtitleSampleEntry(
            namespace: "http://www.w3.org/ns/ttml",
            schemaLocation: "https://example.org/ttml-schema.xsd",
            auxiliaryMIMETypes: "application/ttml+xml"
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.schemaLocation == "https://example.org/ttml-schema.xsd")
    }

    @Test
    func bitRateChildRoundTrip() async throws {
        let entry = XMLSubtitleSampleEntry(
            namespace: "http://www.w3.org/ns/ttml",
            auxiliaryMIMETypes: "application/ttml+xml",
            bitRate: BitRateBox(bufferSizeDB: 1024, maxBitrate: 64_000, avgBitrate: 32_000)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.bitRate?.avgBitrate == 32_000)
    }

    @Test
    func emptyAuxiliaryMIMETypesAccepted() async throws {
        let entry = XMLSubtitleSampleEntry(
            namespace: "http://www.w3.org/ns/ttml",
            schemaLocation: "",
            auxiliaryMIMETypes: ""
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.auxiliaryMIMETypes.isEmpty)
    }

    @Test
    func boxType() {
        #expect(XMLSubtitleSampleEntry.boxType == "stpp")
    }

    @Test
    func registryParserRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        #expect(await registry.parser(for: "stpp") != nil)
    }

    @Test
    func dataReferenceIndexPreserved() async throws {
        let entry = XMLSubtitleSampleEntry(
            dataReferenceIndex: 3,
            namespace: "http://www.w3.org/ns/ttml",
            auxiliaryMIMETypes: ""
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.dataReferenceIndex == 3)
    }

    @Test
    func unicodeNamespaceRoundTrip() async throws {
        let entry = XMLSubtitleSampleEntry(
            namespace: "http://example.org/ns/字幕",
            schemaLocation: "",
            auxiliaryMIMETypes: ""
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.namespace == "http://example.org/ns/字幕")
    }

    @Test
    func byteForByteRoundTrip() async throws {
        let entry = XMLSubtitleSampleEntry(
            namespace: "http://www.w3.org/ns/ttml",
            auxiliaryMIMETypes: "application/ttml+xml"
        )
        var w1 = BinaryWriter()
        entry.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes {
            box.encode(to: &w2)
        }
        #expect(w1.data == w2.data)
    }

    @Test
    func equalityComparesAllFields() {
        let a = XMLSubtitleSampleEntry(
            namespace: "ns1",
            auxiliaryMIMETypes: "mime1"
        )
        let b = XMLSubtitleSampleEntry(
            namespace: "ns1",
            auxiliaryMIMETypes: "mime1"
        )
        let c = XMLSubtitleSampleEntry(
            namespace: "ns2",
            auxiliaryMIMETypes: "mime1"
        )
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func defaultDataReferenceIndexIsOne() {
        let entry = XMLSubtitleSampleEntry(
            namespace: "ns",
            auxiliaryMIMETypes: "mime"
        )
        #expect(entry.dataReferenceIndex == 1)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for the data reference family (dref + url + urn) — ISO/IEC 14496-12 §8.7.2.

import Foundation
import Testing

@testable import CMAFKit

// MARK: - dref

@Suite("DataReferenceBox")
struct DataReferenceBoxTests {

    @Test
    func emptyRoundTrip() async throws {
        let original = DataReferenceBox(entries: [])
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DataReferenceBox)
        #expect(parsed == original)
    }

    @Test
    func singleSelfContainedURL() async throws {
        let urlBox = DataEntryURLBox(selfContained: true, location: "")
        let dref = DataReferenceBox(entries: [urlBox])
        var writer = BinaryWriter()
        dref.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DataReferenceBox)
        #expect(parsed.entries.count == 1)
        let parsedURL = try #require(parsed.entries[0] as? DataEntryURLBox)
        #expect(parsedURL.isSelfContained)
        #expect(parsedURL.location.isEmpty)
    }

    @Test
    func externalURLPreservesLocation() async throws {
        let urlBox = DataEntryURLBox(selfContained: false, location: "file:///media.mp4")
        let dref = DataReferenceBox(entries: [urlBox])
        var writer = BinaryWriter()
        dref.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DataReferenceBox)
        let parsedURL = try #require(parsed.entries[0] as? DataEntryURLBox)
        #expect(parsedURL.location == "file:///media.mp4")
    }

    @Test
    func mixedSelfContainedAndExternal() async throws {
        let entries: [any ISOBox] = [
            DataEntryURLBox(selfContained: true, location: ""),
            DataEntryURLBox(selfContained: false, location: "https://example.com/media.mp4"),
            DataEntryURNBox(selfContained: false, name: "urn:example", location: "ref")
        ]
        let dref = DataReferenceBox(entries: entries)
        var writer = BinaryWriter()
        dref.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DataReferenceBox)
        #expect(parsed.entries.count == 3)
    }

    @Test
    func unknownEntryFallsBackToUnknownBox() async throws {
        // Build a dref containing an entry with an unregistered FourCC.
        var writer = BinaryWriter()
        writer.writeFullBox(type: "dref", version: 0, flags: 0) { body in
            body.writeUInt32(1)
            body.writeBox(type: "wxyz", body: Data([0x01, 0x02]))
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DataReferenceBox)
        #expect(parsed.entries[0] is UnknownBox)
    }

    @Test
    func equatableByEncodedBytes() {
        let a = DataReferenceBox(entries: [
            DataEntryURLBox(selfContained: true, location: "")
        ])
        let b = DataReferenceBox(entries: [
            DataEntryURLBox(selfContained: true, location: "")
        ])
        let c = DataReferenceBox(entries: [
            DataEntryURLBox(selfContained: false, location: "x")
        ])
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func entryCountFieldMatchesEntries() async throws {
        let dref = DataReferenceBox(entries: [
            DataEntryURLBox(selfContained: true, location: ""),
            DataEntryURLBox(selfContained: true, location: "")
        ])
        var writer = BinaryWriter()
        dref.encode(to: &writer)
        var reader = BinaryReader(writer.data, offset: 12)
        let count = try reader.readUInt32()
        #expect(count == 2)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 14 64 72 65 66 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        // dref(ver=0, flags=0, entry_count=1, url ' with self-contained flag, no body)
        // url body: ver=0, flags=0x00_0001 — total entry = 8+4 = 12
        // dref total = 8 + 4 + 4 + 12 = 28
        let originalBytes = Data(
            hex: """
                00 00 00 1C 64 72 65 66
                00 00 00 00
                00 00 00 01
                00 00 00 0C 75 72 6C 20 00 00 00 01
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? DataReferenceBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }
}

// MARK: - url

@Suite("DataEntryURLBox")
struct DataEntryURLBoxTests {

    @Test
    func selfContainedHasEmptyLocation() {
        let box = DataEntryURLBox(selfContained: true, location: "")
        #expect(box.isSelfContained)
        #expect(box.location.isEmpty)
        #expect(box.flags & DataEntryURLBox.flagSelfContained != 0)
    }

    @Test
    func externalHasNonEmptyLocation() {
        let box = DataEntryURLBox(selfContained: false, location: "https://example.com")
        #expect(!box.isSelfContained)
        #expect(box.location == "https://example.com")
        #expect(box.flags & DataEntryURLBox.flagSelfContained == 0)
    }

    @Test
    func roundTripSelfContained() async throws {
        let original = DataEntryURLBox(selfContained: true, location: "")
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DataEntryURLBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripExternal() async throws {
        let original = DataEntryURLBox(selfContained: false, location: "file:///path/to/media")
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DataEntryURLBox)
        #expect(parsed.location == "file:///path/to/media")
        #expect(!parsed.isSelfContained)
    }

    @Test
    func boxTypeIncludesTrailingSpace() {
        #expect(DataEntryURLBox.boxType.stringValue == "url ")
    }

    @Test
    func selfContainedEncodeHasNoLocationBytes() {
        let box = DataEntryURLBox(selfContained: true, location: "")
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) = 12
        #expect(writer.data.count == 12)
    }

    @Test
    func flagBitConstant() {
        #expect(DataEntryURLBox.flagSelfContained == 0x0000_0001)
    }
}

// MARK: - urn

@Suite("DataEntryURNBox")
struct DataEntryURNBoxTests {

    @Test
    func selfContainedHasEmptyNameAndLocation() {
        let box = DataEntryURNBox(selfContained: true, name: "", location: "")
        #expect(box.isSelfContained)
        #expect(box.name.isEmpty)
        #expect(box.location.isEmpty)
    }

    @Test
    func externalCarriesNameAndLocation() {
        let box = DataEntryURNBox(selfContained: false, name: "urn:foo", location: "ref")
        #expect(!box.isSelfContained)
        #expect(box.name == "urn:foo")
        #expect(box.location == "ref")
    }

    @Test
    func roundTripSelfContained() async throws {
        let original = DataEntryURNBox(selfContained: true, name: "", location: "")
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DataEntryURNBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripExternal() async throws {
        let original = DataEntryURNBox(
            selfContained: false,
            name: "urn:example:scheme",
            location: "secondary.mp4"
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? DataEntryURNBox)
        #expect(parsed.name == "urn:example:scheme")
        #expect(parsed.location == "secondary.mp4")
    }

    @Test
    func boxTypeIncludesTrailingSpace() {
        #expect(DataEntryURNBox.boxType.stringValue == "urn ")
    }

    @Test
    func selfContainedEncodeHasNoStringBytes() {
        let box = DataEntryURNBox(selfContained: true, name: "", location: "")
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) = 12
        #expect(writer.data.count == 12)
    }

    @Test
    func flagBitConstant() {
        #expect(DataEntryURNBox.flagSelfContained == 0x0000_0001)
    }
}

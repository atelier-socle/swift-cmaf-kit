// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SampleDescriptionBox (stsd) — ISO/IEC 14496-12 §8.5.2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleDescriptionBox")
struct SampleDescriptionBoxTests {

    @Test
    func emptyEntriesRoundTrip() async throws {
        let original = SampleDescriptionBox(entries: [])
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleDescriptionBox)
        #expect(parsed.entries.isEmpty)
    }

    @Test
    func singleRawSampleEntryRoundTrip() async throws {
        let entry = RawSampleEntry(
            format: "mp4a",
            dataReferenceIndex: 1,
            payload: Data([0x01, 0x02, 0x03, 0x04])
        )
        let original = SampleDescriptionBox(entries: [entry])
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleDescriptionBox)
        #expect(parsed.entries.count == 1)
        let parsedEntry = try #require(parsed.entries[0] as? RawSampleEntry)
        #expect(parsedEntry == entry)
    }

    @Test
    func multipleRawSampleEntriesPreserveOrder() async throws {
        let avc = RawSampleEntry(format: "avc1", dataReferenceIndex: 1, payload: Data([0xAA]))
        let hev = RawSampleEntry(format: "hvc1", dataReferenceIndex: 1, payload: Data([0xBB]))
        let original = SampleDescriptionBox(entries: [avc, hev])
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleDescriptionBox)
        #expect(parsed.entries.count == 2)
        let first = try #require(parsed.entries[0] as? RawSampleEntry)
        let second = try #require(parsed.entries[1] as? RawSampleEntry)
        #expect(first.format == "avc1")
        #expect(second.format == "hvc1")
    }

    @Test
    func unrecognisedFourCCFallsBackToRawSampleEntry() async throws {
        let entry = RawSampleEntry(
            format: "wxy1",
            dataReferenceIndex: 1,
            payload: Data([0x99])
        )
        let original = SampleDescriptionBox(entries: [entry])
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleDescriptionBox)
        #expect(parsed.entries[0] is RawSampleEntry)
    }

    @Test
    func entryCountFieldMatchesEntries() async throws {
        let entries: [any SampleEntry] = [
            RawSampleEntry(format: "abcd", dataReferenceIndex: 1, payload: Data()),
            RawSampleEntry(format: "efgh", dataReferenceIndex: 1, payload: Data()),
            RawSampleEntry(format: "ijkl", dataReferenceIndex: 1, payload: Data())
        ]
        let original = SampleDescriptionBox(entries: entries)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        // After 8-byte box header + 4-byte ver+flags, the next UInt32 is
        // the entry_count.
        var reader = BinaryReader(writer.data, offset: 12)
        let count = try reader.readUInt32()
        #expect(count == 3)
    }

    @Test
    func dataReferenceIndexPreservedPerEntry() async throws {
        let entry = RawSampleEntry(
            format: "wxy1",
            dataReferenceIndex: 42,
            payload: Data()
        )
        let original = SampleDescriptionBox(entries: [entry])
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleDescriptionBox)
        let parsedEntry = try #require(parsed.entries[0] as? RawSampleEntry)
        #expect(parsedEntry.dataReferenceIndex == 42)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 14 73 74 73 64 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }

    @Test
    func encodeMatchesKnownBytesEmpty() {
        let box = SampleDescriptionBox(entries: [])
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) + entry_count(4) = 16
        let expected = Data(hex: "00 00 00 10 73 74 73 64 00 00 00 00 00 00 00 00")
        #expect(writer.data == expected)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        // 1 RawSampleEntry: 4 size + 4 type + 6 reserved + 2 dri + 0 payload = 16 bytes entry.
        // stsd: 8 header + 4 ver+flags + 4 count + 16 entry = 32 (0x20).
        let originalBytes = Data(
            hex: """
                00 00 00 20 73 74 73 64
                00 00 00 00
                00 00 00 01
                00 00 00 10 77 78 79 31
                00 00 00 00 00 00 00 01
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? SampleDescriptionBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }

    @Test
    func sampleEntryProtocolMembers() {
        let entry: any SampleEntry = RawSampleEntry(
            format: "abcd",
            dataReferenceIndex: 7,
            payload: Data()
        )
        #expect(entry.dataReferenceIndex == 7)
    }
}

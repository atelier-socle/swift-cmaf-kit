// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SampleGroupDescriptionBox (sgpd) — ISO/IEC 14496-12 §8.9.3.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleGroupDescriptionBox")
struct SampleGroupDescriptionBoxTests {

    @Test
    func roundTripV2RollEntries() async throws {
        let entries: [any SampleGroupDescription] = [
            RollSampleGroupDescription(rollDistance: -10),
            RollSampleGroupDescription(rollDistance: 5)
        ]
        let original = SampleGroupDescriptionBox(
            groupingType: "roll",
            defaultSampleDescriptionIndex: 0,
            entries: entries
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)
        #expect(parsed.groupingType == "roll")
        #expect(parsed.entries.count == 2)
        let first = try #require(parsed.entries[0] as? RollSampleGroupDescription)
        let second = try #require(parsed.entries[1] as? RollSampleGroupDescription)
        #expect(first.rollDistance == -10)
        #expect(second.rollDistance == 5)
    }

    @Test
    func roundTripV2AudioPreRollEntries() async throws {
        let entries: [any SampleGroupDescription] = [
            AudioPreRollSampleGroupDescription(rollDistance: -1024)
        ]
        let original = SampleGroupDescriptionBox(
            groupingType: "prol",
            defaultSampleDescriptionIndex: 0,
            entries: entries
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)
        let entry = try #require(parsed.entries.first as? AudioPreRollSampleGroupDescription)
        #expect(entry.rollDistance == -1024)
    }

    @Test
    func roundTripV2RandomAccessPointEntries() async throws {
        let entries: [any SampleGroupDescription] = [
            RandomAccessPointSampleGroupDescription(numLeadingSamplesKnown: true, numLeadingSamples: 5),
            RandomAccessPointSampleGroupDescription(numLeadingSamplesKnown: false, numLeadingSamples: 0)
        ]
        let original = SampleGroupDescriptionBox(
            groupingType: "rap ",
            defaultSampleDescriptionIndex: 0,
            entries: entries
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)
        let first = try #require(parsed.entries[0] as? RandomAccessPointSampleGroupDescription)
        let second = try #require(parsed.entries[1] as? RandomAccessPointSampleGroupDescription)
        #expect(first.numLeadingSamplesKnown == true)
        #expect(first.numLeadingSamples == 5)
        #expect(second.numLeadingSamplesKnown == false)
    }

    @Test
    func roundTripV2CENCEntriesWithoutConstantIV() async throws {
        let kid = try #require(UUID(uuidString: "01020304-0506-0708-090A-0B0C0D0E0F10"))
        let entries: [any SampleGroupDescription] = [
            CENCSampleGroupDescription(
                cryptByteBlock: 0,
                skipByteBlock: 0,
                isProtected: 1,
                perSampleIVSize: 8,
                kid: kid,
                constantIV: Data()
            )
        ]
        let original = SampleGroupDescriptionBox(
            groupingType: "seig",
            defaultSampleDescriptionIndex: 1,
            entries: entries
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)
        let entry = try #require(parsed.entries.first as? CENCSampleGroupDescription)
        #expect(entry.kid == kid)
        #expect(entry.perSampleIVSize == 8)
        #expect(entry.isProtected == 1)
        #expect(entry.constantIV.isEmpty)
    }

    @Test
    func roundTripV2CENCEntriesWithConstantIV() async throws {
        let kid = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let constantIV = Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11])
        let entries: [any SampleGroupDescription] = [
            CENCSampleGroupDescription(
                cryptByteBlock: 1,
                skipByteBlock: 9,
                isProtected: 1,
                perSampleIVSize: 0,
                kid: kid,
                constantIV: constantIV
            )
        ]
        let original = SampleGroupDescriptionBox(
            groupingType: "seig",
            defaultSampleDescriptionIndex: 1,
            entries: entries
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)
        let entry = try #require(parsed.entries.first as? CENCSampleGroupDescription)
        #expect(entry.cryptByteBlock == 1)
        #expect(entry.skipByteBlock == 9)
        #expect(entry.constantIV == constantIV)
    }

    @Test
    func unknownGroupingTypeFallsBackToRaw() async throws {
        // v1 with defaultLength=4 and a custom grouping_type "abcd"
        // should fall through to RawSampleGroupDescription.
        let payload = Data([0x12, 0x34, 0x56, 0x78])
        let entries: [any SampleGroupDescription] = [
            RawSampleGroupDescription(payload: payload)
        ]
        let original = SampleGroupDescriptionBox(
            version: 1,
            groupingType: "abcd",
            defaultLength: 4,
            entries: entries
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)
        let entry = try #require(parsed.entries.first as? RawSampleGroupDescription)
        #expect(entry.payload == payload)
    }

    @Test
    func v1ZeroDefaultLengthUsesPerEntryPrefix() async throws {
        // v1 with default_length=0 means each entry has a 4-byte length prefix.
        let payload1 = Data([0xAA, 0xBB])
        let payload2 = Data([0xCC, 0xDD, 0xEE, 0xFF])
        let entries: [any SampleGroupDescription] = [
            RawSampleGroupDescription(payload: payload1),
            RawSampleGroupDescription(payload: payload2)
        ]
        let original = SampleGroupDescriptionBox(
            version: 1,
            groupingType: "abcd",
            defaultLength: 0,
            entries: entries
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)
        #expect(parsed.entries.count == 2)
        let first = try #require(parsed.entries[0] as? RawSampleGroupDescription)
        let second = try #require(parsed.entries[1] as? RawSampleGroupDescription)
        #expect(first.payload == payload1)
        #expect(second.payload == payload2)
    }

    @Test
    func defaultsToV2() {
        let box = SampleGroupDescriptionBox(
            groupingType: "roll",
            defaultSampleDescriptionIndex: 0,
            entries: []
        )
        #expect(box.version == 2)
    }

    @Test
    func malformedFullBoxErrorCaseExists() throws {
        // Ensures the ISOBoxError.malformedFullBox case is part of the
        // public surface and constructible with the expected payload
        // shape. This guards against accidental removal during future
        // enum refactors.
        let error = ISOBoxError.malformedFullBox(
            type: SampleGroupDescriptionBox.boxType,
            reason: "test"
        )
        switch error {
        case .malformedFullBox(let type, let reason):
            #expect(type == SampleGroupDescriptionBox.boxType)
            #expect(reason == "test")
        default:
            Issue.record("Expected malformedFullBox case")
        }
    }

    @Test
    func parseDoesNotSilentlyProduceEmptyPayloadForUnknownGroupingType() async throws {
        // Structural guard: under valid inputs, the unknown grouping_type
        // path always has a determinable budget. Exercise the v2 path
        // with an unrecognised grouping_type and a single raw entry to
        // confirm that the round-trip produces a non-empty payload when
        // the byte budget is well-defined (derived from the remaining
        // body bytes divided by the entry count).
        //
        // Reference: ISO/IEC 14496-12 §8.9.3.
        let payload = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        let box = SampleGroupDescriptionBox(
            version: 2,
            flags: 0,
            groupingType: "xxxx",
            defaultLength: nil,
            defaultSampleDescriptionIndex: 1,
            entries: [RawSampleGroupDescription(payload: payload)]
        )

        var writer = BinaryWriter()
        box.encode(to: &writer)

        let registry = await BoxRegistry.defaultRegistry()
        let isoBoxReader = ISOBoxReader()
        let boxes = try await isoBoxReader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)

        #expect(parsed.entries.count == 1)
        let parsedRaw = try #require(parsed.entries[0] as? RawSampleGroupDescription)
        #expect(parsedRaw.payload == payload)
        #expect(!parsedRaw.payload.isEmpty)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for RawSampleEntry — the byte-perfect fallback for unrecognised
// sample-entry FourCCs.

import Foundation
import Testing

@testable import CMAFKit

@Suite("RawSampleEntry")
struct SampleEntryTests {

    @Test
    func encodeRoundTrip() throws {
        let original = RawSampleEntry(
            format: "xyz1",
            dataReferenceIndex: 1,
            payload: Data([0xAA, 0xBB, 0xCC, 0xDD])
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        // size(4) + type(4) + reserved(6) + dataRefIndex(2) + payload(4) = 20 bytes
        #expect(writer.data.count == 20)

        // Re-parse via the internal parser path: skip the 8-byte box header.
        var reader = BinaryReader(writer.data, offset: 8)
        let parsed = try RawSampleEntry.parse(format: "xyz1", reader: &reader)
        #expect(parsed == original)
    }

    @Test
    func emptyPayload() throws {
        let original = RawSampleEntry(
            format: "test",
            dataReferenceIndex: 5,
            payload: Data()
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data, offset: 8)
        let parsed = try RawSampleEntry.parse(format: "test", reader: &reader)
        #expect(parsed.payload.isEmpty)
        #expect(parsed.dataReferenceIndex == 5)
    }

    @Test
    func preserveDataReferenceIndex() throws {
        for dri: UInt16 in [0, 1, 100, 0xFFFF] {
            let original = RawSampleEntry(
                format: "abcd",
                dataReferenceIndex: dri,
                payload: Data()
            )
            var writer = BinaryWriter()
            original.encode(to: &writer)
            var reader = BinaryReader(writer.data, offset: 8)
            let parsed = try RawSampleEntry.parse(format: "abcd", reader: &reader)
            #expect(parsed.dataReferenceIndex == dri)
        }
    }

    @Test
    func reservedBytesZeroOnEncode() {
        let entry = RawSampleEntry(
            format: "xyz1",
            dataReferenceIndex: 1,
            payload: Data()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        // Bytes 8..13 are the reserved area.
        for index in 8..<14 {
            #expect(writer.data[index] == 0)
        }
    }

    @Test
    func boxTypeSentinel() {
        #expect(RawSampleEntry.boxType == FourCC(0))
    }

    @Test
    func equatableComparesAllFields() {
        let a = RawSampleEntry(format: "abcd", dataReferenceIndex: 1, payload: Data([0x01]))
        let b = RawSampleEntry(format: "abcd", dataReferenceIndex: 1, payload: Data([0x01]))
        let c = RawSampleEntry(format: "abcd", dataReferenceIndex: 2, payload: Data([0x01]))
        let d = RawSampleEntry(format: "abcd", dataReferenceIndex: 1, payload: Data([0x02]))
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }
}

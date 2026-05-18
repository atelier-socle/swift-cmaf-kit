// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("VisualSampleEntryFields")
struct VisualSampleEntryFieldsTests {

    @Test
    func roundTripDefault1080p() throws {
        let fields = VisualSampleEntryFields(width: 1920, height: 1080)
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try VisualSampleEntryFields.parse(reader: &reader)
        #expect(decoded == fields)
    }

    @Test
    func roundTrip4K() throws {
        let fields = VisualSampleEntryFields(width: 3840, height: 2160, compressorName: "AVC Coding")
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try VisualSampleEntryFields.parse(reader: &reader)
        #expect(decoded.width == 3840)
        #expect(decoded.height == 2160)
        #expect(decoded.compressorName == "AVC Coding")
    }

    @Test
    func encodedSizeIs78Bytes() {
        let fields = VisualSampleEntryFields(width: 100, height: 100)
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        #expect(writer.data.count == 78)
    }

    @Test
    func defaultDpi72() {
        let fields = VisualSampleEntryFields(width: 100, height: 100)
        #expect(fields.horizResolution == 0x0048_0000)
        #expect(fields.vertResolution == 0x0048_0000)
    }

    @Test
    func defaultDepth24() {
        let fields = VisualSampleEntryFields(width: 100, height: 100)
        #expect(fields.depth == 0x0018)
    }

    @Test
    func compressorNameEmptyRoundTrip() throws {
        let fields = VisualSampleEntryFields(width: 100, height: 100, compressorName: "")
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try VisualSampleEntryFields.parse(reader: &reader)
        #expect(decoded.compressorName == "")
    }

    @Test
    func compressorName31CharsRoundTrip() throws {
        let name = String(repeating: "A", count: 31)
        let fields = VisualSampleEntryFields(width: 100, height: 100, compressorName: name)
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try VisualSampleEntryFields.parse(reader: &reader)
        #expect(decoded.compressorName == name)
    }

    @Test
    func parseRejectsNonZeroReserved() async throws {
        var bytes = Data(count: 78)
        bytes[0] = 0x01  // first SampleEntry reserved byte non-zero
        bytes[6] = 0x00
        bytes[7] = 0x01  // dataReferenceIndex
        bytes[76] = 0xFF
        bytes[77] = 0xFF  // preDefined4 = -1
        var reader = BinaryReader(bytes)
        #expect(throws: ISOBoxError.self) {
            _ = try VisualSampleEntryFields.parse(reader: &reader)
        }
    }

    @Test
    func parseRejectsFrameCountNotOne() async throws {
        let fields = VisualSampleEntryFields(width: 100, height: 100)
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var bytes = writer.data
        // frameCount lives at offset 40..41 inside the 78-byte payload.
        bytes[40] = 0
        bytes[41] = 2
        var reader = BinaryReader(bytes)
        #expect(throws: ISOBoxError.self) {
            _ = try VisualSampleEntryFields.parse(reader: &reader)
        }
    }

    @Test
    func parseRejectsPreDefined4NotMinusOne() async throws {
        let fields = VisualSampleEntryFields(width: 100, height: 100)
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var bytes = writer.data
        bytes[76] = 0
        bytes[77] = 0
        var reader = BinaryReader(bytes)
        #expect(throws: ISOBoxError.self) {
            _ = try VisualSampleEntryFields.parse(reader: &reader)
        }
    }

    @Test
    func dataReferenceIndexRoundTrip() throws {
        let fields = VisualSampleEntryFields(
            dataReferenceIndex: 7,
            width: 100,
            height: 100
        )
        var writer = BinaryWriter()
        fields.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try VisualSampleEntryFields.parse(reader: &reader)
        #expect(decoded.dataReferenceIndex == 7)
    }

    @Test
    func hashableConformance() {
        let a = VisualSampleEntryFields(width: 100, height: 200)
        let b = VisualSampleEntryFields(width: 100, height: 200)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func equalityDistinguishesWidth() {
        let a = VisualSampleEntryFields(width: 100, height: 100)
        let b = VisualSampleEntryFields(width: 101, height: 100)
        #expect(a != b)
    }
}

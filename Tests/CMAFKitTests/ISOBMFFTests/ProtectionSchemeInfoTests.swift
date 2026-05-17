// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for sinf + frma + schm + schi grouped in one file
// (ISO/IEC 14496-12 §8.12, ISO/IEC 23001-7 §8.1).

import Foundation
import Testing

@testable import CMAFKit

// MARK: - sinf

@Suite("ProtectionSchemeInfoBox (sinf)")
struct ProtectionSchemeInfoBoxTests {

    @Test
    func emptyRoundTrip() async throws {
        let header = ISOBoxHeader(type: "sinf", size: 8, headerSize: 8)
        let sinf = ProtectionSchemeInfoBox(header: header, children: [])
        var writer = BinaryWriter()
        sinf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is ProtectionSchemeInfoBox)
    }

    @Test
    func fullChildSetAccessors() {
        let header = ISOBoxHeader(type: "sinf", size: 0, headerSize: 8)
        let frma = OriginalFormatBox(dataFormat: "avc1")
        let schm = SchemeTypeBox(schemeType: "cenc", schemeVersion: 0x0001_0000)
        let schiHeader = ISOBoxHeader(type: "schi", size: 8, headerSize: 8)
        let schi = SchemeInformationBox(header: schiHeader, children: [])
        let sinf = ProtectionSchemeInfoBox(header: header, children: [frma, schm, schi])
        #expect(sinf.originalFormat?.dataFormat == "avc1")
        #expect(sinf.schemeType?.schemeType == "cenc")
        #expect(sinf.schemeInformation != nil)
    }

    @Test
    func partialChildrenAccessors() {
        let header = ISOBoxHeader(type: "sinf", size: 0, headerSize: 8)
        let frma = OriginalFormatBox(dataFormat: "hvc1")
        let sinf = ProtectionSchemeInfoBox(header: header, children: [frma])
        #expect(sinf.originalFormat?.dataFormat == "hvc1")
        #expect(sinf.schemeType == nil)
        #expect(sinf.schemeInformation == nil)
    }

    @Test
    func roundTripWithCompleteSchemeSubtree() async throws {
        let header = ISOBoxHeader(type: "sinf", size: 0, headerSize: 8)
        let frma = OriginalFormatBox(dataFormat: "avc1")
        let schm = SchemeTypeBox(schemeType: "cbcs", schemeVersion: 0x0001_0000)
        let schiHeader = ISOBoxHeader(type: "schi", size: 0, headerSize: 8)
        let tencHeader = ISOBoxHeader(type: "tenc", size: 12, headerSize: 8)
        let tenc = UnknownBox(actualType: "tenc", header: tencHeader, payload: Data([0x00, 0x00, 0x00, 0x00]))
        let schi = SchemeInformationBox(header: schiHeader, children: [tenc])
        let sinf = ProtectionSchemeInfoBox(header: header, children: [frma, schm, schi])

        var w1 = BinaryWriter()
        sinf.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)
        let parsedSinf = try #require(boxes.first as? ProtectionSchemeInfoBox)
        #expect(parsedSinf.schemeType?.schemeType == "cbcs")
    }

    @Test
    func childrenOrderPreserved() async throws {
        let header = ISOBoxHeader(type: "sinf", size: 0, headerSize: 8)
        let schiHeader = ISOBoxHeader(type: "schi", size: 8, headerSize: 8)
        let schi = SchemeInformationBox(header: schiHeader, children: [])
        let schm = SchemeTypeBox(schemeType: "cenc", schemeVersion: 0)
        let frma = OriginalFormatBox(dataFormat: "hvc1")
        // Intentionally reversed canonical order to verify preservation.
        let sinf = ProtectionSchemeInfoBox(header: header, children: [schi, schm, frma])

        var writer = BinaryWriter()
        sinf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ProtectionSchemeInfoBox)
        #expect(parsed.children.count == 3)
        #expect(parsed.children[0] is SchemeInformationBox)
        #expect(parsed.children[1] is SchemeTypeBox)
        #expect(parsed.children[2] is OriginalFormatBox)
    }

    @Test
    func absentAccessorsReturnNil() {
        let header = ISOBoxHeader(type: "sinf", size: 8, headerSize: 8)
        let sinf = ProtectionSchemeInfoBox(header: header, children: [])
        #expect(sinf.originalFormat == nil)
        #expect(sinf.schemeType == nil)
        #expect(sinf.schemeInformation == nil)
    }
}

// MARK: - frma

@Suite("OriginalFormatBox (frma)")
struct OriginalFormatBoxTests {

    @Test
    func roundTripAVC() async throws {
        let original = OriginalFormatBox(dataFormat: "avc1")
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? OriginalFormatBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripHEVC() async throws {
        let original = OriginalFormatBox(dataFormat: "hvc1")
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? OriginalFormatBox)
        #expect(parsed.dataFormat == "hvc1")
    }

    @Test
    func roundTripAudio() async throws {
        let original = OriginalFormatBox(dataFormat: "mp4a")
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? OriginalFormatBox)
        #expect(parsed.dataFormat == "mp4a")
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = OriginalFormatBox(dataFormat: "avc1")
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(hex: "00 00 00 0C 66 72 6D 61 61 76 63 31")
        #expect(writer.data == expected)
    }

    @Test
    func throwsOnTruncation() async throws {
        let bad = Data(hex: "00 00 00 0C 66 72 6D 61 61 76 63")  // 11 bytes
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: bad, using: registry)
        }
    }

    @Test
    func throwsOnSizeSmallerThanHeader() async throws {
        let bad = Data(hex: "00 00 00 04 66 72 6D 61")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bad, using: registry)
        }
    }
}

// MARK: - schm

@Suite("SchemeTypeBox (schm)")
struct SchemeTypeBoxTests {

    @Test
    func roundTripWithoutURI() async throws {
        let original = SchemeTypeBox(
            schemeType: "cenc",
            schemeVersion: 0x0001_0000,
            schemeURI: nil
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SchemeTypeBox)
        #expect(parsed == original)
        #expect(parsed.flags & SchemeTypeBox.flagURIPresent == 0)
    }

    @Test
    func roundTripWithURI() async throws {
        let uri = "urn:example:scheme"
        let original = SchemeTypeBox(
            schemeType: "cbcs",
            schemeVersion: 0x0001_0000,
            schemeURI: uri
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SchemeTypeBox)
        #expect(parsed.schemeURI == uri)
        #expect(parsed.flags & SchemeTypeBox.flagURIPresent == 1)
    }

    @Test
    func initEnforcesFlagBitConsistency() {
        // Passing nil URI clears bit 0 even when caller sets it.
        let cleared = SchemeTypeBox(
            flags: SchemeTypeBox.flagURIPresent,  // attempt to force the bit
            schemeType: "cenc",
            schemeVersion: 0,
            schemeURI: nil
        )
        #expect(cleared.flags & SchemeTypeBox.flagURIPresent == 0)

        // Passing a URI sets bit 0 even when caller clears it.
        let setBit = SchemeTypeBox(
            flags: 0,
            schemeType: "cenc",
            schemeVersion: 0,
            schemeURI: "uri"
        )
        #expect(setBit.flags & SchemeTypeBox.flagURIPresent == 1)
    }

    @Test
    func defaultVersionIsZero() {
        let box = SchemeTypeBox(schemeType: "cenc", schemeVersion: 0)
        #expect(box.version == 0)
    }

    @Test
    func roundTripAllFourCENCSchemes() async throws {
        for scheme: FourCC in ["cenc", "cbc1", "cens", "cbcs"] {
            let original = SchemeTypeBox(schemeType: scheme, schemeVersion: 0x0001_0000)
            var writer = BinaryWriter()
            original.encode(to: &writer)
            let registry = await BoxRegistry.defaultRegistry()
            let reader = ISOBoxReader()
            let boxes = try await reader.readBoxes(from: writer.data, using: registry)
            let parsed = try #require(boxes.first as? SchemeTypeBox)
            #expect(parsed.schemeType == scheme)
        }
    }

    @Test
    func throwsOnTruncation() async throws {
        let bad = Data(hex: "00 00 00 14 73 63 68 6D 00 00 00 00 63 65 6E")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: bad, using: registry)
        }
    }

    @Test
    func encodeMatchesKnownBytesWithoutURI() {
        let box = SchemeTypeBox(schemeType: "cenc", schemeVersion: 0x0001_0000)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) + schemeType(4) + schemeVersion(4) = 20
        let expected = Data(hex: "00 00 00 14 73 63 68 6D 00 00 00 00 63 65 6E 63 00 01 00 00")
        #expect(writer.data == expected)
    }
}

// MARK: - schi

@Suite("SchemeInformationBox (schi)")
struct SchemeInformationBoxTests {

    @Test
    func emptyRoundTrip() async throws {
        let header = ISOBoxHeader(type: "schi", size: 8, headerSize: 8)
        let schi = SchemeInformationBox(header: header, children: [])
        var writer = BinaryWriter()
        schi.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.first is SchemeInformationBox)
    }

    @Test
    func tencChildRoundTripsAsUnknown() async throws {
        // tenc is registered in a later session; here it round-trips via UnknownBox.
        let schiHeader = ISOBoxHeader(type: "schi", size: 0, headerSize: 8)
        let tencHeader = ISOBoxHeader(type: "tenc", size: 16, headerSize: 8)
        let tenc = UnknownBox(
            actualType: "tenc",
            header: tencHeader,
            payload: Data([0x00, 0x00, 0x01, 0x08, 0x10, 0x11, 0x12, 0x13])
        )
        let schi = SchemeInformationBox(header: schiHeader, children: [tenc])

        var w1 = BinaryWriter()
        schi.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)
    }

    @Test
    func multipleChildrenPreserved() async throws {
        let schiHeader = ISOBoxHeader(type: "schi", size: 0, headerSize: 8)
        let tencHeader = ISOBoxHeader(type: "tenc", size: 8, headerSize: 8)
        let tref = ISOBoxHeader(type: "trkr", size: 8, headerSize: 8)
        let children: [any ISOBox] = [
            UnknownBox(actualType: "tenc", header: tencHeader, payload: Data()),
            UnknownBox(actualType: "trkr", header: tref, payload: Data())
        ]
        let schi = SchemeInformationBox(header: schiHeader, children: children)

        var writer = BinaryWriter()
        schi.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SchemeInformationBox)
        #expect(parsed.children.count == 2)
    }

    @Test
    func emptyChildrenEncodesAsBareHeader() {
        let header = ISOBoxHeader(type: "schi", size: 8, headerSize: 8)
        let schi = SchemeInformationBox(header: header, children: [])
        var writer = BinaryWriter()
        schi.encode(to: &writer)
        #expect(Array(writer.data) == [0x00, 0x00, 0x00, 0x08, 0x73, 0x63, 0x68, 0x69])
    }

    @Test
    func roundTripPreservesByteSequence() async throws {
        let schiHeader = ISOBoxHeader(type: "schi", size: 0, headerSize: 8)
        let tencHeader = ISOBoxHeader(type: "tenc", size: 14, headerSize: 8)
        let tenc = UnknownBox(actualType: "tenc", header: tencHeader, payload: Data([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE]))
        let schi = SchemeInformationBox(header: schiHeader, children: [tenc])
        var w1 = BinaryWriter()
        schi.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        var w2 = BinaryWriter()
        for box in boxes { box.encode(to: &w2) }
        #expect(w1.data == w2.data)
    }
}

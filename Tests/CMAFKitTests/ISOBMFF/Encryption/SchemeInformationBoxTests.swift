// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("SchemeInformationBox (schi)")
struct SchemeInformationBoxTests {

    private static func makeTENC() -> TrackEncryptionBox {
        TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0xAA, count: 16))
        )
    }

    private func roundTrip(_ box: SchemeInformationBox) async throws -> SchemeInformationBox {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? SchemeInformationBox)
    }

    @Test
    func tencOnlyRoundTrip() async throws {
        let box = SchemeInformationBox(trackEncryption: Self.makeTENC())
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.trackEncryption != nil)
    }

    @Test
    func emptySchiRoundTrip() async throws {
        let box = SchemeInformationBox()
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.trackEncryption == nil)
        #expect(parsed.unknownChildren.isEmpty)
    }

    @Test
    func unknownChildrenPreservedVerbatim() async throws {
        var rawWriter = BinaryWriter()
        rawWriter.writeBox(type: "schi") { body in
            Self.makeTENC().encode(to: &body)
            // Synthetic unknown DRM child (FairPlay-style):
            body.writeUInt32(12)  // size
            body.writeFourCC("frpk")
            body.writeUInt32(0xDEAD_BEEF)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: rawWriter.data, using: registry)
        let parsed = try #require(boxes.first as? SchemeInformationBox)
        #expect(parsed.trackEncryption != nil)
        #expect(parsed.unknownChildren.count == 1)
        #expect(parsed.unknownChildren[0].boxType == "frpk")
    }

    @Test
    func multipleUnknownChildrenPreservedInOrder() async throws {
        var rawWriter = BinaryWriter()
        rawWriter.writeBox(type: "schi") { body in
            body.writeUInt32(10)
            body.writeFourCC("aaaa")
            body.writeData(Data([0x01, 0x02]))
            body.writeUInt32(10)
            body.writeFourCC("bbbb")
            body.writeData(Data([0x03, 0x04]))
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: rawWriter.data, using: registry)
        let parsed = try #require(boxes.first as? SchemeInformationBox)
        #expect(parsed.unknownChildren.count == 2)
        #expect(parsed.unknownChildren[0].boxType == "aaaa")
        #expect(parsed.unknownChildren[1].boxType == "bbbb")
    }

    @Test
    func unknownChildrenSurviveByteForByteRoundTrip() async throws {
        var rawWriter = BinaryWriter()
        rawWriter.writeBox(type: "schi") { body in
            body.writeUInt32(12)
            body.writeFourCC("xxxx")
            body.writeUInt32(0xCAFE_BABE)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: rawWriter.data, using: registry)
        let parsed = try #require(boxes.first as? SchemeInformationBox)
        var rewrite = BinaryWriter()
        parsed.encode(to: &rewrite)
        #expect(rawWriter.data == rewrite.data)
    }

    @Test
    func boxType() {
        #expect(SchemeInformationBox.boxType == "schi")
    }

    @Test
    func registryParserIsRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "schi")
        #expect(parser != nil)
    }

    @Test
    func equalityComparesAllFields() {
        let a = SchemeInformationBox(trackEncryption: Self.makeTENC())
        let b = SchemeInformationBox(trackEncryption: Self.makeTENC())
        let c = SchemeInformationBox(trackEncryption: nil)
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func tencFollowedByUnknownChildrenAllPreserved() async throws {
        let tenc = Self.makeTENC()
        var raw = BinaryWriter()
        raw.writeBox(type: "schi") { body in
            tenc.encode(to: &body)
            body.writeUInt32(10)
            body.writeFourCC("zzzz")
            body.writeData(Data([0xFE, 0xED]))
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: raw.data, using: registry)
        let parsed = try #require(boxes.first as? SchemeInformationBox)
        #expect(parsed.trackEncryption == tenc)
        #expect(parsed.unknownChildren.count == 1)
        #expect(parsed.unknownChildren[0].boxType == "zzzz")
    }

    @Test
    func unknownChildBeforeTENCStillRoutesTENC() async throws {
        let tenc = Self.makeTENC()
        var raw = BinaryWriter()
        raw.writeBox(type: "schi") { body in
            body.writeUInt32(10)
            body.writeFourCC("yyyy")
            body.writeData(Data([0x01, 0x02]))
            tenc.encode(to: &body)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: raw.data, using: registry)
        let parsed = try #require(boxes.first as? SchemeInformationBox)
        #expect(parsed.trackEncryption == tenc)
        #expect(parsed.unknownChildren.count == 1)
    }

    @Test
    func bodyBoundedSoTrailingBoxesAreNotConsumed() async throws {
        // Build a schi followed by another box at the outer level; the outer
        // reader must see both.
        let schi = SchemeInformationBox(trackEncryption: Self.makeTENC())
        let trailing = OriginalFormatBox(dataFormat: "avc1")
        var writer = BinaryWriter()
        schi.encode(to: &writer)
        trailing.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.count == 2)
        #expect(boxes[1] is OriginalFormatBox)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("SchemeTypeBox (schm)")
struct SchemeTypeBoxTests {

    private func roundTrip(_ box: SchemeTypeBox) async throws -> SchemeTypeBox {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? SchemeTypeBox)
    }

    @Test
    func cencRoundTrip() async throws {
        let box = SchemeTypeBox(schemeType: .cenc)
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.schemeType == .cenc)
    }

    @Test
    func cbc1RoundTrip() async throws {
        let box = SchemeTypeBox(schemeType: .cbc1)
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func censRoundTrip() async throws {
        let box = SchemeTypeBox(schemeType: .cens)
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func cbcsRoundTrip() async throws {
        let box = SchemeTypeBox(schemeType: .cbcs)
        #expect(try await roundTrip(box) == box)
    }

    @Test
    func schemeVersionMajorMinorRoundTrip() async throws {
        let box = SchemeTypeBox(
            schemeType: .cenc,
            schemeVersion: SchemeTypeBox.SchemeVersion(major: 1, minor: 0)
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.schemeVersion.major == 1)
        #expect(parsed.schemeVersion.minor == 0)
    }

    @Test
    func schemeVersionWithMinor() async throws {
        let box = SchemeTypeBox(
            schemeType: .cbcs,
            schemeVersion: SchemeTypeBox.SchemeVersion(major: 2, minor: 7)
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.schemeVersion.major == 2)
        #expect(parsed.schemeVersion.minor == 7)
    }

    @Test
    func schemeURIPresentSetsFlag() async throws {
        let box = SchemeTypeBox(
            schemeType: .cenc,
            schemeURI: "urn:mpeg:dash:mp4protection:2011"
        )
        #expect(box.flags & SchemeTypeBox.flagURIPresent != 0)
        let parsed = try await roundTrip(box)
        #expect(parsed.schemeURI == "urn:mpeg:dash:mp4protection:2011")
    }

    @Test
    func schemeURIAbsentClearsFlag() {
        let box = SchemeTypeBox(flags: 0xFFFF_FFFF, schemeType: .cenc, schemeURI: nil)
        #expect(box.flags & SchemeTypeBox.flagURIPresent == 0)
    }

    @Test
    func unknownSchemeFourCCThrows() async throws {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "schm", version: 0, flags: 0) { body in
            body.writeFourCC("ZZZZ")
            body.writeUInt32(0x0001_0000)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func boxType() {
        #expect(SchemeTypeBox.boxType == "schm")
    }

    @Test
    func registryParserIsRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "schm")
        #expect(parser != nil)
    }

    @Test
    func schemeVersionRawValueIsBigEndianPacked() {
        let version = SchemeTypeBox.SchemeVersion(major: 0x0102, minor: 0x0304)
        #expect(version.rawValue == 0x0102_0304)
    }

    @Test
    func schemeVersionFromRawValue() {
        let version = SchemeTypeBox.SchemeVersion(rawValue: 0xCAFE_BABE)
        #expect(version.major == 0xCAFE)
        #expect(version.minor == 0xBABE)
    }

    @Test
    func schemeURIByteForByteRoundTrip() async throws {
        let box = SchemeTypeBox(
            schemeType: .cbcs,
            schemeURI: "https://standards.example/cbcs-2026"
        )
        var w1 = BinaryWriter()
        box.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? SchemeTypeBox)
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func emptySchemeURITreatedAsPresent() async throws {
        let box = SchemeTypeBox(schemeType: .cenc, schemeURI: "")
        #expect(box.flags & SchemeTypeBox.flagURIPresent != 0)
        let parsed = try await roundTrip(box)
        #expect(parsed.schemeURI == "")
    }

    @Test
    func versionFieldDefaultsToZero() {
        let box = SchemeTypeBox(schemeType: .cenc)
        #expect(box.version == 0)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("MarlinInitData — parse + encode")
struct MarlinInitDataParsingTests {

    private static let kidHex = "abcdef0123456789aabbccddeeff0011"
    private static let kidBytes = Data([
        0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89,
        0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11
    ])

    @Test
    func parsesBBAOnly() throws {
        let urn = "urn:marlin:kid:\(Self.kidHex)"
        let bytes = Data(urn.utf8)
        let parsed = try MarlinInitData.parse(bytes)
        try #require(parsed.broadbandAssetIdentifier != nil)
        #expect(parsed.broadbandAssetIdentifier?.kid == Self.kidBytes)
        #expect(parsed.broadbandAssetIdentifier?.urn == urn)
        #expect(parsed.innerPayload.isEmpty)
    }

    @Test
    func parsesBBAWithInnerPayload() throws {
        let urn = "urn:marlin:kid:\(Self.kidHex)"
        var bytes = Data(urn.utf8)
        bytes.append(Data([0xCA, 0xFE, 0xBA, 0xBE]))
        let parsed = try MarlinInitData.parse(bytes)
        #expect(parsed.broadbandAssetIdentifier?.kid == Self.kidBytes)
        #expect(parsed.innerPayload == Data([0xCA, 0xFE, 0xBA, 0xBE]))
    }

    @Test
    func nonBBAPayloadPreservedAsInner() throws {
        // No recognised URN — entire buffer goes to innerPayload.
        let bytes = Data([0x00, 0x01, 0x02, 0x03])
        let parsed = try MarlinInitData.parse(bytes)
        #expect(parsed.broadbandAssetIdentifier == nil)
        #expect(parsed.innerPayload == bytes)
    }

    @Test
    func emptyPayloadParses() throws {
        let parsed = try MarlinInitData.parse(Data())
        #expect(parsed.broadbandAssetIdentifier == nil)
        #expect(parsed.innerPayload.isEmpty)
    }

    @Test
    func bbaRoundTripIsByteForByte() throws {
        let urn = "urn:marlin:kid:\(Self.kidHex)"
        let original = Data(urn.utf8)
        let parsed = try MarlinInitData.parse(original)
        let reencoded = try MarlinInitData.encode(parsed)
        #expect(reencoded == original)
    }

    @Test
    func bbaWithInnerRoundTripIsByteForByte() throws {
        let urn = "urn:marlin:kid:\(Self.kidHex)"
        var original = Data(urn.utf8)
        original.append(Data([0x99, 0xAA, 0xBB]))
        let parsed = try MarlinInitData.parse(original)
        let reencoded = try MarlinInitData.encode(parsed)
        #expect(reencoded == original)
    }

    @Test
    func opaqueRoundTripIsByteForByte() throws {
        let bytes = Data([0x10, 0x11, 0x12, 0x13])
        let parsed = try MarlinInitData.parse(bytes)
        let reencoded = try MarlinInitData.encode(parsed)
        #expect(reencoded == bytes)
    }

    @Test
    func nonHexKIDFallsBackToInnerPayload() throws {
        // URN prefix matches but the hex is invalid.
        let urn = "urn:marlin:kid:notvalid_hex_here_xyz_padded__"
        let bytes = Data(urn.utf8)
        let parsed = try MarlinInitData.parse(bytes)
        #expect(parsed.broadbandAssetIdentifier == nil)
        #expect(parsed.innerPayload == bytes)
    }

    @Test
    func systemIDPropagates() {
        #expect(MarlinInitData.systemID == .marlin)
    }
}

@Suite("MarlinInitData — fixtures")
struct MarlinInitDataFixturesTests {

    @Test
    func patternABBAOnly() throws {
        let kidHex = "0123456789abcdef0123456789abcdef"
        let urn = "urn:marlin:kid:\(kidHex)"
        let bytes = Data(urn.utf8)
        let parsed = try MarlinInitData.parse(bytes)
        #expect(parsed.broadbandAssetIdentifier?.urn == urn)
        #expect(try MarlinInitData.encode(parsed) == bytes)
    }

    @Test
    func patternABBAWithInner() throws {
        let kidHex = "11111111222222223333333344444444"
        let urn = "urn:marlin:kid:\(kidHex)"
        var bytes = Data(urn.utf8)
        bytes.append(Data([0xFE, 0xED, 0xFA, 0xCE]))
        let parsed = try MarlinInitData.parse(bytes)
        #expect(parsed.innerPayload == Data([0xFE, 0xED, 0xFA, 0xCE]))
        #expect(try MarlinInitData.encode(parsed) == bytes)
    }
}

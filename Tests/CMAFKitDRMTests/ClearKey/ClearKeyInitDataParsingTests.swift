// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("ClearKeyInitData — parse + encode")
struct ClearKeyInitDataParsingTests {

    private static func kid(_ marker: UInt8) -> Data {
        Data(repeating: marker, count: 16)
    }

    @Test
    func base64URLDecodeStripsPaddingAndRespellsCharset() {
        // The padded standard base64 "AAECAwQF" represents 6 bytes;
        // base64url "AAECAwQF" (no padding) decodes to the same bytes.
        let decoded = Base64URL.decode("AAECAwQF")
        #expect(decoded == Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]))
    }

    @Test
    func base64URLEncodeRemovesPaddingAndRespellsCharset() {
        let encoded = Base64URL.encode(Data([0xFB, 0xFF, 0xBF]))
        #expect(!encoded.contains("="))
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
    }

    @Test
    func base64URLDecodeRejectsRemainderOfOne() {
        // A base64url string with length % 4 == 1 is malformed —
        // no padding combination yields a valid 4-char group.
        #expect(Base64URL.decode("ABCDA") == nil)
    }

    @Test
    func temporarySingleKIDRoundTrip() throws {
        let original = ClearKeyInitData(kids: [Self.kid(0xAA)], type: .temporary)
        let encoded = try ClearKeyInitData.encode(original)
        let parsed = try ClearKeyInitData.parse(encoded)
        #expect(parsed == original)
    }

    @Test
    func persistentLicenseSingleKIDRoundTrip() throws {
        let original = ClearKeyInitData(kids: [Self.kid(0xBB)], type: .persistentLicense)
        let encoded = try ClearKeyInitData.encode(original)
        let parsed = try ClearKeyInitData.parse(encoded)
        #expect(parsed.type == .persistentLicense)
    }

    @Test
    func multipleKIDsRoundTrip() throws {
        let kids = (0..<3).map { Self.kid(UInt8(0x10 + $0)) }
        let original = ClearKeyInitData(kids: kids, type: .temporary)
        let encoded = try ClearKeyInitData.encode(original)
        let parsed = try ClearKeyInitData.parse(encoded)
        #expect(parsed.kids == kids)
    }

    @Test
    func malformedJSONThrows() {
        let payload = Data("{not json".utf8)
        #expect(throws: DRMSystemError.self) {
            _ = try ClearKeyInitData.parse(payload)
        }
    }

    @Test
    func emptyPayloadThrows() {
        #expect(throws: DRMSystemError.self) {
            _ = try ClearKeyInitData.parse(Data())
        }
    }

    @Test
    func unknownTypeValueThrows() {
        let payload = Data(#"{"kids":["AAECAwQFBgcICQoLDA0ODw"],"type":"forever"}"#.utf8)
        #expect(throws: DRMSystemError.self) {
            _ = try ClearKeyInitData.parse(payload)
        }
    }

    @Test
    func malformedBase64URLKidThrows() {
        // Length-1-mod-4 base64url is invalid.
        let payload = Data(#"{"kids":["ABCDA"],"type":"temporary"}"#.utf8)
        #expect(throws: DRMSystemError.self) {
            _ = try ClearKeyInitData.parse(payload)
        }
    }

    @Test
    func wrongKIDLengthAfterDecodeThrows() {
        // Decode("AAECAwQF") = 6 bytes (not 16).
        let payload = Data(#"{"kids":["AAECAwQF"],"type":"temporary"}"#.utf8)
        #expect(throws: DRMSystemError.self) {
            _ = try ClearKeyInitData.parse(payload)
        }
    }

    @Test
    func missingFieldsThrows() {
        let payload = Data(#"{"type":"temporary"}"#.utf8)
        #expect(throws: DRMSystemError.self) {
            _ = try ClearKeyInitData.parse(payload)
        }
    }

    @Test
    func unknownExtraFieldsTolerated() throws {
        // JSONDecoder by default ignores unknown keys.
        let payload = Data(
            #"""
            {"kids":["q6urq6urq6urq6urq6urqw"],"type":"temporary","x":1}
            """#.utf8
        )
        let parsed = try ClearKeyInitData.parse(payload)
        #expect(parsed.kids.count == 1)
    }

    @Test
    func canonicalEncoderEmitsSortedKeys() throws {
        let original = ClearKeyInitData(kids: [Self.kid(0xAB)], type: .temporary)
        let encoded = try ClearKeyInitData.encode(original)
        let string = String(data: encoded, encoding: .utf8) ?? ""
        // sortedKeys: "kids" before "type" alphabetically.
        guard let kidsPos = string.range(of: "kids"),
            let typePos = string.range(of: "type")
        else {
            Issue.record("Missing expected keys")
            return
        }
        #expect(kidsPos.lowerBound < typePos.lowerBound)
    }

    @Test
    func systemIDPropagates() {
        #expect(ClearKeyInitData.systemID == .clearKey)
    }
}

@Suite("ClearKeyInitData — fixtures")
struct ClearKeyInitDataFixturesTests {

    /// Pattern A — hand-built canonical JSON per W3C EME §9.
    @Test
    func patternASingleKIDTemporaryRoundTrip() throws {
        let kid = Data(repeating: 0xAB, count: 16)
        // base64url(0xAB * 16) without padding
        let encodedKID = Base64URL.encode(kid)
        let canonical = Data(
            "{\"kids\":[\"\(encodedKID)\"],\"type\":\"temporary\"}".utf8
        )
        let parsed = try ClearKeyInitData.parse(canonical)
        #expect(parsed.kids == [kid])
        #expect(parsed.type == .temporary)

        let reencoded = try ClearKeyInitData.encode(parsed)
        #expect(reencoded == canonical, "Pattern A round-trip must be byte-perfect")
    }

    /// Pattern B — synthesised W3C EME spec example with two KIDs
    /// (sample from EME §9 documentation).
    @Test
    func patternBTwoKIDsRoundTripsSemantically() throws {
        let kid1 = Data(repeating: 0x11, count: 16)
        let kid2 = Data(repeating: 0x22, count: 16)
        let json = """
            {  "kids" : [ "\(Base64URL.encode(kid1))", "\(Base64URL.encode(kid2))" ],
               "type" : "persistent-license" }
            """
        let parsed = try ClearKeyInitData.parse(Data(json.utf8))
        #expect(parsed.kids == [kid1, kid2])
        #expect(parsed.type == .persistentLicense)
        // Pattern B uses non-canonical whitespace; re-encode is
        // canonical but the parsed structure round-trips.
        let reencoded = try ClearKeyInitData.encode(parsed)
        let reparsed = try ClearKeyInitData.parse(reencoded)
        #expect(reparsed == parsed)
    }
}

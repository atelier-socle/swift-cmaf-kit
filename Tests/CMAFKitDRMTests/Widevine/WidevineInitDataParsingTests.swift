// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import CMAFKit
import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("WidevineInitData — parse + encode")
struct WidevineInitDataParsingTests {

    private static let kid1 = Data(repeating: 0xAB, count: 16)
    private static let kid2 = Data(repeating: 0xCD, count: 16)

    @Test
    func emptyPayloadParsesAsAllNilOptionalsAndEmptyKIDs() throws {
        let parsed = try WidevineInitData.parse(Data())
        #expect(parsed.algorithm == nil)
        #expect(parsed.keyIDs.isEmpty)
        #expect(parsed.provider == nil)
        #expect(parsed.contentID == nil)
        #expect(parsed.policy == nil)
        #expect(parsed.cryptoPeriodIndex == nil)
        #expect(parsed.groupedLicense == nil)
        #expect(parsed.protectionScheme == nil)
        #expect(parsed.cryptoPeriodSeconds == nil)
    }

    @Test
    func singleKIDRoundTrip() throws {
        let original = WidevineInitData(keyIDs: [Self.kid1])
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed == original)
    }

    @Test
    func multipleKIDsRoundTrip() throws {
        let original = WidevineInitData(keyIDs: [Self.kid1, Self.kid2])
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.keyIDs == [Self.kid1, Self.kid2])
    }

    @Test
    func malformedKIDLengthThrows() {
        // tag for field 2 (key_id, wire type 2) = 0x12; declared
        // length 4 (less than 16).
        let payload = Data([0x12, 0x04, 0xAA, 0xBB, 0xCC, 0xDD])
        #expect(throws: DRMSystemError.self) {
            _ = try WidevineInitData.parse(payload)
        }
    }

    @Test
    func algorithmAESCTRRoundTrip() throws {
        let original = WidevineInitData(algorithm: .aesCTR, keyIDs: [Self.kid1])
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.algorithm == .aesCTR)
    }

    @Test
    func algorithmUnencryptedRoundTrip() throws {
        let original = WidevineInitData(algorithm: .unencrypted)
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.algorithm == .unencrypted)
    }

    @Test
    func unknownAlgorithmValueThrows() {
        // field 1 (algorithm, wire type 0) tag = 0x08; varint value = 99
        let payload = Data([0x08, 0x63])
        #expect(throws: DRMSystemError.self) {
            _ = try WidevineInitData.parse(payload)
        }
    }

    @Test
    func providerRoundTrip() throws {
        let original = WidevineInitData(provider: "atelier-socle")
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.provider == "atelier-socle")
    }

    @Test
    func contentIDRoundTrip() throws {
        let original = WidevineInitData(contentID: Data([0xCA, 0xFE, 0xBA, 0xBE]))
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.contentID == Data([0xCA, 0xFE, 0xBA, 0xBE]))
    }

    @Test
    func trackTypeRoundTrip() throws {
        let original = WidevineInitData(trackType: "AUDIO")
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.trackType == "AUDIO")
    }

    @Test
    func policyRoundTrip() throws {
        let original = WidevineInitData(policy: "default-policy")
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.policy == "default-policy")
    }

    @Test
    func cryptoPeriodIndexRoundTrip() throws {
        let original = WidevineInitData(cryptoPeriodIndex: 12345)
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.cryptoPeriodIndex == 12345)
    }

    @Test
    func groupedLicenseRoundTrip() throws {
        let original = WidevineInitData(groupedLicense: Data([0xFF, 0xEE]))
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.groupedLicense == Data([0xFF, 0xEE]))
    }

    @Test
    func protectionSchemeCencRoundTrip() throws {
        let original = WidevineInitData(protectionScheme: .cenc)
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.protectionScheme == .cenc)
    }

    @Test
    func protectionSchemeCbcsRoundTrip() throws {
        let original = WidevineInitData(protectionScheme: .cbcs)
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.protectionScheme == .cbcs)
    }

    @Test
    func unknownProtectionSchemeFallsBackToRaw() throws {
        // field 9 (protection_scheme, wire type 0) tag = 0x48;
        // varint value = 0x12345678 (not a registered scheme).
        var writer = ProtocolBufferWriter()
        writer.writeVarintField(fieldNumber: 9, value: 0x1234_5678)
        let parsed = try WidevineInitData.parse(writer.data)
        #expect(parsed.protectionScheme == nil)
        #expect(parsed.protectionSchemeRaw == 0x1234_5678)
    }

    @Test
    func cryptoPeriodSecondsRoundTrip() throws {
        let original = WidevineInitData(cryptoPeriodSeconds: 3600)
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed.cryptoPeriodSeconds == 3600)
    }

    @Test
    func allFieldsSetRoundTrip() throws {
        let original = WidevineInitData(
            algorithm: .aesCTR,
            keyIDs: [Self.kid1, Self.kid2],
            provider: "test-provider",
            contentID: Data([0x01, 0x02, 0x03]),
            trackType: "VIDEO",
            policy: "policy-x",
            cryptoPeriodIndex: 5,
            groupedLicense: Data([0x99]),
            protectionScheme: .cenc,
            cryptoPeriodSeconds: 60
        )
        let encoded = try WidevineInitData.encode(original)
        let parsed = try WidevineInitData.parse(encoded)
        #expect(parsed == original)
    }

    @Test
    func unknownFieldNumberIsSkipped() throws {
        // field 11 (unknown, varint) tag = (11<<3)|0 = 0x58; value 1
        // then field 7 (cryptoPeriodIndex) tag 0x38 value 99
        let payload = Data([0x58, 0x01, 0x38, 0x63])
        let parsed = try WidevineInitData.parse(payload)
        #expect(parsed.cryptoPeriodIndex == 99)
    }

    @Test
    func truncatedVarintThrows() {
        // tag for field 7 (varint) then a high-bit-set byte
        // (continuation) followed by end-of-stream.
        let payload = Data([0x38, 0x80])
        #expect(throws: DRMSystemError.self) {
            _ = try WidevineInitData.parse(payload)
        }
    }

    @Test
    func nonUTF8StringFieldThrows() {
        // field 3 (provider, wire type 2) tag = 0x1A; length 2;
        // bytes 0xFF 0xFE (invalid UTF-8).
        let payload = Data([0x1A, 0x02, 0xFF, 0xFE])
        #expect(throws: DRMSystemError.self) {
            _ = try WidevineInitData.parse(payload)
        }
    }

    @Test
    func systemIDPropagatesToProtocol() {
        #expect(WidevineInitData.systemID == .widevine)
    }

    @Test
    func encodeFieldOrderIsAscending() throws {
        // Build with non-canonical construction; encode must emit
        // fields 1 → 10 ascending.
        let original = WidevineInitData(
            algorithm: .aesCTR,
            keyIDs: [Self.kid1],
            protectionScheme: .cenc,
            cryptoPeriodSeconds: 30
        )
        let encoded = try WidevineInitData.encode(original)
        var reader = ProtocolBufferReader(encoded)
        var fieldNumbersSeen: [UInt32] = []
        while reader.hasMore {
            let (fieldNumber, wireType) = try reader.readTag()
            fieldNumbersSeen.append(fieldNumber)
            try reader.skip(wireType: wireType)
        }
        #expect(fieldNumbersSeen == fieldNumbersSeen.sorted())
    }

    @Test
    func parserAndProtocolWitnessTypeAlignment() {
        #expect(WidevineInitData.self == WidevineInitData.TypedInitData.self)
    }
}

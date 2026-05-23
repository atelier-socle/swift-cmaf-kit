// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("FairPlayInitData — parse + encode")
struct FairPlayInitDataParsingTests {

    private static func kid(_ marker: UInt8) -> Data {
        Data(repeating: marker, count: 16)
    }

    @Test
    func singleKIDRoundTrip() throws {
        let original = FairPlayInitData(keyIDs: [Self.kid(0xAA)])
        let encoded = try FairPlayInitData.encode(original)
        let parsed = try FairPlayInitData.parse(encoded)
        #expect(parsed == original)
    }

    @Test
    func multipleKIDsRoundTrip() throws {
        let kids = (0..<4).map { Self.kid(0x10 + UInt8($0)) }
        let original = FairPlayInitData(keyIDs: kids)
        let encoded = try FairPlayInitData.encode(original)
        let parsed = try FairPlayInitData.parse(encoded)
        #expect(parsed.keyIDs == kids)
    }

    @Test
    func emptyKIDArrayRoundTrip() throws {
        let original = FairPlayInitData(keyIDs: [])
        let encoded = try FairPlayInitData.encode(original)
        let parsed = try FairPlayInitData.parse(encoded)
        #expect(parsed.keyIDs.isEmpty)
    }

    @Test
    func encodedBytesStartWithFormatVersion1() throws {
        let original = FairPlayInitData(keyIDs: [Self.kid(0xAB)])
        let encoded = try FairPlayInitData.encode(original)
        #expect(encoded.first == 0x01)
    }

    @Test
    func encodedBytesEncodeBigEndianKIDCount() throws {
        let original = FairPlayInitData(keyIDs: [
            Self.kid(0x11), Self.kid(0x22), Self.kid(0x33)
        ])
        let encoded = try FairPlayInitData.encode(original)
        // Bytes 1..4 carry big-endian UInt32 = 3.
        #expect(encoded[1] == 0x00)
        #expect(encoded[2] == 0x00)
        #expect(encoded[3] == 0x00)
        #expect(encoded[4] == 0x03)
    }

    @Test
    func tooShortPayloadThrows() {
        #expect(throws: DRMSystemError.self) {
            _ = try FairPlayInitData.parse(Data([0x01]))
        }
    }

    @Test
    func wrongFormatVersionThrows() {
        let payload = Data([0x02, 0x00, 0x00, 0x00, 0x00])
        #expect(throws: DRMSystemError.self) {
            _ = try FairPlayInitData.parse(payload)
        }
    }

    @Test
    func declaredCountExceedsBufferThrows() {
        // Format=1, count=2 but only 16 bytes of KID data (need 32).
        var bytes: [UInt8] = [0x01, 0x00, 0x00, 0x00, 0x02]
        bytes.append(contentsOf: Array(repeating: UInt8(0xAA), count: 16))
        #expect(throws: DRMSystemError.self) {
            _ = try FairPlayInitData.parse(Data(bytes))
        }
    }

    @Test
    func trailingBytesThrows() {
        var bytes: [UInt8] = [0x01, 0x00, 0x00, 0x00, 0x01]
        bytes.append(contentsOf: Array(repeating: UInt8(0xAA), count: 16))
        bytes.append(0xFF)  // unexpected trailing byte
        #expect(throws: DRMSystemError.self) {
            _ = try FairPlayInitData.parse(Data(bytes))
        }
    }

    @Test
    func emptyPayloadThrows() {
        #expect(throws: DRMSystemError.self) {
            _ = try FairPlayInitData.parse(Data())
        }
    }

    @Test
    func systemIDPropagates() {
        #expect(FairPlayInitData.systemID == .fairPlay)
    }

    @Test
    func encodeWithWrongFormatVersionThrows() {
        let value = FairPlayInitData(formatVersion: 9, keyIDs: [Self.kid(0xAA)])
        #expect(throws: DRMSystemError.self) {
            _ = try FairPlayInitData.encode(value)
        }
    }
}

@Suite("FairPlayInitData — fixtures")
struct FairPlayInitDataFixturesTests {

    /// Pattern A — hand-built canonical Modular DRM init data.
    @Test
    func patternASingleKIDRoundTrips() throws {
        let kid: [UInt8] = [
            0x12, 0x34, 0x56, 0x78,
            0x9A, 0xBC, 0xDE, 0xF0,
            0x11, 0x22, 0x33, 0x44,
            0x55, 0x66, 0x77, 0x88
        ]
        var bytes: [UInt8] = [0x01, 0x00, 0x00, 0x00, 0x01]
        bytes.append(contentsOf: kid)
        let parsed = try FairPlayInitData.parse(Data(bytes))
        #expect(parsed.keyIDs == [Data(kid)])

        let reencoded = try FairPlayInitData.encode(parsed)
        #expect(reencoded == Data(bytes), "Pattern A round-trip must be byte-perfect")
    }

    /// Pattern B — synthesized multi-KID fixture modelled on
    /// Apple Modular DRM examples in the public Apple developer
    /// documentation.
    @Test
    func patternBTwoKIDsRoundTripsSemantically() throws {
        var bytes: [UInt8] = [0x01, 0x00, 0x00, 0x00, 0x02]
        bytes.append(contentsOf: Array(repeating: UInt8(0xAA), count: 16))
        bytes.append(contentsOf: Array(repeating: UInt8(0xBB), count: 16))
        let parsed = try FairPlayInitData.parse(Data(bytes))
        #expect(parsed.keyIDs.count == 2)

        let reencoded = try FairPlayInitData.encode(parsed)
        let reparsed = try FairPlayInitData.parse(reencoded)
        #expect(reparsed == parsed)
    }
}

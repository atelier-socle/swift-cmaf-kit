// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("ChinaDRMInitData — parse + encode")
struct ChinaDRMInitDataParsingTests {

    private static func kid(_ marker: UInt8) -> Data {
        Data(repeating: marker, count: 16)
    }

    @Test
    func zeroKIDsRoundTrip() throws {
        let original = ChinaDRMInitData(kids: [])
        let encoded = try ChinaDRMInitData.encode(original)
        let parsed = try ChinaDRMInitData.parse(encoded)
        #expect(parsed.kids.isEmpty)
        #expect(parsed.innerPayload.isEmpty)
    }

    @Test
    func singleKIDRoundTrip() throws {
        let original = ChinaDRMInitData(kids: [Self.kid(0xAB)])
        let encoded = try ChinaDRMInitData.encode(original)
        let parsed = try ChinaDRMInitData.parse(encoded)
        #expect(parsed.kids == [Self.kid(0xAB)])
    }

    @Test
    func multipleKIDsRoundTrip() throws {
        let kids = (0..<4).map { Self.kid(UInt8(0x10 + $0)) }
        let original = ChinaDRMInitData(kids: kids)
        let encoded = try ChinaDRMInitData.encode(original)
        let parsed = try ChinaDRMInitData.parse(encoded)
        #expect(parsed.kids == kids)
    }

    @Test
    func kidsWithInnerPayloadRoundTrip() throws {
        let original = ChinaDRMInitData(
            kids: [Self.kid(0x42)],
            innerPayload: Data([0xCA, 0xFE, 0xBA, 0xBE])
        )
        let encoded = try ChinaDRMInitData.encode(original)
        let parsed = try ChinaDRMInitData.parse(encoded)
        #expect(parsed.kids == [Self.kid(0x42)])
        #expect(parsed.innerPayload == Data([0xCA, 0xFE, 0xBA, 0xBE]))
    }

    @Test
    func encodedBytesStartWithBigEndianCount() throws {
        let original = ChinaDRMInitData(
            kids: [Self.kid(0x01), Self.kid(0x02), Self.kid(0x03)]
        )
        let encoded = try ChinaDRMInitData.encode(original)
        #expect(encoded[0] == 0x00)
        #expect(encoded[1] == 0x00)
        #expect(encoded[2] == 0x00)
        #expect(encoded[3] == 0x03)
    }

    @Test
    func tooShortPayloadThrows() {
        #expect(throws: DRMSystemError.self) {
            _ = try ChinaDRMInitData.parse(Data([0x00, 0x00, 0x00]))
        }
    }

    @Test
    func declaredCountExceedsBufferThrows() {
        // Count = 2 but only 16 bytes of payload (32 needed).
        var bytes: [UInt8] = [0x00, 0x00, 0x00, 0x02]
        bytes.append(contentsOf: Array(repeating: UInt8(0xAA), count: 16))
        #expect(throws: DRMSystemError.self) {
            _ = try ChinaDRMInitData.parse(Data(bytes))
        }
    }

    @Test
    func innerPayloadPreservedBetweenKIDs() throws {
        var bytes: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        bytes.append(contentsOf: Array(repeating: UInt8(0xBB), count: 16))
        bytes.append(contentsOf: [0xDE, 0xAD, 0xBE, 0xEF])  // inner
        let parsed = try ChinaDRMInitData.parse(Data(bytes))
        #expect(parsed.kids.count == 1)
        #expect(parsed.innerPayload == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }

    @Test
    func emptyInnerPayloadOnRoundTrip() throws {
        let original = ChinaDRMInitData(kids: [Self.kid(0x11)])
        let encoded = try ChinaDRMInitData.encode(original)
        let parsed = try ChinaDRMInitData.parse(encoded)
        #expect(parsed.innerPayload.isEmpty)
    }

    @Test
    func systemIDPropagates() {
        #expect(ChinaDRMInitData.systemID == .chinaDRM)
    }

    @Test
    func roundTripIsByteForByte() throws {
        let original = ChinaDRMInitData(
            kids: [Self.kid(0x01), Self.kid(0x02)],
            innerPayload: Data([0xFF])
        )
        let encoded1 = try ChinaDRMInitData.encode(original)
        let parsed = try ChinaDRMInitData.parse(encoded1)
        let encoded2 = try ChinaDRMInitData.encode(parsed)
        #expect(encoded1 == encoded2)
    }
}

@Suite("ChinaDRMInitData — fixtures")
struct ChinaDRMInitDataFixturesTests {

    /// Pattern A — hand-built two-KID fixture per GY/T 277.2.
    @Test
    func patternATwoKIDsRoundTrip() throws {
        let kid1 = Data(repeating: 0x11, count: 16)
        let kid2 = Data(repeating: 0x22, count: 16)
        var bytes: [UInt8] = [0x00, 0x00, 0x00, 0x02]
        bytes.append(contentsOf: kid1)
        bytes.append(contentsOf: kid2)
        let parsed = try ChinaDRMInitData.parse(Data(bytes))
        #expect(parsed.kids == [kid1, kid2])
        #expect(try ChinaDRMInitData.encode(parsed) == Data(bytes))
    }

    @Test
    func patternAWithOperatorExtension() throws {
        let kid = Data(repeating: 0x33, count: 16)
        var bytes: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        bytes.append(contentsOf: kid)
        bytes.append(contentsOf: [0x12, 0x34, 0x56])
        let parsed = try ChinaDRMInitData.parse(Data(bytes))
        #expect(parsed.innerPayload == Data([0x12, 0x34, 0x56]))
        #expect(try ChinaDRMInitData.encode(parsed) == Data(bytes))
    }
}

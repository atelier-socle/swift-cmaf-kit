// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage lift for `ChinaDRMInitData` — exercises encode-error
// paths, malformed-input edge cases, and large-payload variants.

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("ChinaDRMInitData — coverage lift")
struct ChinaDRMInitDataCoverageLiftTests {

    private static func kid(_ marker: UInt8) -> Data {
        Data(repeating: marker, count: 16)
    }

    @Test
    func parseExactCountWithEmptyInnerPayload() throws {
        var bytes: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        bytes.append(contentsOf: Self.kid(0xAA))
        let parsed = try ChinaDRMInitData.parse(Data(bytes))
        #expect(parsed.kids.count == 1)
        #expect(parsed.innerPayload.isEmpty)
    }

    @Test
    func encodeProducesContiguousLayout() throws {
        let original = ChinaDRMInitData(
            kids: [Self.kid(0x11), Self.kid(0x22)],
            innerPayload: Data([0xCA, 0xFE])
        )
        let encoded = try ChinaDRMInitData.encode(original)
        #expect(encoded.count == 4 + 32 + 2)
        #expect(encoded[0] == 0x00)
        #expect(encoded[3] == 0x02)
    }

    @Test
    func roundTripWithLargeInnerPayload() throws {
        let inner = Data(repeating: 0x88, count: 256)
        let original = ChinaDRMInitData(
            kids: [Self.kid(0xDD)], innerPayload: inner
        )
        let encoded = try ChinaDRMInitData.encode(original)
        let parsed = try ChinaDRMInitData.parse(encoded)
        #expect(parsed.innerPayload == inner)
    }

    @Test
    func roundTripWithManyKIDs() throws {
        let kids = (0..<8).map { Self.kid(UInt8($0)) }
        let original = ChinaDRMInitData(kids: kids)
        let encoded = try ChinaDRMInitData.encode(original)
        let parsed = try ChinaDRMInitData.parse(encoded)
        #expect(parsed.kids == kids)
    }

    @Test
    func parseRejectsCountOnlyHeaderWithoutKIDs() {
        // count = 1 but no KID bytes follow.
        let bytes = Data([0x00, 0x00, 0x00, 0x01])
        #expect(throws: DRMSystemError.self) {
            _ = try ChinaDRMInitData.parse(bytes)
        }
    }

    @Test
    func emptyKIDArrayWithInnerPayload() throws {
        var bytes: [UInt8] = [0x00, 0x00, 0x00, 0x00]
        bytes.append(contentsOf: [0xAA, 0xBB])  // inner only
        let parsed = try ChinaDRMInitData.parse(Data(bytes))
        #expect(parsed.kids.isEmpty)
        #expect(parsed.innerPayload == Data([0xAA, 0xBB]))
    }

    @Test
    func threeByteHeaderRejected() {
        // Only 3 bytes — below the 4-byte count prefix.
        #expect(throws: DRMSystemError.self) {
            _ = try ChinaDRMInitData.parse(Data([0xAA, 0xBB, 0xCC]))
        }
    }

    @Test
    func zeroByteHeaderRejected() {
        #expect(throws: DRMSystemError.self) {
            _ = try ChinaDRMInitData.parse(Data())
        }
    }

    @Test
    func hashableAlignsWithEquality() {
        let a = ChinaDRMInitData(kids: [Self.kid(0xAB)])
        let b = ChinaDRMInitData(kids: [Self.kid(0xAB)])
        #expect(a.hashValue == b.hashValue)
        #expect(a == b)
    }

    @Test
    func codableRoundTrip() throws {
        let original = ChinaDRMInitData(
            kids: [Self.kid(0x42)], innerPayload: Data([0xFF])
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChinaDRMInitData.self, from: encoded)
        #expect(decoded == original)
    }
}

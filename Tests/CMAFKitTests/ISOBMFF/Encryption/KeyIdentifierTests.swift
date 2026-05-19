// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("KeyIdentifier")
struct KeyIdentifierTests {

    @Test
    func rawBytesAreStoredVerbatim() {
        let bytes = Data((0..<16).map { UInt8($0) })
        let kid = KeyIdentifier(rawBytes: bytes)
        #expect(kid.rawBytes == bytes)
    }

    @Test
    func uuidInitMapsBytesInNetworkOrder() throws {
        let uuid = try #require(UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF"))
        let kid = KeyIdentifier(uuid: uuid)
        let expected = Data([
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF
        ])
        #expect(kid.rawBytes == expected)
    }

    @Test
    func uuidStringRoundTripsCanonicalForm() throws {
        let uuid = try #require(UUID(uuidString: "F8C80E32-2A07-4C9D-B5C9-9D2A2F90B1A4"))
        let kid = KeyIdentifier(uuid: uuid)
        #expect(kid.uuidString == "F8C80E32-2A07-4C9D-B5C9-9D2A2F90B1A4")
    }

    @Test
    func uuidStringFromRawBytes() {
        let bytes = Data([
            0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF
        ])
        let kid = KeyIdentifier(rawBytes: bytes)
        #expect(kid.uuidString == "DEADBEEF-CAFE-BABE-0123-456789ABCDEF")
    }

    @Test
    func equalityComparesByRawBytes() {
        let a = KeyIdentifier(rawBytes: Data(repeating: 0x42, count: 16))
        let b = KeyIdentifier(rawBytes: Data(repeating: 0x42, count: 16))
        let c = KeyIdentifier(rawBytes: Data(repeating: 0x43, count: 16))
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func hashingIsConsistentWithEquality() {
        let a = KeyIdentifier(rawBytes: Data(repeating: 0x77, count: 16))
        let b = KeyIdentifier(rawBytes: Data(repeating: 0x77, count: 16))
        var setA: Set<KeyIdentifier> = [a]
        setA.insert(b)
        #expect(setA.count == 1)
    }

    @Test
    func codableRoundTrip() throws {
        let kid = KeyIdentifier(rawBytes: Data((0..<16).map { _ in UInt8.random(in: 0...255) }))
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let encoded = try encoder.encode(kid)
        let decoded = try decoder.decode(KeyIdentifier.self, from: encoded)
        #expect(decoded == kid)
    }

    @Test
    func zeroKID() {
        let kid = KeyIdentifier(rawBytes: Data(repeating: 0x00, count: 16))
        #expect(kid.uuidString == "00000000-0000-0000-0000-000000000000")
    }
}

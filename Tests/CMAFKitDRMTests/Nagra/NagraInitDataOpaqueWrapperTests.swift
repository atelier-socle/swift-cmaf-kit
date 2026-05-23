// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Nagra is a closed-spec provider per the file-header doc in
// ``NagraInitData``. These tests verify the opaque wrapper
// preserves bytes byte-perfect through parse + encode.

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("NagraInitData — opaque wrapper")
struct NagraInitDataOpaqueWrapperTests {

    @Test
    func emptyBytesRoundTrip() throws {
        let parsed = try NagraInitData.parse(Data())
        #expect(parsed.rawBytes.isEmpty)
        #expect(try NagraInitData.encode(parsed) == Data())
    }

    @Test
    func singleByteRoundTrip() throws {
        let original = Data([0xAA])
        let parsed = try NagraInitData.parse(original)
        #expect(parsed.rawBytes == original)
        #expect(try NagraInitData.encode(parsed) == original)
    }

    @Test
    func largeBytesRoundTrip() throws {
        let original = Data(repeating: 0x42, count: 1024)
        let parsed = try NagraInitData.parse(original)
        #expect(parsed.rawBytes == original)
        #expect(try NagraInitData.encode(parsed) == original)
    }

    @Test
    func arbitraryBytesRoundTrip() throws {
        let original = Data([0x00, 0xFF, 0x7F, 0x80, 0x12, 0x34, 0x56, 0x78])
        let parsed = try NagraInitData.parse(original)
        #expect(try NagraInitData.encode(parsed) == original)
    }

    @Test
    func equatableWorksAcrossInstances() {
        let a = NagraInitData(rawBytes: Data([0x01]))
        let b = NagraInitData(rawBytes: Data([0x01]))
        let c = NagraInitData(rawBytes: Data([0x02]))
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func systemIDPropagates() {
        #expect(NagraInitData.systemID == .nagra)
    }

    @Test
    func codableRoundTrip() throws {
        let original = NagraInitData(rawBytes: Data([0x99, 0x88, 0x77]))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NagraInitData.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func hashableAlignsWithEquality() {
        let a = NagraInitData(rawBytes: Data([0x01, 0x02]))
        let b = NagraInitData(rawBytes: Data([0x01, 0x02]))
        #expect(a.hashValue == b.hashValue)
    }
}

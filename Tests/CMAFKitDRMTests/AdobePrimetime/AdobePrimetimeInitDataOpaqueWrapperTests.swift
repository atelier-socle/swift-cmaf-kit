// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Adobe Primetime was deprecated in 2020 per the file-header doc
// in ``AdobePrimetimeInitData``. These tests verify the opaque
// wrapper preserves bytes byte-perfect for archived content.

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("AdobePrimetimeInitData — opaque wrapper")
struct AdobePrimetimeInitDataOpaqueWrapperTests {

    @Test
    func emptyBytesRoundTrip() throws {
        let parsed = try AdobePrimetimeInitData.parse(Data())
        #expect(try AdobePrimetimeInitData.encode(parsed) == Data())
    }

    @Test
    func singleByteRoundTrip() throws {
        let original = Data([0x77])
        let parsed = try AdobePrimetimeInitData.parse(original)
        #expect(try AdobePrimetimeInitData.encode(parsed) == original)
    }

    @Test
    func largeBytesRoundTrip() throws {
        let original = Data(repeating: 0xDD, count: 512)
        let parsed = try AdobePrimetimeInitData.parse(original)
        #expect(try AdobePrimetimeInitData.encode(parsed) == original)
    }

    @Test
    func arbitraryBytesRoundTrip() throws {
        let original = Data([0xAB, 0xCD, 0xEF, 0x12, 0x34])
        let parsed = try AdobePrimetimeInitData.parse(original)
        #expect(try AdobePrimetimeInitData.encode(parsed) == original)
    }

    @Test
    func equatableWorksAcrossInstances() {
        let a = AdobePrimetimeInitData(rawBytes: Data([0x01]))
        let b = AdobePrimetimeInitData(rawBytes: Data([0x01]))
        #expect(a == b)
    }

    @Test
    func systemIDPropagates() {
        #expect(AdobePrimetimeInitData.systemID == .adobePrimetime)
    }

    @Test
    func codableRoundTrip() throws {
        let original = AdobePrimetimeInitData(rawBytes: Data([0x55]))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            AdobePrimetimeInitData.self, from: encoded
        )
        #expect(decoded == original)
    }

    @Test
    func hashableConsistency() {
        let a = AdobePrimetimeInitData(rawBytes: Data([0x99]))
        let b = AdobePrimetimeInitData(rawBytes: Data([0x99]))
        #expect(a.hashValue == b.hashValue)
    }
}

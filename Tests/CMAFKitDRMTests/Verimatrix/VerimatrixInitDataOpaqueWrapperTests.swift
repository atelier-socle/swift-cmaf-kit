// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Verimatrix is a closed-spec provider per the file-header doc
// in ``VerimatrixInitData``. These tests verify the opaque
// wrapper preserves bytes byte-perfect.

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("VerimatrixInitData — opaque wrapper")
struct VerimatrixInitDataOpaqueWrapperTests {

    @Test
    func emptyBytesRoundTrip() throws {
        let parsed = try VerimatrixInitData.parse(Data())
        #expect(try VerimatrixInitData.encode(parsed) == Data())
    }

    @Test
    func singleByteRoundTrip() throws {
        let original = Data([0x11])
        let parsed = try VerimatrixInitData.parse(original)
        #expect(try VerimatrixInitData.encode(parsed) == original)
    }

    @Test
    func largeBytesRoundTrip() throws {
        let original = Data(repeating: 0xCC, count: 2048)
        let parsed = try VerimatrixInitData.parse(original)
        #expect(try VerimatrixInitData.encode(parsed) == original)
    }

    @Test
    func arbitraryBytesRoundTrip() throws {
        let original = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE])
        let parsed = try VerimatrixInitData.parse(original)
        #expect(try VerimatrixInitData.encode(parsed) == original)
    }

    @Test
    func equatableWorksAcrossInstances() {
        let a = VerimatrixInitData(rawBytes: Data([0x01]))
        let b = VerimatrixInitData(rawBytes: Data([0x01]))
        #expect(a == b)
    }

    @Test
    func systemIDPropagates() {
        #expect(VerimatrixInitData.systemID == .verimatrix)
    }

    @Test
    func codableRoundTrip() throws {
        let original = VerimatrixInitData(rawBytes: Data([0xAA]))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            VerimatrixInitData.self, from: encoded
        )
        #expect(decoded == original)
    }

    @Test
    func hashableConsistency() {
        let a = VerimatrixInitData(rawBytes: Data([0xFF, 0xEE]))
        let b = VerimatrixInitData(rawBytes: Data([0xFF, 0xEE]))
        #expect(a.hashValue == b.hashValue)
    }
}

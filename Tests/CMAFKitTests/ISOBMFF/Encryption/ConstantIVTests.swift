// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ConstantIV")
struct ConstantIVTests {

    @Test
    func eightByteIVAccepted() throws {
        let iv = try ConstantIV(rawBytes: Data(repeating: 0xAA, count: 8))
        #expect(iv.rawBytes.count == 8)
    }

    @Test
    func sixteenByteIVAccepted() throws {
        let iv = try ConstantIV(rawBytes: Data(repeating: 0xBB, count: 16))
        #expect(iv.rawBytes.count == 16)
    }

    @Test
    func zeroByteIVRejected() {
        #expect(throws: ISOBoxError.self) {
            _ = try ConstantIV(rawBytes: Data())
        }
    }

    @Test
    func twelveByteIVRejected() {
        #expect(throws: ISOBoxError.self) {
            _ = try ConstantIV(rawBytes: Data(repeating: 0xCC, count: 12))
        }
    }

    @Test
    func twentyByteIVRejected() {
        #expect(throws: ISOBoxError.self) {
            _ = try ConstantIV(rawBytes: Data(repeating: 0xCC, count: 20))
        }
    }

    @Test
    func equalityComparesByRawBytes() throws {
        let a = try ConstantIV(rawBytes: Data(repeating: 0x42, count: 16))
        let b = try ConstantIV(rawBytes: Data(repeating: 0x42, count: 16))
        let c = try ConstantIV(rawBytes: Data(repeating: 0x43, count: 16))
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func codableRoundTrip() throws {
        let iv = try ConstantIV(rawBytes: Data((0..<16).map { UInt8($0) }))
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let encoded = try encoder.encode(iv)
        let decoded = try decoder.decode(ConstantIV.self, from: encoded)
        #expect(decoded == iv)
    }
}

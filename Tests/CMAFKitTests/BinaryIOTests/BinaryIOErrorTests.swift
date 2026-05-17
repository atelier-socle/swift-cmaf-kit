// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for BinaryIOError — Equatable + Sendable surface for BinaryReader/Writer.

import Foundation
import Testing

@testable import CMAFKit

@Suite("BinaryIOError")
struct BinaryIOErrorTests {

    @Test
    func equatableAcrossCases() {
        let a = BinaryIOError.insufficientData(expected: 10, available: 4)
        let b = BinaryIOError.insufficientData(expected: 10, available: 4)
        let c = BinaryIOError.insufficientData(expected: 8, available: 4)
        let d = BinaryIOError.invalidFourCC(bytes: [0xFF, 0x66, 0x74, 0x70])
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    @Test
    func insufficientDataCarriesPair() {
        let err = BinaryIOError.insufficientData(expected: 16, available: 3)
        if case let .insufficientData(expected, available) = err {
            #expect(expected == 16)
            #expect(available == 3)
        } else {
            Issue.record("expected .insufficientData")
        }
    }

    @Test
    func invalidFourCCCarriesBytes() {
        let bytes: [UInt8] = [0xFE, 0xFD, 0xFC, 0xFB]
        let err = BinaryIOError.invalidFourCC(bytes: bytes)
        if case let .invalidFourCC(received) = err {
            #expect(received == bytes)
        } else {
            Issue.record("expected .invalidFourCC")
        }
    }

    @Test
    func invalidStringCarriesEncodingRawValue() {
        let err = BinaryIOError.invalidString(encodingRawValue: String.Encoding.utf8.rawValue)
        if case let .invalidString(encodingRawValue) = err {
            #expect(encodingRawValue == String.Encoding.utf8.rawValue)
        } else {
            Issue.record("expected .invalidString")
        }
    }

    @Test
    func sendableAcrossActorHop() async {
        actor Holder {
            var captured: BinaryIOError?
            func store(_ err: BinaryIOError) { captured = err }
        }
        let holder = Holder()
        let err = BinaryIOError.invalidFixedPoint
        await holder.store(err)
        let stored = await holder.captured
        #expect(stored == err)
    }
}

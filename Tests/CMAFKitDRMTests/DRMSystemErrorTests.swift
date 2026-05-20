// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("DRMSystemError")
struct DRMSystemErrorTests {

    @Test
    func equalityAcrossAllCases() throws {
        let uuid = try #require(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        )
        let a = DRMSystemError.unsupportedSystem(systemID: uuid)
        let b = DRMSystemError.unsupportedSystem(systemID: uuid)
        #expect(a == b)
    }

    @Test
    func malformedInitDataIsConstructible() {
        let error = DRMSystemError.malformedInitData(
            systemID: .widevine,
            reason: "protobuf schema mismatch"
        )
        if case let .malformedInitData(id, reason) = error {
            #expect(id == .widevine)
            #expect(reason == "protobuf schema mismatch")
        } else {
            Issue.record("expected .malformedInitData")
        }
    }

    @Test
    func roundTripFailureIsConstructible() {
        let error = DRMSystemError.roundTripFailure(
            systemID: .playReady,
            reason: "XML serialisation differed"
        )
        if case let .roundTripFailure(id, _) = error {
            #expect(id == .playReady)
        } else {
            Issue.record("expected .roundTripFailure")
        }
    }

    @Test
    func unexpectedTrailingBytesIsConstructible() {
        let error = DRMSystemError.unexpectedTrailingBytes(
            systemID: .fairPlay,
            byteCount: 17
        )
        if case let .unexpectedTrailingBytes(id, count) = error {
            #expect(id == .fairPlay)
            #expect(count == 17)
        } else {
            Issue.record("expected .unexpectedTrailingBytes")
        }
    }

    @Test
    func wireFormatVersionUnsupportedIsConstructible() {
        let error = DRMSystemError.wireFormatVersionUnsupported(
            systemID: .clearKey,
            version: 99
        )
        if case let .wireFormatVersionUnsupported(id, version) = error {
            #expect(id == .clearKey)
            #expect(version == 99)
        } else {
            Issue.record("expected .wireFormatVersionUnsupported")
        }
    }

    @Test
    func inequalityAcrossSystems() {
        let a = DRMSystemError.malformedInitData(
            systemID: .widevine, reason: "x"
        )
        let b = DRMSystemError.malformedInitData(
            systemID: .playReady, reason: "x"
        )
        #expect(a != b)
    }
}

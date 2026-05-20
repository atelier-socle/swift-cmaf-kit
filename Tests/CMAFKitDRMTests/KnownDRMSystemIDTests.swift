// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("KnownDRMSystemID")
struct KnownDRMSystemIDTests {

    @Test
    func widevineUUIDMatchesPublicRegistry() {
        let expected = UUID(uuidString: "EDEF8BA9-79D6-4ACE-A3C8-27DCD51D21ED")
        #expect(KnownDRMSystemID.widevine.uuid == expected)
    }

    @Test
    func playReadyUUIDMatchesPublicRegistry() {
        let expected = UUID(uuidString: "9A04F079-9840-4286-AB92-E65BE0885F95")
        #expect(KnownDRMSystemID.playReady.uuid == expected)
    }

    @Test
    func fairPlayUUIDMatchesPublicRegistry() {
        let expected = UUID(uuidString: "94CE86FB-07FF-4F43-ADB8-93D2FA968CA2")
        #expect(KnownDRMSystemID.fairPlay.uuid == expected)
    }

    @Test
    func clearKeyUUIDMatchesPublicRegistry() {
        let expected = UUID(uuidString: "1077EFEC-C0B2-4D02-ACE3-3C1E52E2FB4B")
        #expect(KnownDRMSystemID.clearKey.uuid == expected)
    }

    @Test
    func marlinUUIDMatchesPublicRegistry() {
        let expected = UUID(uuidString: "5E629AF5-38DA-4063-8977-97FFBD9902D4")
        #expect(KnownDRMSystemID.marlin.uuid == expected)
    }

    @Test
    func nagraUUIDMatchesPublicRegistry() {
        let expected = UUID(uuidString: "ADB41C24-2DBF-4A6D-958B-4457C0D27B95")
        #expect(KnownDRMSystemID.nagra.uuid == expected)
    }

    @Test
    func verimatrixUUIDMatchesPublicRegistry() {
        let expected = UUID(uuidString: "9A27DD82-FDE2-4725-8CBC-4234AA06EC09")
        #expect(KnownDRMSystemID.verimatrix.uuid == expected)
    }

    @Test
    func adobePrimetimeUUIDMatchesPublicRegistry() {
        let expected = UUID(uuidString: "F239E769-EFA3-4850-9C16-A903C6932EFB")
        #expect(KnownDRMSystemID.adobePrimetime.uuid == expected)
    }

    @Test
    func chinaDRMUUIDMatchesPublicRegistry() {
        let expected = UUID(uuidString: "3D5E6D35-9B9A-41E8-B843-DD3C6E72C42C")
        #expect(KnownDRMSystemID.chinaDRM.uuid == expected)
    }

    // MARK: - Reverse lookup

    @Test
    func allNineNamedCasesRoundTripThroughInitUUID() {
        for known in KnownDRMSystemID.allKnownCases {
            let recovered = KnownDRMSystemID(uuid: known.uuid)
            #expect(recovered == known, "round-trip failed for \(known)")
        }
    }

    @Test
    func unknownUUIDFallsBackToOther() throws {
        let novel = try #require(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        )
        let lifted = KnownDRMSystemID(uuid: novel)
        if case let .other(uuid) = lifted {
            #expect(uuid == novel)
        } else {
            Issue.record("expected .other(UUID), got \(lifted)")
        }
    }

    @Test
    func otherCaseUUIDAccessor() throws {
        let novel = try #require(
            UUID(uuidString: "11111111-2222-3333-4444-555555555555")
        )
        let id = KnownDRMSystemID.other(novel)
        #expect(id.uuid == novel)
    }

    // MARK: - allKnownCases shape

    @Test
    func allKnownCasesContainsExactlyNine() {
        #expect(KnownDRMSystemID.allKnownCases.count == 9)
    }

    @Test
    func allKnownCasesAreUniqueByUUID() {
        let uuids = Set(KnownDRMSystemID.allKnownCases.map { $0.uuid })
        #expect(uuids.count == KnownDRMSystemID.allKnownCases.count)
    }

    @Test
    func codableRoundTripNamedCase() throws {
        let original = KnownDRMSystemID.widevine
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KnownDRMSystemID.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func codableRoundTripOtherCase() throws {
        let novel = try #require(
            UUID(uuidString: "12345678-9ABC-DEF0-1234-567890ABCDEF")
        )
        let original = KnownDRMSystemID.other(novel)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KnownDRMSystemID.self, from: encoded)
        #expect(decoded == original)
    }
}

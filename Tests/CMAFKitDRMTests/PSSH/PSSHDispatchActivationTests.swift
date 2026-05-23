// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Activation tests for the PSSH → TypedDRMInitData dispatch path
// updated in S12b. Each known UUID dispatches to its provider's
// typed parser; unknown UUIDs fall through to
// `.unknown(systemID:rawBytes:)`. Round-trip uses
// `TypedDRMInitData.encoded()` so the 4 fully-typed providers
// emit canonical bytes and the 5 secondary providers preserve
// inputs verbatim.

import CMAFKit
import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("PSSH → TypedDRMInitData dispatch activation")
struct PSSHDispatchActivationTests {

    private static func kid(_ marker: UInt8) -> Data {
        Data(repeating: marker, count: 16)
    }

    private func makePSSH(
        systemID: UUID, data: Data
    ) -> ProtectionSystemSpecificHeaderBox {
        ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: systemID,
            keyIdentifiers: [],
            data: data
        )
    }

    // MARK: - Widevine

    @Test
    func widevineDispatchesAndRoundTrips() throws {
        let bytes: Data = {
            var writer = ProtocolBufferWriter()
            writer.writeVarintField(fieldNumber: 1, value: 1)  // AESCTR
            writer.writeBytesField(fieldNumber: 2, value: Self.kid(0xAA))
            return writer.data
        }()
        let pssh = makePSSH(systemID: KnownDRMSystemID.widevine.uuid, data: bytes)
        let typed = try pssh.typedInitData()
        if case let .widevine(value) = typed {
            #expect(value.keyIDs == [Self.kid(0xAA)])
        } else {
            Issue.record("expected .widevine")
        }
        #expect(try typed.encoded() == bytes)
    }

    // MARK: - PlayReady

    @Test
    func playReadyDispatchesAndRoundTrips() throws {
        let header = PlayReadyInitData.WRMHeader(
            version: .v4_1,
            kids: [PlayReadyInitData.WRMHeader.KID(value: Self.kid(0x42))]
        )
        let original = PlayReadyInitData(records: [.wrmHeader(header)])
        let bytes = try PlayReadyInitData.encode(original)
        let pssh = makePSSH(systemID: KnownDRMSystemID.playReady.uuid, data: bytes)
        let typed = try pssh.typedInitData()
        if case let .playReady(value) = typed {
            #expect(value.records.count == 1)
        } else {
            Issue.record("expected .playReady")
        }
        // Re-encode and re-parse for semantic equivalence (XML
        // serializer is canonical-deterministic).
        let reencoded = try typed.encoded()
        let reparsed = try PlayReadyInitData.parse(reencoded)
        #expect(reparsed == original)
    }

    // MARK: - FairPlay

    @Test
    func fairPlayDispatchesAndRoundTrips() throws {
        let value = FairPlayInitData(keyIDs: [Self.kid(0x55)])
        let bytes = try FairPlayInitData.encode(value)
        let pssh = makePSSH(systemID: KnownDRMSystemID.fairPlay.uuid, data: bytes)
        let typed = try pssh.typedInitData()
        if case let .fairPlay(parsed) = typed {
            #expect(parsed == value)
        } else {
            Issue.record("expected .fairPlay")
        }
        #expect(try typed.encoded() == bytes)
    }

    // MARK: - ClearKey

    @Test
    func clearKeyDispatchesAndRoundTrips() throws {
        let value = ClearKeyInitData(kids: [Self.kid(0x99)], type: .temporary)
        let bytes = try ClearKeyInitData.encode(value)
        let pssh = makePSSH(systemID: KnownDRMSystemID.clearKey.uuid, data: bytes)
        let typed = try pssh.typedInitData()
        if case let .clearKey(parsed) = typed {
            #expect(parsed == value)
        } else {
            Issue.record("expected .clearKey")
        }
        #expect(try typed.encoded() == bytes)
    }

    // MARK: - Marlin

    @Test
    func marlinDispatchesAndRoundTrips() throws {
        let urn = "urn:marlin:kid:0123456789abcdef0123456789abcdef"
        let bytes = Data(urn.utf8)
        let pssh = makePSSH(systemID: KnownDRMSystemID.marlin.uuid, data: bytes)
        let typed = try pssh.typedInitData()
        if case let .marlin(value) = typed {
            #expect(value.broadbandAssetIdentifier?.urn == urn)
        } else {
            Issue.record("expected .marlin")
        }
        #expect(try typed.encoded() == bytes)
    }

    // MARK: - Closed-spec / deprecated providers

    @Test
    func nagraDispatchesAndPreservesBytes() throws {
        let bytes = Data([0xAA, 0xBB, 0xCC, 0xDD])
        let pssh = makePSSH(systemID: KnownDRMSystemID.nagra.uuid, data: bytes)
        let typed = try pssh.typedInitData()
        if case let .nagra(value) = typed {
            #expect(value.rawBytes == bytes)
        } else {
            Issue.record("expected .nagra")
        }
        #expect(try typed.encoded() == bytes)
    }

    @Test
    func verimatrixDispatchesAndPreservesBytes() throws {
        let bytes = Data([0xCA, 0xFE, 0xBA, 0xBE])
        let pssh = makePSSH(systemID: KnownDRMSystemID.verimatrix.uuid, data: bytes)
        let typed = try pssh.typedInitData()
        if case let .verimatrix(value) = typed {
            #expect(value.rawBytes == bytes)
        } else {
            Issue.record("expected .verimatrix")
        }
        #expect(try typed.encoded() == bytes)
    }

    @Test
    func adobePrimetimeDispatchesAndPreservesBytes() throws {
        let bytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let pssh = makePSSH(
            systemID: KnownDRMSystemID.adobePrimetime.uuid, data: bytes
        )
        let typed = try pssh.typedInitData()
        if case let .adobePrimetime(value) = typed {
            #expect(value.rawBytes == bytes)
        } else {
            Issue.record("expected .adobePrimetime")
        }
        #expect(try typed.encoded() == bytes)
    }

    @Test
    func chinaDRMDispatchesAndRoundTrips() throws {
        let value = ChinaDRMInitData(kids: [Self.kid(0x77)])
        let bytes = try ChinaDRMInitData.encode(value)
        let pssh = makePSSH(systemID: KnownDRMSystemID.chinaDRM.uuid, data: bytes)
        let typed = try pssh.typedInitData()
        if case let .chinaDRM(parsed) = typed {
            #expect(parsed == value)
        } else {
            Issue.record("expected .chinaDRM")
        }
        #expect(try typed.encoded() == bytes)
    }

    // MARK: - Unknown system identifier

    @Test
    func unknownSystemIDDispatchesToUnknownArm() throws {
        let novel = try #require(
            UUID(uuidString: "12345678-9ABC-DEF0-1234-567890ABCDEF")
        )
        let bytes = Data([0x01, 0x02, 0x03])
        let pssh = makePSSH(systemID: novel, data: bytes)
        let typed = try pssh.typedInitData()
        if case let .unknown(systemID, raw) = typed {
            #expect(systemID == novel)
            #expect(raw == bytes)
        } else {
            Issue.record("expected .unknown")
        }
        #expect(try typed.encoded() == bytes)
    }

    @Test
    func malformedFairPlayPSSHPropagatesError() {
        let pssh = makePSSH(
            systemID: KnownDRMSystemID.fairPlay.uuid,
            data: Data([0x09])  // wrong version byte
        )
        #expect(throws: DRMSystemError.self) {
            _ = try pssh.typedInitData()
        }
    }

    @Test
    func malformedClearKeyPSSHPropagatesError() {
        let pssh = makePSSH(
            systemID: KnownDRMSystemID.clearKey.uuid,
            data: Data("not json".utf8)
        )
        #expect(throws: DRMSystemError.self) {
            _ = try pssh.typedInitData()
        }
    }

    @Test
    func systemIDAccessorMatchesOriginalUUIDForKnownArms() throws {
        for known in KnownDRMSystemID.allKnownCases {
            let bytes = try makeMinimalFixture(for: known)
            let pssh = makePSSH(systemID: known.uuid, data: bytes)
            let typed = try pssh.typedInitData()
            #expect(typed.systemID == known.uuid)
        }
    }

    @Test
    func everyKnownProviderRoundTripsBytePerfectForCanonicalFixture() throws {
        for known in KnownDRMSystemID.allKnownCases {
            let bytes = try makeMinimalFixture(for: known)
            let pssh = makePSSH(systemID: known.uuid, data: bytes)
            let typed = try pssh.typedInitData()
            let reencoded = try typed.encoded()
            #expect(
                reencoded == bytes,
                "Canonical-fixture round-trip must be byte-perfect for \(known)"
            )
        }
    }

    private func makeMinimalFixture(for system: KnownDRMSystemID) throws -> Data {
        switch system {
        case .widevine:
            var writer = ProtocolBufferWriter()
            writer.writeBytesField(fieldNumber: 2, value: Self.kid(0xAA))
            return writer.data
        case .playReady:
            let header = PlayReadyInitData.WRMHeader(
                version: .v4_1,
                kids: [PlayReadyInitData.WRMHeader.KID(value: Self.kid(0xBB))]
            )
            return try PlayReadyInitData.encode(
                PlayReadyInitData(records: [.wrmHeader(header)])
            )
        case .fairPlay:
            return try FairPlayInitData.encode(
                FairPlayInitData(keyIDs: [Self.kid(0xCC)])
            )
        case .clearKey:
            return try ClearKeyInitData.encode(
                ClearKeyInitData(kids: [Self.kid(0xDD)], type: .temporary)
            )
        case .marlin:
            let urn = "urn:marlin:kid:0123456789abcdef0123456789abcdef"
            return Data(urn.utf8)
        case .nagra, .verimatrix, .adobePrimetime:
            return Data([0x12, 0x34, 0x56])
        case .chinaDRM:
            return try ChinaDRMInitData.encode(
                ChinaDRMInitData(kids: [Self.kid(0xEE)])
            )
        case .other:
            return Data()
        }
    }
}

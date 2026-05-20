// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import CMAFKit
import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("ProtectionSystemSpecificHeaderBox → TypedDRMInitData dispatch")
struct ProtectionSystemSpecificHeaderBoxDispatchTests {

    private static let stubBytes = Data([0xAA, 0xBB, 0xCC, 0xDD])

    private func makePSSH(systemID: UUID) -> ProtectionSystemSpecificHeaderBox {
        ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: systemID,
            keyIdentifiers: [],
            data: Self.stubBytes
        )
    }

    @Test
    func widevineDispatchesToWidevineArm() {
        let pssh = makePSSH(systemID: KnownDRMSystemID.widevine.uuid)
        if case let .widevine(payload) = pssh.typedInitData() {
            #expect(payload.rawBytes == Self.stubBytes)
        } else {
            Issue.record("expected .widevine")
        }
    }

    @Test
    func playReadyDispatchesToPlayReadyArm() {
        let pssh = makePSSH(systemID: KnownDRMSystemID.playReady.uuid)
        if case let .playReady(payload) = pssh.typedInitData() {
            #expect(payload.rawBytes == Self.stubBytes)
        } else {
            Issue.record("expected .playReady")
        }
    }

    @Test
    func fairPlayDispatchesToFairPlayArm() {
        let pssh = makePSSH(systemID: KnownDRMSystemID.fairPlay.uuid)
        if case let .fairPlay(payload) = pssh.typedInitData() {
            #expect(payload.rawBytes == Self.stubBytes)
        } else {
            Issue.record("expected .fairPlay")
        }
    }

    @Test
    func clearKeyDispatchesToClearKeyArm() {
        let pssh = makePSSH(systemID: KnownDRMSystemID.clearKey.uuid)
        if case let .clearKey(payload) = pssh.typedInitData() {
            #expect(payload.rawBytes == Self.stubBytes)
        } else {
            Issue.record("expected .clearKey")
        }
    }

    @Test
    func marlinDispatchesToMarlinArm() {
        let pssh = makePSSH(systemID: KnownDRMSystemID.marlin.uuid)
        if case let .marlin(payload) = pssh.typedInitData() {
            #expect(payload.rawBytes == Self.stubBytes)
        } else {
            Issue.record("expected .marlin")
        }
    }

    @Test
    func nagraDispatchesToNagraArm() {
        let pssh = makePSSH(systemID: KnownDRMSystemID.nagra.uuid)
        if case let .nagra(payload) = pssh.typedInitData() {
            #expect(payload.rawBytes == Self.stubBytes)
        } else {
            Issue.record("expected .nagra")
        }
    }

    @Test
    func verimatrixDispatchesToVerimatrixArm() {
        let pssh = makePSSH(systemID: KnownDRMSystemID.verimatrix.uuid)
        if case let .verimatrix(payload) = pssh.typedInitData() {
            #expect(payload.rawBytes == Self.stubBytes)
        } else {
            Issue.record("expected .verimatrix")
        }
    }

    @Test
    func adobePrimetimeDispatchesToAdobePrimetimeArm() {
        let pssh = makePSSH(systemID: KnownDRMSystemID.adobePrimetime.uuid)
        if case let .adobePrimetime(payload) = pssh.typedInitData() {
            #expect(payload.rawBytes == Self.stubBytes)
        } else {
            Issue.record("expected .adobePrimetime")
        }
    }

    @Test
    func chinaDRMDispatchesToChinaDRMArm() {
        let pssh = makePSSH(systemID: KnownDRMSystemID.chinaDRM.uuid)
        if case let .chinaDRM(payload) = pssh.typedInitData() {
            #expect(payload.rawBytes == Self.stubBytes)
        } else {
            Issue.record("expected .chinaDRM")
        }
    }

    @Test
    func unknownSystemIDDispatchesToUnknownArm() throws {
        let novel = try #require(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        )
        let pssh = makePSSH(systemID: novel)
        if case let .unknown(systemID, bytes) = pssh.typedInitData() {
            #expect(systemID == novel)
            #expect(bytes == Self.stubBytes)
        } else {
            Issue.record("expected .unknown")
        }
    }

    @Test
    func bytesPreservedVerbatimAcrossDispatch() {
        let bytes = Data(repeating: 0x42, count: 256)
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: KnownDRMSystemID.widevine.uuid,
            keyIdentifiers: [],
            data: bytes
        )
        let typed = pssh.typedInitData()
        #expect(typed.rawBytes == bytes)
    }

    @Test
    func systemIDAccessorMatchesOriginal() {
        for known in KnownDRMSystemID.allKnownCases {
            let pssh = makePSSH(systemID: known.uuid)
            #expect(pssh.typedInitData().systemID == known.uuid)
        }
    }
}

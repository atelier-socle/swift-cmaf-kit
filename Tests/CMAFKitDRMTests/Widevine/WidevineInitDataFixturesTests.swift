// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Pattern A (hand-built canonical) + Pattern B (synthesized in-the-
// wild) fixtures for the Widevine `WidevineCencHeader` proto2
// payload. Pattern A asserts byte-perfect round-trip. Pattern B
// asserts semantic equivalence (re-parse of re-encoded bytes
// produces the same typed structure) since the Widevine
// Protocol Buffer wire format does not have a unique
// serialisation and external encoders may emit fields in a
// non-canonical order.

import CMAFKit
import Foundation
import Testing

@testable import CMAFKitDRM

@Suite("WidevineInitData — fixtures")
struct WidevineInitDataFixturesTests {

    // MARK: - Pattern A — hand-built canonical fixtures

    /// One-KID Widevine fixture with algorithm AESCTR and
    /// protection_scheme=cenc. Bytes are emitted by the
    /// CMAFKitDRM canonical encoder; round-trip is byte-perfect.
    @Test
    func patternAOneKIDAlgorithmAESCTRProtectionSchemeCenc() throws {
        let kid = Data(repeating: 0x55, count: 16)
        let bytes: Data = {
            var writer = ProtocolBufferWriter()
            writer.writeVarintField(fieldNumber: 1, value: 1)  // algorithm = AESCTR
            writer.writeBytesField(fieldNumber: 2, value: kid)
            writer.writeVarintField(fieldNumber: 9, value: UInt64(CommonEncryptionScheme.cenc.rawValue))
            return writer.data
        }()
        let parsed = try WidevineInitData.parse(bytes)
        #expect(parsed.algorithm == .aesCTR)
        #expect(parsed.keyIDs == [kid])
        #expect(parsed.protectionScheme == .cenc)

        let reencoded = try WidevineInitData.encode(parsed)
        #expect(reencoded == bytes, "Pattern A round-trip must be byte-perfect")
    }

    /// Three-KID Widevine fixture (DASH-IF multi-key reference).
    @Test
    func patternAThreeKIDsProtectionSchemeCbcs() throws {
        let kids = (0..<3).map { Data(repeating: UInt8(0x10 + $0), count: 16) }
        let bytes: Data = {
            var writer = ProtocolBufferWriter()
            for kid in kids {
                writer.writeBytesField(fieldNumber: 2, value: kid)
            }
            writer.writeVarintField(fieldNumber: 9, value: UInt64(CommonEncryptionScheme.cbcs.rawValue))
            return writer.data
        }()
        let parsed = try WidevineInitData.parse(bytes)
        #expect(parsed.keyIDs == kids)
        #expect(parsed.protectionScheme == .cbcs)

        let reencoded = try WidevineInitData.encode(parsed)
        #expect(reencoded == bytes)
    }

    /// Widevine fixture with provider + content ID strings.
    @Test
    func patternAWithProviderAndContentID() throws {
        let kid = Data(repeating: 0x42, count: 16)
        let bytes: Data = {
            var writer = ProtocolBufferWriter()
            writer.writeBytesField(fieldNumber: 2, value: kid)
            writer.writeStringField(fieldNumber: 3, value: "atelier-socle")
            writer.writeBytesField(fieldNumber: 4, value: Data([0xFE, 0xED, 0xFA, 0xCE]))
            return writer.data
        }()
        let parsed = try WidevineInitData.parse(bytes)
        #expect(parsed.provider == "atelier-socle")
        #expect(parsed.contentID == Data([0xFE, 0xED, 0xFA, 0xCE]))

        let reencoded = try WidevineInitData.encode(parsed)
        #expect(reencoded == bytes)
    }

    // MARK: - Pattern B — synthesised in-the-wild fixture

    /// Synthesised in-the-wild fixture modelled on DASH-IF
    /// reference content. Emits fields in a non-canonical order
    /// (key_id first, then algorithm) — the parser must still
    /// recover the structure correctly, but the re-encoded bytes
    /// equal the canonical-order encoding rather than the
    /// original; semantic equivalence is verified by re-parsing
    /// the re-encoded bytes.
    @Test
    func patternBNonCanonicalFieldOrderRoundTripsSemantically() throws {
        let kid = Data(repeating: 0x66, count: 16)
        let inTheWildBytes: Data = {
            var writer = ProtocolBufferWriter()
            writer.writeBytesField(fieldNumber: 2, value: kid)  // key_id first
            writer.writeVarintField(fieldNumber: 1, value: 1)  // algorithm second
            return writer.data
        }()
        let parsed = try WidevineInitData.parse(inTheWildBytes)
        #expect(parsed.algorithm == .aesCTR)
        #expect(parsed.keyIDs == [kid])

        let reencoded = try WidevineInitData.encode(parsed)
        // Re-encoded bytes are canonical-order; not equal to the
        // non-canonical input but semantically equivalent.
        let reparsed = try WidevineInitData.parse(reencoded)
        #expect(reparsed == parsed, "Semantic equivalence holds across non-canonical sources")
    }
}

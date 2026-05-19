// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

/// Comprehensive exercise of ISO/IEC 23001-7 §8.2 / §10.x cross-field
/// rules between `SchemeTypeBox` and `TrackEncryptionBox`.
@Suite("CENC scheme cross-field validation")
struct CENCSchemeValidationTests {

    private static func kid() -> KeyIdentifier {
        KeyIdentifier(rawBytes: Data(repeating: 0xEE, count: 16))
    }

    private static func tencV0() -> TrackEncryptionBox {
        TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: kid()
        )
    }

    private static func tencV1(
        crypt: UInt8 = 1,
        skip: UInt8 = 9,
        ivSize: TrackEncryptionBox.PerSampleIVSize = .eight,
        constantIV: ConstantIV? = nil
    ) -> TrackEncryptionBox {
        TrackEncryptionBox(
            version: 1,
            defaultCryptByteBlock: crypt,
            defaultSkipByteBlock: skip,
            defaultIsProtected: true,
            defaultPerSampleIVSize: ivSize,
            defaultKID: kid(),
            defaultConstantIV: constantIV
        )
    }

    private static func sinf(
        scheme: CommonEncryptionScheme,
        tenc: TrackEncryptionBox
    ) -> ProtectionSchemeInfoBox {
        ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "avc1"),
            schemeType: SchemeTypeBox(schemeType: scheme),
            schemeInformation: SchemeInformationBox(trackEncryption: tenc)
        )
    }

    // MARK: - Valid combinations (no throw)

    @Test
    func cencWithV0TencAccepted() throws {
        try Self.sinf(scheme: .cenc, tenc: Self.tencV0()).validateCommonEncryptionConsistency()
    }

    @Test
    func cbc1WithV0TencAccepted() throws {
        try Self.sinf(scheme: .cbc1, tenc: Self.tencV0()).validateCommonEncryptionConsistency()
    }

    @Test
    func censWithV1PatternAccepted() throws {
        try Self.sinf(scheme: .cens, tenc: Self.tencV1()).validateCommonEncryptionConsistency()
    }

    @Test
    func cbcsWithV1PatternAccepted() throws {
        try Self.sinf(scheme: .cbcs, tenc: Self.tencV1()).validateCommonEncryptionConsistency()
    }

    @Test
    func cencWithV1NoPatternAccepted() throws {
        let tenc = Self.tencV1(crypt: 0, skip: 0)
        try Self.sinf(scheme: .cenc, tenc: tenc).validateCommonEncryptionConsistency()
    }

    @Test
    func cbcsWithSixteenByteConstantIV() throws {
        let iv = try ConstantIV(rawBytes: Data(repeating: 0x33, count: 16))
        let tenc = Self.tencV1(ivSize: .zero, constantIV: iv)
        try Self.sinf(scheme: .cbcs, tenc: tenc).validateCommonEncryptionConsistency()
    }

    @Test
    func censWithEightByteConstantIVAccepted() throws {
        // For cens, the standard does not forbid 8-byte IVs.
        let iv = try ConstantIV(rawBytes: Data(repeating: 0x99, count: 8))
        let tenc = Self.tencV1(ivSize: .zero, constantIV: iv)
        try Self.sinf(scheme: .cens, tenc: tenc).validateCommonEncryptionConsistency()
    }

    @Test
    func patternSchemeWithOnlyCryptBlockAccepted() throws {
        let tenc = Self.tencV1(crypt: 7, skip: 0)
        try Self.sinf(scheme: .cens, tenc: tenc).validateCommonEncryptionConsistency()
    }

    @Test
    func patternSchemeWithOnlySkipBlockAccepted() throws {
        let tenc = Self.tencV1(crypt: 0, skip: 4)
        try Self.sinf(scheme: .cbcs, tenc: tenc).validateCommonEncryptionConsistency()
    }

    // MARK: - Invalid combinations (must throw)

    @Test
    func censWithV0TencRejected() {
        let sinf = Self.sinf(scheme: .cens, tenc: Self.tencV0())
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cbcsWithV0TencRejected() {
        let sinf = Self.sinf(scheme: .cbcs, tenc: Self.tencV0())
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cencWithPatternBlocksRejected() {
        let sinf = Self.sinf(scheme: .cenc, tenc: Self.tencV1(crypt: 1, skip: 9))
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cbc1WithPatternBlocksRejected() {
        let sinf = Self.sinf(scheme: .cbc1, tenc: Self.tencV1(crypt: 1, skip: 9))
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cencWithCryptOnlyRejected() {
        let sinf = Self.sinf(scheme: .cenc, tenc: Self.tencV1(crypt: 1, skip: 0))
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cencWithSkipOnlyRejected() {
        let sinf = Self.sinf(scheme: .cenc, tenc: Self.tencV1(crypt: 0, skip: 1))
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func censWithBothZeroBlocksRejected() {
        let sinf = Self.sinf(scheme: .cens, tenc: Self.tencV1(crypt: 0, skip: 0))
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cbcsWithBothZeroBlocksRejected() {
        let sinf = Self.sinf(scheme: .cbcs, tenc: Self.tencV1(crypt: 0, skip: 0))
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cbcsWithEightByteConstantIVRejected() throws {
        let iv = try ConstantIV(rawBytes: Data(repeating: 0x55, count: 8))
        let tenc = Self.tencV1(ivSize: .zero, constantIV: iv)
        let sinf = Self.sinf(scheme: .cbcs, tenc: tenc)
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func anySchemeWithoutSchemeInformationRejected() {
        for scheme in CommonEncryptionScheme.allCases {
            let sinf = ProtectionSchemeInfoBox(
                originalFormat: OriginalFormatBox(dataFormat: "avc1"),
                schemeType: SchemeTypeBox(schemeType: scheme),
                schemeInformation: nil
            )
            #expect(throws: ISOBoxError.self) {
                try sinf.validateCommonEncryptionConsistency()
            }
        }
    }

    @Test
    func anySchemeWithoutTencRejected() {
        for scheme in CommonEncryptionScheme.allCases {
            let sinf = ProtectionSchemeInfoBox(
                originalFormat: OriginalFormatBox(dataFormat: "avc1"),
                schemeType: SchemeTypeBox(schemeType: scheme),
                schemeInformation: SchemeInformationBox(trackEncryption: nil)
            )
            #expect(throws: ISOBoxError.self) {
                try sinf.validateCommonEncryptionConsistency()
            }
        }
    }

    @Test
    func sinfWithoutSchemeTypeSkipsAllValidation() throws {
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "avc1"),
            schemeType: nil,
            schemeInformation: SchemeInformationBox()
        )
        try sinf.validateCommonEncryptionConsistency()
    }

    @Test
    func censRejectsV0Tenc() {
        let sinf = Self.sinf(scheme: .cens, tenc: Self.tencV0())
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cbc1RejectsCryptBlock() {
        let sinf = Self.sinf(scheme: .cbc1, tenc: Self.tencV1(crypt: 1, skip: 0))
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cbc1RejectsSkipBlock() {
        let sinf = Self.sinf(scheme: .cbc1, tenc: Self.tencV1(crypt: 0, skip: 1))
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    // MARK: - Validation enforced at parse time

    @Test
    func invalidCombinationRejectedOnParse() async throws {
        let sinf = Self.sinf(scheme: .cbcs, tenc: Self.tencV0())  // wrong version
        var writer = BinaryWriter()
        sinf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func validCombinationParsesCleanly() async throws {
        let sinf = Self.sinf(scheme: .cenc, tenc: Self.tencV0())
        var writer = BinaryWriter()
        sinf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ProtectionSchemeInfoBox)
        #expect(parsed == sinf)
    }
}

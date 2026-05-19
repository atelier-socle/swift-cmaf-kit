// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ProtectionSchemeInfoBox (sinf) — round-trip")
struct ProtectionSchemeInfoBoxRoundTripTests {

    fileprivate static func makeKID() -> KeyIdentifier {
        KeyIdentifier(rawBytes: Data(repeating: 0x55, count: 16))
    }

    fileprivate static func makeTENCv0() -> TrackEncryptionBox {
        TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: makeKID()
        )
    }

    fileprivate static func makeTENCv1(
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
            defaultKID: makeKID(),
            defaultConstantIV: constantIV
        )
    }

    fileprivate static func makeSinf(
        scheme: CommonEncryptionScheme,
        tenc: TrackEncryptionBox,
        originalFormat: FourCC = "avc1"
    ) -> ProtectionSchemeInfoBox {
        ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: originalFormat),
            schemeType: SchemeTypeBox(schemeType: scheme),
            schemeInformation: SchemeInformationBox(trackEncryption: tenc)
        )
    }

    private func roundTrip(_ box: ProtectionSchemeInfoBox) async throws -> ProtectionSchemeInfoBox {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? ProtectionSchemeInfoBox)
    }

    @Test
    func cencRoundTrip() async throws {
        let box = Self.makeSinf(scheme: .cenc, tenc: Self.makeTENCv0())
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.schemeType?.schemeType == .cenc)
    }

    @Test
    func cbc1RoundTrip() async throws {
        let box = Self.makeSinf(scheme: .cbc1, tenc: Self.makeTENCv0())
        let parsed = try await roundTrip(box)
        #expect(parsed.schemeType?.schemeType == .cbc1)
    }

    @Test
    func censPatternRoundTrip() async throws {
        let box = Self.makeSinf(scheme: .cens, tenc: Self.makeTENCv1())
        let parsed = try await roundTrip(box)
        #expect(parsed.schemeType?.schemeType == .cens)
    }

    @Test
    func cbcsPatternRoundTrip() async throws {
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0xC0, count: 16))
        let box = Self.makeSinf(
            scheme: .cbcs,
            tenc: Self.makeTENCv1(ivSize: .zero, constantIV: constantIV)
        )
        let parsed = try await roundTrip(box)
        #expect(parsed.schemeType?.schemeType == .cbcs)
        #expect(parsed.schemeInformation?.trackEncryption?.defaultConstantIV == constantIV)
    }

    @Test
    func sinfWithOnlyFrma() async throws {
        let box = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "hvc1")
        )
        let parsed = try await roundTrip(box)
        #expect(parsed == box)
        #expect(parsed.schemeType == nil)
        #expect(parsed.schemeInformation == nil)
    }

    @Test
    func boxType() {
        #expect(ProtectionSchemeInfoBox.boxType == "sinf")
    }

    @Test
    func registryParserIsRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        let parser = await registry.parser(for: "sinf")
        #expect(parser != nil)
    }

    @Test
    func missingFrmaRejected() async {
        var raw = BinaryWriter()
        raw.writeBox(type: "sinf") { _ in
            // intentionally empty
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: raw.data, using: registry)
        }
    }

    @Test
    func bodyBoundedSoTrailingContainerBoxesAreNotConsumed() async throws {
        let sinf = Self.makeSinf(scheme: .cenc, tenc: Self.makeTENCv0())
        let trailing = OriginalFormatBox(dataFormat: "mp4a")
        var writer = BinaryWriter()
        sinf.encode(to: &writer)
        trailing.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        #expect(boxes.count == 2)
        let parsedSinf = try #require(boxes[0] as? ProtectionSchemeInfoBox)
        #expect(parsedSinf.originalFormat.dataFormat == "avc1")
        let parsedTrailing = try #require(boxes[1] as? OriginalFormatBox)
        #expect(parsedTrailing.dataFormat == "mp4a")
    }
}

@Suite("ProtectionSchemeInfoBox (sinf) — cross-field validation")
struct ProtectionSchemeInfoBoxValidationTests {

    @Test
    func patternSchemeWithVersion0TencThrows() {
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(
            scheme: .cens,
            tenc: ProtectionSchemeInfoBoxRoundTripTests.makeTENCv0()
        )
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cbcsWithVersion0TencThrows() {
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(
            scheme: .cbcs,
            tenc: ProtectionSchemeInfoBoxRoundTripTests.makeTENCv0()
        )
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func patternSchemeWithBothBlocksZeroThrows() {
        let tenc = ProtectionSchemeInfoBoxRoundTripTests.makeTENCv1(crypt: 0, skip: 0)
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(scheme: .cens, tenc: tenc)
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cencWithPatternBlocksThrows() {
        let tenc = ProtectionSchemeInfoBoxRoundTripTests.makeTENCv1(crypt: 1, skip: 9)
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(scheme: .cenc, tenc: tenc)
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cbc1WithPatternBlocksThrows() {
        let tenc = ProtectionSchemeInfoBoxRoundTripTests.makeTENCv1(crypt: 1, skip: 9)
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(scheme: .cbc1, tenc: tenc)
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cencWithoutTencThrows() {
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "avc1"),
            schemeType: SchemeTypeBox(schemeType: .cenc),
            schemeInformation: SchemeInformationBox()
        )
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cencWithoutSchemeInformationThrows() {
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "avc1"),
            schemeType: SchemeTypeBox(schemeType: .cenc),
            schemeInformation: nil
        )
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cbcsWithEightByteConstantIVThrows() throws {
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0x42, count: 8))
        let tenc = ProtectionSchemeInfoBoxRoundTripTests.makeTENCv1(
            ivSize: .zero,
            constantIV: constantIV
        )
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(scheme: .cbcs, tenc: tenc)
        #expect(throws: ISOBoxError.self) {
            try sinf.validateCommonEncryptionConsistency()
        }
    }

    @Test
    func cbcsWithSixteenByteConstantIVPasses() throws {
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0x42, count: 16))
        let tenc = ProtectionSchemeInfoBoxRoundTripTests.makeTENCv1(
            ivSize: .zero,
            constantIV: constantIV
        )
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(scheme: .cbcs, tenc: tenc)
        try sinf.validateCommonEncryptionConsistency()
    }

    @Test
    func cencWithMatchingV0TencPasses() throws {
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(
            scheme: .cenc,
            tenc: ProtectionSchemeInfoBoxRoundTripTests.makeTENCv0()
        )
        try sinf.validateCommonEncryptionConsistency()
    }

    @Test
    func cbc1WithMatchingV0TencPasses() throws {
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(
            scheme: .cbc1,
            tenc: ProtectionSchemeInfoBoxRoundTripTests.makeTENCv0()
        )
        try sinf.validateCommonEncryptionConsistency()
    }

    @Test
    func censWithPatternBlocksPasses() throws {
        let tenc = ProtectionSchemeInfoBoxRoundTripTests.makeTENCv1(crypt: 1, skip: 9)
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(scheme: .cens, tenc: tenc)
        try sinf.validateCommonEncryptionConsistency()
    }

    @Test
    func sinfWithoutSchmSkipsValidation() throws {
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "avc1")
        )
        try sinf.validateCommonEncryptionConsistency()
    }

    @Test
    func patternSchemeWithOnlyCryptBlockNonZeroPasses() throws {
        let tenc = ProtectionSchemeInfoBoxRoundTripTests.makeTENCv1(crypt: 1, skip: 0)
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(scheme: .cens, tenc: tenc)
        try sinf.validateCommonEncryptionConsistency()
    }

    @Test
    func patternSchemeWithOnlySkipBlockNonZeroPasses() throws {
        let tenc = ProtectionSchemeInfoBoxRoundTripTests.makeTENCv1(crypt: 0, skip: 1)
        let sinf = ProtectionSchemeInfoBoxRoundTripTests.makeSinf(scheme: .cens, tenc: tenc)
        try sinf.validateCommonEncryptionConsistency()
    }

    @Test
    func invalidCombinationsRejectedOnParse() async throws {
        // Encode a cbcs sinf with a version-0 tenc: round-trip should throw
        // because parse runs validate after assembling.
        let tenc = ProtectionSchemeInfoBoxRoundTripTests.makeTENCv0()
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: "avc1"),
            schemeType: SchemeTypeBox(schemeType: .cbcs),
            schemeInformation: SchemeInformationBox(trackEncryption: tenc)
        )
        var writer = BinaryWriter()
        sinf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }
}

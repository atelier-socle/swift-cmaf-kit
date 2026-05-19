// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFEncryptionParameters")
struct CMAFEncryptionParametersTests {

    private static func makeKID() -> KeyIdentifier {
        KeyIdentifier(rawBytes: Data(repeating: 0x42, count: 16))
    }

    @Test
    func cencComposesVersion0Tenc() {
        let params = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: Self.makeKID(),
            defaultPerSampleIVSize: .eight
        )
        let tenc = params.makeTrackEncryptionBox()
        #expect(tenc.version == 0)
        #expect(tenc.defaultIsProtected)
        #expect(tenc.defaultPerSampleIVSize == .eight)
        #expect(tenc.defaultCryptByteBlock == 0)
        #expect(tenc.defaultSkipByteBlock == 0)
    }

    @Test
    func cbcsComposesVersion1TencWithPattern() throws {
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0xAA, count: 16))
        let params = CMAFEncryptionParameters(
            scheme: .cbcs,
            defaultKID: Self.makeKID(),
            defaultPerSampleIVSize: .zero,
            defaultConstantIV: constantIV,
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9
        )
        let tenc = params.makeTrackEncryptionBox()
        #expect(tenc.version == 1)
        #expect(tenc.defaultCryptByteBlock == 1)
        #expect(tenc.defaultSkipByteBlock == 9)
        #expect(tenc.defaultConstantIV == constantIV)
    }

    @Test
    func sinfWrapsOriginalFormatAndScheme() {
        let params = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: Self.makeKID(),
            defaultPerSampleIVSize: .eight
        )
        let sinf = params.makeProtectionSchemeInfoBox(originalFormat: "avc1")
        #expect(sinf.originalFormat.dataFormat == "avc1")
        #expect(sinf.schemeType?.schemeType == .cenc)
        #expect(sinf.schemeInformation?.trackEncryption?.defaultIsProtected == true)
    }

    @Test
    func sinfCensWithPatternRoundTripsValidation() throws {
        let params = CMAFEncryptionParameters(
            scheme: .cens,
            defaultKID: Self.makeKID(),
            defaultPerSampleIVSize: .eight,
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9
        )
        let sinf = params.makeProtectionSchemeInfoBox(originalFormat: "hvc1")
        try sinf.validateCommonEncryptionConsistency()
    }

    @Test
    func psshBoxesPassthrough() throws {
        let widevine = try #require(UUID(uuidString: "EDEF8BA9-79D6-4ACE-A3C8-27DCD51D21ED"))
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevine,
            keyIdentifiers: [Self.makeKID()],
            data: Data([0xDE, 0xAD])
        )
        let params = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: Self.makeKID(),
            defaultPerSampleIVSize: .eight,
            psshBoxes: [pssh]
        )
        #expect(params.psshBoxes.count == 1)
        #expect(params.psshBoxes[0].systemID == widevine)
    }
}

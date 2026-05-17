// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCTag validation")
struct ICCTagValidationTests {

    @Test
    func mediaWhitePointAcceptsXYZ() {
        let element: ICCElement = .xyz(
            ICCXYZType(values: [
                ICCXYZNumber(
                    x: ICCS15Fixed16Number(0.9505),
                    y: ICCS15Fixed16Number(1.0),
                    z: ICCS15Fixed16Number(1.0890)
                )
            ]))
        #expect(ICCTag.isValidElementType(signature: .mediaWhitePoint, element: element))
    }

    @Test
    func mediaWhitePointRejectsCurve() {
        let element: ICCElement = .curve(ICCCurveType(values: []))
        #expect(!ICCTag.isValidElementType(signature: .mediaWhitePoint, element: element))
    }

    @Test
    func redTRCAcceptsCurve() {
        let element: ICCElement = .curve(ICCCurveType(values: [0x0233]))
        #expect(ICCTag.isValidElementType(signature: .redTRC, element: element))
    }

    @Test
    func redTRCAcceptsParametricCurve() {
        let element: ICCElement = .parametricCurve(
            ICCParametricCurveType(
                functionType: .gammaOnly,
                parameters: [ICCS15Fixed16Number(2.2)]
            ))
        #expect(ICCTag.isValidElementType(signature: .redTRC, element: element))
    }

    @Test
    func copyrightAcceptsMlucOrText() {
        let mluc: ICCElement = .multiLocalizedUnicode(
            ICCMultiLocalizedUnicodeType(
                strings: [.init(languageCode: 0x656E, countryCode: 0x5553, text: "© 2026")]
            ))
        let text: ICCElement = .text("Copyright 2026")
        #expect(ICCTag.isValidElementType(signature: .copyright, element: mluc))
        #expect(ICCTag.isValidElementType(signature: .copyright, element: text))
    }

    @Test
    func chromaticAdaptationAcceptsS15Fixed16Array() {
        let element: ICCElement = .s15Fixed16Array(
            ICCS15Fixed16ArrayType(values: [
                ICCS15Fixed16Number(1.0)
            ]))
        #expect(ICCTag.isValidElementType(signature: .chromaticAdaptation, element: element))
    }

    @Test
    func aToB0AcceptsLUTTypes() {
        let lut8: ICCElement = .lut8(ICCLUT8Type(inputChannels: 0, outputChannels: 0, clutPoints: 0, rawPayload: Data()))
        let lut16: ICCElement = .lut16(ICCLUT16Type(inputChannels: 0, outputChannels: 0, clutPoints: 0, rawPayload: Data()))
        let aToB: ICCElement = .lutAToB(ICCLUTAToBType(inputChannels: 0, outputChannels: 0, rawPayload: Data()))
        #expect(ICCTag.isValidElementType(signature: .aToB0, element: lut8))
        #expect(ICCTag.isValidElementType(signature: .aToB0, element: lut16))
        #expect(ICCTag.isValidElementType(signature: .aToB0, element: aToB))
    }

    @Test
    func technologyAcceptsSignatureOnly() {
        let sig: ICCElement = .signature(ICCSignatureType(signature: 0x6463_7274))
        #expect(ICCTag.isValidElementType(signature: .technology, element: sig))
        let xyz: ICCElement = .xyz(ICCXYZType(values: []))
        #expect(!ICCTag.isValidElementType(signature: .technology, element: xyz))
    }

    @Test
    func bToD0AcceptsMPE() {
        let mpe: ICCElement = .multiProcessElements(
            ICCMultiProcessElementsType(
                inputChannels: 3, outputChannels: 3, rawPayload: Data()
            ))
        #expect(ICCTag.isValidElementType(signature: .bToD0, element: mpe))
    }

    @Test
    func viewingConditionsAcceptsViewType() {
        let view: ICCElement = .viewingConditions(
            ICCViewingConditionsType(
                unconditionalIlluminant: ICCXYZNumber(
                    x: ICCS15Fixed16Number(0.0),
                    y: ICCS15Fixed16Number(0.0),
                    z: ICCS15Fixed16Number(0.0)
                ),
                unconditionalSurround: ICCXYZNumber(
                    x: ICCS15Fixed16Number(0.0),
                    y: ICCS15Fixed16Number(0.0),
                    z: ICCS15Fixed16Number(0.0)
                ),
                illuminantType: .d50
            ))
        #expect(ICCTag.isValidElementType(signature: .viewingConditions, element: view))
    }

    @Test
    func calibrationDateTimeAcceptsDateTime() {
        let dt: ICCElement = .dateTime(
            ICCDateTimeNumber(
                year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0
            ))
        #expect(ICCTag.isValidElementType(signature: .calibrationDateTime, element: dt))
    }

    @Test
    func namedColor2AcceptsNcl2() {
        let ncl: ICCElement = .namedColor2(
            ICCNamedColor2Type(
                vendorFlags: 0,
                deviceCoordinateCount: 0,
                prefix: Data(count: 32),
                suffix: Data(count: 32),
                colors: []
            ))
        #expect(ICCTag.isValidElementType(signature: .namedColor2, element: ncl))
    }

    @Test
    func charTargetAcceptsText() {
        let text: ICCElement = .text("Test target")
        #expect(ICCTag.isValidElementType(signature: .charTarget, element: text))
    }
}

@Suite("ICCProfile round-trip")
struct ICCProfileRoundTripTests {

    private func makeMinimalDisplayProfile() -> ICCProfile {
        let header = ICCProfileHeader(
            profileSize: 0,
            preferredCMMType: 0x6170_706C,
            versionMajor: 4, versionMinor: 0, versionPatch: 0,
            profileClass: .displayDevice,
            colorSpace: .rgb,
            pcsColorSpace: .xyz,
            dateCreated: ICCDateTimeNumber(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0),
            primaryPlatform: .apple,
            flags: 0,
            deviceManufacturer: 0,
            deviceModel: 0,
            deviceAttributes: 0,
            renderingIntent: .perceptual,
            illuminantXYZ: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.9642),
                y: ICCS15Fixed16Number(1.0),
                z: ICCS15Fixed16Number(0.8249)
            ),
            creator: 0x6170_706C,
            profileID: Data(count: 16)
        )
        let whitePoint = ICCXYZNumber(
            x: ICCS15Fixed16Number(0.9505),
            y: ICCS15Fixed16Number(1.0),
            z: ICCS15Fixed16Number(1.0890)
        )
        let tag = ICCTag(
            signature: .mediaWhitePoint,
            element: .xyz(ICCXYZType(values: [whitePoint]))
        )
        return ICCProfile(header: header, tags: [tag])
    }

    @Test
    func minimalProfileRoundTrip() throws {
        let original = makeMinimalDisplayProfile()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfile.parse(reader: &reader)
        #expect(decoded.tags.count == original.tags.count)
        #expect(decoded.tags[0].signature == .mediaWhitePoint)
    }

    @Test
    func profileSizeFieldMatchesActualLength() throws {
        let original = makeMinimalDisplayProfile()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let encodedSize = writer.data.count
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfile.parse(reader: &reader)
        #expect(Int(decoded.header.profileSize) == encodedSize)
    }

    @Test
    func unknownTagSignatureThrows() async throws {
        // Build a minimal header + 1 tag with unknown signature.
        let header = makeMinimalDisplayProfile().header
        var headerWriter = BinaryWriter()
        header.encode(to: &headerWriter)
        var fullWriter = BinaryWriter()
        fullWriter.writeData(headerWriter.data)
        fullWriter.writeUInt32(1)  // tagCount
        fullWriter.writeUInt32(0xDEAD_BEEF)  // unknown signature
        fullWriter.writeUInt32(0)
        fullWriter.writeUInt32(0)

        var bytes = fullWriter.data
        // Patch profileSize at offset 0.
        let total = UInt32(bytes.count)
        bytes[0] = UInt8((total >> 24) & 0xFF)
        bytes[1] = UInt8((total >> 16) & 0xFF)
        bytes[2] = UInt8((total >> 8) & 0xFF)
        bytes[3] = UInt8(total & 0xFF)

        var reader = BinaryReader(bytes)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCProfile.parse(reader: &reader)
        }
    }

    @Test
    func twoTagsRoundTrip() throws {
        let header = makeMinimalDisplayProfile().header
        let wtpt = ICCTag(
            signature: .mediaWhitePoint,
            element: .xyz(
                ICCXYZType(values: [
                    ICCXYZNumber(
                        x: ICCS15Fixed16Number(0.9505),
                        y: ICCS15Fixed16Number(1.0),
                        z: ICCS15Fixed16Number(1.0890)
                    )
                ]))
        )
        let rxyz = ICCTag(
            signature: .redMatrixColumn,
            element: .xyz(
                ICCXYZType(values: [
                    ICCXYZNumber(
                        x: ICCS15Fixed16Number(0.4361),
                        y: ICCS15Fixed16Number(0.2225),
                        z: ICCS15Fixed16Number(0.0139)
                    )
                ]))
        )
        let original = ICCProfile(header: header, tags: [wtpt, rxyz])
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfile.parse(reader: &reader)
        #expect(decoded.tags.count == 2)
    }

    @Test
    func tagDataPaddingPreserved() throws {
        let original = makeMinimalDisplayProfile()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        // Encoded size must be 4-byte aligned per ICC.1:2022 §7.3.2.
        #expect(writer.data.count % 4 == 0)
    }

    @Test
    func bytePerfectRoundTrip() throws {
        let original = makeMinimalDisplayProfile()
        var w1 = BinaryWriter()
        original.encode(to: &w1)
        var reader = BinaryReader(w1.data)
        let decoded = try ICCProfile.parse(reader: &reader)
        var w2 = BinaryWriter()
        decoded.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func emptyTagsRoundTrip() throws {
        let header = makeMinimalDisplayProfile().header
        let original = ICCProfile(header: header, tags: [])
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfile.parse(reader: &reader)
        #expect(decoded.tags.isEmpty)
    }

    @Test
    func headerProfileClassPreserved() throws {
        let original = makeMinimalDisplayProfile()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfile.parse(reader: &reader)
        #expect(decoded.header.profileClass == .displayDevice)
    }

    @Test
    func renderingIntentPreserved() throws {
        let original = makeMinimalDisplayProfile()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfile.parse(reader: &reader)
        #expect(decoded.header.renderingIntent == .perceptual)
    }

    @Test
    func curveTagRoundTrip() throws {
        let header = makeMinimalDisplayProfile().header
        let trc = ICCTag(
            signature: .redTRC,
            element: .curve(ICCCurveType(values: [0x0233]))
        )
        let original = ICCProfile(header: header, tags: [trc])
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfile.parse(reader: &reader)
        #expect(decoded.tags[0].signature == .redTRC)
        if case .curve(let curve) = decoded.tags[0].element {
            #expect(curve.values == [0x0233])
        } else {
            Issue.record("Expected curve element")
        }
    }
}

@Suite("RestrictedICCProfile")
struct RestrictedICCProfileTests {

    private func makeDisplayProfile() -> ICCProfile {
        let header = ICCProfileHeader(
            profileSize: 0,
            preferredCMMType: 0,
            versionMajor: 4, versionMinor: 0, versionPatch: 0,
            profileClass: .displayDevice,
            colorSpace: .rgb,
            pcsColorSpace: .xyz,
            dateCreated: ICCDateTimeNumber(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0),
            primaryPlatform: .apple,
            flags: 0, deviceManufacturer: 0, deviceModel: 0, deviceAttributes: 0,
            renderingIntent: .perceptual,
            illuminantXYZ: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.9642),
                y: ICCS15Fixed16Number(1.0),
                z: ICCS15Fixed16Number(0.8249)
            ),
            creator: 0,
            profileID: Data(count: 16)
        )
        return ICCProfile(header: header, tags: [])
    }

    private func makeOutputProfile() -> ICCProfile {
        let header = ICCProfileHeader(
            profileSize: 0,
            preferredCMMType: 0,
            versionMajor: 4, versionMinor: 0, versionPatch: 0,
            profileClass: .outputDevice,
            colorSpace: .cmyk,
            pcsColorSpace: .lab,
            dateCreated: ICCDateTimeNumber(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0),
            primaryPlatform: .apple,
            flags: 0, deviceManufacturer: 0, deviceModel: 0, deviceAttributes: 0,
            renderingIntent: .perceptual,
            illuminantXYZ: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.9642),
                y: ICCS15Fixed16Number(1.0),
                z: ICCS15Fixed16Number(0.8249)
            ),
            creator: 0,
            profileID: Data(count: 16)
        )
        return ICCProfile(header: header, tags: [])
    }

    @Test
    func acceptsDisplayDeviceProfile() throws {
        _ = try RestrictedICCProfile(profile: makeDisplayProfile())
    }

    @Test
    func rejectsOutputDeviceProfile() async throws {
        let profile = makeOutputProfile()
        #expect(throws: ISOBoxError.self) {
            _ = try RestrictedICCProfile(profile: profile)
        }
    }

    @Test
    func validateDirectlyOnNonDisplayThrows() async throws {
        let profile = makeOutputProfile()
        #expect(throws: ISOBoxError.self) {
            try RestrictedICCProfile.validate(profile: profile)
        }
    }

    @Test
    func validateDirectlyOnDisplaySucceeds() throws {
        try RestrictedICCProfile.validate(profile: makeDisplayProfile())
    }

    @Test
    func roundTrip() throws {
        let restricted = try RestrictedICCProfile(profile: makeDisplayProfile())
        var writer = BinaryWriter()
        restricted.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try RestrictedICCProfile.parse(reader: &reader)
        #expect(decoded.profile.header.profileClass == .displayDevice)
    }

    @Test
    func equatableConformance() throws {
        let a = try RestrictedICCProfile(profile: makeDisplayProfile())
        let b = try RestrictedICCProfile(profile: makeDisplayProfile())
        #expect(a == b)
    }
}

@Suite("UnrestrictedICCProfile")
struct UnrestrictedICCProfileTests {

    private func makeAnyProfile() -> ICCProfile {
        let header = ICCProfileHeader(
            profileSize: 0,
            preferredCMMType: 0,
            versionMajor: 4, versionMinor: 0, versionPatch: 0,
            profileClass: .colorSpace,
            colorSpace: .lab,
            pcsColorSpace: .xyz,
            dateCreated: ICCDateTimeNumber(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0),
            primaryPlatform: .apple,
            flags: 0, deviceManufacturer: 0, deviceModel: 0, deviceAttributes: 0,
            renderingIntent: .perceptual,
            illuminantXYZ: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.0),
                y: ICCS15Fixed16Number(0.0),
                z: ICCS15Fixed16Number(0.0)
            ),
            creator: 0,
            profileID: Data(count: 16)
        )
        return ICCProfile(header: header, tags: [])
    }

    @Test
    func acceptsAnyClass() {
        _ = UnrestrictedICCProfile(profile: makeAnyProfile())
    }

    @Test
    func roundTrip() throws {
        let unrestricted = UnrestrictedICCProfile(profile: makeAnyProfile())
        var writer = BinaryWriter()
        unrestricted.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try UnrestrictedICCProfile.parse(reader: &reader)
        #expect(decoded.profile.header.colorSpace == .lab)
    }

    @Test
    func equatableConformance() {
        let a = UnrestrictedICCProfile(profile: makeAnyProfile())
        let b = UnrestrictedICCProfile(profile: makeAnyProfile())
        #expect(a == b)
    }

    @Test
    func wrappedProfileAccessible() {
        let u = UnrestrictedICCProfile(profile: makeAnyProfile())
        #expect(u.profile.header.profileClass == .colorSpace)
    }
}

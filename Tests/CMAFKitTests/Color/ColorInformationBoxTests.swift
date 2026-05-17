// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ColorInformationBox")
struct ColorInformationBoxTests {

    @Test
    func nclxBT709RoundTrip() async throws {
        let original = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709,
                    fullRangeFlag: .limited
                )))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ColorInformationBox)
        #expect(parsed == original)
    }

    @Test
    func nclxBT2020PQRoundTrip() async throws {
        let original = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt2020,
                    transferCharacteristics: .smpteST2084_PQ,
                    matrixCoefficients: .bt2020NCL,
                    fullRangeFlag: .limited
                )))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ColorInformationBox)
        #expect(parsed == original)
    }

    @Test
    func nclxHLGRoundTrip() async throws {
        let original = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt2020,
                    transferCharacteristics: .aribSTDB67_HLG,
                    matrixCoefficients: .bt2020NCL,
                    fullRangeFlag: .full
                )))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ColorInformationBox)
        #expect(parsed == original)
    }

    @Test
    func nclxDisplayP3RoundTrip() async throws {
        let original = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .p3D65,
                    transferCharacteristics: .iec61966_2_1_sRGB,
                    matrixCoefficients: .bt709,
                    fullRangeFlag: .full
                )))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ColorInformationBox)
        #expect(parsed == original)
    }

    @Test
    func wireSubTypeMatchesNclx() {
        let box = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709,
                    fullRangeFlag: .limited
                )))
        #expect(box.variant.wireSubType == "nclx")
    }

    @Test
    func unknownSubTypeThrows() async throws {
        // colr box with subtype 'xxxx' (unknown)
        let bytes = Data(hex: "00 00 00 0C 63 6F 6C 72 78 78 78 78")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func nclxFullRangeBitIsolated() async throws {
        let original = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709,
                    fullRangeFlag: .full
                )))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        // Look for the full-range byte (last byte of body before any padding)
        let lastByte = writer.data.last
        #expect(lastByte == 0x80)
    }

    @Test
    func encodedSizeForNclxBox() {
        let box = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709,
                    fullRangeFlag: .limited
                )))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // 8 header + 4 subtype + 2 cp + 2 tc + 2 mc + 1 frf = 19
        #expect(writer.data.count == 19)
    }

    @Test
    func equatableConformance() {
        let a = ColorInformationBox(
            variant: .nclx(
                NCLXColorInformation(
                    colorPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709,
                    fullRangeFlag: .limited
                )))
        let b = a
        #expect(a == b)
    }

    @Test
    func wireSubTypeRestrictedICC() throws {
        let header = ICCProfileHeader(
            profileSize: 128,
            preferredCMMType: 0,
            versionMajor: 4,
            versionMinor: 0,
            versionPatch: 0,
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
            creator: 0,
            profileID: Data(count: 16)
        )
        let profile = ICCProfile(header: header, tags: [])
        let restricted = try #require(try? RestrictedICCProfile(profile: profile))
        let box = ColorInformationBox(variant: .restrictedICC(restricted))
        #expect(box.variant.wireSubType == "rICC")
    }

    @Test
    func wireSubTypeUnrestrictedICC() {
        let header = ICCProfileHeader(
            profileSize: 128,
            preferredCMMType: 0,
            versionMajor: 4, versionMinor: 0, versionPatch: 0,
            profileClass: .outputDevice,
            colorSpace: .cmyk,
            pcsColorSpace: .lab,
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
            creator: 0,
            profileID: Data(count: 16)
        )
        let unrestricted = UnrestrictedICCProfile(profile: ICCProfile(header: header, tags: []))
        let box = ColorInformationBox(variant: .unrestrictedICC(unrestricted))
        #expect(box.variant.wireSubType == "prof")
    }
}

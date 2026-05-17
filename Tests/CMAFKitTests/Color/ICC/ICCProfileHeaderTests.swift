// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCProfileHeader")
struct ICCProfileHeaderTests {

    private func makeMinimalHeader() -> ICCProfileHeader {
        ICCProfileHeader(
            profileSize: 0,
            preferredCMMType: 0x6170_706C,
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
            creator: 0x6170_706C,
            profileID: Data(count: 16)
        )
    }

    @Test
    func roundTripMinimal() throws {
        let original = makeMinimalHeader()
        var writer = BinaryWriter()
        original.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileHeader.parse(reader: &reader)
        #expect(decoded == original)
    }

    @Test
    func isExactly128BytesOnWire() {
        let h = makeMinimalHeader()
        var writer = BinaryWriter()
        h.encode(to: &writer)
        #expect(writer.data.count == 128)
    }

    @Test
    func fileSignatureIsAcsp() {
        let h = makeMinimalHeader()
        #expect(h.fileSignature == 0x6163_7370)
    }

    @Test
    func wrongFileSignatureRejected() async throws {
        var data = Data(count: 128)
        // Set profileSize = 128, fileSignature = 'BAD!' at offset 36.
        data[3] = 128
        data[36] = 0x42
        data[37] = 0x41
        data[38] = 0x44
        data[39] = 0x21
        var reader = BinaryReader(data)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCProfileHeader.parse(reader: &reader)
        }
    }

    @Test
    func versionEncoding() {
        let h = makeMinimalHeader()
        var writer = BinaryWriter()
        h.encode(to: &writer)
        // versionMajor at byte 8, packed minor.patch at byte 9.
        #expect(writer.data[8] == 4)
    }

    @Test
    func displayClassPreserved() throws {
        let h = makeMinimalHeader()
        var writer = BinaryWriter()
        h.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileHeader.parse(reader: &reader)
        #expect(decoded.profileClass == .displayDevice)
    }

    @Test
    func renderingIntentPreserved() throws {
        let h = ICCProfileHeader(
            profileSize: 0,
            preferredCMMType: 0,
            versionMajor: 4, versionMinor: 0, versionPatch: 0,
            profileClass: .displayDevice,
            colorSpace: .rgb,
            pcsColorSpace: .xyz,
            dateCreated: ICCDateTimeNumber(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0),
            primaryPlatform: .apple,
            flags: 0, deviceManufacturer: 0, deviceModel: 0, deviceAttributes: 0,
            renderingIntent: .saturation,
            illuminantXYZ: ICCXYZNumber(
                x: ICCS15Fixed16Number(0.0),
                y: ICCS15Fixed16Number(0.0),
                z: ICCS15Fixed16Number(0.0)
            ),
            creator: 0,
            profileID: Data(count: 16)
        )
        var writer = BinaryWriter()
        h.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileHeader.parse(reader: &reader)
        #expect(decoded.renderingIntent == .saturation)
    }

    @Test
    func cmykProfilePreserved() throws {
        let h = ICCProfileHeader(
            profileSize: 0,
            preferredCMMType: 0,
            versionMajor: 4, versionMinor: 0, versionPatch: 0,
            profileClass: .outputDevice,
            colorSpace: .cmyk,
            pcsColorSpace: .lab,
            dateCreated: ICCDateTimeNumber(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0),
            primaryPlatform: .microsoft,
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
        var writer = BinaryWriter()
        h.encode(to: &writer)
        var reader = BinaryReader(writer.data)
        let decoded = try ICCProfileHeader.parse(reader: &reader)
        #expect(decoded.colorSpace == .cmyk)
        #expect(decoded.pcsColorSpace == .lab)
        #expect(decoded.profileClass == .outputDevice)
        #expect(decoded.primaryPlatform == .microsoft)
    }

    @Test
    func unknownProfileClassRejected() async throws {
        var data = Data(count: 128)
        data[3] = 128
        // file signature 'acsp' at offset 36
        data[36] = 0x61
        data[37] = 0x63
        data[38] = 0x73
        data[39] = 0x70
        // profile class at offset 12: 'XXXX'
        data[12] = 0x58
        data[13] = 0x58
        data[14] = 0x58
        data[15] = 0x58
        // color space 'RGB ' at offset 16
        data[16] = 0x52
        data[17] = 0x47
        data[18] = 0x42
        data[19] = 0x20
        // PCS 'XYZ ' at offset 20
        data[20] = 0x58
        data[21] = 0x59
        data[22] = 0x5A
        data[23] = 0x20
        var reader = BinaryReader(data)
        #expect(throws: ISOBoxError.self) {
            _ = try ICCProfileHeader.parse(reader: &reader)
        }
    }

    @Test
    func profileIDIs16Bytes() {
        let h = makeMinimalHeader()
        #expect(h.profileID.count == 16)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("EncryptedVideoSampleEntry — typed re-wire")
struct EncryptedVideoSampleEntryRewireTests {

    private static func makeAVC() -> AVCDecoderConfigurationRecord {
        AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0xE0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))],
            pictureParameterSets: [AVCParameterSet(rbspBytes: Data([0x68, 0xCE, 0x3C, 0x80]))]
        )
    }

    private static func makeKID() -> KeyIdentifier {
        KeyIdentifier(rawBytes: Data(repeating: 0x33, count: 16))
    }

    private static func makeSinf(
        scheme: CommonEncryptionScheme,
        originalFormat: FourCC = "avc1"
    ) -> ProtectionSchemeInfoBox {
        let tenc: TrackEncryptionBox
        if scheme.usesPattern {
            tenc = TrackEncryptionBox(
                version: 1,
                defaultCryptByteBlock: 1,
                defaultSkipByteBlock: 9,
                defaultIsProtected: true,
                defaultPerSampleIVSize: .eight,
                defaultKID: makeKID()
            )
        } else {
            tenc = TrackEncryptionBox(
                version: 0,
                defaultIsProtected: true,
                defaultPerSampleIVSize: .eight,
                defaultKID: makeKID()
            )
        }
        return ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: originalFormat),
            schemeType: SchemeTypeBox(schemeType: scheme),
            schemeInformation: SchemeInformationBox(trackEncryption: tenc)
        )
    }

    private func roundTrip(
        _ entry: EncryptedVideoSampleEntry
    ) async throws -> EncryptedVideoSampleEntry {
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? EncryptedVideoSampleEntry)
    }

    @Test
    func avcCenc() async throws {
        let entry = EncryptedVideoSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            originalCodecConfiguration: .avc(Self.makeAVC()),
            protectionSchemeInfo: Self.makeSinf(scheme: .cenc)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed == entry)
    }

    @Test
    func avcCbc1() async throws {
        let entry = EncryptedVideoSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            originalCodecConfiguration: .avc(Self.makeAVC()),
            protectionSchemeInfo: Self.makeSinf(scheme: .cbc1)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.protectionSchemeInfo.schemeType?.schemeType == .cbc1)
    }

    @Test
    func avcCens() async throws {
        let entry = EncryptedVideoSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            originalCodecConfiguration: .avc(Self.makeAVC()),
            protectionSchemeInfo: Self.makeSinf(scheme: .cens)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.protectionSchemeInfo.schemeType?.schemeType == .cens)
    }

    @Test
    func avcCbcs() async throws {
        let entry = EncryptedVideoSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1920, height: 1080),
            originalCodecConfiguration: .avc(Self.makeAVC()),
            protectionSchemeInfo: Self.makeSinf(scheme: .cbcs)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.protectionSchemeInfo.schemeType?.schemeType == .cbcs)
    }

    @Test
    func videoCodecConfigurationBoxTypeMapping() {
        #expect(VideoCodecConfiguration.avc(Self.makeAVC()).boxType == "avcC")
    }

    @Test
    func encvBoxType() {
        #expect(EncryptedVideoSampleEntry.boxType == "encv")
    }

    @Test
    func videoCodecConfigurationEquality() {
        let a = VideoCodecConfiguration.avc(Self.makeAVC())
        let b = VideoCodecConfiguration.avc(Self.makeAVC())
        #expect(a == b)
    }

    @Test
    func encvByteForByteRoundTrip() async throws {
        let entry = EncryptedVideoSampleEntry(
            visualFields: VisualSampleEntryFields(width: 1280, height: 720),
            originalCodecConfiguration: .avc(Self.makeAVC()),
            protectionSchemeInfo: Self.makeSinf(scheme: .cenc)
        )
        var w1 = BinaryWriter()
        entry.encode(to: &w1)
        let parsed = try await roundTrip(entry)
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func missingCodecConfigChildThrows() async throws {
        var writer = BinaryWriter()
        writer.writeBox(type: "encv") { body in
            VisualSampleEntryFields(width: 1920, height: 1080).encode(to: &body)
            Self.makeSinf(scheme: .cenc).encode(to: &body)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }
}

@Suite("EncryptedAudioSampleEntry — typed re-wire")
struct EncryptedAudioSampleEntryRewireTests {

    private static func makeESDS() -> ElementaryStreamDescriptor {
        ElementaryStreamDescriptor(
            esID: 1,
            decoderConfig: ElementaryStreamDescriptor.DecoderConfigDescriptor(
                objectTypeIndication: .audioISO14496_3,
                streamType: .audioStream,
                upStream: false,
                bufferSizeDB: 1536,
                maxBitrate: 128_000,
                avgBitrate: 96_000,
                decoderSpecificInfo: Data([0x12, 0x10])
            )
        )
    }

    private static func makeAC3() -> AC3SpecificBox {
        AC3SpecificBox(
            fscod: .freq48000,
            bsid: 8,
            bsmod: .completeMain,
            acmod: .stereo,
            lfeon: false,
            bitRateCode: 6
        )
    }

    private static func makeKID() -> KeyIdentifier {
        KeyIdentifier(rawBytes: Data(repeating: 0x44, count: 16))
    }

    private static func makeSinf(
        scheme: CommonEncryptionScheme,
        originalFormat: FourCC = "mp4a"
    ) -> ProtectionSchemeInfoBox {
        let tenc: TrackEncryptionBox
        if scheme.usesPattern {
            tenc = TrackEncryptionBox(
                version: 1,
                defaultCryptByteBlock: 1,
                defaultSkipByteBlock: 9,
                defaultIsProtected: true,
                defaultPerSampleIVSize: .eight,
                defaultKID: makeKID()
            )
        } else {
            tenc = TrackEncryptionBox(
                version: 0,
                defaultIsProtected: true,
                defaultPerSampleIVSize: .eight,
                defaultKID: makeKID()
            )
        }
        return ProtectionSchemeInfoBox(
            originalFormat: OriginalFormatBox(dataFormat: originalFormat),
            schemeType: SchemeTypeBox(schemeType: scheme),
            schemeInformation: SchemeInformationBox(trackEncryption: tenc)
        )
    }

    private func roundTrip(
        _ entry: EncryptedAudioSampleEntry
    ) async throws -> EncryptedAudioSampleEntry {
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? EncryptedAudioSampleEntry)
    }

    @Test
    func mp4aCenc() async throws {
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            originalCodecConfiguration: .mp4Audio(Self.makeESDS()),
            protectionSchemeInfo: Self.makeSinf(scheme: .cenc)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed == entry)
    }

    @Test
    func mp4aCbc1() async throws {
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            originalCodecConfiguration: .mp4Audio(Self.makeESDS()),
            protectionSchemeInfo: Self.makeSinf(scheme: .cbc1)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.protectionSchemeInfo.schemeType?.schemeType == .cbc1)
    }

    @Test
    func ac3Cens() async throws {
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            originalCodecConfiguration: .ac3(Self.makeAC3()),
            protectionSchemeInfo: Self.makeSinf(scheme: .cens, originalFormat: "ac-3")
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.protectionSchemeInfo.schemeType?.schemeType == .cens)
    }

    @Test
    func ac3Cbcs() async throws {
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            originalCodecConfiguration: .ac3(Self.makeAC3()),
            protectionSchemeInfo: Self.makeSinf(scheme: .cbcs, originalFormat: "ac-3")
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.protectionSchemeInfo.schemeType?.schemeType == .cbcs)
    }

    @Test
    func audioCodecConfigurationBoxTypeMapping() {
        #expect(AudioCodecConfiguration.mp4Audio(Self.makeESDS()).boxType == "esds")
        #expect(AudioCodecConfiguration.ac3(Self.makeAC3()).boxType == "dac3")
    }

    @Test
    func encaBoxType() {
        #expect(EncryptedAudioSampleEntry.boxType == "enca")
    }

    @Test
    func audioCodecConfigurationEquality() {
        let a = AudioCodecConfiguration.mp4Audio(Self.makeESDS())
        let b = AudioCodecConfiguration.mp4Audio(Self.makeESDS())
        #expect(a == b)
    }

    @Test
    func encaByteForByteRoundTrip() async throws {
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            originalCodecConfiguration: .mp4Audio(Self.makeESDS()),
            protectionSchemeInfo: Self.makeSinf(scheme: .cenc)
        )
        var w1 = BinaryWriter()
        entry.encode(to: &w1)
        let parsed = try await roundTrip(entry)
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func missingCodecConfigChildThrows() async throws {
        var writer = BinaryWriter()
        writer.writeBox(type: "enca") { body in
            AudioSampleEntryFields().encode(to: &body)
            Self.makeSinf(scheme: .cenc).encode(to: &body)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }
}

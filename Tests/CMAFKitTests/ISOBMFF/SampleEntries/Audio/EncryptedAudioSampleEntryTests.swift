// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("EncryptedAudioSampleEntry")
struct EncryptedAudioSampleEntryTests {

    private static func makeKID() -> KeyIdentifier {
        KeyIdentifier(rawBytes: Data(repeating: 0xAB, count: 16))
    }

    private static func makeCENCSinf(
        originalFormat: FourCC = "mp4a"
    ) -> ProtectionSchemeInfoBox {
        let frma = OriginalFormatBox(dataFormat: originalFormat)
        let schm = SchemeTypeBox(schemeType: .cenc)
        let tenc = TrackEncryptionBox(
            version: 0,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .eight,
            defaultKID: makeKID()
        )
        let schi = SchemeInformationBox(trackEncryption: tenc)
        return ProtectionSchemeInfoBox(
            originalFormat: frma,
            schemeType: schm,
            schemeInformation: schi
        )
    }

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

    @Test
    func mp4AudioWithCENCRoundTrip() async throws {
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            originalCodecConfiguration: .mp4Audio(Self.makeESDS()),
            protectionSchemeInfo: Self.makeCENCSinf()
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedAudioSampleEntry)
        #expect(parsed == entry)
        #expect(parsed.protectionSchemeInfo.originalFormat.dataFormat == "mp4a")
    }

    @Test
    func ac3WithCBCSRoundTrip() async throws {
        let ac3 = AC3SpecificBox(
            fscod: .freq48000,
            bsid: 8,
            bsmod: .completeMain,
            acmod: .stereo,
            lfeon: false,
            bitRateCode: 6
        )
        let frma = OriginalFormatBox(dataFormat: "ac-3")
        let schm = SchemeTypeBox(schemeType: .cbcs)
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0x42, count: 16))
        let tenc = TrackEncryptionBox(
            version: 1,
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9,
            defaultIsProtected: true,
            defaultPerSampleIVSize: .zero,
            defaultKID: Self.makeKID(),
            defaultConstantIV: constantIV
        )
        let schi = SchemeInformationBox(trackEncryption: tenc)
        let sinf = ProtectionSchemeInfoBox(
            originalFormat: frma,
            schemeType: schm,
            schemeInformation: schi
        )
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            originalCodecConfiguration: .ac3(ac3),
            protectionSchemeInfo: sinf
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedAudioSampleEntry)
        #expect(parsed == entry)
        #expect(parsed.protectionSchemeInfo.schemeType?.schemeType == .cbcs)
    }

    @Test
    func extensionsRoutedSeparately() async throws {
        let chnl = ChannelLayoutBox(
            streamStructure: .channelStructured,
            channelLayout: .predefined(layout: .stereo, omittedChannelsMap: 0)
        )
        let entry = EncryptedAudioSampleEntry(
            audioFields: AudioSampleEntryFields(),
            originalCodecConfiguration: .mp4Audio(Self.makeESDS()),
            protectionSchemeInfo: Self.makeCENCSinf(),
            extensions: AudioSampleEntryExtensions(channelLayout: chnl)
        )
        var writer = BinaryWriter()
        entry.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EncryptedAudioSampleEntry)
        #expect(parsed.extensions.channelLayout == chnl)
        #expect(parsed.protectionSchemeInfo.originalFormat.dataFormat == "mp4a")
    }

    @Test
    func boxTypeIsEnca() {
        #expect(EncryptedAudioSampleEntry.boxType == "enca")
    }

    @Test
    func missingSinfThrows() async throws {
        // Manually craft an enca with only the codec config child to
        // ensure parse rejects the missing-sinf case.
        var writer = BinaryWriter()
        writer.writeBox(type: "enca") { body in
            AudioSampleEntryFields().encode(to: &body)
            Self.makeESDS().encode(to: &body)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }
}

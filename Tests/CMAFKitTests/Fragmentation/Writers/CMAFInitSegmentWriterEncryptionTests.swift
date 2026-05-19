// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("CMAFInitSegmentWriter — encryption")
struct CMAFInitSegmentWriterEncryptionTests {

    private func widevineUUID() throws -> UUID {
        try #require(UUID(uuidString: "EDEF8BA9-79D6-4ACE-A3C8-27DCD51D21ED"))
    }

    @Test
    func cencEncryptedVideoEmitsEncv() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [
                WriterFixtures.videoConfig(encrypted: WriterFixtures.cencParameters())
            ]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let stsd = try #require(sampleDescription(in: trak))
        let entry = try #require(stsd.entries.first as? EncryptedVideoSampleEntry)
        #expect(entry.protectionSchemeInfo.originalFormat.dataFormat == "avc1")
        #expect(entry.protectionSchemeInfo.schemeType?.schemeType == .cenc)
    }

    @Test
    func cbcsEncryptedAudioEmitsEnca() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [
                WriterFixtures.audioConfig(encrypted: try WriterFixtures.cbcsParameters())
            ]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let stsd = try #require(sampleDescription(in: trak))
        let entry = try #require(stsd.entries.first as? EncryptedAudioSampleEntry)
        #expect(entry.protectionSchemeInfo.schemeType?.schemeType == .cbcs)
    }

    @Test
    func psshBoxesEmittedAtMovieLevel() async throws {
        let widevine = try widevineUUID()
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevine,
            keyIdentifiers: [],
            data: Data([0xCA, 0xFE])
        )
        let encParams = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: WriterFixtures.makeKID(),
            defaultPerSampleIVSize: .eight,
            psshBoxes: [pssh]
        )
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.videoConfig(encrypted: encParams)]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let psshCount = moov.children
            .compactMap { $0 as? ProtectionSystemSpecificHeaderBox }
            .count
        #expect(psshCount == 1)
    }

    @Test
    func censSchemeRoundTrip() async throws {
        let encParams = CMAFEncryptionParameters(
            scheme: .cens,
            defaultKID: WriterFixtures.makeKID(),
            defaultPerSampleIVSize: .eight,
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9
        )
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.videoConfig(encrypted: encParams)]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let entry = try #require(
            sampleDescription(in: moov.tracks[0])?.entries.first as? EncryptedVideoSampleEntry
        )
        #expect(entry.protectionSchemeInfo.schemeType?.schemeType == .cens)
        let tenc = entry.protectionSchemeInfo.schemeInformation?.trackEncryption
        #expect(tenc?.version == 1)
        #expect(tenc?.defaultCryptByteBlock == 1)
    }

    @Test
    func cbc1SchemeRoundTrip() async throws {
        let encParams = CMAFEncryptionParameters(
            scheme: .cbc1,
            defaultKID: WriterFixtures.makeKID(),
            defaultPerSampleIVSize: .sixteen
        )
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.videoConfig(encrypted: encParams)]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let entry = try #require(
            sampleDescription(in: moov.tracks[0])?.entries.first as? EncryptedVideoSampleEntry
        )
        #expect(entry.protectionSchemeInfo.schemeType?.schemeType == .cbc1)
    }

    @Test
    func multipleDRMPsshBoxes() async throws {
        let widevine = try widevineUUID()
        let playReady = try #require(
            UUID(uuidString: "9A04F079-9840-4286-AB92-E65BE0885F95")
        )
        let pssh1 = ProtectionSystemSpecificHeaderBox(
            version: 1, systemID: widevine, keyIdentifiers: [], data: Data()
        )
        let pssh2 = ProtectionSystemSpecificHeaderBox(
            version: 1, systemID: playReady, keyIdentifiers: [], data: Data()
        )
        let encParams = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: WriterFixtures.makeKID(),
            defaultPerSampleIVSize: .eight,
            psshBoxes: [pssh1, pssh2]
        )
        let writer = try CMAFInitSegmentWriter(
            configurations: [WriterFixtures.videoConfig(encrypted: encParams)]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let psshes = moov.children.compactMap { $0 as? ProtectionSystemSpecificHeaderBox }
        #expect(psshes.count == 2)
    }

    @Test
    func encryptedAndPlainTracksCoexist() async throws {
        let writer = try CMAFInitSegmentWriter(
            configurations: [
                WriterFixtures.videoConfig(
                    trackID: 1,
                    encrypted: WriterFixtures.cencParameters()
                ),
                WriterFixtures.audioConfig(trackID: 2)
            ]
        )
        let bytes = try writer.emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let video = try #require(sampleDescription(in: moov.tracks[0])?.entries.first)
        let audio = try #require(sampleDescription(in: moov.tracks[1])?.entries.first)
        #expect(video is EncryptedVideoSampleEntry)
        #expect(audio is MP4AudioSampleEntry)
    }

    // MARK: - Helpers

    private func sampleDescription(in trak: TrackBox) -> SampleDescriptionBox? {
        trak.media?.mediaInformation?.children
            .compactMap { $0 as? SampleTableBox }
            .first?
            .children
            .compactMap { $0 as? SampleDescriptionBox }
            .first
    }
}

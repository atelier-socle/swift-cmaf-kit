// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("MovieTreeBuilder")
struct MovieTreeBuilderTests {

    fileprivate static func makeAVCConfig() -> AVCDecoderConfigurationRecord {
        AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0xE0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))],
            pictureParameterSets: [AVCParameterSet(rbspBytes: Data([0x68, 0xCE, 0x3C, 0x80]))]
        )
    }

    fileprivate static func makeESDS() -> ElementaryStreamDescriptor {
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

    fileprivate static func videoConfig() -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920,
                height: 1080,
                codec: .avc1,
                codecConfiguration: .avc(makeAVCConfig()),
                frameRate: CMAFTrackConfiguration.VideoFields.FrameRate(
                    numerator: 30,
                    denominator: 1
                )
            )
        )
    }

    fileprivate static func audioConfig() -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: 2,
            kind: .audio,
            profile: .basic,
            timescale: 48_000,
            language: "eng",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: .mp4a,
                codecConfiguration: .mp4Audio(makeESDS()),
                channelCount: 2,
                sampleRate: 48_000
            )
        )
    }

    @Test
    func singleVideoTrackMovieComposes() async throws {
        let moov = try MovieTreeBuilder.makeMovieBox(
            configurations: [Self.videoConfig()],
            referenceTimestamp: 0,
            movieTimescale: 1000
        )
        var writer = BinaryWriter()
        moov.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieBox)
        #expect(parsed.movieHeader?.timescale == 1000)
        #expect(parsed.movieHeader?.nextTrackID == 2)
        #expect(parsed.tracks.count == 1)
        #expect(parsed.tracks[0].trackHeader?.trackID == 1)
    }

    @Test
    func multiTrackMovieComposesWithMvex() async throws {
        let moov = try MovieTreeBuilder.makeMovieBox(
            configurations: [Self.videoConfig(), Self.audioConfig()],
            referenceTimestamp: 0,
            movieTimescale: 1000
        )
        let mvex = moov.children.first { $0 is MovieExtendsBox } as? MovieExtendsBox
        let trexes = mvex?.children.compactMap { $0 as? TrackExtendsBox } ?? []
        #expect(trexes.count == 2)
        #expect(Set(trexes.map { $0.trackID }) == [1, 2])
    }

    @Test
    func videoTrackHasVmhd() throws {
        let moov = try MovieTreeBuilder.makeMovieBox(
            configurations: [Self.videoConfig()],
            referenceTimestamp: 0,
            movieTimescale: 1000
        )
        let trak = try #require(moov.children.compactMap { $0 as? TrackBox }.first)
        let minf = try #require(trak.media?.mediaInformation)
        let hasVmhd = minf.children.contains { $0 is VideoMediaHeaderBox }
        #expect(hasVmhd)
    }

    @Test
    func audioTrackHasSmhd() throws {
        let moov = try MovieTreeBuilder.makeMovieBox(
            configurations: [Self.audioConfig()],
            referenceTimestamp: 0,
            movieTimescale: 1000
        )
        let trak = try #require(moov.children.compactMap { $0 as? TrackBox }.first)
        let minf = try #require(trak.media?.mediaInformation)
        let hasSmhd = minf.children.contains { $0 is SoundMediaHeaderBox }
        #expect(hasSmhd)
    }

    @Test
    func psshBoxesEmittedAtMovieLevel() async throws {
        let widevine = try #require(UUID(uuidString: "EDEF8BA9-79D6-4ACE-A3C8-27DCD51D21ED"))
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: widevine,
            keyIdentifiers: [],
            data: Data([0xCA])
        )
        let encryptionParams = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0x77, count: 16)),
            defaultPerSampleIVSize: .eight,
            psshBoxes: [pssh]
        )
        var config = Self.videoConfig()
        config = CMAFTrackConfiguration(
            trackID: config.trackID,
            kind: config.kind,
            profile: config.profile,
            timescale: config.timescale,
            language: config.language,
            videoFields: config.videoFields,
            audioFields: nil,
            subtitleFields: nil,
            metadataFields: nil,
            editList: nil,
            encryptionParameters: encryptionParams,
            defaultSampleFlags: config.defaultSampleFlags
        )
        let moov = try MovieTreeBuilder.makeMovieBox(
            configurations: [config],
            referenceTimestamp: 0,
            movieTimescale: 1000
        )
        let psshCount = moov.children.compactMap { $0 as? ProtectionSystemSpecificHeaderBox }.count
        #expect(psshCount == 1)
    }

    @Test
    func encryptedVideoSampleEntryHasSinf() throws {
        let encryptionParams = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: KeyIdentifier(rawBytes: Data(repeating: 0x77, count: 16)),
            defaultPerSampleIVSize: .eight
        )
        var config = Self.videoConfig()
        config = CMAFTrackConfiguration(
            trackID: config.trackID,
            kind: config.kind,
            profile: config.profile,
            timescale: config.timescale,
            language: config.language,
            videoFields: config.videoFields,
            audioFields: nil,
            subtitleFields: nil,
            metadataFields: nil,
            editList: nil,
            encryptionParameters: encryptionParams,
            defaultSampleFlags: config.defaultSampleFlags
        )
        let moov = try MovieTreeBuilder.makeMovieBox(
            configurations: [config],
            referenceTimestamp: 0,
            movieTimescale: 1000
        )
        let trak = try #require(moov.children.compactMap { $0 as? TrackBox }.first)
        let stbl = try #require(
            trak.media?.mediaInformation?.children
                .compactMap { $0 as? SampleTableBox }.first)
        let stsd = try #require(stbl.children.compactMap { $0 as? SampleDescriptionBox }.first)
        let entry = try #require(stsd.entries.first as? EncryptedVideoSampleEntry)
        #expect(entry.protectionSchemeInfo.originalFormat.dataFormat == "avc1")
    }

    @Test
    func mehdEmittedWhenFragmentDurationProvided() throws {
        let moov = try MovieTreeBuilder.makeMovieBox(
            configurations: [Self.videoConfig()],
            referenceTimestamp: 0,
            movieTimescale: 1000,
            fragmentDuration: 60_000
        )
        let mvex = try #require(moov.children.compactMap { $0 as? MovieExtendsBox }.first)
        let mehd = mvex.children.compactMap { $0 as? MovieExtendsHeaderBox }.first
        #expect(mehd?.fragmentDuration == 60_000)
    }
}

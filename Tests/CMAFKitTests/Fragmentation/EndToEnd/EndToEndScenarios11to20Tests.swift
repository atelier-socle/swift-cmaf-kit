// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// End-to-end scenarios 11 through 20.

import Foundation
import Testing

@testable import CMAFKit

@Suite("End-to-end scenarios 11-20")
struct EndToEndScenarios11to20Tests {

    @Test
    func scenario11_encryptedAVC_AAC_CENC_FairPlayPSSH() async throws {
        let fairPlay = try #require(
            UUID(uuidString: "94CE86FB-07FF-4F43-ADB8-93D2FA968CA2")
        )
        let enc = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: WriterFixtures.makeKID(),
            defaultPerSampleIVSize: .eight,
            psshBoxes: [
                ProtectionSystemSpecificHeaderBox(
                    version: 1, systemID: fairPlay, keyIdentifiers: [], data: Data()
                )
            ]
        )
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig()),
            encrypted: enc
        )
        let result = try await EndToEndFixtures.runScenario(configurations: [video])
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario12_encryptedHEVC_EC3_CBCS_WidevinePSSH() async throws {
        let widevine = try #require(
            UUID(uuidString: "EDEF8BA9-79D6-4ACE-A3C8-27DCD51D21ED")
        )
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0x55, count: 16))
        let enc = CMAFEncryptionParameters(
            scheme: .cbcs,
            defaultKID: WriterFixtures.makeKID(),
            defaultPerSampleIVSize: .zero,
            defaultConstantIV: constantIV,
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9,
            psshBoxes: [
                ProtectionSystemSpecificHeaderBox(
                    version: 1, systemID: widevine, keyIdentifiers: [], data: Data()
                )
            ]
        )
        let video = EndToEndFixtures.videoConfig(
            codec: .hvc1,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig()),
            width: 3840,
            height: 2160,
            encrypted: enc
        )
        let result = try await EndToEndFixtures.runScenario(configurations: [video])
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario13_encryptedDvhe_AC4_CBCS_FairPlayPlayReadyPSSH() async throws {
        let fairPlay = try #require(
            UUID(uuidString: "94CE86FB-07FF-4F43-ADB8-93D2FA968CA2")
        )
        let playReady = try #require(
            UUID(uuidString: "9A04F079-9840-4286-AB92-E65BE0885F95")
        )
        let constantIV = try ConstantIV(rawBytes: Data(repeating: 0xAA, count: 16))
        let enc = CMAFEncryptionParameters(
            scheme: .cbcs,
            defaultKID: WriterFixtures.makeKID(),
            defaultPerSampleIVSize: .zero,
            defaultConstantIV: constantIV,
            defaultCryptByteBlock: 1,
            defaultSkipByteBlock: 9,
            psshBoxes: [
                ProtectionSystemSpecificHeaderBox(
                    version: 1, systemID: fairPlay, keyIdentifiers: [], data: Data()
                ),
                ProtectionSystemSpecificHeaderBox(
                    version: 1, systemID: playReady, keyIdentifiers: [], data: Data()
                )
            ]
        )
        let dvcC = DolbyVisionConfigurationBox(
            configuration: DolbyVisionConfiguration(
                versionMajor: 1, versionMinor: 0,
                profile: .profile8(subProfile: .hdr10Compatible),
                level: .level05,
                rpuPresent: true, elPresent: false, blPresent: true,
                blSignalCompatibilityID: .hdr10Compatible
            )
        )
        let video = EndToEndFixtures.videoConfig(
            codec: .dvhe,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig()),
            dolbyVisionConfiguration: dvcC,
            encrypted: enc
        )
        let result = try await EndToEndFixtures.runScenario(configurations: [video])
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario14_encryptedOpus_CENC_ClearKeyPSSH() async throws {
        let clearKey = try #require(
            UUID(uuidString: "1077EFEC-C0B2-4D02-ACE3-3C1E52E2FB4B")
        )
        let enc = CMAFEncryptionParameters(
            scheme: .cenc,
            defaultKID: WriterFixtures.makeKID(),
            defaultPerSampleIVSize: .eight,
            psshBoxes: [
                ProtectionSystemSpecificHeaderBox(
                    version: 1, systemID: clearKey, keyIdentifiers: [], data: Data()
                )
            ]
        )
        let audio = EndToEndFixtures.audioConfig(
            codec: .mp4a,
            codecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
            trackID: 1,
            encrypted: enc
        )
        let result = try await EndToEndFixtures.runScenario(configurations: [audio])
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
    }

    @Test
    func scenario15_multiBitrateABR_AVC_480p_720p_1080p_SharedEncryption() async throws {
        let enc = WriterFixtures.cencParameters()
        let bitrates: [(UInt32, UInt32)] = [(854, 480), (1280, 720), (1920, 1080)]
        for (index, dims) in bitrates.enumerated() {
            let video = EndToEndFixtures.videoConfig(
                codec: .avc1,
                codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig()),
                width: dims.0,
                height: dims.1,
                trackID: UInt32(1 + index),
                encrypted: enc
            )
            let result = try await EndToEndFixtures.runScenario(configurations: [video])
            try await EndToEndFixtures.assertScenario(
                initSegment: result.initSegment,
                fragments: result.fragments
            )
        }
    }

    @Test
    func scenario16_liveHEVC_EC3_PrftEveryFragment() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .hvc1,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig())
        )
        let result = try await EndToEndFixtures.runScenario(
            configurations: [video],
            emitProducerReferenceTime: true,
            samples: 6
        )
        try await EndToEndFixtures.assertScenario(
            initSegment: result.initSegment,
            fragments: result.fragments
        )
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        for segment in result.fragments {
            let boxes = try await reader.readBoxes(from: segment.bytes, using: registry)
            #expect(boxes.contains { $0 is ProducerReferenceTimeBox })
        }
    }

    @Test
    func scenario17_dashManifestAligned_EmsgForAdInsertion() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .avc1,
            codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig()),
            profile: .dash
        )
        let initBytes = try CMAFInitSegmentWriter(configurations: [video]).emit()
        let writer = try CMAFMediaSegmentWriter(
            configuration: video,
            fragmentBoundary: .sampleCount(2),
            emitSegmentIndex: true
        )
        let event = EventMessageBox(
            schemeIDURI: "urn:mpeg:dash:event:2012",
            value: "ad-cue",
            timescale: 90_000,
            presentationTimeDelta: 0,
            eventDuration: 90_000,
            id: 100,
            messageData: Data([0xFC])
        )
        await writer.attachEventMessage(event)
        var emitted: [CMAFFragmentSegment] = []
        for _ in 0..<2 {
            emitted += try await writer.appendSample(
                WriterFixtures.videoSample(),
                toTrack: 1
            )
        }
        try await EndToEndFixtures.assertScenario(
            initSegment: initBytes,
            fragments: emitted
        )
    }

    @Test
    func scenario18_editList_AACHEAAC_PrimingDelay2112Samples() async throws {
        let audio = EndToEndFixtures.audioConfig(
            codec: .mp4a,
            codecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
            trackID: 1,
            priming: AudioPriming(preSkip: 2112)
        )
        let bytes = try CMAFInitSegmentWriter(configurations: [audio]).emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let edts = try #require(trak.children.compactMap { $0 as? EditBox }.first)
        let elst = try #require(edts.children.compactMap { $0 as? EditListBox }.first)
        #expect(elst.table.first?.mediaTime == 2112)
    }

    @Test
    func scenario19_editList_Opus_312SamplePreSkip() async throws {
        let audio = EndToEndFixtures.audioConfig(
            codec: .mp4a,
            codecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
            trackID: 1,
            priming: AudioPriming(preSkip: 312)
        )
        let bytes = try CMAFInitSegmentWriter(configurations: [audio]).emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let edts = try #require(trak.children.compactMap { $0 as? EditBox }.first)
        let elst = try #require(edts.children.compactMap { $0 as? EditListBox }.first)
        #expect(elst.table.first?.mediaTime == 312)
    }

    @Test
    func scenario20_editList_EmptyEditMediaTimeMinusOne() async throws {
        let explicit = EditListBox(
            version: 1,
            table: EditListTable(
                entries: [
                    EditListEntry(
                        segmentDuration: 1000,
                        mediaTime: -1,
                        mediaRateInteger: 1,
                        mediaRateFraction: 0
                    )
                ],
                version: 1
            )
        )
        let audio = CMAFTrackConfiguration(
            trackID: 1,
            kind: .audio,
            profile: .basic,
            timescale: 48_000,
            language: "eng",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: .mp4a,
                codecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
                channelCount: 2,
                sampleRate: 48_000
            ),
            editList: explicit
        )
        let bytes = try CMAFInitSegmentWriter(configurations: [audio]).emit()
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let moov = try #require(boxes.compactMap { $0 as? MovieBox }.first)
        let trak = try #require(moov.tracks.first)
        let edts = try #require(trak.children.compactMap { $0 as? EditBox }.first)
        let elst = try #require(edts.children.compactMap { $0 as? EditListBox }.first)
        #expect(elst.table.first?.mediaTime == -1)
    }
}

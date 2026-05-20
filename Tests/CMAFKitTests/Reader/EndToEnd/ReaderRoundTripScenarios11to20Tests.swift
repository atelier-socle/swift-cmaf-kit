// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Reader-side round-trip scenarios 11 through 20.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Reader round-trip scenarios 11-20")
struct ReaderRoundTripScenarios11to20Tests {

    // MARK: - 11. Encrypted AVC + AAC, cenc, FairPlay pssh

    @Test
    func scenario11_readBack_encryptedAVC_AAC_cenc_FairPlayPSSH() async throws {
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
        let samples = RoundTripFixtures.encryptedSamples(count: 4, ivSize: 8)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(configuration: video, samples: samples)
        )
        RoundTripAssertions.assertTrackShape(
            recovered: result.recoveredTracks, original: [video]
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
        #expect(result.recoveredTracks.first?.encryptionParameters?.scheme == .cenc)
    }

    // MARK: - 12. Encrypted HEVC + EC-3, cbcs 1:9, Widevine pssh

    @Test
    func scenario12_readBack_encryptedHEVC_EC3_cbcs_WidevinePSSH() async throws {
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
        let samples = RoundTripFixtures.encryptedSamples(count: 4, ivSize: 0)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(configuration: video, samples: samples)
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
        #expect(result.recoveredTracks.first?.encryptionParameters?.scheme == .cbcs)
        #expect(
            result.recoveredTracks.first?.encryptionParameters?.defaultConstantIV
                != nil
        )
    }

    // MARK: - 13. Encrypted dvhe Profile 8.1 + AC-4, cbcs 1:9, FairPlay + PlayReady

    @Test
    func scenario13_readBack_encryptedDvhe_AC4_cbcs_FairPlayPlayReadyPSSH()
        async throws
    {
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
        let samples = RoundTripFixtures.encryptedSamples(count: 4, ivSize: 0)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(configuration: video, samples: samples)
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
        // Both pssh boxes must be recovered.
        let initReader = try await CMAFInitSegmentReader(
            bytes: CMAFInitSegmentWriter(configurations: [video]).emit()
        )
        #expect(initReader.protectionSystemSpecificHeaders().count == 2)
    }

    // MARK: - 14. Encrypted Opus (AAC carrier), cenc, ClearKey pssh

    @Test
    func scenario14_readBack_encryptedOpus_cenc_ClearKeyPSSH() async throws {
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
        let samples = RoundTripFixtures.encryptedSamples(count: 4, ivSize: 8)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(configuration: audio, samples: samples)
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
        #expect(result.recoveredTracks.first?.audioFields?.codec == .mp4a)
    }

    // MARK: - 15. Multi-bitrate ABR set with shared encryption parameters

    @Test
    func scenario15_readBack_multiBitrateABR_AVC_sharedEncryption() async throws {
        let enc = WriterFixtures.cencParameters()
        let dimensions: [(UInt32, UInt32)] = [(854, 480), (1280, 720), (1920, 1080)]
        for (index, dims) in dimensions.enumerated() {
            let video = EndToEndFixtures.videoConfig(
                codec: .avc1,
                codecConfiguration: .avc(EndToEndFixtures.makeAVCConfig()),
                width: dims.0,
                height: dims.1,
                trackID: UInt32(1 + index),
                encrypted: enc
            )
            let samples = RoundTripFixtures.encryptedSamples(count: 4, ivSize: 8)
            let result = try await RoundTripFixtures.runSingleTrack(
                .init(configuration: video, samples: samples)
            )
            RoundTripAssertions.assertEquivalence(
                original: samples, parsed: result.recoveredSamples
            )
            #expect(
                result.recoveredTracks.first?.encryptionParameters?.scheme == .cenc
            )
        }
    }

    // MARK: - 16. Live HEVC + EC-3 carrier, prft every fragment

    @Test
    func scenario16_readBack_liveHEVC_EC3_PrftEveryFragment() async throws {
        let video = EndToEndFixtures.videoConfig(
            codec: .hvc1,
            codecConfiguration: .hevc(EndToEndFixtures.makeHEVCConfig())
        )
        let samples = RoundTripFixtures.videoSamples(count: 6)
        let result = try await RoundTripFixtures.runSingleTrack(
            .init(
                configuration: video,
                samples: samples,
                emitProducerReferenceTime: true
            )
        )
        RoundTripAssertions.assertEquivalence(
            original: samples, parsed: result.recoveredSamples
        )
    }

    // MARK: - 17. DASH-aligned, emsg for ad-insertion cues

    @Test
    func scenario17_readBack_dashManifestAligned_EmsgForAdInsertion() async throws {
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
        let inputs = RoundTripFixtures.videoSamples(count: 2)
        var emitted: [CMAFFragmentSegment] = []
        for input in inputs {
            emitted += try await writer.appendSample(input, toTrack: 1)
        }
        let result = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: emitted.map(\.bytes)
        )
        RoundTripAssertions.assertEquivalence(
            original: inputs, parsed: result.recoveredSamples
        )
    }

    // MARK: - 18. Edit list: AAC HE-AAC priming delay 2112 samples

    @Test
    func scenario18_readBack_editList_AACHEAAC_PrimingDelay2112() async throws {
        let audio = EndToEndFixtures.audioConfig(
            codec: .mp4a,
            codecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
            trackID: 1,
            priming: AudioPriming(preSkip: 2112)
        )
        let initBytes = try CMAFInitSegmentWriter(configurations: [audio]).emit()
        let result = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: []
        )
        let recovered = try #require(result.recoveredTracks.first)
        #expect(recovered.editList?.table.first?.mediaTime == 2112)
    }

    // MARK: - 19. Edit list: Opus 312-sample pre-skip

    @Test
    func scenario19_readBack_editList_Opus_312SamplePreSkip() async throws {
        let audio = EndToEndFixtures.audioConfig(
            codec: .mp4a,
            codecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
            trackID: 1,
            priming: AudioPriming(preSkip: 312)
        )
        let initBytes = try CMAFInitSegmentWriter(configurations: [audio]).emit()
        let result = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: []
        )
        let recovered = try #require(result.recoveredTracks.first)
        #expect(recovered.editList?.table.first?.mediaTime == 312)
    }

    // MARK: - 20. Edit list: empty edit (mediaTime = -1) at start

    @Test
    func scenario20_readBack_editList_EmptyEditMediaTimeMinusOne() async throws {
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
        let initBytes = try CMAFInitSegmentWriter(configurations: [audio]).emit()
        let result = try await RoundTripFixtures.readBack(
            initBytes: initBytes, mediaSegments: []
        )
        let recovered = try #require(result.recoveredTracks.first)
        #expect(recovered.editList?.table.first?.mediaTime == -1)
    }
}

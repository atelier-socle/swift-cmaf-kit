// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Shared fixtures and helpers for the 30 end-to-end CMAF scenarios.

import Foundation
import Testing

@testable import CMAFKit

internal enum EndToEndFixtures {

    // MARK: - Codec config factories

    static func makeAVCConfig() -> AVCDecoderConfigurationRecord {
        SampleEntryComposerCodecSweepTests.makeAVCConfig()
    }

    static func makeHEVCConfig() -> HEVCDecoderConfigurationRecord {
        SampleEntryComposerCodecSweepTests.makeHEVCConfig()
    }

    static func makeVPConfig() -> VPCodecConfigurationRecord {
        SampleEntryComposerCodecSweepTests.makeVPConfig()
    }

    static func makeAV1Config() -> AV1CodecConfigurationRecord {
        SampleEntryComposerCodecSweepTests.makeAV1Config()
    }

    static func makeAC3() -> AC3SpecificBox {
        SampleEntryComposerCodecSweepTests.makeAC3()
    }

    // MARK: - Track-configuration factories

    static func videoConfig(
        codec: VideoCodec,
        codecConfiguration: VideoCodecConfiguration,
        width: UInt32 = 1920,
        height: UInt32 = 1080,
        profile: CMAFProfile = .basic,
        trackID: UInt32 = 1,
        colorInformation: ColorInformationBox? = nil,
        masteringDisplay: MasteringDisplayColourVolumeBox? = nil,
        contentLightLevel: ContentLightLevelBox? = nil,
        dolbyVisionConfiguration: DolbyVisionConfigurationBox? = nil,
        encrypted: CMAFEncryptionParameters? = nil
    ) -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: trackID,
            kind: .video,
            profile: profile,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: width,
                height: height,
                codec: codec,
                codecConfiguration: codecConfiguration,
                colorInformation: colorInformation,
                masteringDisplay: masteringDisplay,
                contentLightLevel: contentLightLevel,
                dolbyVisionConfiguration: dolbyVisionConfiguration,
                frameRate: .init(numerator: 30, denominator: 1)
            ),
            encryptionParameters: encrypted
        )
    }

    static func audioConfig(
        codec: AudioCodec,
        codecConfiguration: AudioCodecConfiguration,
        trackID: UInt32 = 2,
        profile: CMAFProfile = .basic,
        channelCount: UInt16 = 2,
        priming: AudioPriming? = nil,
        encrypted: CMAFEncryptionParameters? = nil
    ) -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: trackID,
            kind: .audio,
            profile: profile,
            timescale: 48_000,
            language: "eng",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: codec,
                codecConfiguration: codecConfiguration,
                channelCount: channelCount,
                sampleRate: 48_000,
                priming: priming
            ),
            encryptionParameters: encrypted
        )
    }

    // MARK: - HDR fixtures

    static let bt2020PQ = ColorInformationBox(
        variant: .nclx(
            NCLXColorInformation(
                colorPrimaries: .bt2020,
                transferCharacteristics: .smpteST2084_PQ,
                matrixCoefficients: .bt2020NCL,
                fullRangeFlag: .limited
            )
        )
    )

    static let mdcv = MasteringDisplayColourVolumeBox(
        metadata: MasteringDisplayColourVolume(
            displayPrimaryRedX: 35400, displayPrimaryRedY: 14600,
            displayPrimaryGreenX: 8500, displayPrimaryGreenY: 39850,
            displayPrimaryBlueX: 6550, displayPrimaryBlueY: 2300,
            whitePointX: 15635, whitePointY: 16450,
            maxDisplayMasteringLuminance: 10_000_000,
            minDisplayMasteringLuminance: 50
        )
    )

    static let clli = ContentLightLevelBox(
        metadata: ContentLightLevel(
            maxContentLightLevel: 1000,
            maxPicAverageLightLevel: 400
        )
    )

    // MARK: - Scenario runner

    /// Walk a track through an init-segment emit + N media-segment
    /// emits. Returns the init segment plus the emitted media
    /// segments for assertion.
    static func runScenario(
        configurations: [CMAFTrackConfiguration],
        fragmentBoundary: CMAFFragmentBoundary = .sampleCount(2),
        partialChunkBoundary: CMAFPartialChunkBoundary? = nil,
        emitSegmentIndex: Bool = false,
        emitProducerReferenceTime: Bool = false,
        samples: Int = 4
    ) async throws -> (initSegment: Data, fragments: [CMAFFragmentSegment]) {
        let initWriter = try CMAFInitSegmentWriter(configurations: configurations)
        let initBytes = try initWriter.emit()
        let writer = try CMAFMediaSegmentWriter(
            configuration: configurations[0],
            fragmentBoundary: fragmentBoundary,
            partialChunkBoundary: partialChunkBoundary,
            emitSegmentIndex: emitSegmentIndex,
            emitProducerReferenceTime: emitProducerReferenceTime
        )
        var emitted: [CMAFFragmentSegment] = []
        let encrypted = configurations[0].encryptionParameters != nil
        let ivSize =
            configurations[0]
            .encryptionParameters?
            .defaultPerSampleIVSize
            .rawValue ?? 0
        for index in 0..<samples {
            let isSync = (index == 0) || (index % 2 == 0)
            let sample = makeSample(
                isSync: isSync,
                encrypted: encrypted,
                ivSize: ivSize
            )
            emitted += try await writer.appendSample(
                sample,
                toTrack: configurations[0].trackID
            )
        }
        emitted += try await writer.finalize()
        return (initBytes, emitted)
    }

    private static func makeSample(
        isSync: Bool,
        encrypted: Bool,
        ivSize: UInt8
    ) -> CMAFSampleInput {
        if encrypted {
            if ivSize == 0 {
                return CMAFSampleInput(
                    bytes: Data(repeating: 0xCC, count: 1024),
                    durationInTimescale: 3000,
                    flags: isSync ? .syncSample : .nonSyncSample,
                    encryption: CMAFSampleInput.EncryptionMetadata(
                        initializationVector: Data()
                    )
                )
            }
            return WriterFixtures.encryptedVideoSample(
                size: 1024,
                durationInTimescale: 3000,
                isSync: isSync,
                ivSize: Int(ivSize)
            )
        }
        return WriterFixtures.videoSample(
            size: 1024,
            durationInTimescale: 3000,
            isSync: isSync
        )
    }

    // MARK: - Assertions

    /// Standard assertion: init-segment parses, ≥ 1 fragment parses,
    /// fragments are in monotonic decode order.
    static func assertScenario(
        initSegment: Data,
        fragments: [CMAFFragmentSegment]
    ) async throws {
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let initBoxes = try await reader.readBoxes(from: initSegment, using: registry)
        #expect(initBoxes.contains { $0 is FileTypeBox })
        #expect(initBoxes.contains { $0 is MovieBox })
        #expect(fragments.isEmpty == false)
        var lastDecodeTime: UInt64 = 0
        for segment in fragments {
            #expect(segment.baseMediaDecodeTime >= lastDecodeTime)
            lastDecodeTime = segment.baseMediaDecodeTime + segment.durationInTimescale
            let mediaBoxes = try await reader.readBoxes(
                from: segment.bytes, using: registry
            )
            #expect(mediaBoxes.contains { $0 is MovieFragmentBox })
            #expect(mediaBoxes.contains { $0 is MediaDataBox })
        }
    }
}

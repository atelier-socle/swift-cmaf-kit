// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

/// Integration coverage for the ``RFC6381CodecStringBuilder/codecString(for:)-(_:)``
/// dispatch path from a full ``CMAFTrackConfiguration``. Split out of
/// `RFC6381CodecStringBuilderParserTests.swift` to keep both files
/// within SwiftLint's `file_length` and `type_body_length` budgets.
///
/// Per-codec fixture helpers live at the bottom; each test instantiates
/// a minimal track configuration matching the codec under test.
@Suite("RFC6381 — CMAFTrackConfiguration integration")
struct RFC6381CodecStringBuilderIntegrationTests {

    private let builder = RFC6381CodecStringBuilder()

    // MARK: - Video dispatchers

    @Test
    func integrationAVCTrackProducesAvc1String() throws {
        let track = makeVideoTrack(
            codec: .avc1,
            codecConfiguration: .avc(
                AVCDecoderConfigurationRecord(
                    profileIndication: .main,
                    profileCompatibility: AVCProfileCompatibility(rawValue: 0x40),
                    levelIndication: .level3_1,
                    lengthSize: .fourBytes,
                    sequenceParameterSets: [],
                    pictureParameterSets: []
                )
            )
        )
        let string = try builder.codecString(for: track)
        #expect(string.hasPrefix("avc1."))
    }

    @Test
    func integrationAVCCodecMismatchThrows() throws {
        let track = makeVideoTrack(
            codec: .avc1,
            codecConfiguration: .hevc(
                MultiLayerHEVCConfigurationTests.minimalHEVCRecord()
            )
        )
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.codecString(for: track)
        }
    }

    @Test
    func integrationHEVCTrackProducesHvc1String() throws {
        let track = makeVideoTrack(
            codec: .hvc1,
            codecConfiguration: .hevc(
                MultiLayerHEVCConfigurationTests.minimalHEVCRecord()
            )
        )
        let string = try builder.codecString(for: track)
        #expect(string.hasPrefix("hvc1."))
    }

    @Test
    func integrationHEVCInbandUsesHev1Prefix() throws {
        let track = makeVideoTrack(
            codec: .hev1,
            codecConfiguration: .hevc(
                MultiLayerHEVCConfigurationTests.minimalHEVCRecord()
            )
        )
        let string = try builder.codecString(for: track)
        #expect(string.hasPrefix("hev1."))
    }

    @Test
    func integrationVP9TrackProducesVp09String() throws {
        let track = makeVideoTrack(
            codec: .vp09,
            codecConfiguration: .vp(
                VPCodecConfigurationRecord(
                    version: 1, flags: 0,
                    profile: .profile0, level: .level50, bitDepth: 10,
                    chromaSubsampling: .format420Colocated,
                    videoFullRangeFlag: .limited,
                    colourPrimaries: .bt709,
                    transferCharacteristics: .bt709,
                    matrixCoefficients: .bt709,
                    codecInitializationData: Data()
                )
            )
        )
        let string = try builder.codecString(for: track)
        #expect(string.hasPrefix("vp09."))
    }

    @Test
    func integrationAV1TrackProducesAv01String() throws {
        let track = makeVideoTrack(
            codec: .av01,
            codecConfiguration: .av1(
                AV1CodecConfigurationRecord(
                    seqProfile: .main,
                    seqLevelIdx0: .level3_0,
                    seqTier0: .main,
                    highBitdepth: true,
                    twelveBit: false,
                    monochrome: false,
                    chromaSubsamplingX: true,
                    chromaSubsamplingY: true,
                    chromaSamplePosition: .unknown
                )
            )
        )
        let string = try builder.codecString(for: track)
        #expect(string.hasPrefix("av01."))
    }

    @Test
    func integrationDolbyVisionTrackProducesDvh1String() throws {
        let track = CMAFTrackConfiguration(
            trackID: 1, kind: .video, profile: .basic,
            timescale: 90_000, language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920, height: 1080,
                codec: .dvh1,
                codecConfiguration: .hevc(
                    MultiLayerHEVCConfigurationTests.minimalHEVCRecord()
                ),
                dolbyVisionConfiguration: DolbyVisionConfigurationBox(
                    configuration: DolbyVisionConfiguration(
                        versionMajor: 1, versionMinor: 0,
                        profile: .profile5, level: .level06,
                        rpuPresent: true, elPresent: false, blPresent: true,
                        blSignalCompatibilityID: .nonCompatible
                    )
                ),
                frameRate: .init(numerator: 24, denominator: 1)
            )
        )
        let string = try builder.codecString(for: track)
        #expect(string == "dvh1.05.06")
    }

    @Test
    func integrationDolbyVisionMissingConfigurationThrows() throws {
        let track = CMAFTrackConfiguration(
            trackID: 1, kind: .video, profile: .basic,
            timescale: 90_000, language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920, height: 1080,
                codec: .dvh1,
                codecConfiguration: .hevc(
                    MultiLayerHEVCConfigurationTests.minimalHEVCRecord()
                ),
                frameRate: .init(numerator: 24, denominator: 1)
            )
        )
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.codecString(for: track)
        }
    }

    @Test
    func integrationVP9CodecMismatchThrows() {
        let track = makeVideoTrack(
            codec: .vp09,
            codecConfiguration: .avc(
                AVCDecoderConfigurationRecord(
                    profileIndication: .main,
                    profileCompatibility: AVCProfileCompatibility(rawValue: 0),
                    levelIndication: .level3_1,
                    lengthSize: .fourBytes,
                    sequenceParameterSets: [],
                    pictureParameterSets: []
                )
            )
        )
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.codecString(for: track)
        }
    }

    @Test
    func integrationMP4VThrowsUnsupportedInSession4() {
        let track = makeVideoTrack(
            codec: .mp4v,
            codecConfiguration: .hevc(
                MultiLayerHEVCConfigurationTests.minimalHEVCRecord()
            )
        )
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.codecString(for: track)
        }
    }

    // MARK: - Audio + subtitle dispatchers

    @Test
    func integrationAudioMP4AThrowsUnsupportedInSession4() throws {
        // mp4a → unsupportedCodec (Session 6 wires AOT extraction)
        let mp4aTrack = makeAudioTrack(
            codec: .mp4a, codecConfiguration: .mp4Audio(makeMinimalESDS())
        )
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.codecString(for: mp4aTrack)
        }
    }

    @Test
    func integrationAC3AudioProducesAc3() throws {
        let track = makeAudioTrack(
            codec: .ac3, codecConfiguration: .ac3(makeMinimalAC3SpecificBox())
        )
        #expect(try builder.codecString(for: track) == "ac-3")
    }

    @Test
    func integrationEC3AudioProducesEc3() throws {
        let track = makeAudioTrack(
            codec: .ec3, codecConfiguration: .ec3(makeMinimalEC3SpecificBox())
        )
        #expect(try builder.codecString(for: track) == "ec-3")
    }

    @Test
    func integrationOpusAudioProducesOpus() throws {
        let track = makeAudioTrack(
            codec: .opus, codecConfiguration: .opus(makeMinimalOpusSpecificBox())
        )
        #expect(try builder.codecString(for: track) == "Opus")
    }

    @Test
    func integrationFLACAudioProducesFLaC() throws {
        let track = makeAudioTrack(
            codec: .flac, codecConfiguration: .flac(makeMinimalFLACSpecificBox())
        )
        #expect(try builder.codecString(for: track) == "fLaC")
    }

    @Test
    func integrationSubtitleWebVTTProducesWvtt() throws {
        let track = makeSubtitleTrack(codec: .webVTT)
        #expect(try builder.codecString(for: track) == "wvtt")
    }

    @Test
    func integrationSubtitleIMSC1TextProducesStppTtmlIm1t() throws {
        let track = makeSubtitleTrack(codec: .imsc1Text)
        #expect(try builder.codecString(for: track) == "stpp.ttml.im1t")
    }

    @Test
    func integrationSubtitleIMSC1ImageProducesStppTtmlIm1i() throws {
        let track = makeSubtitleTrack(codec: .imsc1Image)
        #expect(try builder.codecString(for: track) == "stpp.ttml.im1i")
    }

    // MARK: - kind/fields mismatch error paths

    @Test
    func integrationMissingVideoFieldsThrows() throws {
        let track = CMAFTrackConfiguration(
            trackID: 1, kind: .video, profile: .basic,
            timescale: 90_000, language: "und"
        )
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.codecString(for: track)
        }
    }

    @Test
    func integrationMissingAudioFieldsThrows() throws {
        let track = CMAFTrackConfiguration(
            trackID: 1, kind: .audio, profile: .basic,
            timescale: 48_000, language: "und"
        )
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.codecString(for: track)
        }
    }

    @Test
    func integrationMissingSubtitleFieldsThrows() throws {
        let track = CMAFTrackConfiguration(
            trackID: 1, kind: .subtitle, profile: .basic,
            timescale: 1_000, language: "und"
        )
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.codecString(for: track)
        }
    }

    // MARK: - Test helpers

    private func makeVideoTrack(
        codec: VideoCodec, codecConfiguration: VideoCodecConfiguration
    ) -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: 1, kind: .video, profile: .basic,
            timescale: 90_000, language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920, height: 1080,
                codec: codec, codecConfiguration: codecConfiguration,
                frameRate: .init(numerator: 30, denominator: 1)
            )
        )
    }

    private func makeAudioTrack(
        codec: AudioCodec, codecConfiguration: AudioCodecConfiguration
    ) -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: 1, kind: .audio, profile: .basic,
            timescale: 48_000, language: "und",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: codec, codecConfiguration: codecConfiguration,
                channelCount: 2, sampleRate: 48_000 << 16
            )
        )
    }

    private func makeSubtitleTrack(codec: SubtitleCodec) -> CMAFTrackConfiguration {
        CMAFTrackConfiguration(
            trackID: 1, kind: .subtitle, profile: .basic,
            timescale: 1_000, language: "und",
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: codec, language: "eng"
            )
        )
    }

    private func makeMinimalESDS() -> ElementaryStreamDescriptor {
        ElementaryStreamDescriptor(
            esID: 1,
            streamDependenceFlag: false, urlFlag: false, ocrStreamFlag: false,
            streamPriority: 0, dependsOnESID: nil, url: nil, ocrESID: nil,
            decoderConfig: ElementaryStreamDescriptor.DecoderConfigDescriptor(
                objectTypeIndication: .audioISO14496_3,
                streamType: .audioStream,
                upStream: false, bufferSizeDB: 0, maxBitrate: 0, avgBitrate: 0,
                decoderSpecificInfo: nil
            ),
            slConfig: ElementaryStreamDescriptor.SLConfigDescriptor(predefined: 2)
        )
    }

    private func makeMinimalAC3SpecificBox() -> AC3SpecificBox {
        AC3SpecificBox(
            fscod: .freq48000, bsid: 8,
            bsmod: .completeMain, acmod: .stereo,
            lfeon: false, bitRateCode: 16
        )
    }

    private func makeMinimalEC3SpecificBox() -> EC3SpecificBox {
        EC3SpecificBox(
            dataRate: 384,
            independentSubstreams: [
                EC3SpecificBox.IndependentSubstream(
                    fscod: .freq48000, bsid: 16, asvc: false,
                    bsmod: .completeMain, acmod: .stereo,
                    lfeon: false, dependentSubstreamCount: 0
                )
            ]
        )
    }

    private func makeMinimalOpusSpecificBox() -> OpusSpecificBox {
        OpusSpecificBox(
            version: 0, outputChannelCount: 2,
            preSkip: 0, inputSampleRate: 48_000, outputGainQ78: 0,
            channelMappingFamily: .rtpMonoStereo
        )
    }

    private func makeMinimalFLACSpecificBox() -> FLACSpecificBox {
        FLACSpecificBox(
            version: 0, flags: 0,
            metadataBlocks: [
                FLACSpecificBox.FLACMetadataBlock(
                    isLast: true, blockType: .streamInfo,
                    blockData: Data(repeating: 0, count: 34)
                )
            ]
        )
    }
}

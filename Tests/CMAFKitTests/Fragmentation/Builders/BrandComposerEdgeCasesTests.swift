// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("BrandComposer — edge cases")
struct BrandComposerEdgeCasesTests {

    // MARK: - Fixtures

    private static func makeAVCConfig() -> AVCDecoderConfigurationRecord {
        AVCDecoderConfigurationRecord(
            profileIndication: .baseline,
            profileCompatibility: AVCProfileCompatibility(rawValue: 0xE0),
            levelIndication: .level3,
            lengthSize: .fourBytes,
            sequenceParameterSets: [AVCParameterSet(rbspBytes: Data([0x67, 0x42, 0xC0, 0x1E]))],
            pictureParameterSets: [AVCParameterSet(rbspBytes: Data([0x68, 0xCE, 0x3C, 0x80]))]
        )
    }

    private static func videoConfig(
        codec: VideoCodec,
        trackID: UInt32 = 1,
        profile: CMAFProfile = .basic,
        encrypted: Bool = false,
        dolbyVision: DolbyVisionConfigurationBox? = nil
    ) -> CMAFTrackConfiguration {
        // Use the AVC config for every codec arm — the BrandComposer
        // only cares about the codec FourCC, not the codec config
        // content. Substituting `.avc` is harmless for brand mapping
        // because no parser ever validates these synthetic configs.
        let cfg = VideoCodecConfiguration.avc(makeAVCConfig())
        return CMAFTrackConfiguration(
            trackID: trackID,
            kind: .video,
            profile: profile,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 1920,
                height: 1080,
                codec: codec,
                codecConfiguration: cfg,
                dolbyVisionConfiguration: dolbyVision,
                frameRate: .init(numerator: 30, denominator: 1)
            ),
            encryptionParameters: encrypted ? WriterFixtures.cencParameters() : nil
        )
    }

    private static func audioConfig(
        codec: AudioCodec,
        trackID: UInt32 = 2,
        profile: CMAFProfile = .basic
    ) -> CMAFTrackConfiguration {
        // Substituting .mp4Audio for every audio codec arm — the
        // BrandComposer only reads the codec enum, not the config.
        return CMAFTrackConfiguration(
            trackID: trackID,
            kind: .audio,
            profile: profile,
            timescale: 48_000,
            language: "eng",
            audioFields: CMAFTrackConfiguration.AudioFields(
                codec: codec,
                codecConfiguration: .mp4Audio(WriterFixtures.makeESDS()),
                channelCount: 2,
                sampleRate: 48_000
            )
        )
    }

    // MARK: - Video codec → brand mapping

    @Test
    func avc1ImpliesAvc1Brand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .avc1)]
        )
        #expect(brands.contains("avc1"))
    }

    @Test
    func avc3ImpliesAvc3Brand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .avc3)]
        )
        #expect(brands.contains("avc3"))
    }

    @Test
    func hvc1ImpliesHvc1Brand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .hvc1)]
        )
        #expect(brands.contains("hvc1"))
    }

    @Test
    func hev1ImpliesHev1Brand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .hev1)]
        )
        #expect(brands.contains("hev1"))
    }

    @Test
    func dvh1AddsDolbyVisionBrand() {
        let dvcC = DolbyVisionConfigurationBox(
            configuration: DolbyVisionConfiguration(
                versionMajor: 1,
                versionMinor: 0,
                profile: .profile5,
                level: .level05,
                rpuPresent: true,
                elPresent: false,
                blPresent: true,
                blSignalCompatibilityID: .nonCompatible
            )
        )
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .dvh1, dolbyVision: dvcC)]
        )
        #expect(brands.contains("dvh1"))
        #expect(brands.contains("dby1"))
    }

    @Test
    func dvheAddsDolbyVisionBrand() {
        let dvcC = DolbyVisionConfigurationBox(
            configuration: DolbyVisionConfiguration(
                versionMajor: 1,
                versionMinor: 0,
                profile: .profile8(subProfile: .hdr10Compatible),
                level: .level05,
                rpuPresent: true,
                elPresent: false,
                blPresent: true,
                blSignalCompatibilityID: .nonCompatible
            )
        )
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .dvhe, dolbyVision: dvcC)]
        )
        #expect(brands.contains("dvhe"))
        #expect(brands.contains("dby1"))
    }

    @Test
    func av01ImpliesAv01Brand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .av01)]
        )
        #expect(brands.contains("av01"))
    }

    @Test
    func vp09ImpliesVp09Brand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .vp09)]
        )
        #expect(brands.contains("vp09"))
    }

    @Test
    func vp08ImpliesVp08Brand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .vp08)]
        )
        #expect(brands.contains("vp08"))
    }

    @Test
    func mp4vImpliesMp4vBrand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .mp4v)]
        )
        #expect(brands.contains("mp4v"))
    }

    // MARK: - Audio codec → brand mapping

    @Test
    func ac3AddsDac3Brand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.audioConfig(codec: .ac3)]
        )
        #expect(brands.contains("dac3"))
    }

    @Test
    func ec3AddsDec3Brand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.audioConfig(codec: .ec3)]
        )
        #expect(brands.contains("dec3"))
    }

    @Test
    func mp4aAddsMp41Brand() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.audioConfig(codec: .mp4a)]
        )
        #expect(brands.contains("mp41"))
    }

    // MARK: - Encryption + multi-stream

    @Test
    func encryptedTrackAddsIso7() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .avc1, encrypted: true)]
        )
        #expect(brands.contains("iso7"))
    }

    @Test
    func multipleAudioTracksAddCmf2() {
        let brands = BrandComposer.compatibleBrands(
            for: [
                Self.audioConfig(codec: .mp4a, trackID: 1),
                Self.audioConfig(codec: .ac3, trackID: 2)
            ]
        )
        #expect(brands.contains("cmf2"))
    }

    @Test
    func singleTrackDoesNotAddCmf2() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .avc1)]
        )
        #expect(brands.contains("cmf2") == false)
    }

    // MARK: - Profile

    @Test
    func dashProfileBrandsIncludeDash() {
        let brands = BrandComposer.compatibleBrands(
            for: [Self.videoConfig(codec: .avc1, profile: .dash)]
        )
        #expect(brands.contains("dash"))
        #expect(brands.contains("msdh"))
    }

    @Test
    func iso6AlwaysIncluded() {
        for profile in CMAFProfile.allCases {
            let brands = BrandComposer.compatibleBrands(
                for: [Self.videoConfig(codec: .avc1, profile: profile)]
            )
            #expect(brands.contains("iso6"), "missing iso6 for \(profile)")
        }
    }

    @Test
    func brandsOrderIsDeterministic() {
        let configs = [
            Self.videoConfig(codec: .avc1, trackID: 1),
            Self.audioConfig(codec: .mp4a, trackID: 2)
        ]
        let brands1 = BrandComposer.compatibleBrands(for: configs)
        let brands2 = BrandComposer.compatibleBrands(for: configs)
        #expect(brands1 == brands2)
    }

    @Test
    func brandsAreDeduplicated() {
        let brands = BrandComposer.compatibleBrands(
            for: [
                Self.videoConfig(codec: .avc1, trackID: 1),
                Self.videoConfig(codec: .avc1, trackID: 2)
            ]
        )
        let avc1Count = brands.filter { $0 == "avc1" }.count
        #expect(avc1Count == 1)
    }

    // MARK: - Subtitle / metadata

    @Test
    func subtitleWebVTTBrandIncluded() {
        let cfg = CMAFTrackConfiguration(
            trackID: 1,
            kind: .subtitle,
            profile: .basic,
            timescale: 1000,
            language: "eng",
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: .webVTT,
                language: "eng"
            )
        )
        let brands = BrandComposer.compatibleBrands(for: [cfg])
        #expect(brands.contains("wvtt"))
    }

    @Test
    func subtitleIMSC1TextAddsIm1tBrand() {
        let cfg = CMAFTrackConfiguration(
            trackID: 1,
            kind: .subtitle,
            profile: .basic,
            timescale: 1000,
            language: "eng",
            subtitleFields: CMAFTrackConfiguration.SubtitleFields(
                codec: .imsc1Text,
                language: "eng"
            )
        )
        let brands = BrandComposer.compatibleBrands(for: [cfg])
        #expect(brands.contains("im1t"))
    }

    // MARK: - Factory wrappers

    @Test
    func ftypFromConfigurationsMatchesMajorBrand() {
        let ftyp = BrandComposer.makeFileTypeBox(
            configurations: [Self.videoConfig(codec: .avc1, profile: .hls)]
        )
        #expect(ftyp.majorBrand == "cmfh")
    }

    @Test
    func stypFromConfigurationsCarriesSameBrands() {
        let configs = [Self.videoConfig(codec: .avc1)]
        let ftyp = BrandComposer.makeFileTypeBox(configurations: configs)
        let styp = BrandComposer.makeSegmentTypeBox(configurations: configs)
        #expect(ftyp.compatibleBrands == styp.compatibleBrands)
    }
}

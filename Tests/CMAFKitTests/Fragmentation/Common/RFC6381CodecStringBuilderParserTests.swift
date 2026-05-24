// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

/// Parser + round-trip tests for ``RFC6381CodecStringBuilder``.
///
/// Each parser test verifies the inverse direction of the builder tests;
/// the round-trip block confirms `parse(string(d)) == [d]` for every
/// well-formed descriptor.
@Suite("RFC6381 — parser & round-trip")
struct RFC6381CodecStringBuilderParserTests {

    private let builder = RFC6381CodecStringBuilder()

    // MARK: - Parser canonical

    @Test
    func parsesAVCAvc1String() throws {
        let parsed = try builder.parse("avc1.42e01e")
        #expect(parsed.count == 1)
        if case .avc(let kind, let prof, let constr, let lev) = parsed[0] {
            #expect(kind == .avc1)
            #expect(prof == 0x42)
            #expect(constr == 0xE0)
            #expect(lev == 0x1E)
        } else {
            Issue.record("expected .avc descriptor; got \(parsed[0])")
        }
    }

    @Test
    func parsesHEVCHvc1String() throws {
        let parsed = try builder.parse("hvc1.1.6.L93.b0")
        #expect(parsed.count == 1)
        if case .hevc(let kind, let space, let prof, let compat, let tier, let lev, let flags) = parsed[0] {
            #expect(kind == .hvc1)
            #expect(space == 0)
            #expect(prof == 1)
            #expect(compat == 0x6000_0000)
            #expect(tier == .main)
            #expect(lev == 93)
            #expect(flags.first == 0xB0)
        } else {
            Issue.record("expected .hevc descriptor; got \(parsed[0])")
        }
    }

    @Test
    func parsesHEVCWithProfileSpaceBPrefix() throws {
        let parsed = try builder.parse("hvc1.B1.6.L93.b0")
        if case .hevc(_, let space, _, _, _, _, _) = parsed[0] {
            #expect(space == 2)
        } else {
            Issue.record("expected .hevc descriptor")
        }
    }

    @Test
    func parsesHEVCAllZeroConstraints() throws {
        let parsed = try builder.parse("hev1.2.4.H150")
        if case .hevc(let kind, _, _, _, let tier, let lev, let flags) = parsed[0] {
            #expect(kind == .hev1)
            #expect(tier == .high)
            #expect(lev == 150)
            #expect(flags == Data([0, 0, 0, 0, 0, 0]))
        } else {
            Issue.record("expected .hevc descriptor")
        }
    }

    @Test
    func parsesMVHEVCHvc2String() throws {
        let parsed = try builder.parse("hvc2.1.6.L93.b0")
        if case .mvHEVC(let base, let ext, let views) = parsed[0] {
            #expect(base.profile == 1)
            #expect(base.profileCompat == 0x6000_0000)
            #expect(base.tier == .main)
            #expect(base.level == 93)
            #expect(ext == nil)
            #expect(views == 2)
        } else {
            Issue.record("expected .mvHEVC descriptor")
        }
    }

    @Test
    func parsesAV1MinimalString() throws {
        let parsed = try builder.parse("av01.0.04M.10")
        if case .av1(let prof, let lev, let tier, let depth, let mono, let chroma, _, _, _, let range) = parsed[0] {
            #expect(prof == 0)
            #expect(lev == 4)
            #expect(tier == .main)
            #expect(depth == 10)
            #expect(mono == false)
            #expect(chroma == .yuv420)
            #expect(range == false)
        } else {
            Issue.record("expected .av1 descriptor")
        }
    }

    @Test
    func parsesAV1ExtendedString() throws {
        let parsed = try builder.parse("av01.0.04M.10.0.110.09.16.09.1")
        if case .av1(_, _, _, _, _, let chroma, let cp, let tc, let mc, let range) = parsed[0] {
            #expect(chroma == .yuv420)
            #expect(cp == 9)
            #expect(tc == 16)
            #expect(mc == 9)
            #expect(range == true)
        } else {
            Issue.record("expected .av1 descriptor")
        }
    }

    @Test
    func parsesDolbyVisionDvh1String() throws {
        let parsed = try builder.parse("dvh1.05.06")
        if case .dolbyVision(let kind, let profile, let level) = parsed[0] {
            #expect(kind == .dvh1)
            #expect(profile.wireProfileNumber == 5)
            #expect(level == .level06)
        } else {
            Issue.record("expected .dolbyVision descriptor")
        }
    }

    @Test
    func parsesVP9String() throws {
        let parsed = try builder.parse("vp09.00.50.10.01.01.01.01.00")
        if case .vp9(let prof, let lev, let depth, let chroma, _, _, _, let range) = parsed[0] {
            #expect(prof == 0)
            #expect(lev == 50)
            #expect(depth == 10)
            #expect(chroma == .yuv420)
            #expect(range == false)
        } else {
            Issue.record("expected .vp9 descriptor")
        }
    }

    @Test
    func parsesVP8Constant() throws {
        let parsed = try builder.parse("vp08")
        #expect(parsed == [.vp8])
    }

    @Test
    func parsesAACMp4aString() throws {
        let parsed = try builder.parse("mp4a.40.2")
        #expect(parsed == [.aac(audioObjectType: .lc)])
    }

    @Test
    func parsesAC3Constant() throws {
        let parsed = try builder.parse("ac-3")
        #expect(parsed == [.ac3])
    }

    @Test
    func parsesEC3Constant() throws {
        let parsed = try builder.parse("ec-3")
        // joc defaults to false on the parser path — caller introspects
        // ``EC3SpecificBox`` for the JOC bit when needed.
        #expect(parsed == [.ec3(joc: false)])
    }

    @Test
    func parsesAC4Bare() throws {
        let parsed = try builder.parse("ac-4")
        #expect(parsed == [.ac4(presentationID: nil)])
    }

    @Test
    func parsesAC4WithPresentationID() throws {
        let parsed = try builder.parse("ac-4.5")
        #expect(parsed == [.ac4(presentationID: 5)])
    }

    @Test
    func parsesMPEGHmhm1() throws {
        let parsed = try builder.parse("mhm1.0x0C")
        #expect(parsed == [.mpegH(sampleEntry: .mhm1, profileLevelIndication: 0x0C)])
    }

    @Test
    func parsesOpusFlacAlacPCMSubtitleConstants() throws {
        #expect(try builder.parse("Opus") == [.opus])
        #expect(try builder.parse("fLaC") == [.flac])
        #expect(try builder.parse("alac") == [.alac])
        #expect(try builder.parse("ipcm") == [.pcmIPCM])
        #expect(try builder.parse("fpcm") == [.pcmFPCM])
        #expect(try builder.parse("lpcm") == [.pcmLPCM])
        #expect(try builder.parse("wvtt") == [.webVTT])
        #expect(try builder.parse("stpp.ttml.im1t") == [.imsc1Text])
        #expect(try builder.parse("stpp.ttml.im1i") == [.imsc1Image])
    }

    // MARK: - Multi-codec parsing

    @Test
    func parsesCommaSeparatedMultiCodecString() throws {
        let parsed = try builder.parse("avc1.42e01e,mp4a.40.2")
        #expect(parsed.count == 2)
        #expect(parsed[1] == .aac(audioObjectType: .lc))
    }

    @Test
    func parsesMultiCodecWithWhitespace() throws {
        let parsed = try builder.parse("avc1.42e01e ,  mp4a.40.2  , ac-3")
        #expect(parsed.count == 3)
        #expect(parsed[2] == .ac3)
    }

    // MARK: - (Parser error paths moved to RFC6381CodecStringBuilderParserErrorsTests suite below)
}

/// Parser error-path coverage. Split out of the main parser suite to
/// keep both structs within SwiftLint's `type_body_length` budget.
@Suite("RFC6381 — parser errors")
struct RFC6381CodecStringBuilderParserErrorsTests {

    private let builder = RFC6381CodecStringBuilder()

    @Test
    func parserRejectsEmptyString() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("")
        }
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("   ")
        }
    }

    @Test
    func parserRejectsUnknownCodecPrefix() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("xyz1.0000")
        }
    }

    @Test
    func parserRejectsTruncatedAVCSuffix() {
        // AVC requires 6 hex digits — 5 should throw.
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("avc1.42e01")
        }
    }

    @Test
    func parserRejectsMalformedHEVCSuffix() {
        // Only 2 parts (need ≥ 3) → throw
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("hvc1.1.6")
        }
    }

    @Test
    func parserRejectsInvalidAV1Tier() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("av01.0.04X.10")
        }
    }

    @Test
    func parserRejectsUnknownAACAOT() {
        // AOT 99 has no corresponding AACProfile enum case
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("mp4a.40.99")
        }
    }

    @Test
    func parserRejectsMPEGHPLIMissingPrefix() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("mhm1.0C")  // missing "0x"
        }
    }

    // MARK: - Round-trip

    @Test(arguments: knownDescriptors)
    func roundTrip(descriptor: RFC6381CodecDescriptor) throws {
        let string = builder.codecString(for: descriptor)
        let parsed = try builder.parse(string)
        #expect(parsed == [descriptor])
    }

    /// Every well-formed descriptor exercised by the round-trip table.
    /// One entry per codec family is enough; per-codec edge cases live
    /// in the explicit canonical tests.
    static let knownDescriptors: [RFC6381CodecDescriptor] = [
        .avc(sampleEntry: .avc1, profile: 0x4D, constraint: 0x40, level: 0x1E),
        .avc(sampleEntry: .avc3, profile: 0x42, constraint: 0xC0, level: 0x0D),
        .hevc(
            sampleEntry: .hvc1, profileSpace: 0, profile: 1,
            profileCompat: 0x6000_0000, tier: .main, level: 93,
            constraintFlags: Data([0xB0, 0, 0, 0, 0, 0])
        ),
        .hevc(
            sampleEntry: .hev1, profileSpace: 2, profile: 2,
            profileCompat: 0x4000_0000, tier: .high, level: 150,
            constraintFlags: Data([0, 0, 0, 0, 0, 0])
        ),
        .mvHEVC(
            baseProfile: HEVCProfileDescriptor(
                profileSpace: 0, profile: 1, profileCompat: 0x6000_0000,
                tier: .main, level: 93, constraintFlags: Data([0xB0, 0, 0, 0, 0, 0])
            ),
            extensionProfile: nil,
            viewCount: 2
        ),
        .av1(
            profile: 0, level: 4, tier: .main, bitDepth: 10,
            monochrome: false, chromaSubsampling: .yuv420,
            colorPrimaries: 1, transferCharacteristics: 1, matrixCoefficients: 1,
            videoFullRangeFlag: false
        ),
        .av1(
            profile: 1, level: 5, tier: .high, bitDepth: 12,
            monochrome: false, chromaSubsampling: .yuv444,
            colorPrimaries: 9, transferCharacteristics: 16, matrixCoefficients: 9,
            videoFullRangeFlag: true
        ),
        .dolbyVision(sampleEntry: .dvh1, profile: .profile5, level: .level06),
        .vp9(
            profile: 0, level: 50, bitDepth: 10,
            chromaSubsampling: .yuv420, colorPrimaries: 1,
            transferCharacteristics: 1, matrixCoefficients: 1,
            videoFullRangeFlag: false
        ),
        .vp8,
        .aac(audioObjectType: .lc),
        .aac(audioObjectType: .sbr),
        .aac(audioObjectType: .psSBR),
        .aac(audioObjectType: .xHE),
        .ac3,
        .ec3(joc: false),
        .ac4(presentationID: nil),
        .ac4(presentationID: 5),
        .mpegH(sampleEntry: .mhm1, profileLevelIndication: 0x0C),
        .mpegH(sampleEntry: .mhm2, profileLevelIndication: 0x13),
        .opus,
        .flac,
        .alac,
        .pcmIPCM,
        .pcmFPCM,
        .pcmLPCM,
        .webVTT,
        .imsc1Text,
        .imsc1Image
    ]

    // MARK: - codecString(for: configuration:) integration

    @Test
    func integrationHvc2ConfigurationProducesHvc2CodecString() throws {
        // Build a hvc2 track configuration and confirm the full
        // CMAFTrackConfiguration → codec string dispatch works.
        let mvConfig = MultiLayerHEVCConfiguration(
            baseLayer: MultiLayerHEVCConfigurationTests.minimalHEVCRecord(),
            extensionLayer: nil,
            layerIDs: [0, 1],
            temporalIDs: [0, 0],
            layerDependencies: [
                LayerDependency(layerID: 0, dependsOnLayerIDs: []),
                LayerDependency(layerID: 1, dependsOnLayerIDs: [0])
            ]
        )
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 4096,
                height: 2160,
                codec: .hvc2,
                codecConfiguration: .mvHEVC(
                    configuration: mvConfig,
                    viewExtendedUsage: ViewExtendedUsageBox(
                        viewIdentifier: 0, usageFlags: 0x01
                    ),
                    stereoInformation: nil,
                    heroEye: nil
                ),
                frameRate: .init(numerator: 30, denominator: 1)
            )
        )
        let string = try builder.codecString(for: track)
        #expect(string.hasPrefix("hvc2."))
    }

    @Test
    func integrationVp8ConfigurationProducesVp08() throws {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .video,
            profile: .basic,
            timescale: 90_000,
            language: "und",
            videoFields: CMAFTrackConfiguration.VideoFields(
                width: 640,
                height: 480,
                codec: .vp08,
                codecConfiguration: .vp(
                    VPCodecConfigurationRecord(
                        version: 1, flags: 0,
                        profile: .profile0,
                        level: .level30,
                        bitDepth: 8,
                        chromaSubsampling: .format420Colocated,
                        videoFullRangeFlag: .limited,
                        colourPrimaries: .bt709,
                        transferCharacteristics: .bt709,
                        matrixCoefficients: .bt709,
                        codecInitializationData: Data()
                    )
                ),
                frameRate: .init(numerator: 30, denominator: 1)
            )
        )
        #expect(try builder.codecString(for: track) == "vp08")
    }

    @Test
    func integrationMetadataTrackThrowsUnsupported() {
        let track = CMAFTrackConfiguration(
            trackID: 1,
            kind: .metadata,
            profile: .basic,
            timescale: 1_000,
            language: "und",
            metadataFields: CMAFTrackConfiguration.MetadataFields(
                handlerType: "meta", metadataType: .id3
            )
        )
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.codecString(for: track)
        }
    }

    // NOTE: AAC integration via `codecString(for: configuration:)` is
    // intentionally deferred to Session 6 (it needs esds →
    // AudioSpecificConfig → AOT traversal). The descriptor-level builder
    // for `.aac(audioObjectType:)` is fully covered above.

    // MARK: - Additional parser error-path coverage

    @Test
    func parserRejectsHEVCMissingTierLetter() {
        // Token starts with a non-L/H character → throws
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("hvc1.1.6.X93")
        }
    }

    @Test
    func parserRejectsHEVCEmptyProfileToken() {
        // Empty first part → "hvc1..6.L93" splits to ["", "6", "L93"]
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("hvc1..6.L93")
        }
    }

    @Test
    func parserRejectsHEVCInvalidProfileSpaceAfterPrefix() {
        // "A" prefix then non-decimal → throws
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("hvc1.AX.6.L93")
        }
    }

    @Test
    func parserRejectsHEVCInvalidCompatHex() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("hvc1.1.ZZ.L93")
        }
    }

    @Test
    func parserRejectsHEVCInvalidConstraintByte() {
        // 4 dot-separated parts where part[3] is non-hex → throws
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("hvc1.1.6.L93.XX")
        }
    }

    @Test
    func parserRejectsHEVCInvalidLevelDecimal() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("hvc1.1.6.Lzz")
        }
    }

    @Test
    func parserRejectsAV1MissingParts() {
        // Only 2 parts → throws
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("av01.0.04M")
        }
    }

    @Test
    func parserRejectsAV1NonDecimalProfile() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("av01.Z.04M.10")
        }
    }

    @Test
    func parserRejectsAV1NonDecimalLevel() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("av01.0.zzM.10")
        }
    }

    @Test
    func parserRejectsAV1NonDecimalDepth() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("av01.0.04M.XX")
        }
    }

    @Test
    func parserAV1UnknownChromaTripleFallsBackToYuv420() throws {
        // Unknown chroma triple → falls back silently to .yuv420
        // (the descriptor still parses successfully)
        let parsed = try builder.parse("av01.0.04M.10.0.999.01.01.01.0")
        if case .av1(_, _, _, _, _, let chroma, _, _, _, _) = parsed[0] {
            #expect(chroma == .yuv420)
        } else {
            Issue.record("expected .av1 descriptor")
        }
    }

    @Test
    func parserRejectsVP9WrongPartCount() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("vp09.00.50.10")  // only 3 parts; need 8
        }
    }

    @Test
    func parserRejectsVP9NonDecimalField() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("vp09.XX.50.10.01.01.01.01.00")
        }
    }

    @Test
    func parserRejectsDolbyVisionWrongPartCount() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("dvh1.05")  // only 1 part
        }
    }

    @Test
    func parserRejectsDolbyVisionUnknownProfileNumber() {
        // Profile number 99 has no corresponding DolbyVisionProfile
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("dvh1.99.06")
        }
    }

    @Test
    func parserRejectsAACWrongPrefix() {
        // First part must be "40"
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("mp4a.41.2")
        }
    }

    @Test
    func parserRejectsAC4NonNumericPresentationID() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("ac-4.xx")
        }
    }

    @Test
    func parserRejectsMPEGHInvalidHex() {
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("mhm1.0xZZ")
        }
    }

    @Test
    func parserRejectsHEVCTokenWithOnlyPrefixCharacter() {
        // "A" alone — no digits after → throws
        #expect(throws: RFC6381BuilderError.self) {
            _ = try builder.parse("hvc1.A.6.L93")
        }
    }

    @Test
    func parserAcceptsHEVCAllConstraintBytes() throws {
        // 6 constraint bytes — full byte vector preserved
        let parsed = try builder.parse("hvc1.1.6.L93.b0.10.20.30.40.50")
        if case .hevc(_, _, _, _, _, _, let flags) = parsed[0] {
            #expect(flags == Data([0xB0, 0x10, 0x20, 0x30, 0x40, 0x50]))
        } else {
            Issue.record("expected .hevc descriptor")
        }
    }
}

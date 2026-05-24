// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

/// Builder + parser tests for ``RFC6381CodecStringBuilder``.
///
/// Every canonical-string test is anchored on a published spec example:
/// IETF RFC 6381 §3.3, Apple HLS Authoring Specification §2.2.x,
/// AOMedia AV1 ISO Media Format Binding §5, ETSI TS 102 366 / 103 190-2,
/// ISO/IEC 23008-3 §1, etc. Each test comment names the source spec
/// section.
@Suite("RFC6381 — builder")
struct RFC6381CodecStringBuilderTests {

    private let builder = RFC6381CodecStringBuilder()

    // MARK: - AVC (RFC 6381 §3.3)

    @Test
    func avcBaselineLevel3MatchesRFC6381Example() {
        // RFC 6381 §3.3 — AVC Baseline Profile, Level 3.0 (constraint set 0xE0)
        let d = RFC6381CodecDescriptor.avc(
            sampleEntry: .avc1, profile: 0x42, constraint: 0xE0, level: 0x1E
        )
        #expect(builder.codecString(for: d) == "avc1.42e01e")
    }

    @Test
    func avcMainProfileLevel4MatchesAppleHLSExample() {
        // Apple HLS Authoring §2.2.1 — AVC Main, Level 4.0 → "avc1.4d401e"
        // (profile 77 = Main, constraint 0x40, level 30 = 4.0)
        let d = RFC6381CodecDescriptor.avc(
            sampleEntry: .avc1, profile: 0x4D, constraint: 0x40, level: 0x1E
        )
        #expect(builder.codecString(for: d) == "avc1.4d401e")
    }

    @Test
    func avc3InbandVariantUsesAvc3Prefix() {
        let d = RFC6381CodecDescriptor.avc(
            sampleEntry: .avc3, profile: 0x42, constraint: 0xC0, level: 0x0D
        )
        #expect(builder.codecString(for: d) == "avc3.42c00d")
    }

    // MARK: - HEVC (ISO/IEC 14496-15 §A.5 + Apple HLS §2.2.1)

    @Test
    func hevcMainProfileLevel3_1MatchesAppleHLSExample() {
        // Apple HLS Authoring §2.2.1 — HEVC Main, Level 3.1
        // profileCompat 0x60000000 → reverse-bit-order → 0x6 → "6"
        // constraint bytes: [0xB0, 0, 0, 0, 0, 0] → trailing zeros stripped → "B0"
        let d = RFC6381CodecDescriptor.hevc(
            sampleEntry: .hvc1, profileSpace: 0, profile: 1,
            profileCompat: 0x6000_0000, tier: .main, level: 93,
            constraintFlags: Data([0xB0, 0, 0, 0, 0, 0])
        )
        #expect(builder.codecString(for: d) == "hvc1.1.6.L93.b0")
    }

    @Test
    func hevcMain10ProfileLevel4_1MatchesAppleHLSExample() {
        // Apple HLS Authoring §2.2.1 — HEVC Main 10, Level 4.1
        let d = RFC6381CodecDescriptor.hevc(
            sampleEntry: .hvc1, profileSpace: 0, profile: 2,
            profileCompat: 0x4000_0000, tier: .main, level: 123,
            constraintFlags: Data([0x90, 0, 0, 0, 0, 0])
        )
        #expect(builder.codecString(for: d) == "hvc1.2.4.L123.90")
    }

    @Test
    func hevcAllZeroConstraintFlagsOmittedEntirely() {
        // Per ISO/IEC 14496-15 §A.5 — when every constraint byte is zero
        // the suffix is omitted entirely (no trailing dot, no zeros).
        let d = RFC6381CodecDescriptor.hevc(
            sampleEntry: .hev1, profileSpace: 0, profile: 2,
            profileCompat: 0x4000_0000, tier: .high, level: 150,
            constraintFlags: Data([0, 0, 0, 0, 0, 0])
        )
        #expect(builder.codecString(for: d) == "hev1.2.4.H150")
    }

    @Test
    func hevcProfileSpace2UsesBPrefix() {
        // ITU-T H.265 §A.3.7 — profileSpace 2 → "B" prefix on the profile token
        let d = RFC6381CodecDescriptor.hevc(
            sampleEntry: .hvc1, profileSpace: 2, profile: 1,
            profileCompat: 0x6000_0000, tier: .main, level: 93,
            constraintFlags: Data([0xB0, 0, 0, 0, 0, 0])
        )
        #expect(builder.codecString(for: d) == "hvc1.B1.6.L93.b0")
    }

    // MARK: - MV-HEVC (Apple HLS §2.2.7 Spatial Video)

    @Test
    func mvHEVCMatchesAppleSpatialVideoExample() {
        // Apple HLS Authoring §2.2.7 — MV-HEVC base profile carried under hvc2
        let base = HEVCProfileDescriptor(
            profileSpace: 0, profile: 1, profileCompat: 0x6000_0000,
            tier: .main, level: 93, constraintFlags: Data([0xB0, 0, 0, 0, 0, 0])
        )
        let d = RFC6381CodecDescriptor.mvHEVC(
            baseProfile: base, extensionProfile: nil, viewCount: 2
        )
        #expect(builder.codecString(for: d) == "hvc2.1.6.L93.b0")
    }

    // MARK: - AV1 (AOMedia AV1 ISO Media Format Binding §5)

    @Test
    func av1Profile0Level4Main10BitDefaultsOmitted() {
        // AOMedia AV1 §5 — AV1 Profile 0, Level 4, Main Tier, 10-bit,
        // 4:2:0, BT.709 colour primaries → defaults → "av01.0.04M.10"
        let d = RFC6381CodecDescriptor.av1(
            profile: 0, level: 4, tier: .main, bitDepth: 10,
            monochrome: false, chromaSubsampling: .yuv420,
            colorPrimaries: 1, transferCharacteristics: 1, matrixCoefficients: 1,
            videoFullRangeFlag: false
        )
        #expect(builder.codecString(for: d) == "av01.0.04M.10")
    }

    @Test
    func av1FullExtendedFieldsWhenAnyNonDefault() {
        // AOMedia AV1 §5 — extended fields must ALL be emitted when ANY
        // of them is non-default (here BT.2020 colour primaries)
        let d = RFC6381CodecDescriptor.av1(
            profile: 0, level: 4, tier: .main, bitDepth: 10,
            monochrome: false, chromaSubsampling: .yuv420,
            colorPrimaries: 9, transferCharacteristics: 16, matrixCoefficients: 9,
            videoFullRangeFlag: true
        )
        #expect(builder.codecString(for: d) == "av01.0.04M.10.0.110.09.16.09.1")
    }

    @Test
    func av1Yuv444TripleIs000() {
        // AOMedia AV1 §5 — 4:4:4 chroma triple is "000"
        let d = RFC6381CodecDescriptor.av1(
            profile: 1, level: 5, tier: .high, bitDepth: 10,
            monochrome: false, chromaSubsampling: .yuv444,
            colorPrimaries: 1, transferCharacteristics: 1, matrixCoefficients: 1,
            videoFullRangeFlag: true  // force extended emission
        )
        #expect(builder.codecString(for: d) == "av01.1.05H.10.0.000.01.01.01.1")
    }

    @Test
    func av1HighTierEmitsH() {
        let d = RFC6381CodecDescriptor.av1(
            profile: 1, level: 5, tier: .high, bitDepth: 8,
            monochrome: false, chromaSubsampling: .yuv420,
            colorPrimaries: 1, transferCharacteristics: 1, matrixCoefficients: 1,
            videoFullRangeFlag: false
        )
        #expect(builder.codecString(for: d) == "av01.1.05H.08")
    }

    // MARK: - Dolby Vision (Dolby Vision Codec ISO Media Specification)

    @Test
    func dolbyVisionProfile5Level6MatchesAppleExample() {
        // Apple HLS Authoring §2.2.1 — Dolby Vision Profile 5, Level 6
        let d = RFC6381CodecDescriptor.dolbyVision(
            sampleEntry: .dvh1, profile: .profile5, level: .level06
        )
        #expect(builder.codecString(for: d) == "dvh1.05.06")
    }

    @Test
    func dolbyVisionProfile8HDR10CompatibleExample() {
        // Apple HLS Authoring §2.2.1 — Dolby Vision Profile 8 (HDR10-compat)
        // Profile wire number stays 8 — the sub-version is in the configuration record
        let d = RFC6381CodecDescriptor.dolbyVision(
            sampleEntry: .dvhe,
            profile: .profile8(subProfile: .hdr10Compatible),
            level: .level10
        )
        #expect(builder.codecString(for: d) == "dvhe.08.10")
    }

    // MARK: - VP9 (VP Codec ISO Media File Format Binding §3.1)

    @Test
    func vp9Profile0Level5_0_10BitMatchesWebMExample() {
        let d = RFC6381CodecDescriptor.vp9(
            profile: 0, level: 50, bitDepth: 10,
            chromaSubsampling: .yuv420, colorPrimaries: 1,
            transferCharacteristics: 1, matrixCoefficients: 1,
            videoFullRangeFlag: false
        )
        #expect(builder.codecString(for: d) == "vp09.00.50.10.01.01.01.01.00")
    }

    @Test
    func vp8IsBareString() {
        #expect(builder.codecString(for: .vp8) == "vp08")
    }

    // MARK: - Audio (RFC 6381 + Apple HLS §2.2.2 + ETSI specs)

    @Test
    func aacLCMatchesAppleHLSExample() {
        // Apple HLS Authoring §2.2.2 — AAC-LC → "mp4a.40.2"
        let d = RFC6381CodecDescriptor.aac(audioObjectType: .lc)
        #expect(builder.codecString(for: d) == "mp4a.40.2")
    }

    @Test
    func aacHEv1MatchesAppleHLSExample() {
        // Apple HLS Authoring §2.2.2 — HE-AAC v1 (SBR) → "mp4a.40.5"
        let d = RFC6381CodecDescriptor.aac(audioObjectType: .sbr)
        #expect(builder.codecString(for: d) == "mp4a.40.5")
    }

    @Test
    func aacHEv2MatchesAppleHLSExample() {
        // Apple HLS Authoring §2.2.2 — HE-AAC v2 (PS + SBR) → "mp4a.40.29"
        let d = RFC6381CodecDescriptor.aac(audioObjectType: .psSBR)
        #expect(builder.codecString(for: d) == "mp4a.40.29")
    }

    @Test
    func aacXHEAACMatchesAppleHLSExample() {
        // Apple HLS Authoring §2.2.2 — xHE-AAC → "mp4a.40.42"
        let d = RFC6381CodecDescriptor.aac(audioObjectType: .xHE)
        #expect(builder.codecString(for: d) == "mp4a.40.42")
    }

    @Test
    func ac3IsBareString() {
        // ETSI TS 102 366 + RFC 6381 — AC-3 → "ac-3"
        #expect(builder.codecString(for: .ac3) == "ac-3")
    }

    @Test
    func ec3IsBareStringRegardlessOfJOC() {
        // ETSI TS 102 366 Annex H — codec string stays "ec-3"; JOC is
        // signalled via the descriptor's `joc` field for the caller to
        // route into its target manifest syntax (e.g., Apple HLS uses
        // CHANNELS="16/JOC" rather than a codec-string suffix).
        #expect(builder.codecString(for: .ec3(joc: false)) == "ec-3")
        #expect(builder.codecString(for: .ec3(joc: true)) == "ec-3")
    }

    @Test
    func ac4WithoutPresentationIDIsBareString() {
        // ETSI TS 103 190-2 + RFC 6381 — AC-4 → "ac-4"
        #expect(builder.codecString(for: .ac4(presentationID: nil)) == "ac-4")
    }

    @Test
    func ac4WithPresentationIDEmitsSuffix() {
        // ETSI TS 103 190-2 — AC-4 with specific presentation → "ac-4.5"
        #expect(builder.codecString(for: .ac4(presentationID: 5)) == "ac-4.5")
    }

    @Test
    func mpegHmhm1WithPLIEmitsUppercaseHex() {
        // ISO/IEC 23008-3 §1 — MPEG-H mhm1 with PLI 0x0C → uppercase hex
        let d = RFC6381CodecDescriptor.mpegH(
            sampleEntry: .mhm1, profileLevelIndication: 0x0C
        )
        #expect(builder.codecString(for: d) == "mhm1.0x0C")
    }

    @Test
    func mpegHmhm2WithPLI0x13() {
        let d = RFC6381CodecDescriptor.mpegH(
            sampleEntry: .mhm2, profileLevelIndication: 0x13
        )
        #expect(builder.codecString(for: d) == "mhm2.0x13")
    }

    // MARK: - Constants — case-sensitive per spec

    @Test
    func opusEmitsCapitalO() {
        // RFC 6716 + ISO/IEC 14496-12 mapping — case-sensitive capital O
        #expect(builder.codecString(for: .opus) == "Opus")
    }

    @Test
    func flacEmitsFLowerLUpperALowerCUpper() {
        // RFC 9639 + FLAC-in-ISOBMFF — "fLaC" case-sensitive
        #expect(builder.codecString(for: .flac) == "fLaC")
    }

    @Test
    func alacEmitsAlac() {
        #expect(builder.codecString(for: .alac) == "alac")
    }

    @Test
    func ipcmEmitsIpcm() {
        #expect(builder.codecString(for: .pcmIPCM) == "ipcm")
    }

    @Test
    func fpcmEmitsFpcm() {
        #expect(builder.codecString(for: .pcmFPCM) == "fpcm")
    }

    @Test
    func lpcmEmitsLpcm() {
        #expect(builder.codecString(for: .pcmLPCM) == "lpcm")
    }

    // MARK: - Subtitles (ISO/IEC 14496-30 §7.3-7.4)

    @Test
    func webVTTEmitsWvtt() {
        #expect(builder.codecString(for: .webVTT) == "wvtt")
    }

    @Test
    func imsc1TextEmitsStppTtmlIm1t() {
        #expect(builder.codecString(for: .imsc1Text) == "stpp.ttml.im1t")
    }

    @Test
    func imsc1ImageEmitsStppTtmlIm1i() {
        #expect(builder.codecString(for: .imsc1Image) == "stpp.ttml.im1i")
    }
}

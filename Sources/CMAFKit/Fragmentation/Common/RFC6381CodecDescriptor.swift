// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - RFC6381CodecDescriptor
//
// Reference: IETF RFC 6381 — "The 'Codecs' and 'Profiles' Parameters for
// 'Bucket' Media Types", ISO/IEC 14496-15 §A.5 (CMAF codec parameter
// generation), Apple HLS Authoring Specification §2.2 (HLS codec string
// conventions), DASH-IF Implementation Guidelines §4 (DASH codec strings).
//
// Tagged union of every codec CMAFKit can emit or parse as an RFC 6381
// `codecs=` attribute value. The descriptor is the typed source of truth
// for ``RFC6381CodecStringBuilder`` — every parameter that affects the
// wire codec string is a field on the descriptor.

import Foundation

/// Tagged union of every codec CMAFKit supports as an RFC 6381 `codecs=`
/// value.
///
/// One case per codec family; parameters carry the bits the codec string
/// encodes (profile, level, chroma subsampling, bit depth, etc.). Reuses
/// the existing enum types (e.g., ``DolbyVisionProfile``,
/// ``AACProfile``) — does not redefine codec parameters.
///
/// References:
/// - IETF RFC 6381 — The 'Codecs' and 'Profiles' Parameters
/// - ISO/IEC 14496-15 §A.5 — CMAF codec parameter generation
/// - Apple HLS Authoring Specification §2.2 — HLS codec string conventions
/// - DASH-IF Implementation Guidelines §4 — DASH codec strings
public enum RFC6381CodecDescriptor: Sendable, Equatable, Hashable {

    // MARK: Video

    /// `avc1.PPCCLL` or `avc3.PPCCLL` per RFC 6381 §3.3 + ISO/IEC 14496-15 §A.5.
    ///
    /// PP = `profile_idc`, CC = constraint flags byte, LL = `level_idc` — all
    /// encoded as 2-digit lowercase hex with leading zeros.
    case avc(
        sampleEntry: AVCSampleEntryKind,
        profile: UInt8,
        constraint: UInt8,
        level: UInt8
    )

    /// `hvc1.A.B.C.D.E.F` or `hev1.A.B.C.D.E.F` per ISO/IEC 14496-15 §A.5.
    ///
    /// A = profileSpace letter ("A"/"B"/"C" for 1/2/3, no prefix for 0) +
    /// `general_profile_idc` decimal. B = `general_profile_compatibility_flags`
    /// reversed-bit-order hex (lowercase, leading zeros stripped). C = tier
    /// letter (`L` for main, `H` for high) + `general_level_idc` decimal.
    /// D-F = constraint bytes 0-2 as 2-digit lowercase hex pairs; trailing
    /// zero bytes are omitted per spec.
    case hevc(
        sampleEntry: HEVCSampleEntryKind,
        profileSpace: UInt8,
        profile: UInt8,
        profileCompat: UInt32,
        tier: HEVCTier,
        level: UInt8,
        constraintFlags: Data
    )

    /// `hvc2.*` per ISO/IEC 14496-15 §A.5 (multi-layer HEVC) + Apple HLS
    /// Authoring Specification §2.2.7 (Spatial Video — Apple Vision Pro).
    ///
    /// The codec string carries the base HEVC profile parameters under
    /// the `hvc2` prefix; the multi-layer information (view count,
    /// extension layer) is signalled externally (CMAF
    /// ``MultiLayerHEVCConfiguration`` + HLS `EXT-X-VIDEO-LAYOUT`).
    /// The optional extension-layer profile and the view count are
    /// stored on the descriptor for caller introspection but are not
    /// emitted in the codec string.
    case mvHEVC(
        baseProfile: HEVCProfileDescriptor,
        extensionProfile: HEVCProfileDescriptor?,
        viewCount: UInt8
    )

    /// `av01.<P>.<LL><T>.<DD>[.<M>.<S>.<CP>.<TC>.<MC>.<R>]` per
    /// AOMedia AV1 Codec ISO Media Format Binding §5.
    ///
    /// The extended fields (monochrome, chroma sample position,
    /// colour primaries, transfer characteristics, matrix coefficients,
    /// video full-range flag) are emitted **only when at least one is
    /// non-default**, matching ffprobe behaviour.
    case av1(
        profile: UInt8,
        level: UInt8,
        tier: AV1Tier,
        bitDepth: UInt8,
        monochrome: Bool,
        chromaSubsampling: ChromaSubsampling,
        colorPrimaries: UInt8,
        transferCharacteristics: UInt8,
        matrixCoefficients: UInt8,
        videoFullRangeFlag: Bool
    )

    /// `dvh1.PP.LL` / `dvhe.PP.LL` / `dvav.PP.LL` / `dav1.PP.LL` per the
    /// Dolby Vision Codec ISO Media Specification.
    ///
    /// PP = profile wire number (e.g., 5 → `05`, 8 → `08`); LL = level
    /// raw value. Both zero-padded to 2 decimal digits.
    case dolbyVision(
        sampleEntry: DolbyVisionSampleEntryKind,
        profile: DolbyVisionProfile,
        level: DolbyVisionLevel
    )

    /// `vp09.<PP>.<LL>.<DD>.<S>.<CP>.<TC>.<MC>.<R>` per the VP Codec
    /// ISO Media File Format Binding §3.1. Every field is emitted as
    /// 2-digit zero-padded decimal (no AV1-style default omission).
    case vp9(
        profile: UInt8,
        level: UInt8,
        bitDepth: UInt8,
        chromaSubsampling: ChromaSubsampling,
        colorPrimaries: UInt8,
        transferCharacteristics: UInt8,
        matrixCoefficients: UInt8,
        videoFullRangeFlag: Bool
    )

    /// `vp08` per WebM convention. No parameters in the codec string.
    case vp8

    // MARK: Audio

    /// `mp4a.40.<AOT>` per ISO/IEC 14496-3 + Apple HLS Authoring §2.2.2.
    ///
    /// Common values: 2 (AAC-LC), 5 (HE-AAC v1 / SBR), 29 (HE-AAC v2 /
    /// PS), 39 (ER-AAC-ELD v2), 42 (xHE-AAC).
    case aac(audioObjectType: AACProfile)

    /// `ac-3` per ETSI TS 102 366 + RFC 6381.
    case ac3

    /// `ec-3` per ETSI TS 102 366.
    ///
    /// The wire codec string is always `"ec-3"` — Dolby Atmos via JOC
    /// (ETSI TS 102 366 Annex H) is signalled externally (Apple HLS:
    /// `CHANNELS="16/JOC"` attribute; DASH-IF varies). The associated
    /// `joc` bit is carried on the descriptor so the caller can route
    /// the signal through its preferred manifest mechanism.
    case ec3(joc: Bool)

    /// `ac-4` per ETSI TS 103 190-2 + RFC 6381.
    ///
    /// When the associated `presentationID` is non-nil the codec string
    /// emits `ac-4.<id>` (id as decimal); the bare `ac-4` form is
    /// emitted otherwise.
    case ac4(presentationID: UInt8?)

    /// `mhm1.0x<PLI>` or `mhm2.0x<PLI>` per ISO/IEC 23008-3 §1.
    ///
    /// `<PLI>` is the `mpegh_profile_level_indication` byte as 2-digit
    /// UPPERCASE hex per the spec's example (this is a deliberate
    /// exception to the otherwise-lowercase-hex rule of other codecs).
    case mpegH(
        sampleEntry: MPEGHSampleEntryKind,
        profileLevelIndication: UInt8
    )

    /// `Opus` per RFC 6716 + ISO/IEC 14496-12 mapping
    /// (case-sensitive — capital `O`).
    case opus

    /// `fLaC` per RFC 9639 + FLAC-in-ISOBMFF binding
    /// (case-sensitive — `f` lower, `L` upper, `a` lower, `C` upper).
    case flac

    /// `alac` per Apple ALAC public specification (open-sourced 2011).
    case alac

    /// `ipcm` per ISO/IEC 23003-5 §6.2 (integer PCM).
    case pcmIPCM

    /// `fpcm` per ISO/IEC 23003-5 §6.3 (floating-point PCM).
    case pcmFPCM

    /// `lpcm` per ISO/IEC 14496-12 §12.2.3 (legacy ISO PCM).
    case pcmLPCM

    // MARK: Subtitle

    /// `wvtt` per ISO/IEC 14496-30 §7.3 (WebVTT in ISOBMFF).
    case webVTT

    /// `stpp.ttml.im1t` per ISO/IEC 14496-30 §7.4 + IMSC1 Text Profile.
    case imsc1Text

    /// `stpp.ttml.im1i` per ISO/IEC 14496-30 §7.4 + IMSC1 Image Profile.
    case imsc1Image
}

// MARK: - Companion types

/// AVC sample-entry variant — `avc1` (out-of-band parameter sets) or
/// `avc3` (in-band parameter sets). Drives the codec-string prefix so
/// the builder cannot emit an invalid one.
public enum AVCSampleEntryKind: String, Sendable, Hashable, Codable, CaseIterable {
    case avc1
    case avc3
}

/// HEVC sample-entry variant — `hvc1` (out-of-band) or `hev1` (in-band).
public enum HEVCSampleEntryKind: String, Sendable, Hashable, Codable, CaseIterable {
    case hvc1
    case hev1
}

/// Dolby Vision sample-entry variant per Dolby Vision Codec ISO Media
/// Specification. `dvh1` / `dvhe` are HEVC-based; `dvav` is AVC-based;
/// `dav1` is AV1-based.
public enum DolbyVisionSampleEntryKind: String, Sendable, Hashable, Codable, CaseIterable {
    case dvh1
    case dvhe
    case dvav
    case dav1
}

/// MPEG-H 3D Audio sample-entry variant per ISO/IEC 23008-3.
public enum MPEGHSampleEntryKind: String, Sendable, Hashable, Codable, CaseIterable {
    case mhm1
    case mhm2
}

/// HEVC tier alias — reuses the existing 0.1.0 ``HEVCTierFlag`` enum so
/// callers can use either name interchangeably. The spec names this
/// concept "tier" plain; the 0.1.0 type is named with the ITU "flag"
/// suffix.
public typealias HEVCTier = HEVCTierFlag

extension HEVCTierFlag {
    /// Letter emitted in the HEVC codec string before the level decimal.
    /// `L` for main tier, `H` for high tier — per ISO/IEC 14496-15 §A.5.
    public var codecStringLetter: Character {
        switch self {
        case .main: return "L"
        case .high: return "H"
        }
    }
}

extension AV1Tier {
    /// Letter emitted in the AV1 codec string suffixed to the level
    /// (`M` for main, `H` for high — per AOMedia AV1 ISO Media Format
    /// Binding §5).
    public var codecStringLetter: Character {
        switch self {
        case .main: return "M"
        case .high: return "H"
        }
    }
}

/// Chroma subsampling per ITU-T H.265 + AV1 + VP9 specs. Raw value
/// matches the on-wire `chroma_format_idc` (`1` = 4:2:0, `2` = 4:2:2,
/// `3` = 4:4:4).
public enum ChromaSubsampling: UInt8, Sendable, Hashable, Codable, CaseIterable {
    case yuv420 = 1
    case yuv422 = 2
    case yuv444 = 3
}

/// HEVC profile descriptor — shared helper between
/// ``RFC6381CodecDescriptor/hevc(sampleEntry:profileSpace:profile:profileCompat:tier:level:constraintFlags:)``
/// and the multi-layer ``RFC6381CodecDescriptor/mvHEVC(baseProfile:extensionProfile:viewCount:)``
/// case so the multi-layer compositional shape reuses the same fields
/// as the single-layer one.
public struct HEVCProfileDescriptor: Sendable, Equatable, Hashable, Codable {
    public let profileSpace: UInt8
    public let profile: UInt8
    public let profileCompat: UInt32
    public let tier: HEVCTier
    public let level: UInt8
    /// 6-byte constraint indicator flags per ISO/IEC 14496-15 §A.5.
    /// Trailing zero bytes are omitted in the codec string.
    public let constraintFlags: Data

    public init(
        profileSpace: UInt8,
        profile: UInt8,
        profileCompat: UInt32,
        tier: HEVCTier,
        level: UInt8,
        constraintFlags: Data
    ) {
        self.profileSpace = profileSpace
        self.profile = profile
        self.profileCompat = profileCompat
        self.tier = tier
        self.level = level
        self.constraintFlags = constraintFlags
    }
}

/// Typed errors thrown by ``RFC6381CodecStringBuilder``.
public enum RFC6381BuilderError: Error, Equatable {
    /// The codec is recognised but not yet wired through
    /// `codecString(for: configuration:)` in this release (the
    /// dispatch from ``CMAFTrackConfiguration`` for that codec is
    /// planned for a follow-up). The descriptor-level builder still
    /// works.
    case unsupportedCodec(reason: String)

    /// The codec string failed to parse. The full input is included in
    /// the error so callers see exactly what failed.
    case malformedCodecString(input: String, reason: String)

    /// The track configuration is missing data needed to build a codec
    /// string for the declared codec (e.g., a video track with no
    /// `videoFields`).
    case missingConfiguration(codec: String)
}

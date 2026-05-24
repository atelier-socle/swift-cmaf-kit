// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BrandComposer
//
// Reference: ISO/IEC 14496-12 §4.3 (FileTypeBox) and §8.16.1
// (SegmentTypeBox). Reference: ISO/IEC 23000-19 §6 (CMAF Media
// Profiles and brand signalling). Composes a conformant `ftyp` or
// `styp` payload from a ``CMAFProfile`` selection and a set of
// track configurations.

import Foundation

/// Helper that turns a ``CMAFProfile`` plus a set of track
/// configurations into the right `ftyp` / `styp` brand metadata.
///
/// The methods are factored so that ``compatibleBrands(for:)`` can
/// be called independently when a consumer needs only the brand list
/// (for example, to validate a downstream packaging pipeline).
public enum BrandComposer {

    /// Compose the `ftyp` box for an init segment from a set of
    /// track configurations. The major brand comes from the first
    /// configuration's profile; the compatible-brands list is the
    /// union of the profile baseline and every codec-specific brand
    /// implied by the configurations.
    public static func makeFileTypeBox(
        configurations: [CMAFTrackConfiguration]
    ) -> FileTypeBox {
        let profile = configurations.first?.profile ?? .basic
        return FileTypeBox(
            majorBrand: profile.majorBrand,
            minorVersion: 0,
            compatibleBrands: compatibleBrands(for: configurations)
        )
    }

    /// Compose the `styp` box for a media segment from a set of
    /// track configurations. Same rule as ``makeFileTypeBox(configurations:)``.
    public static func makeSegmentTypeBox(
        configurations: [CMAFTrackConfiguration]
    ) -> SegmentTypeBox {
        let profile = configurations.first?.profile ?? .basic
        return SegmentTypeBox(
            majorBrand: profile.majorBrand,
            minorVersion: 0,
            compatibleBrands: compatibleBrands(for: configurations)
        )
    }

    /// Profile-only ftyp helper used by call sites that have no
    /// configuration set on hand. Equivalent to passing one synthetic
    /// configuration with the supplied profile.
    static func makeFileTypeBox(
        profile: CMAFProfile,
        extraCompatibleBrands: [FourCC] = []
    ) -> FileTypeBox {
        let combined = profile.compatibleBrands + extraCompatibleBrands
        return FileTypeBox(
            majorBrand: profile.majorBrand,
            minorVersion: 0,
            compatibleBrands: deduplicate(combined)
        )
    }

    /// Profile-only styp helper.
    static func makeSegmentTypeBox(
        profile: CMAFProfile,
        extraCompatibleBrands: [FourCC] = []
    ) -> SegmentTypeBox {
        let combined = profile.compatibleBrands + extraCompatibleBrands
        return SegmentTypeBox(
            majorBrand: profile.majorBrand,
            minorVersion: 0,
            compatibleBrands: deduplicate(combined)
        )
    }

    /// Compute the full `compatible_brands` list per ISO/IEC 23000-19
    /// §6 for the given track configurations.
    ///
    /// The order is:
    ///
    ///   1. Profile baseline (always includes `iso6` and `cmfc`).
    ///   2. Codec-specific brands implied by every track
    ///      (e.g., `avc1` / `hvc1` / `dby1` / `av01`).
    ///   3. Encryption-related brands when any track carries CENC
    ///      parameters (`iso7` per ISO/IEC 14496-12 §4.3).
    ///   4. Multi-stream brand `cmf2` when multiple tracks of the
    ///      same kind are present.
    ///
    /// Duplicates are removed; the original order is preserved.
    public static func compatibleBrands(
        for configurations: [CMAFTrackConfiguration]
    ) -> [FourCC] {
        let profile = configurations.first?.profile ?? .basic
        var brands: [FourCC] = profile.compatibleBrands
        for configuration in configurations {
            brands.append(contentsOf: codecSpecificBrands(for: configuration))
        }
        if configurations.contains(where: { $0.encryptionParameters != nil }) {
            // ISO/IEC 14496-12 §4.3 documents `iso7` as the brand for
            // files that carry sample-encryption metadata. CMAFKit
            // appends it whenever any track is encrypted.
            brands.append("iso7")
        }
        if multiStreamKindCount(configurations: configurations) > 0 {
            brands.append("cmf2")
        }
        return deduplicate(brands)
    }

    // MARK: - Codec-specific brand mapping

    /// Brands implied by a single track's codec and profile state.
    private static func codecSpecificBrands(
        for configuration: CMAFTrackConfiguration
    ) -> [FourCC] {
        switch configuration.kind {
        case .video:
            return videoCodecBrands(for: configuration)
        case .audio:
            return audioCodecBrands(for: configuration)
        case .subtitle:
            return subtitleCodecBrands(for: configuration)
        case .metadata:
            return []
        }
    }

    private static func videoCodecBrands(
        for configuration: CMAFTrackConfiguration
    ) -> [FourCC] {
        guard let video = configuration.videoFields else { return [] }
        switch video.codec {
        case .avc1: return ["avc1"]
        case .avc3: return ["avc3"]
        case .hvc1: return ["hvc1"]
        case .hev1: return ["hev1"]
        case .dvh1: return ["dvh1", "dby1"]
        case .dvhe: return ["dvhe", "dby1"]
        case .vp08: return ["vp08"]
        case .vp09: return ["vp09"]
        case .av01: return ["av01"]
        case .mp4v: return ["mp4v"]
        case .hvc2: return ["hvc2", "mvhc"]
        }
    }

    private static func audioCodecBrands(
        for configuration: CMAFTrackConfiguration
    ) -> [FourCC] {
        guard let audio = configuration.audioFields else { return [] }
        switch audio.codec {
        case .mp4a: return ["mp41"]
        case .ac3: return ["dac3"]
        case .ec3: return ["dec3"]
        case .ac4: return ["dac4"]
        case .opus: return ["opus"]
        case .flac: return ["flac"]
        case .mpegHMain, .mpegHMultiStream: return ["mhm1"]
        case .alac: return ["alac"]
        // CMAF (ISO/IEC 23000-19) §7.5.2 — CMAF Uncompressed Audio
        // brands "cup1" / "cup2" cover ipcm / fpcm / lpcm; emit them
        // as compatibility brands for receivers that filter on the
        // uncompressed profile.
        case .ipcm, .fpcm: return ["cup1"]
        case .lpcm: return ["cup2"]
        }
    }

    private static func subtitleCodecBrands(
        for configuration: CMAFTrackConfiguration
    ) -> [FourCC] {
        guard let subtitle = configuration.subtitleFields else { return [] }
        switch subtitle.codec {
        case .webVTT: return ["wvtt"]
        case .imsc1Text: return ["im1t"]
        case .imsc1Image: return ["im1i"]
        }
    }

    /// Count of multi-stream pairs (≥ 2 tracks of the same kind).
    private static func multiStreamKindCount(
        configurations: [CMAFTrackConfiguration]
    ) -> Int {
        var counts: [CMAFTrackKind: Int] = [:]
        for configuration in configurations {
            counts[configuration.kind, default: 0] += 1
        }
        return counts.values.filter { $0 >= 2 }.count
    }

    /// Order-preserving deduplication helper.
    private static func deduplicate(_ brands: [FourCC]) -> [FourCC] {
        var seen: Set<FourCC> = []
        var result: [FourCC] = []
        result.reserveCapacity(brands.count)
        for brand in brands where seen.insert(brand).inserted {
            result.append(brand)
        }
        return result
    }
}

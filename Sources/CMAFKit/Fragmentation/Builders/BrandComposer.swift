// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BrandComposer
//
// Reference: ISO/IEC 14496-12 §4.3 (FileTypeBox) and §8.16.1
// (SegmentTypeBox). Composes a conformant `ftyp` or `styp` payload
// from a ``CMAFProfile`` selection.

import Foundation

/// Internal helper that turns a ``CMAFProfile`` into a ready-to-encode
/// ``FileTypeBox`` or ``SegmentTypeBox``.
internal enum BrandComposer {

    /// Compose the `ftyp` box for an init segment.
    ///
    /// - Parameters:
    ///   - profile: the CMAF profile in use, supplying the major brand
    ///     and the baseline compatible-brands list.
    ///   - extraCompatibleBrands: optional extra brands appended to
    ///     the compatible-brands list (for example codec-specific
    ///     brands like `"hev1"` for HEVC content).
    /// - Returns: A ``FileTypeBox`` whose `compatible_brands` list is
    ///   deduplicated while preserving order.
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

    /// Compose the `styp` box for a media segment.
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

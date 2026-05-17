// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MP4Epoch
//
// Reference: ISO/IEC 14496-12 §8.2.2 (movie header box).
//
// ISOBMFF time fields use the Mac OS / QuickTime epoch: 1904-01-01
// 00:00:00 UTC, distinct from the Unix epoch (1970-01-01). This file
// provides exact-arithmetic conversion helpers used by the header boxes.

import Foundation

/// Mac OS / QuickTime epoch used by `mvhd`, `tkhd`, `mdhd`.
///
/// 1904-01-01 00:00:00 UTC = `-2_082_844_800` seconds relative to the
/// Unix epoch. The offset is exact and fits in `Int64`.
public enum MP4Epoch {
    /// Seconds between the Mac OS epoch (1904-01-01) and the Unix epoch
    /// (1970-01-01). Subtract to convert MP4 → Unix; add to convert
    /// Unix → MP4.
    public static let macOSEpochOffsetSeconds: Int64 = 2_082_844_800

    /// Convert an ISOBMFF time field (seconds since 1904-01-01) into a `Date`.
    public static func date(fromMP4Seconds seconds: UInt64) -> Date {
        let unixSeconds = Int64(seconds) - macOSEpochOffsetSeconds
        return Date(timeIntervalSince1970: TimeInterval(unixSeconds))
    }

    /// Convert a `Date` into the ISOBMFF time field (seconds since
    /// 1904-01-01). Returns `0` for dates predating the Mac OS epoch.
    public static func mp4Seconds(from date: Date) -> UInt64 {
        let unixSeconds = Int64(date.timeIntervalSince1970)
        let mp4Seconds = unixSeconds + macOSEpochOffsetSeconds
        return mp4Seconds < 0 ? 0 : UInt64(mp4Seconds)
    }
}

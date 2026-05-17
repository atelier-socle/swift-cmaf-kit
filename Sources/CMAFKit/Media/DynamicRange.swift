// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DynamicRange
//
// Classification of HDR variants. Referenced from `HDRMetadata`.

import Foundation

/// Display dynamic-range classification.
public enum DynamicRange: Sendable, Hashable {
    /// Standard dynamic range.
    case sdr
    /// HDR10 (PQ + static metadata: mdcv, clli).
    case hdr10
    /// HDR10+ (PQ + dynamic SMPTE ST 2094-40 SEI metadata).
    case hdr10Plus
    /// Dolby Vision, with its specific profile (5/7/8/10).
    case dolbyVision(profile: DolbyVisionProfile)
    /// Hybrid Log-Gamma (BT.2100).
    case hlg
}

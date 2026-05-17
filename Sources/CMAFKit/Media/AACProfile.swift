// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AACProfile
//
// Reference: ISO/IEC 14496-3 §1.6.2.1 and Table 1.16 (audio object type).

import Foundation

/// AAC audio object type per ISO/IEC 14496-3 §1.6.2.1 and Table 1.16.
///
/// Used as the AOT field in `AudioSpecificConfig`, and indirectly in the
/// codec-string `mp4a.40.<aot>` form (RFC 6381).
public enum AACProfile: UInt8, Sendable, Hashable, CaseIterable {
    /// AAC Main.
    case main = 1
    /// AAC Low Complexity (the most common AAC profile).
    case lc = 2
    /// AAC Scalable Sample Rate.
    case ssr = 3
    /// AAC Long Term Prediction.
    case ltp = 4
    /// HE-AAC v1 (AAC-LC + SBR).
    case sbr = 5
    /// HE-AAC v2 (AAC-LC + SBR + Parametric Stereo).
    case psSBR = 29
    /// Enhanced Low Delay v2.
    case eldV2 = 39
    /// xHE-AAC (Extended HE-AAC).
    case xHE = 42
}

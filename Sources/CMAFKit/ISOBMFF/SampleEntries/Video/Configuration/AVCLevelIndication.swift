// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCLevelIndication
//
// Reference: ISO/IEC 14496-10 Annex A.3 (level limits).

import Foundation

/// AVC level indication carried by `AVCDecoderConfigurationRecord`.
///
/// Reference: ISO/IEC 14496-10 Annex A.3.
public enum AVCLevelIndication: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Level 1.
    case level1 = 10
    /// Level 1b (low-bitrate baseline; encoded as 11 with constraint_set3_flag=1
    /// — the on-wire rawValue is still 11; CMAFKit treats 1b as a profile
    /// constraint, not a separate level value).
    case level1_1 = 11
    /// Level 1.2.
    case level1_2 = 12
    /// Level 1.3.
    case level1_3 = 13
    /// Level 2.
    case level2 = 20
    /// Level 2.1.
    case level2_1 = 21
    /// Level 2.2.
    case level2_2 = 22
    /// Level 3.
    case level3 = 30
    /// Level 3.1.
    case level3_1 = 31
    /// Level 3.2.
    case level3_2 = 32
    /// Level 4.
    case level4 = 40
    /// Level 4.1.
    case level4_1 = 41
    /// Level 4.2.
    case level4_2 = 42
    /// Level 5.
    case level5 = 50
    /// Level 5.1.
    case level5_1 = 51
    /// Level 5.2.
    case level5_2 = 52
    /// Level 6.
    case level6 = 60
    /// Level 6.1.
    case level6_1 = 61
    /// Level 6.2.
    case level6_2 = 62
    /// Reserved level 9 (legacy, sometimes seen for Level 1b alternative encoding).
    case level9 = 9
}

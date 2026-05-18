// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVC enums
//
// Reference: ISO/IEC 23008-2 (HEVC) + ISO/IEC 14496-15 §8.3.3.

import Foundation

/// HEVC profile space (2-bit field).
///
/// Reference: ISO/IEC 23008-2 Annex A.3.
public enum HEVCProfileSpace: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3
}

/// HEVC tier flag (1-bit field).
///
/// Reference: ISO/IEC 23008-2 Annex A.4.
public enum HEVCTierFlag: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case main = 0
    case high = 1
}

/// HEVC profile IDC carried by `HEVCDecoderConfigurationRecord`.
///
/// Reference: ISO/IEC 23008-2 Annex A.3 + ISO/IEC 14496-15 §8.3.3.
public enum HEVCProfileIDC: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case main = 1
    case main10 = 2
    case mainStillPicture = 3
    case rangeExtensions = 4
    case highThroughput = 5
    case multiviewMain = 6
    case scalableMain = 7
    case threeDMain = 8
    case screenContentCoding = 9
    case scalableRangeExtensions = 10
    case highThroughputScreenContentCoding = 11
}

/// HEVC parallelism type.
///
/// Reference: ISO/IEC 14496-15 §8.3.3.
public enum HEVCParallelismType: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case mixedOrUnknown = 0
    case slice = 1
    case tile = 2
    case waveFront = 3
}

/// HEVC constant-frame-rate indicator.
///
/// Reference: ISO/IEC 14496-15 §8.3.3.
public enum HEVCConstantFrameRate: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case unknown = 0
    case constant = 1
    case temporal = 2
    case reserved = 3
}

/// HEVC chroma format IDC.
///
/// Reference: ISO/IEC 23008-2 §6.2.
public enum HEVCChromaFormatIDC: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case monochrome = 0
    case format420 = 1
    case format422 = 2
    case format444 = 3
}

/// HEVC level IDC.
///
/// Reference: ISO/IEC 23008-2 Annex A.4. Level numbers are encoded as
/// 30 × level (i.e. level 3.0 is 90, level 6.2 is 186).
public enum HEVCLevelIDC: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Level 1.0.
    case level1 = 30
    /// Level 2.0.
    case level2 = 60
    /// Level 2.1.
    case level2_1 = 63
    /// Level 3.0.
    case level3 = 90
    /// Level 3.1.
    case level3_1 = 93
    /// Level 4.0.
    case level4 = 120
    /// Level 4.1.
    case level4_1 = 123
    /// Level 5.0.
    case level5 = 150
    /// Level 5.1.
    case level5_1 = 153
    /// Level 5.2.
    case level5_2 = 156
    /// Level 6.0.
    case level6 = 180
    /// Level 6.1.
    case level6_1 = 183
    /// Level 6.2.
    case level6_2 = 186
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MPEGHProfileLevelIndication
//
// Reference: ISO/IEC 23008-3 §5.3.2 Table 67 (mpegh3da profile-level
// indications).

import Foundation

/// MPEG-H 3D Audio profile / level indication per ISO/IEC 23008-3
/// §5.3.2 Table 67.
///
/// The raw value combines the profile family and the level. Reserved
/// values throw on parse rather than being collapsed to a fallback.
public enum MPEGHProfileLevelIndication: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Reserved value (0x00).
    case reserved0 = 0x00
    /// MPEG-H 3D Audio Main Profile, Level 1.
    case mainProfileLevel1 = 0x01
    /// MPEG-H 3D Audio Main Profile, Level 2.
    case mainProfileLevel2 = 0x02
    /// MPEG-H 3D Audio Main Profile, Level 3.
    case mainProfileLevel3 = 0x03
    /// MPEG-H 3D Audio Main Profile, Level 4.
    case mainProfileLevel4 = 0x04
    /// MPEG-H 3D Audio Main Profile, Level 5.
    case mainProfileLevel5 = 0x05
    /// MPEG-H 3D Audio High Profile, Level 1.
    case highProfileLevel1 = 0x06
    /// MPEG-H 3D Audio High Profile, Level 2.
    case highProfileLevel2 = 0x07
    /// MPEG-H 3D Audio High Profile, Level 3.
    case highProfileLevel3 = 0x08
    /// MPEG-H 3D Audio High Profile, Level 4.
    case highProfileLevel4 = 0x09
    /// MPEG-H 3D Audio High Profile, Level 5.
    case highProfileLevel5 = 0x0A
    /// MPEG-H 3D Audio Low Complexity (LC) Profile, Level 1.
    case lcProfileLevel1 = 0x0B
    /// MPEG-H 3D Audio Low Complexity (LC) Profile, Level 2.
    case lcProfileLevel2 = 0x0C
    /// MPEG-H 3D Audio Low Complexity (LC) Profile, Level 3.
    case lcProfileLevel3 = 0x0D
    /// MPEG-H 3D Audio Low Complexity (LC) Profile, Level 4.
    case lcProfileLevel4 = 0x0E
    /// MPEG-H 3D Audio Low Complexity (LC) Profile, Level 5.
    case lcProfileLevel5 = 0x0F
    /// MPEG-H 3D Audio Baseline Profile, Level 1.
    case baselineProfileLevel1 = 0x10
    /// MPEG-H 3D Audio Baseline Profile, Level 2.
    case baselineProfileLevel2 = 0x11
    /// MPEG-H 3D Audio Baseline Profile, Level 3.
    case baselineProfileLevel3 = 0x12
    /// MPEG-H 3D Audio Baseline Profile, Level 4.
    case baselineProfileLevel4 = 0x13
    /// MPEG-H 3D Audio Baseline Profile, Level 5.
    case baselineProfileLevel5 = 0x14
}

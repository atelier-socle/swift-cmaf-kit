// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AV1 enums
//
// Reference: AOMedia AV1 ISO Media File Format Binding v1.2.0 §2.3.1 +
// AOMedia AV1 Bitstream Specification §6.4.

import Foundation

/// AV1 profile per AOMedia AV1 §6.4.
public enum AV1Profile: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Main: 4:2:0, 8 or 10 bit.
    case main = 0
    /// High: 4:4:4, 8 or 10 bit.
    case high = 1
    /// Professional: 4:2:0/4:2:2/4:4:4, 8/10/12 bit.
    case professional = 2
}

/// AV1 level per AOMedia AV1 §A.3. Rawvalues 0..23 encode levels 2.0
/// through 7.3; 24..30 are reserved; 31 represents the maximum level
/// per spec.
public enum AV1Level: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case level2_0 = 0
    case level2_1 = 1
    case level2_2 = 2
    case level2_3 = 3
    case level3_0 = 4
    case level3_1 = 5
    case level3_2 = 6
    case level3_3 = 7
    case level4_0 = 8
    case level4_1 = 9
    case level4_2 = 10
    case level4_3 = 11
    case level5_0 = 12
    case level5_1 = 13
    case level5_2 = 14
    case level5_3 = 15
    case level6_0 = 16
    case level6_1 = 17
    case level6_2 = 18
    case level6_3 = 19
    case level7_0 = 20
    case level7_1 = 21
    case level7_2 = 22
    case level7_3 = 23
    case maximum = 31
}

/// AV1 tier per AOMedia AV1 §A.3.
public enum AV1Tier: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case main = 0
    case high = 1
}

/// AV1 chroma sample position per AOMedia AV1 §6.4.
public enum AV1ChromaSamplePosition: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case unknown = 0
    case vertical = 1
    case colocated = 2
    case reserved = 3
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCProfileCompatibilityFlags
//
// Reference: ISO/IEC 23008-2 Annex A.3 (general_profile_compatibility_flag).
//
// 32-bit flag set indicating compatibility with each of the documented
// profile IDCs. Bit 31 (MSB-first) maps to profile IDC 0, bit 30 to
// profile IDC 1, and so on.

import Foundation

/// HEVC profile compatibility flags (32 bits).
///
/// Reference: ISO/IEC 23008-2 Annex A.3.
public struct HEVCProfileCompatibilityFlags: Sendable, Hashable, Equatable, Codable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// `true` iff the profile compatibility bit for the given
    /// `profileIDC` index is set. Index `0` checks the MSB.
    public func isCompatible(profileIDC index: Int) -> Bool {
        precondition(
            index >= 0 && index < 32,
            "HEVC profile compatibility bit index out of range"
        )
        return (rawValue & (UInt32(1) << UInt32(31 - index))) != 0
    }
}

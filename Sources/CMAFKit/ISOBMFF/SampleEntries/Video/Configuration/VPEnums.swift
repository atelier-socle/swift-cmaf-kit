// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - VP enums
//
// Reference: VP Codec ISO Media File Format Binding v1.0 §2.4.

import Foundation

/// VP profile per VP Codec ISO Media File Format Binding §2.4.
public enum VPProfile: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// 4:2:0, 8 bit.
    case profile0 = 0
    /// 4:2:2 or 4:4:4, 8 bit.
    case profile1 = 1
    /// 4:2:0, 10 or 12 bit.
    case profile2 = 2
    /// 4:2:2 or 4:4:4, 10 or 12 bit.
    case profile3 = 3
}

/// VP level per VP Codec ISO Media File Format Binding §2.4.
public enum VPLevel: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case level10 = 10
    case level11 = 11
    case level20 = 20
    case level21 = 21
    case level30 = 30
    case level31 = 31
    case level40 = 40
    case level41 = 41
    case level50 = 50
    case level51 = 51
    case level52 = 52
    case level60 = 60
    case level61 = 61
    case level62 = 62
}

/// VP chroma subsampling per VP Codec ISO Media File Format Binding §2.4.
public enum VPChromaSubsampling: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// 4:2:0 chroma horizontally co-sited with (0, 0) luma.
    case format420Vertical = 0
    /// 4:2:0 chroma co-sited with (0, 0) luma.
    case format420Colocated = 1
    /// 4:2:2.
    case format422 = 2
    /// 4:4:4.
    case format444 = 3
}

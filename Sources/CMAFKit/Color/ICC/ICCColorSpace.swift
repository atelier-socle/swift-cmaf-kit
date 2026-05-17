// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ICCColorSpace
//
// Reference: ICC.1:2022 §7.2.6 (data color space) + §7.2.7 (PCS).

import Foundation

/// ICC color-space signature per ICC.1:2022 §7.2.6.
///
/// The `nCLR` variants (2CLR..15CLR) represent n-component color
/// spaces (e.g., Hexachrome printer).
public enum ICCColorSpace: UInt32, Sendable, Hashable, CaseIterable, Codable {
    case xyz = 0x5859_5A20
    case lab = 0x4C61_6220
    case luv = 0x4C75_7620
    case yCbr = 0x5943_6272
    case yxy = 0x5978_7920
    case rgb = 0x5247_4220
    case gray = 0x4752_4159
    case hsv = 0x4853_5620
    case hls = 0x484C_5320
    case cmyk = 0x434D_594B
    case cmy = 0x434D_5920
    case nclr2 = 0x3243_4C52
    case nclr3 = 0x3343_4C52
    case nclr4 = 0x3443_4C52
    case nclr5 = 0x3543_4C52
    case nclr6 = 0x3643_4C52
    case nclr7 = 0x3743_4C52
    case nclr8 = 0x3843_4C52
    case nclr9 = 0x3943_4C52
    case nclrA = 0x4143_4C52
    case nclrB = 0x4243_4C52
    case nclrC = 0x4343_4C52
    case nclrD = 0x4443_4C52
    case nclrE = 0x4543_4C52
    case nclrF = 0x4643_4C52
}

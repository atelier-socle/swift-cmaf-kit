// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MatrixCoefficients
//
// Reference: ISO/IEC 23001-8 §7.3 Table 4 (Matrix Coefficients).

import Foundation

/// Coding-independent code point identifying the matrix coefficients
/// used to derive luma and chroma signals from RGB.
///
/// Reference: ISO/IEC 23001-8 §7.3 Table 4.
public enum MatrixCoefficients: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Identity (IEC 61966-2-1 sRGB / RGB no luma-chroma derivation).
    case identityRGB = 0
    /// Rec. ITU-R BT.709-6.
    case bt709 = 1
    /// Image characteristics are unknown.
    case unspecified = 2
    /// FCC Title 47 §73.682(a)(20) (US).
    case fcc = 4
    /// Rec. ITU-R BT.470-6 System B, G.
    case bt470BG = 5
    /// Rec. ITU-R BT.601-7 525 / 625.
    case bt601 = 6
    /// SMPTE 240M (1999).
    case smpte240M = 7
    /// YCgCo.
    case yCgCo = 8
    /// Rec. ITU-R BT.2020-2 non-constant luminance.
    case bt2020NCL = 9
    /// Rec. ITU-R BT.2020-2 constant luminance.
    case bt2020CL = 10
    /// SMPTE ST 2085 YDzDx.
    case smpteST2085 = 11
    /// Chromaticity-derived non-constant luminance.
    case chromaticityDerivedNCL = 12
    /// Chromaticity-derived constant luminance.
    case chromaticityDerivedCL = 13
    /// Rec. ITU-R BT.2100 ICtCp.
    case ictcp = 14
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TransferCharacteristics
//
// Reference: ISO/IEC 23001-8 §7.2 Table 3 (Transfer Characteristics).

import Foundation

/// Coding-independent code point identifying the opto-electronic and
/// electro-optical transfer characteristics of an image or video stream.
///
/// Reference: ISO/IEC 23001-8 §7.2 Table 3.
public enum TransferCharacteristics: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Rec. ITU-R BT.709-6 (HDTV gamma).
    case bt709 = 1
    /// Image characteristics are unknown.
    case unspecified = 2
    /// Assumed display gamma 2.2 (Rec. ITU-R BT.470-6 System M).
    case bt470M_gamma22 = 4
    /// Assumed display gamma 2.8 (Rec. ITU-R BT.470-6 System B, G).
    case bt470BG_gamma28 = 5
    /// Rec. ITU-R BT.601-7 525 / 625.
    case bt601 = 6
    /// SMPTE 240M (1999).
    case smpte240M = 7
    /// Linear transfer.
    case linear = 8
    /// Logarithmic transfer characteristic, 100:1 range.
    case log100to1 = 9
    /// Logarithmic transfer characteristic, 316.22777:1 range.
    case log316to1 = 10
    /// IEC 61966-2-4 xvYCC (extended-gamut YCC).
    case iec61966_2_4 = 11
    /// Rec. ITU-R BT.1361 extended-colour-gamut.
    case bt1361Extended = 12
    /// IEC 61966-2-1 sRGB / sYCC.
    case iec61966_2_1_sRGB = 13
    /// Rec. ITU-R BT.2020-2 10-bit.
    case bt2020_10bit = 14
    /// Rec. ITU-R BT.2020-2 12-bit.
    case bt2020_12bit = 15
    /// SMPTE ST 2084 PQ (Perceptual Quantizer) for HDR.
    case smpteST2084_PQ = 16
    /// SMPTE ST 428-1.
    case smpteST428_1 = 17
    /// ARIB STD-B67 HLG (Hybrid Log-Gamma) for HDR.
    case aribSTDB67_HLG = 18
}

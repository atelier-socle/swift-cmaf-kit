// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ColorPrimaries
//
// Reference: ISO/IEC 23001-8 §7.1 Table 2 (Colour Primaries).
//
// Enumerates every value defined by ISO/IEC 23001-8 for the colour-
// primaries field used by the `nclx` colour-information variant and
// by codec-specific VUI parameters (e.g. AVC, HEVC, AV1).

import Foundation

/// Coding-independent code point identifying the colour primaries used
/// by an image or video stream.
///
/// Reference: ISO/IEC 23001-8 §7.1 Table 2.
///
/// Values 0 and 3 are reserved by ISO; encountering them on the wire
/// causes a parse error. Values 13..21 and 23..255 are unassigned at
/// the time of this publication; future ISO additions will extend this
/// enum additively.
public enum ColorPrimaries: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Rec. ITU-R BT.709-6 (HDTV).
    case bt709 = 1
    /// Image characteristics are unknown or determined by the application.
    case unspecified = 2
    /// Rec. ITU-R BT.470-6 System M (NTSC 1953).
    case bt470M = 4
    /// Rec. ITU-R BT.470-6 System B, G (PAL/SECAM).
    case bt470BG = 5
    /// Rec. ITU-R BT.601-7 525 (NTSC).
    case bt601 = 6
    /// SMPTE 240M (1999, historical HDTV).
    case smpte240M = 7
    /// Generic film (colour filters using Illuminant C).
    case genericFilm = 8
    /// Rec. ITU-R BT.2020-2 (UHDTV).
    case bt2020 = 9
    /// SMPTE ST 428-1 (CIE 1931 XYZ as in ISO 11664-1).
    case smpte428 = 10
    /// SMPTE RP 431-2 (DCI P3, theatrical projection).
    case smpteRP431 = 11
    /// SMPTE EG 432-1 (P3-D65, consumer wide colour gamut).
    case smpteEG432_P3D65 = 12
    /// EBU Tech. 3213-E (historical European broadcasting).
    case ebu3213 = 22

    /// Colloquial alias for ``smpteEG432_P3D65`` (Display P3, P3-D65).
    public static let p3D65: ColorPrimaries = .smpteEG432_P3D65
}

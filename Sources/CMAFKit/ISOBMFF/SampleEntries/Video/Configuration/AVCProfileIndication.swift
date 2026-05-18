// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCProfileIndication
//
// Reference: ISO/IEC 14496-10 (AVC/H.264) Annex A + ISO/IEC 14496-15
// §5.3.3 (profile_indication in AVCDecoderConfigurationRecord).
//
// The set of AVC profile indication values currently standardised. An
// unrecognised value on the wire throws a parse error per the project-
// wide complete-coverage policy.

import Foundation

/// AVC profile indication carried by `AVCDecoderConfigurationRecord`.
///
/// Reference: ISO/IEC 14496-10 Annex A.
public enum AVCProfileIndication: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Baseline (CAVLC, I/P slices).
    case baseline = 66
    /// Main (CAVLC/CABAC, B slices, weighted prediction).
    case main = 77
    /// Extended (CAVLC, SP/SI slices, error resilience).
    case extended = 88
    /// High (CABAC, 8 bit, 4:2:0).
    case high = 100
    /// High 10 (10 bit, 4:2:0).
    case high10 = 110
    /// High 4:2:2 (10 bit, 4:2:2).
    case high422 = 122
    /// High 4:4:4 Predictive (14 bit, 4:4:4).
    case high444Predictive = 244
    /// CAVLC 4:4:4 Intra-only.
    case cavlc444Intra = 44
    /// Scalable Baseline (SVC).
    case scalableBaseline = 83
    /// Scalable High (SVC).
    case scalableHigh = 86
    /// Stereo High (MVC).
    case stereoHigh = 128
    /// Multiview High (MVC).
    case multiviewHigh = 118
    /// Multiview Depth High (3D-AVC).
    case multiviewDepthHigh = 138
    /// Enhanced Multiview Depth High (3D-AVC).
    case enhancedMultiviewDepthHigh = 139
    /// 3D Multiview High (3D-AVC).
    case threeDMultiviewHigh = 134
    /// 3D 4:4:4 Multiview High (3D-AVC).
    case threeD444MultiviewHigh = 135

    /// Whether the profile activates the high-profile conditional fields
    /// (`chroma_format`, `bit_depth_luma_minus8`, `bit_depth_chroma_minus8`,
    /// `numOfSequenceParameterSetExt`) in `AVCDecoderConfigurationRecord`.
    public static func requiresHighProfileFields(profileIDC: UInt8) -> Bool {
        // Per ISO/IEC 14496-15 §5.3.3.1.2.
        switch profileIDC {
        case 100, 110, 122, 144, 44, 83, 86, 118, 128, 138, 139, 134, 135:
            return true
        default:
            return false
        }
    }

    /// Whether this profile activates the high-profile conditional fields.
    public var requiresHighProfileFields: Bool {
        Self.requiresHighProfileFields(profileIDC: rawValue)
    }
}

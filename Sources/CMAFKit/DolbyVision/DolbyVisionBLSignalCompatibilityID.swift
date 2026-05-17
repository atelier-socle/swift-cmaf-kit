// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DolbyVisionBLSignalCompatibilityID
//
// Reference: Dolby Vision Streams Within the ISO Base Media File Format
// (Dolby public specification), section "Dolby Vision Configuration Box".
//
// The 4-bit `dv_bl_signal_compatibility_id` field describes how the
// Base Layer is cross-compatible with conventional HDR / SDR / HLG
// decoders for backward-compatible Dolby Vision profiles.

import Foundation

/// Base-layer signal cross-compatibility identifier carried in the
/// Dolby Vision configuration box.
///
/// Reference: Dolby Vision public specification — Dolby Vision Streams
/// Within the ISO Base Media File Format.
public enum DolbyVisionBLSignalCompatibilityID: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Base layer is non-backward-compatible (Dolby Vision only).
    case nonCompatible = 0
    /// Base layer is compatible with HDR10.
    case hdr10Compatible = 1
    /// Base layer is compatible with SDR (Rec. 709).
    case sdrCompatible = 2
    /// Reserved by Dolby (value 3).
    case reserved3 = 3
    /// Base layer is compatible with HLG.
    case hlgCompatible = 4
    /// Reserved by Dolby (value 5).
    case reserved5 = 5
    /// Reserved by Dolby (value 6).
    case reserved6 = 6
    /// Reserved by Dolby (value 7).
    case reserved7 = 7
    /// Reserved by Dolby (value 8).
    case reserved8 = 8
    /// Reserved by Dolby (value 9).
    case reserved9 = 9
    /// Reserved by Dolby (value 10).
    case reserved10 = 10
    /// Reserved by Dolby (value 11).
    case reserved11 = 11
    /// Reserved by Dolby (value 12).
    case reserved12 = 12
    /// Reserved by Dolby (value 13).
    case reserved13 = 13
    /// Reserved by Dolby (value 14).
    case reserved14 = 14
    /// Reserved by Dolby (value 15).
    case reserved15 = 15
}

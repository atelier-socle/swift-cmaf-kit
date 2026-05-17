// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DolbyVisionProfile
//
// Reference: Dolby Vision Streams Within the ISO Base Media File Format
// (Dolby public specification).
//
// Profiles 4, 5, 7, 8, 9, 10 are all defined. Profiles 8 and 10 have
// sub-profiles derived from the BL-signal cross-compatibility identifier.

import Foundation

/// Dolby Vision profile, fully typed including sub-profiles for the
/// backward-compatible profile families (8.x and 10.x).
///
/// Reference: Dolby Vision Streams Within the ISO Base Media File Format.
public enum DolbyVisionProfile: Sendable, Hashable, Equatable, Codable {
    /// dvhe.04 — dual-layer HEVC main 10, BL non-backward-compatible.
    case profile4
    /// dvhe.05 — single-layer HEVC main 10, RPU only, non-backward-compatible.
    case profile5
    /// dvhe.07 — dual-layer HEVC main 10, EL + RPU, BL non-backward-compatible
    /// (used in UHD Blu-ray).
    case profile7
    /// dvhe.08 / dvh1.08 — single-layer HEVC main 10, RPU only, BL
    /// backward-compatible. The associated sub-profile records which
    /// conventional pipeline (HDR10, SDR, HLG) the BL is compatible with.
    case profile8(subProfile: Profile8SubProfile)
    /// dvav.09 — single-layer AVC, RPU only, BL backward-compatible SDR.
    case profile9
    /// dav1.10 — single-layer AV1, RPU only. The associated sub-profile
    /// records BL cross-compatibility (none / HDR10 / SDR / HLG).
    case profile10(subProfile: Profile10SubProfile)

    /// Sub-profile for Dolby Vision profile 8.
    ///
    /// Reference: Dolby Vision public specification.
    public enum Profile8SubProfile: UInt8, Sendable, Hashable, CaseIterable, Codable {
        /// 8.1 — BL compatible with HDR10.
        case hdr10Compatible = 1
        /// 8.2 — BL compatible with SDR (Rec. 709).
        case sdrCompatible = 2
        /// 8.4 — BL compatible with HLG.
        case hlgCompatible = 4
    }

    /// Sub-profile for Dolby Vision profile 10.
    ///
    /// Reference: Dolby Vision public specification.
    public enum Profile10SubProfile: UInt8, Sendable, Hashable, CaseIterable, Codable {
        /// 10.0 — BL non-backward-compatible (Dolby Vision only).
        case nonCompatible = 0
        /// 10.1 — BL compatible with HDR10.
        case hdr10Compatible = 1
        /// 10.2 — BL compatible with SDR (Rec. 709).
        case sdrCompatible = 2
        /// 10.4 — BL compatible with HLG.
        case hlgCompatible = 4
    }

    /// The raw `dv_profile` byte as encoded on the wire.
    public var wireProfileNumber: UInt8 {
        switch self {
        case .profile4: return 4
        case .profile5: return 5
        case .profile7: return 7
        case .profile8: return 8
        case .profile9: return 9
        case .profile10: return 10
        }
    }

    /// Derive the typed profile from the raw wire fields.
    public static func make(
        wireProfileNumber: UInt8,
        compatibilityID: DolbyVisionBLSignalCompatibilityID
    ) throws -> DolbyVisionProfile {
        switch wireProfileNumber {
        case 4: return .profile4
        case 5: return .profile5
        case 7: return .profile7
        case 8:
            guard let sub = Profile8SubProfile(rawValue: compatibilityID.rawValue) else {
                throw ISOBoxError.malformedFullBox(
                    type: DolbyVisionConfigurationBox.boxType,
                    reason: "Dolby Vision profile 8 cross-compat \(compatibilityID.rawValue) is reserved"
                )
            }
            return .profile8(subProfile: sub)
        case 9: return .profile9
        case 10:
            guard let sub = Profile10SubProfile(rawValue: compatibilityID.rawValue) else {
                throw ISOBoxError.malformedFullBox(
                    type: DolbyVisionConfigurationBox.boxType,
                    reason: "Dolby Vision profile 10 cross-compat \(compatibilityID.rawValue) is reserved"
                )
            }
            return .profile10(subProfile: sub)
        default:
            throw ISOBoxError.malformedFullBox(
                type: DolbyVisionConfigurationBox.boxType,
                reason: "Unknown Dolby Vision profile number \(wireProfileNumber)"
            )
        }
    }
}

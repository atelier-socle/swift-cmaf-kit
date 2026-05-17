// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// =====================================================================
// MARK: - Color module — minimal stubs
// =====================================================================
// This file contains the subset of public types from the Color module that
// `HDRMetadata` references in the Media module. The complete Color module
// implementation lands in a later checkpoint and supersedes this file
// byte-for-byte — same case names, same raw values, same conformances.
//
// Contract for the future expansion:
//   1. Delete this entire file when the full module lands.
//   2. Place the production files under Sources/CMAFKit/Color/.
//   3. Preserve the raw values and case names defined here verbatim.
//   4. The continuity tests in `ColorPrimariesStubGuardTests` must keep
//      passing without modification — that is the contract this stub
//      enforces.
// =====================================================================

import Foundation

/// Colour primaries per ISO/IEC 23001-8 §7.
///
/// **STUB**: only `bt709` and `smpteEG432_P3D65` are defined in Session 1.
/// Full enum lands in Session 5 with all CICP code points.
public enum ColorPrimaries: UInt8, Sendable, Hashable {
    case bt709 = 1
    case smpteEG432_P3D65 = 12  // ISO/IEC 23001-8 §7 code point 12 — SMPTE EG 432-1 / Display P3.

    /// Colloquial alias for `.smpteEG432_P3D65` (Display P3, P3-D65).
    public static let p3D65: ColorPrimaries = .smpteEG432_P3D65
}

/// Transfer characteristics per ISO/IEC 23001-8 §7.
///
/// **STUB**: only `bt709` in Session 1. Full enum in Session 5.
public enum TransferCharacteristics: UInt8, Sendable, Hashable {
    case bt709 = 1
}

/// Matrix coefficients per ISO/IEC 23001-8 §7.
///
/// **STUB**: only `bt709` in Session 1. Full enum in Session 5.
public enum MatrixCoefficients: UInt8, Sendable, Hashable {
    case bt709 = 1
}

/// HDR10 mastering display metadata per SMPTE ST 2086.
///
/// **STUB**: empty struct in Session 1. Session 5 fills in all fields.
public struct MasteringDisplayMetadata: Sendable, Hashable, Equatable {
    public init() {}
}

/// Content light level metadata per CTA-861.3.
///
/// **STUB**: empty struct in Session 1. Session 5 fills in `maxCLL`, `maxFALL`.
public struct ContentLightLevelMetadata: Sendable, Hashable, Equatable {
    public init() {}
}

/// Dolby Vision profile per the public Dolby Vision specification.
///
/// The enum is intentionally flat: profile-8 sub-flavors ("8.1", "8.4") are
/// not separate top-level profile values. Per the Dolby Vision spec,
/// sub-flavors are decoded from the combination of the `dv_profile` field
/// (this enum) and the `dv_bl_signal_compatibility_id` field (surfaced as
/// ``DolbyVisionMetadata/dvBLSignalCompatibilityID``). This avoids
/// combinatorial-explosion in the enum and aligns the type with the
/// on-wire representation. This is the canonical, final form preserved by
/// the full Color module when it supersedes this stub.
public enum DolbyVisionProfile: UInt8, Sendable, Hashable, CaseIterable {
    case profile5 = 5
    case profile7 = 7
    case profile8 = 8
    case profile10 = 10
}

/// Dolby Vision metadata, `dvcC` / `dvvC` payload structure.
///
/// The `dvBLSignalCompatibilityID` field carries the sub-flavor information
/// that distinguishes profile-8 variants ("8.1", "8.2", "8.4", …). Combined
/// with ``DolbyVisionProfile``, it covers every Dolby Vision profile
/// surfaced by the public specification.
public struct DolbyVisionMetadata: Sendable, Hashable, Equatable {
    public let profile: DolbyVisionProfile
    public let level: UInt8
    public let rpuPresent: Bool
    public let elPresent: Bool
    public let blPresent: Bool
    public let dvBLSignalCompatibilityID: UInt8

    public init(
        profile: DolbyVisionProfile,
        level: UInt8,
        rpuPresent: Bool,
        elPresent: Bool,
        blPresent: Bool,
        dvBLSignalCompatibilityID: UInt8
    ) {
        self.profile = profile
        self.level = level
        self.rpuPresent = rpuPresent
        self.elPresent = elPresent
        self.blPresent = blPresent
        self.dvBLSignalCompatibilityID = dvBLSignalCompatibilityID
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// =====================================================================
// MARK: - SESSION 1 STUBS — TO BE DELETED IN SESSION 5
// =====================================================================
// This file contains stub types used by HDRMetadata (Module 2, Session 1).
// They will be SUPERSEDED, not migrated, in Session 5 when the full Color
// module is implemented per addendum F.5 / F.6.
//
// Session 5 contract:
//   1. Delete this entire file.
//   2. Create the proper files under Sources/CMAFKit/Color/.
//   3. The rawValues and case names defined below MUST be preserved
//      verbatim — Session 5 is a byte-compatible replacement.
//   4. Existing tests (ColorPrimariesStubGuardTests, etc.) MUST keep
//      passing without modification — that is the stub contract.
// =====================================================================

import Foundation

/// Colour primaries per ISO/IEC 23001-8 §7.
///
/// **STUB**: only `bt709` and `smpteEG432_P3D65` are defined in Session 1.
/// Full enum lands in Session 5 with all CICP code points.
public enum ColorPrimaries: UInt8, Sendable, Hashable {
    case bt709 = 1
    case smpteEG432_P3D65 = 12  // Per addendum F.5 — SMPTE EG 432-1 / Display P3.

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

/// Dolby Vision profile per public Dolby Vision documentation.
///
/// Per addendum F.6, the enum is flat: profile sub-flavors ("8.1", "8.4")
/// are surfaced via `DolbyVisionMetadata.dvBLSignalCompatibilityID`, not
/// as separate enum cases. This is the canonical, final form — Session 5
/// preserves it byte-for-byte.
public enum DolbyVisionProfile: UInt8, Sendable, Hashable, CaseIterable {
    case profile5 = 5
    case profile7 = 7
    case profile8 = 8
    case profile10 = 10
}

/// Dolby Vision metadata, dvcC / dvvC payload structure.
///
/// Per addendum F.6, `dvBLSignalCompatibilityID` carries the sub-flavor
/// information that distinguishes profile-8 variants (8.1, 8.2, 8.4, …).
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

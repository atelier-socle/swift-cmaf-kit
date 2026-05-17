// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// =====================================================================
// MARK: - Color stub continuity contract
// =====================================================================
// These tests assert that the Session-1 stubs in
// Sources/CMAFKit/Color/_ModulePlaceholder.swift expose the EXACT same
// public surface that the full Session-5 implementation will expose
// (for the subset of types defined in Session 1).
//
// **Contract**: these tests MUST continue to pass after Session 5
// replaces the stub file with the full Color module. Failing to keep
// them green is a regression on the API surface.
// =====================================================================

import Foundation
import Testing

@testable import CMAFKit

@Suite("Color stub continuity (Session 1 ↔ Session 5)")
struct ColorPrimariesStubGuardTests {

    @Test
    func bt709RawValueIsOne() {
        #expect(ColorPrimaries.bt709.rawValue == 1)
    }

    @Test
    func smpteEG432P3D65RawValueIs12() {
        // Per addendum F.5 — ISO/IEC 23001-8 §7 code point 12.
        #expect(ColorPrimaries.smpteEG432_P3D65.rawValue == 12)
    }

    @Test
    func p3D65IsAliasForSmpteEG432() {
        #expect(ColorPrimaries.p3D65 == .smpteEG432_P3D65)
    }

    @Test
    func colorPrimariesFromRawValue12() {
        #expect(ColorPrimaries(rawValue: 12) == .smpteEG432_P3D65)
    }

    @Test
    func dolbyVisionProfilesFlatEnum() {
        // Per addendum F.6 — flat enum, sub-flavors via dvBLSignalCompatibilityID.
        #expect(DolbyVisionProfile(rawValue: 5) == .profile5)
        #expect(DolbyVisionProfile(rawValue: 7) == .profile7)
        #expect(DolbyVisionProfile(rawValue: 8) == .profile8)
        #expect(DolbyVisionProfile(rawValue: 10) == .profile10)
    }

    @Test
    func dolbyVisionMetadataPreservesSubFlavorID() {
        let meta = DolbyVisionMetadata(
            profile: .profile8,
            level: 9,
            rpuPresent: true,
            elPresent: false,
            blPresent: true,
            dvBLSignalCompatibilityID: 1  // Profile 8.1 (HDR10-compatible)
        )
        #expect(meta.profile == .profile8)
        #expect(meta.dvBLSignalCompatibilityID == 1)
    }
}

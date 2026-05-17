// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// =====================================================================
// MARK: - ColorPrimaries / DolbyVision public-surface continuity
// =====================================================================
// These tests assert that the raw values and case names that earlier
// versions of CMAFKit exposed for the partial Color API are preserved
// by the full implementation. Future ISO additions extend the
// `ColorPrimaries` enum additively; raw values for existing cases must
// never change.
// =====================================================================

import Foundation
import Testing

@testable import CMAFKit

@Suite("Color stub continuity")
struct ColorPrimariesStubGuardTests {

    @Test
    func bt709RawValueIsOne() {
        #expect(ColorPrimaries.bt709.rawValue == 1)
    }

    @Test
    func smpteEG432P3D65RawValueIs12() {
        // ISO/IEC 23001-8 §7 code point 12 — SMPTE EG 432-1 / Display P3.
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
    func dolbyVisionProfileCasesPresent() {
        // The case names .profile5, .profile7, .profile8, .profile10
        // are preserved. Profiles 8 and 10 now carry typed sub-profile
        // associated values per the public Dolby Vision specification;
        // profiles 5 and 7 remain unparameterised.
        let p5: DolbyVisionProfile = .profile5
        let p7: DolbyVisionProfile = .profile7
        let p8: DolbyVisionProfile = .profile8(subProfile: .hdr10Compatible)
        let p10: DolbyVisionProfile = .profile10(subProfile: .nonCompatible)
        #expect(p5.wireProfileNumber == 5)
        #expect(p7.wireProfileNumber == 7)
        #expect(p8.wireProfileNumber == 8)
        #expect(p10.wireProfileNumber == 10)
    }

    @Test
    func dolbyVisionConfigurationCarriesProfileAndCompatibilityID() {
        let config = DolbyVisionConfiguration(
            versionMajor: 1,
            versionMinor: 0,
            profile: .profile8(subProfile: .hdr10Compatible),
            level: .level09,
            rpuPresent: true,
            elPresent: false,
            blPresent: true,
            blSignalCompatibilityID: .hdr10Compatible
        )
        #expect(config.profile.wireProfileNumber == 8)
        #expect(config.blSignalCompatibilityID == .hdr10Compatible)
    }
}

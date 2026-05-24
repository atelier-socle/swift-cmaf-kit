// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFConformanceValidator — ISO + CENC composition accessors
//
// Additive surface exposing the two orthogonal validators
// (`ISOConformanceValidator`, `CENCConformanceValidator`) so that
// callers (HLSKit / DASHKit / CMAFKitDRM) can compose ISO-layer or
// CENC-layer validation independently of the CMAF profile rules.
//
// These accessors are **purely additive** — the existing
// `validate(initSegment:mediaSegments:)` entry point and its
// observable behaviour are unchanged.

import Foundation

extension CMAFConformanceValidator {

    /// A generic ISO BMFF conformance validator suitable for the
    /// `[any ISOBox]` representation of a file. Use this when you have
    /// raw root boxes (HLS init segment, MOV capture) rather than a
    /// parsed CMAF `initSegment` / `mediaSegments` pair.
    ///
    /// References: ISO/IEC 14496-12 §4-§8 — see
    /// ``ISOConformanceValidator``.
    public var isoValidator: ISOConformanceValidator {
        ISOConformanceValidator(level: .strict)
    }

    /// A generic Common Encryption conformance validator suitable for
    /// the `[any ISOBox]` representation of a file. Use this when you
    /// need standalone CENC validation (CMAFKitDRM tests, DRM provider
    /// verification) without the CMAF profile overhead.
    ///
    /// References: ISO/IEC 23001-7 §4 — see ``CENCConformanceValidator``.
    public var cencValidator: CENCConformanceValidator {
        CENCConformanceValidator(level: .strict)
    }
}

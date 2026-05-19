// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCNALUnitType helpers
//
// Reference: ITU-T H.265 §7.4.2.2 + Table 7-1.

import Foundation

extension HEVCNALUnitType {
    /// True iff this unit carries Video Coding Layer (VCL) data. Per
    /// ITU-T H.265 Table 7-1 the VCL units occupy raw values 0…31.
    public var isVCL: Bool { rawValue < 32 }

    /// True iff this unit is an Intra Random Access Point (IRAP)
    /// picture: BLA / IDR / CRA, plus the two reserved IRAP slots
    /// (raw values 22, 23). IRAP units have raw values in `16...23`.
    public var isIRAP: Bool { (16...23).contains(rawValue) }

    /// True iff this unit is a Video / Sequence / Picture Parameter
    /// Set (raw values 32, 33, 34).
    public var isParameterSet: Bool {
        self == .vpsNUT || self == .spsNUT || self == .ppsNUT
    }

    /// True iff this unit is one of the SEI types (prefix or suffix).
    public var isSEI: Bool {
        self == .prefixSEINUT || self == .suffixSEINUT
    }

    /// True iff this unit is in the spec's "unspecified" range
    /// (raw values 48…63). Carriers/transports may use these for
    /// signalling that lives outside the decoder.
    public var isUnspecified: Bool { rawValue >= 48 }
}

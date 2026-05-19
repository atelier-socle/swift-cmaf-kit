// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCNALUnitType helpers
//
// Reference: ITU-T H.264 §7.4.1 + Table 7-1.
//
// Computed-property helpers grouping NAL unit types by role
// (VCL, IDR, parameter-set, SEI). The base enum is declared by
// Module 6 (`Sources/CMAFKit/ISOBMFF/SampleEntries/Video/Configuration/AVCNALUnitType.swift`)
// and remains the single source of truth for the rawValue mapping.

import Foundation

extension AVCNALUnitType {
    /// True iff this unit carries Video Coding Layer (VCL) data per
    /// ITU-T H.264 §7.4.1. VCL units include non-IDR slices, IDR
    /// slices, and the data partitions A/B/C.
    public var isVCL: Bool {
        switch self {
        case .codedSliceNonIDR, .codedSliceDataPartitionA,
            .codedSliceDataPartitionB, .codedSliceDataPartitionC,
            .codedSliceIDR, .auxiliaryCodedPictureSlice,
            .codedSliceExtension, .codedSliceDepthExtension:
            return true
        default:
            return false
        }
    }

    /// True iff this unit is the start of an Instantaneous Decoder
    /// Refresh (IDR) access unit.
    public var isIDR: Bool { self == .codedSliceIDR }

    /// True iff this unit carries a Sequence or Picture Parameter Set,
    /// or one of their SVC/MVC/depth extension variants.
    public var isParameterSet: Bool {
        switch self {
        case .sequenceParameterSet, .pictureParameterSet,
            .sequenceParameterSetExtension, .subsetSequenceParameterSet,
            .depthParameterSet:
            return true
        default:
            return false
        }
    }

    /// True iff this unit is reserved for future use per the standard.
    public var isReserved: Bool {
        switch self {
        case .reserved17, .reserved18, .reserved22, .reserved23:
            return true
        default:
            return false
        }
    }

    /// True iff this unit's raw value is in the spec-reserved
    /// "unspecified" range (0, 24..31). These are typically used by
    /// transports and are not produced by encoders.
    public var isUnspecified: Bool {
        switch self {
        case .unspecified0,
            .unspecified24, .unspecified25, .unspecified26, .unspecified27,
            .unspecified28, .unspecified29, .unspecified30, .unspecified31:
            return true
        default:
            return false
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCNALUnitHeader
//
// Reference: ITU-T H.265 §7.3.1.2 / §7.4.2.2.
//
// Two-byte big-endian header:
//   bit 15      : forbidden_zero_bit (must be 0)
//   bits 14..9  : nal_unit_type (6 bits)
//   bits 8..3   : nuh_layer_id (6 bits)
//   bits 2..0   : nuh_temporal_id_plus1 (3 bits; the on-wire value is
//                 temporal_id + 1, so 0 is invalid)

import Foundation

/// HEVC NAL unit header per ITU-T H.265 §7.3.1.2.
public struct HEVCNALUnitHeader: Sendable, Hashable, Equatable, Codable {
    /// Forbidden-zero bit. Must be `false` in conforming streams.
    public let forbiddenZeroBit: Bool
    /// 6-bit NAL unit type code.
    public let nalUnitType: HEVCNALUnitType
    /// 6-bit layer ID for multi-layer extensions (L-HEVC, 3D-HEVC). 0 in
    /// single-layer streams.
    public let layerID: UInt8
    /// 3-bit temporal ID (after subtracting the +1 wire offset). Range
    /// `0...6`.
    public let temporalID: UInt8

    public init(
        forbiddenZeroBit: Bool = false,
        nalUnitType: HEVCNALUnitType,
        layerID: UInt8 = 0,
        temporalID: UInt8 = 0
    ) {
        precondition(layerID <= 0x3F, "HEVCNALUnitHeader.layerID must fit 6 bits")
        precondition(temporalID <= 6, "HEVCNALUnitHeader.temporalID must be 0...6")
        self.forbiddenZeroBit = forbiddenZeroBit
        self.nalUnitType = nalUnitType
        self.layerID = layerID
        self.temporalID = temporalID
    }

    /// True iff this unit participates as a reference for higher
    /// temporal sub-layers. Per ITU-T H.265 §7.4.2.2 Table 7-1, the
    /// "_N" suffix marks non-reference units. Reserved VCL units at
    /// raw indices 10, 12, 14 are non-reference; 11, 13, 15 are
    /// reference (by their N/R position in the table).
    public var isReference: Bool {
        switch nalUnitType {
        case .trailN, .tsaN, .stsaN, .radlN, .raslN,
            .rsvVclN10, .rsvVclN12, .rsvVclN14:
            return false
        default:
            return true
        }
    }

    public static func parse(bytes: (UInt8, UInt8)) throws -> HEVCNALUnitHeader {
        let raw = (UInt16(bytes.0) << 8) | UInt16(bytes.1)
        let forbidden = (raw & 0x8000) != 0
        let typeRaw = UInt8((raw >> 9) & 0x3F)
        let layerID = UInt8((raw >> 3) & 0x3F)
        let tidPlus1 = UInt8(raw & 0x07)
        guard let nalUnitType = HEVCNALUnitType(rawValue: typeRaw) else {
            throw BitstreamError.unknownNALUnitType(codec: "HEVC", rawValue: typeRaw)
        }
        guard tidPlus1 >= 1 else {
            throw BitstreamError.reservedBitsNonZero(
                codec: "HEVC", field: "nuh_temporal_id_plus1"
            )
        }
        return HEVCNALUnitHeader(
            forbiddenZeroBit: forbidden,
            nalUnitType: nalUnitType,
            layerID: layerID,
            temporalID: tidPlus1 - 1
        )
    }

    public func encode() -> (UInt8, UInt8) {
        var raw: UInt16 = 0
        if forbiddenZeroBit { raw |= 0x8000 }
        raw |= (UInt16(nalUnitType.rawValue) & 0x3F) << 9
        raw |= (UInt16(layerID) & 0x3F) << 3
        raw |= UInt16(temporalID + 1) & 0x07
        return (UInt8(raw >> 8), UInt8(raw & 0xFF))
    }
}

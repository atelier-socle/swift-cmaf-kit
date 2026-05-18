// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCParameterSet / HEVCParameterSetArray
//
// Reference: ISO/IEC 14496-15 §8.3.3 + ISO/IEC 23008-2 §7.3.1.
//
// HEVC NAL unit header layout (16 bits, big-endian):
//   bit 15:        forbidden_zero_bit (must be 0)
//   bits 14..9:    nal_unit_type (6 bits)
//   bits 8..3:     nuh_layer_id (6 bits)
//   bits 2..0:     nuh_temporal_id_plus1 (3 bits; reported value is minus 1)

import Foundation

/// One HEVC parameter-set NAL unit.
public struct HEVCParameterSet: Sendable, Equatable, Hashable {
    /// Full NAL unit bytes (2-byte header + RBSP).
    public let rbspBytes: Data

    public init(rbspBytes: Data) {
        precondition(
            rbspBytes.count >= 2,
            "HEVCParameterSet rbspBytes must contain the 2-byte NAL header"
        )
        self.rbspBytes = rbspBytes
    }

    /// `nal_unit_type` decoded from the first byte. `nil` if the value
    /// is outside the documented range.
    public var nalUnitType: HEVCNALUnitType? {
        guard let first = rbspBytes.first else { return nil }
        let typeBits = (first >> 1) & 0x3F
        return HEVCNALUnitType(rawValue: typeBits)
    }

    /// `nuh_layer_id` decoded from bits 8..3 of the NAL header.
    public var layerID: UInt8 {
        guard rbspBytes.count >= 2 else { return 0 }
        let baseIndex = rbspBytes.startIndex
        let b0 = rbspBytes[baseIndex]
        let b1 = rbspBytes[baseIndex.advanced(by: 1)]
        // Layer ID: bit 0 of b0 (= bit 8 of header) shifted to position 5,
        // bits 7..3 of b1 give the remaining 5 bits.
        let high = (b0 & 0x01) << 5
        let low = (b1 >> 3) & 0x1F
        return high | low
    }

    /// `nuh_temporal_id_plus1 - 1` decoded from the low 3 bits of byte 1.
    public var temporalID: UInt8 {
        guard rbspBytes.count >= 2 else { return 0 }
        let b1 = rbspBytes[rbspBytes.startIndex.advanced(by: 1)]
        let plusOne = b1 & 0x07
        return plusOne > 0 ? plusOne - 1 : 0
    }
}

/// One NAL-unit-type-grouped array of parameter sets within `hvcC`.
public struct HEVCParameterSetArray: Sendable, Equatable, Hashable {
    /// `true` if every parameter set of this NAL unit type for the stream
    /// is present in this array.
    public let arrayCompleteness: Bool
    /// The NAL unit type all entries in this array share.
    public let nalUnitType: HEVCNALUnitType
    public let parameterSets: [HEVCParameterSet]

    public init(
        arrayCompleteness: Bool,
        nalUnitType: HEVCNALUnitType,
        parameterSets: [HEVCParameterSet]
    ) {
        self.arrayCompleteness = arrayCompleteness
        self.nalUnitType = nalUnitType
        self.parameterSets = parameterSets
    }
}

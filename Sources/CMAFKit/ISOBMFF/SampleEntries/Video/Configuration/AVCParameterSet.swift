// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCParameterSet
//
// Reference: ISO/IEC 14496-15 §5.3.3 + ISO/IEC 14496-10 §7.3.1.
//
// A parameter-set NAL unit carried by `AVCDecoderConfigurationRecord`.
// The first byte of the NAL unit carries:
//   - bit 7: forbidden_zero_bit (must be 0)
//   - bits 6..5: nal_ref_idc
//   - bits 4..0: nal_unit_type

import Foundation

/// One AVC parameter-set NAL unit (SPS, PPS, or SPS extension).
public struct AVCParameterSet: Sendable, Equatable, Hashable {
    /// Full NAL unit bytes (header byte + RBSP).
    public let rbspBytes: Data

    public init(rbspBytes: Data) {
        precondition(
            !rbspBytes.isEmpty,
            "AVCParameterSet rbspBytes must not be empty"
        )
        self.rbspBytes = rbspBytes
    }

    /// `nal_unit_type` decoded from the first byte. Returns `nil` if the
    /// value is outside the documented range (the raw byte is preserved
    /// in ``rbspBytes`` regardless).
    public var nalUnitType: AVCNALUnitType? {
        guard let first = rbspBytes.first else { return nil }
        let typeBits = first & 0x1F
        return AVCNALUnitType(rawValue: typeBits)
    }

    /// `nal_ref_idc` decoded from bits 6..5 of the first byte.
    public var nalRefIdc: UInt8 {
        guard let first = rbspBytes.first else { return 0 }
        return (first >> 5) & 0x03
    }
}

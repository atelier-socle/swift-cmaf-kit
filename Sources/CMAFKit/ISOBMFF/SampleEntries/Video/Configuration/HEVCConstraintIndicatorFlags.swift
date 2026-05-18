// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCConstraintIndicatorFlags
//
// Reference: ISO/IEC 23008-2 Annex A.3 + ISO/IEC 14496-15 §8.3.3.1.2.
//
// 48-bit field carrying named constraint flags (4 documented) plus 44
// reserved/extended bits preserved verbatim for byte-perfect round-trip.

import Foundation

/// HEVC constraint indicator flags carried by
/// `HEVCDecoderConfigurationRecord`.
///
/// Reference: ISO/IEC 23008-2 Annex A.3.
public struct HEVCConstraintIndicatorFlags: Sendable, Hashable, Equatable, Codable {
    public let progressiveSourceFlag: Bool
    public let interlacedSourceFlag: Bool
    public let nonPackedConstraintFlag: Bool
    public let frameOnlyConstraintFlag: Bool
    /// The remaining 44 bits of the 48-bit field, preserved verbatim.
    /// Masked to the low 44 bits.
    public let extendedConstraintBits: UInt64

    public init(
        progressiveSourceFlag: Bool,
        interlacedSourceFlag: Bool,
        nonPackedConstraintFlag: Bool,
        frameOnlyConstraintFlag: Bool,
        extendedConstraintBits: UInt64 = 0
    ) {
        precondition(
            extendedConstraintBits <= 0x0FFF_FFFF_FFFF,
            "HEVCConstraintIndicatorFlags.extendedConstraintBits must fit in 44 bits"
        )
        self.progressiveSourceFlag = progressiveSourceFlag
        self.interlacedSourceFlag = interlacedSourceFlag
        self.nonPackedConstraintFlag = nonPackedConstraintFlag
        self.frameOnlyConstraintFlag = frameOnlyConstraintFlag
        self.extendedConstraintBits = extendedConstraintBits
    }

    /// Construct from the 48-bit raw value parsed from 6 big-endian
    /// bytes (stored in the low 48 bits of a `UInt64`).
    public init(rawValueBigEndian: UInt64) {
        let mask48: UInt64 = 0x0000_FFFF_FFFF_FFFF
        let masked = rawValueBigEndian & mask48
        self.progressiveSourceFlag = (masked & (UInt64(1) << 47)) != 0
        self.interlacedSourceFlag = (masked & (UInt64(1) << 46)) != 0
        self.nonPackedConstraintFlag = (masked & (UInt64(1) << 45)) != 0
        self.frameOnlyConstraintFlag = (masked & (UInt64(1) << 44)) != 0
        self.extendedConstraintBits = masked & 0x0FFF_FFFF_FFFF
    }

    /// The 48-bit value packed into the low bits of a `UInt64`,
    /// suitable for big-endian wire emission.
    public var rawValueBigEndian: UInt64 {
        var value: UInt64 = 0
        if progressiveSourceFlag { value |= (UInt64(1) << 47) }
        if interlacedSourceFlag { value |= (UInt64(1) << 46) }
        if nonPackedConstraintFlag { value |= (UInt64(1) << 45) }
        if frameOnlyConstraintFlag { value |= (UInt64(1) << 44) }
        value |= extendedConstraintBits & 0x0FFF_FFFF_FFFF
        return value
    }
}

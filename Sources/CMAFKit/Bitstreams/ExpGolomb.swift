// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ExpGolomb
//
// Exp-Golomb codes per ITU-T H.264 §9.1 (identical for HEVC per
// ITU-T H.265 §9.2). The decoder/encoder live on ``BitReader`` and
// ``BitWriter`` directly; this namespace exposes the closed-form
// mapping helpers used by tests and by callers that need to compute
// codeword sizes without I/O.

import Foundation

/// Closed-form helpers for Exp-Golomb codes.
public enum ExpGolomb {

    /// Number of bits required to encode an unsigned value as
    /// Exp-Golomb. Useful for size estimation prior to actual encoding.
    public static func bitCount(unsigned value: UInt32) -> Int {
        let codeNum = UInt64(value) + 1
        let bitWidth = 64 - codeNum.leadingZeroBitCount
        return 2 * bitWidth - 1
    }

    /// Map a signed value to its unsigned Exp-Golomb code number per
    /// the `me(v)` mapping. Provided as a pure function for testing
    /// independently of I/O.
    public static func mapSignedToUnsigned(_ value: Int32) -> UInt32 {
        let value64 = Int64(value)
        let unsigned64: UInt64
        if value64 <= 0 {
            unsigned64 = UInt64(-value64 * 2)
        } else {
            unsigned64 = UInt64(value64 * 2 - 1)
        }
        return unsigned64 > UInt64(UInt32.max)
            ? UInt32.max
            : UInt32(unsigned64)
    }

    /// Inverse of ``mapSignedToUnsigned(_:)``.
    public static func mapUnsignedToSigned(_ value: UInt32) -> Int32 {
        if value == 0 { return 0 }
        if value & 1 == 1 {
            return Int32((value + 1) / 2)
        } else {
            return -Int32(value / 2)
        }
    }
}

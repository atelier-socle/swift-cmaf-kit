// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - NALRBSPDecoder
//
// Emulation-prevention byte stripping / insertion for AVC + HEVC NAL
// units.
//
// Reference: ITU-T H.264 §7.4.1.1 (and ITU-T H.265 §7.4.2.1).
//
// Within an EBSP (Encapsulated Byte Sequence Payload), the encoder
// inserts a `0x03` byte after every `0x00 0x00` sequence whose next
// byte would otherwise be `0x00`, `0x01`, `0x02` or `0x03`. The
// decoder strips those `0x03` bytes to recover the RBSP.

import Foundation

/// Emulation-prevention byte handling for AVC + HEVC NAL units.
public enum NALRBSPDecoder {

    /// Strip emulation-prevention bytes from an EBSP to recover the
    /// underlying RBSP.
    ///
    /// Replaces every `0x00 0x00 0x03 XX` sequence (with `XX` in the
    /// set `{0x00, 0x01, 0x02, 0x03}`) with `0x00 0x00 XX`. The `0x03`
    /// byte is the emulation-prevention three byte; the standard
    /// guarantees it is the only place a literal `0x03` follows two
    /// zero bytes in an EBSP.
    public static func ebspToRBSP(_ ebsp: Data) -> Data {
        var rbsp = Data()
        rbsp.reserveCapacity(ebsp.count)
        var consecutiveZeros = 0
        for byte in ebsp {
            if consecutiveZeros >= 2, byte == 0x03 {
                // Skip the emulation-prevention byte; the next byte is
                // the actual payload byte that triggered the escape.
                consecutiveZeros = 0
                continue
            }
            rbsp.append(byte)
            consecutiveZeros = byte == 0x00 ? consecutiveZeros + 1 : 0
        }
        return rbsp
    }

    /// Insert emulation-prevention bytes into an RBSP to produce an
    /// EBSP suitable for transport in a NAL unit.
    public static func rbspToEBSP(_ rbsp: Data) -> Data {
        var ebsp = Data()
        ebsp.reserveCapacity(rbsp.count + rbsp.count / 64)  // small heuristic
        var consecutiveZeros = 0
        for byte in rbsp {
            if consecutiveZeros >= 2, byte <= 0x03 {
                ebsp.append(0x03)
                consecutiveZeros = 0
            }
            ebsp.append(byte)
            consecutiveZeros = byte == 0x00 ? consecutiveZeros + 1 : 0
        }
        return ebsp
    }
}

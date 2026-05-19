// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BitReader
//
// MSB-first bit-level reader. The MSB-first convention matches every
// codec bitstream this kit parses: AVC and HEVC bitstreams per
// ITU-T H.264/H.265, AV1 per AOMedia AV1 Bitstream §4, and AAC per
// ISO/IEC 14496-3 §1.6.

import Foundation

/// MSB-first bit-level reader over an immutable byte buffer.
///
/// Reads consume bits left-to-right within each byte (most significant
/// bit first). The reader exposes both single-bit and multi-bit reads,
/// plus codec-specific helpers (`readUnsignedExpGolomb`,
/// `readSignedExpGolomb`) used by the AVC and HEVC parsers.
public struct BitReader: Sendable {
    private let bytes: Data
    /// Current byte cursor, in bytes from the start of `bytes`.
    public private(set) var byteOffset: Int = 0
    /// Current bit cursor within the byte at `byteOffset`, in the range
    /// `0...7` where 0 is the most-significant bit (next-to-read).
    public private(set) var bitOffset: Int = 0

    public init(_ bytes: Data) {
        self.bytes = bytes
    }

    /// Bits remaining from the current cursor to the end of the buffer.
    public var bitsRemaining: Int {
        max(0, (bytes.count - byteOffset) * 8 - bitOffset)
    }

    /// True iff the cursor is byte-aligned (i.e., `bitOffset == 0`).
    public var isByteAligned: Bool {
        bitOffset == 0
    }

    /// Read a single bit. Returns 0 or 1.
    public mutating func readBit() throws -> UInt8 {
        guard bitsRemaining >= 1 else {
            throw BitstreamError.truncated(codec: "BitReader", field: "bit")
        }
        let byte = bytes[bytes.startIndex + byteOffset]
        let bit = (byte >> (7 - UInt8(bitOffset))) & 0x01
        bitOffset += 1
        if bitOffset == 8 {
            bitOffset = 0
            byteOffset += 1
        }
        return bit
    }

    /// Read `n` bits (0 < n <= 64) as an MSB-first unsigned value.
    public mutating func readBits(_ count: Int) throws -> UInt64 {
        precondition((0...64).contains(count), "BitReader.readBits: 0 <= count <= 64")
        if count == 0 { return 0 }
        guard bitsRemaining >= count else {
            throw BitstreamError.truncated(codec: "BitReader", field: "bits(\(count))")
        }
        var value: UInt64 = 0
        var remaining = count
        while remaining > 0 {
            let byte = UInt64(bytes[bytes.startIndex + byteOffset])
            let bitsInThisByte = 8 - bitOffset
            let take = min(remaining, bitsInThisByte)
            let shift = bitsInThisByte - take
            let mask = (UInt64(1) << take) - 1
            value = (value << take) | ((byte >> shift) & mask)
            bitOffset += take
            if bitOffset == 8 {
                bitOffset = 0
                byteOffset += 1
            }
            remaining -= take
        }
        return value
    }

    /// Peek `n` bits without advancing the cursor.
    public func peekBits(_ count: Int) throws -> UInt64 {
        var copy = self
        return try copy.readBits(count)
    }

    /// Read a single bit as a `Bool` (1 → true, 0 → false).
    public mutating func readBool() throws -> Bool {
        try readBit() != 0
    }

    /// Skip `n` bits without producing a value.
    public mutating func skipBits(_ count: Int) throws {
        guard bitsRemaining >= count else {
            throw BitstreamError.truncated(codec: "BitReader", field: "skip(\(count))")
        }
        let total = bitOffset + count
        byteOffset += total / 8
        bitOffset = total % 8
    }

    /// Advance to the next byte boundary. No-op when already aligned.
    public mutating func byteAlign() {
        if bitOffset != 0 {
            byteOffset += 1
            bitOffset = 0
        }
    }

    /// Whether more RBSP data exists beyond the trailing
    /// `rbsp_stop_one_bit` per ITU-T H.264 §7.2.
    ///
    /// Returns `true` iff the cursor sits strictly before the buffer's
    /// last set bit (which is the rbsp_stop_one_bit). When the buffer
    /// has no set bits at or after the cursor, returns `false`.
    public func hasMoreRBSPData() -> Bool {
        // Find the position (in absolute bit offsets) of the buffer's
        // last set bit. That is the rbsp_stop_one_bit per the standard.
        let count = bytes.count
        for byteIdx in stride(from: count - 1, through: 0, by: -1) {
            let byte = bytes[bytes.startIndex + byteIdx]
            if byte == 0 { continue }
            for bit in 0..<8 where (byte >> bit) & 1 == 1 {
                let stopBitAbs = byteIdx * 8 + (7 - bit)
                let currentAbs = byteOffset * 8 + bitOffset
                return currentAbs < stopBitAbs
            }
        }
        return false
    }

    /// Decode an unsigned Exp-Golomb codeword per ITU-T H.264 §9.1.
    ///
    /// A codeword consists of `leadingZeros` zero bits, a single `1`
    /// bit, then `leadingZeros` payload bits. The decoded value is
    /// `(1 << leadingZeros) - 1 + payload`.
    public mutating func readUnsignedExpGolomb() throws -> UInt32 {
        var leadingZeros = 0
        while true {
            let bit = try readBit()
            if bit == 1 { break }
            leadingZeros += 1
            if leadingZeros > 32 {
                throw BitstreamError.malformedExpGolomb(
                    reason: "leading-zero run exceeds 32 bits (would overflow UInt32)"
                )
            }
        }
        if leadingZeros == 0 { return 0 }
        let suffix = try readBits(leadingZeros)
        let result = (UInt64(1) << leadingZeros) - 1 + suffix
        guard result <= UInt64(UInt32.max) else {
            throw BitstreamError.malformedExpGolomb(
                reason: "decoded value \(result) overflows UInt32"
            )
        }
        return UInt32(result)
    }

    /// Decode a signed Exp-Golomb codeword per ITU-T H.264 §9.1
    /// (`me(v)` mapping: 0 → 0, 1 → 1, 2 → -1, 3 → 2, 4 → -2, …).
    public mutating func readSignedExpGolomb() throws -> Int32 {
        let unsigned = try readUnsignedExpGolomb()
        if unsigned == 0 { return 0 }
        // Per the standard: signed = (-1)^(k+1) * ceil(k/2)
        //                          = (k & 1 == 1) ?  ((k+1)/2) : -((k+1)/2 - 1) … simplifies as below.
        if unsigned & 1 == 1 {
            // Odd → positive: (unsigned + 1) / 2
            return Int32((unsigned + 1) / 2)
        } else {
            // Even → negative: -((unsigned + 1) / 2) (signed magnitude)
            return -Int32(unsigned / 2)
        }
    }
}

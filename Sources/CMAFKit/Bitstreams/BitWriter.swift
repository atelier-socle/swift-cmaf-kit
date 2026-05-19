// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BitWriter
//
// MSB-first bit-level writer used by the codec-bitstream encoders.
// Symmetric counterpart of ``BitReader``.

import Foundation

/// MSB-first bit-level writer. Bytes appear in ``data`` once they are
/// completely filled; the trailing partial byte (if any) is emitted by
/// ``byteAlign()`` or ``finish()`` and padded with zero bits on the
/// right (the codec-bitstream "stuffing" convention).
public struct BitWriter: Sendable {
    public private(set) var data: Data
    private var pendingByte: UInt8 = 0
    private var pendingBits: Int = 0

    public init() {
        self.data = Data()
    }

    public init(reservingCapacity capacity: Int) {
        var data = Data()
        data.reserveCapacity(capacity)
        self.data = data
    }

    /// Number of bits written so far (including any in-flight partial
    /// byte).
    public var bitCount: Int {
        data.count * 8 + pendingBits
    }

    /// Write a single bit (0 or 1).
    public mutating func writeBit(_ bit: UInt8) {
        precondition(bit <= 1, "BitWriter.writeBit: bit must be 0 or 1")
        pendingByte = (pendingByte << 1) | (bit & 0x01)
        pendingBits += 1
        if pendingBits == 8 {
            data.append(pendingByte)
            pendingByte = 0
            pendingBits = 0
        }
    }

    /// Write the low `count` bits of `value` MSB-first (0 < count <= 64).
    public mutating func writeBits(_ value: UInt64, count: Int) {
        precondition((0...64).contains(count), "BitWriter.writeBits: 0 <= count <= 64")
        if count == 0 { return }
        var remaining = count
        while remaining > 0 {
            let bit = UInt8((value >> (remaining - 1)) & 0x01)
            writeBit(bit)
            remaining -= 1
        }
    }

    /// Write a `Bool` as a single bit.
    public mutating func writeBool(_ value: Bool) {
        writeBit(value ? 1 : 0)
    }

    /// Pad the in-flight partial byte with zero bits (MSB-first) to
    /// reach a byte boundary. No-op when already aligned.
    public mutating func byteAlign() {
        if pendingBits == 0 { return }
        pendingByte <<= (8 - pendingBits)
        data.append(pendingByte)
        pendingByte = 0
        pendingBits = 0
    }

    /// Finalise the writer; equivalent to ``byteAlign()``. Returns the
    /// produced bytes.
    @discardableResult
    public mutating func finish() -> Data {
        byteAlign()
        return data
    }

    /// Encode an unsigned Exp-Golomb codeword per ITU-T H.264 §9.1.
    public mutating func writeUnsignedExpGolomb(_ value: UInt32) {
        // codeNum = value; k = leading zeros = bit-width of (value+1) - 1.
        let codeNum = UInt64(value) + 1
        let bitWidth = 64 - codeNum.leadingZeroBitCount  // 1..33 for UInt32 inputs
        let leadingZeros = bitWidth - 1
        // Write `leadingZeros` zero bits, then the `bitWidth`-bit
        // representation of `codeNum` (which starts with a 1 bit).
        if leadingZeros > 0 {
            writeBits(0, count: leadingZeros)
        }
        writeBits(codeNum, count: bitWidth)
    }

    /// Encode a signed Exp-Golomb codeword per ITU-T H.264 §9.1
    /// (`me(v)` mapping).
    public mutating func writeSignedExpGolomb(_ value: Int32) {
        // Widen to Int64 to keep the doubling step safe for value == Int32.min.
        let value64 = Int64(value)
        let unsigned64: UInt64
        if value64 <= 0 {
            unsigned64 = UInt64(-value64 * 2)
        } else {
            unsigned64 = UInt64(value64 * 2 - 1)
        }
        // Practical AVC / HEVC signed-Golomb fields never approach UInt32
        // overflow; clamp defensively in the impossible case.
        let unsigned =
            unsigned64 > UInt64(UInt32.max)
            ? UInt32.max
            : UInt32(unsigned64)
        writeUnsignedExpGolomb(unsigned)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AV1 LEB128
//
// Reference: AOMedia AV1 Bitstream §4.10.5 (leb128).
//
// Up to 8 bytes; each byte's low 7 bits contribute payload and the
// high bit indicates continuation.

import Foundation

/// AV1 LEB128 unsigned-integer encoding.
public enum AV1LEB128 {

    /// Decode a leb128 value from `data` starting at `offset`. Returns
    /// the decoded value and the number of bytes consumed.
    public static func decode(from data: Data, at offset: Int) throws -> (value: UInt64, byteCount: Int) {
        var value: UInt64 = 0
        var consumed = 0
        for i in 0..<8 {
            let idx = data.startIndex + offset + i
            guard idx < data.endIndex else {
                throw BitstreamError.truncated(codec: "AV1", field: "leb128")
            }
            let byte = data[idx]
            value |= UInt64(byte & 0x7F) << (7 * i)
            consumed += 1
            if (byte & 0x80) == 0 {
                return (value, consumed)
            }
        }
        throw BitstreamError.obuLEB128Overflow
    }

    /// Encode `value` as leb128.
    public static func encode(_ value: UInt64) -> Data {
        var bytes = Data()
        var remaining = value
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 {
                byte |= 0x80
            }
            bytes.append(byte)
        } while remaining != 0
        return bytes
    }

    /// Number of bytes required to encode `value`.
    public static func byteCount(for value: UInt64) -> Int {
        if value == 0 { return 1 }
        return (64 - value.leadingZeroBitCount + 6) / 7
    }
}

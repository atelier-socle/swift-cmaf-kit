// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - NALLengthSize
//
// Reference: ISO/IEC 14496-15 §5.3.3 (AVC) + §8.3.3 (HEVC).
//
// The number of bytes used to encode each NAL unit length prefix within
// AVC and HEVC sample data. The wire encoding stores `rawValue - 1` in
// the low 2 bits of a configuration byte; the high 6 bits are reserved
// and must be 1.

import Foundation

/// NAL unit length prefix size, as carried by AVC/HEVC configuration
/// records.
///
/// Reference: ISO/IEC 14496-15 §5.3.3 + §8.3.3.
public enum NALLengthSize: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// One-byte length prefix.
    case oneByte = 1
    /// Two-byte length prefix.
    case twoBytes = 2
    /// Four-byte length prefix.
    case fourBytes = 4

    /// Decode from the on-wire `lengthSizeMinusOne` 2-bit field.
    public init(lengthSizeMinusOne: UInt8) throws {
        switch lengthSizeMinusOne {
        case 0: self = .oneByte
        case 1: self = .twoBytes
        case 3: self = .fourBytes
        default:
            throw ISOBoxError.malformedFullBox(
                type: "avcC",
                reason: "Invalid NAL lengthSizeMinusOne \(lengthSizeMinusOne); valid values are 0, 1, 3"
            )
        }
    }

    /// The on-wire `lengthSizeMinusOne` 2-bit field.
    public var lengthSizeMinusOne: UInt8 {
        switch self {
        case .oneByte: return 0
        case .twoBytes: return 1
        case .fourBytes: return 3
        }
    }
}

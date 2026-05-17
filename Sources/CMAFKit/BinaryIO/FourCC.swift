// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FourCC
//
// Four-character code used as the type field of every ISOBMFF box.
// Reference: ISO/IEC 14496-12 §4.2 (object structured representation).

import Foundation

/// Four-character code identifying an ISOBMFF box type or sample-entry type.
///
/// Stored as a 4-byte big-endian `UInt32`. `FourCC` is the canonical identifier
/// type for boxes, sample entries, brand codes, and any other 4-character
/// identifier used by ISO/IEC 14496-12 and its derivatives.
///
/// ## Construction
///
/// - Compile-time string literal:
///   ```swift
///   let ftyp: FourCC = "ftyp"  // ExpressibleByStringLiteral
///   ```
/// - Runtime parsing (recommended for untrusted input):
///   ```swift
///   guard let code = FourCC("ftyp") else { /* handle invalid input */ }
///   ```
/// - Runtime parsing (trapping form — for invariant guarantees):
///   ```swift
///   let code = FourCC(trapping: "ftyp")
///   ```
public struct FourCC: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {

    /// The big-endian `UInt32` representation of the four-character code.
    public let rawValue: UInt32

    /// Compile-time literal initialiser.
    ///
    /// The literal MUST be exactly 4 ASCII bytes. Using a non-4-ASCII literal is
    /// a programmer error caught at first use via `precondition`. Use the
    /// failable `init?(_:)` for runtime input.
    public init(stringLiteral value: String) {
        self = FourCC(trapping: value)
    }

    /// Failable string initialiser. Returns `nil` if `string` is not exactly 4
    /// ASCII bytes.
    public init?(_ string: String) {
        guard let value = FourCC.encode(string) else { return nil }
        self.rawValue = value
    }

    /// Trapping string initialiser. Triggers `precondition` if `string` is not
    /// exactly 4 ASCII bytes.
    public init(trapping string: String) {
        guard let value = FourCC.encode(string) else {
            preconditionFailure(
                "FourCC requires exactly 4 ASCII bytes, got: \(string.debugDescription)"
            )
        }
        self.rawValue = value
    }

    /// Raw-value initialiser. The value is stored as-is (big-endian on the wire).
    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Four-character string view of the code.
    public var stringValue: String {
        let bytes: [UInt8] = [
            UInt8((rawValue >> 24) & 0xff),
            UInt8((rawValue >> 16) & 0xff),
            UInt8((rawValue >> 8) & 0xff),
            UInt8(rawValue & 0xff)
        ]
        return String(decoding: bytes, as: UTF8.self)
    }

    public var description: String { stringValue }

    private static func encode(_ string: String) -> UInt32? {
        let scalars = string.unicodeScalars
        guard scalars.count == 4 else { return nil }
        var value: UInt32 = 0
        for scalar in scalars {
            guard scalar.value <= 0x7F else { return nil }  // ASCII only
            value = (value << 8) | UInt32(scalar.value)
        }
        return value
    }
}

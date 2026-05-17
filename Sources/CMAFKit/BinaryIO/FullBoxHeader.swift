// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - FullBoxHeader
//
// Full box header per ISO/IEC 14496-12 §4.2. Adds 1-byte version + 3-byte flags
// after the standard box header.

import Foundation

/// Header of an ISOBMFF "full box" per ISO/IEC 14496-12 §4.2.
///
/// A full box extends the standard box header with a 1-byte `version` field
/// and a 24-bit `flags` field. The `flags` value is constrained to the lower
/// 24 bits; the upper byte of a 4-byte word is the `version`.
public struct FullBoxHeader: Sendable, Equatable {
    /// Underlying box header.
    public let boxHeader: ISOBoxHeader

    /// Box version (1 byte).
    public let version: UInt8

    /// Box flags (lower 24 bits used).
    public let flags: UInt32

    public init(boxHeader: ISOBoxHeader, version: UInt8, flags: UInt32) {
        precondition(
            flags <= 0x00FF_FFFF,
            "FullBox flags must fit in 24 bits, got 0x\(String(flags, radix: 16))"
        )
        self.boxHeader = boxHeader
        self.version = version
        self.flags = flags
    }
}

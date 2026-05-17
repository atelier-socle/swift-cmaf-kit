// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ISOBoxHeader
//
// Box header per ISO/IEC 14496-12 §4.2 (object structured representation).
// Handles `size = 1` (largesize) and `type = "uuid"` (extended user type).

import Foundation

/// Header of an ISOBMFF box per ISO/IEC 14496-12 §4.2.
///
/// `size` is the resolved total box size, including header bytes. When the
/// on-disk `size` field is `1`, the 8-byte `largesize` field follows and is
/// merged into this value. When `type == "uuid"`, `userType` carries the
/// 16-byte extended type that follows the standard header.
public struct ISOBoxHeader: Sendable, Equatable {
    /// Box type (FourCC).
    public let type: FourCC

    /// Resolved total box size in bytes (header + body). Handles `size = 1` (largesize).
    public let size: UInt64

    /// Header size in bytes: 8 (standard), 16 (largesize), or 24 (uuid).
    public let headerSize: Int

    /// Extended user type. Non-nil iff `type == "uuid"`.
    public let userType: UUID?

    public init(type: FourCC, size: UInt64, headerSize: Int, userType: UUID? = nil) {
        self.type = type
        self.size = size
        self.headerSize = headerSize
        self.userType = userType
    }
}

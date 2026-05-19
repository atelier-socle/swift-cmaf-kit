// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - KeyIdentifier
//
// Reference: ISO/IEC 23001-7 §8.2 (default_KID).
//
// A 16-byte UUID-shaped identifier referencing a content-encryption key.
// CMAFKit stores it as raw bytes (the on-wire representation) plus a
// canonical UUID-string accessor for logging and DRM-layer interop.

import Foundation

/// Content-encryption key identifier per ISO/IEC 23001-7 §8.2.
///
/// On the wire the KID is a 16-byte UUID. CMAFKit preserves the byte
/// ordering verbatim and exposes a canonical UUID-string accessor.
public struct KeyIdentifier: Sendable, Hashable, Equatable, Codable {
    /// Sixteen raw bytes of the key identifier, in on-wire order.
    public let rawBytes: Data

    /// Construct from 16 bytes. Traps if the length is not exactly 16.
    public init(rawBytes: Data) {
        precondition(rawBytes.count == 16, "KeyIdentifier must be 16 bytes; got \(rawBytes.count)")
        self.rawBytes = rawBytes
    }

    /// Construct from a `UUID`. The UUID's byte representation maps
    /// directly to ``rawBytes`` in network order.
    public init(uuid: UUID) {
        let u = uuid.uuid
        self.rawBytes = Data([
            u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
            u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15
        ])
    }

    /// The 16 bytes formatted as a canonical UUID string.
    public var uuidString: String {
        let b = [UInt8](rawBytes)
        let uuid = UUID(
            uuid: (
                b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
            )
        )
        return uuid.uuidString
    }
}

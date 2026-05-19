// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ConstantIV
//
// Reference: ISO/IEC 23001-7 §9.2 (default_constant_IV).
//
// Per-scheme initialisation vector used when the track's per-sample IV
// size is zero (so every sample reuses the same IV).

import Foundation

/// Constant initialisation vector per ISO/IEC 23001-7 §9.2.
///
/// Used when ``TrackEncryptionBox/defaultPerSampleIVSize`` is `.zero`,
/// in which case every sample reuses this constant IV. Length is either
/// 8 bytes (for AES-CTR schemes `cenc` / `cens`) or 16 bytes (for the
/// AES-CBC pattern scheme `cbcs`).
public struct ConstantIV: Sendable, Hashable, Equatable, Codable {
    /// Raw IV bytes. Exactly 8 or 16 bytes.
    public let rawBytes: Data

    /// Construct from raw bytes. Throws if the length is neither 8 nor 16.
    public init(rawBytes: Data) throws {
        guard rawBytes.count == 8 || rawBytes.count == 16 else {
            throw ISOBoxError.malformedFullBox(
                type: "tenc",
                reason: "ConstantIV must be 8 or 16 bytes; got \(rawBytes.count)"
            )
        }
        self.rawBytes = rawBytes
    }
}

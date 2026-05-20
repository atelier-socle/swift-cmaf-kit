// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - DRMSystemError
//
// Reference: ISO/IEC 23001-7 §8.1.1 (pssh.data is opaque to the
// container) and individual DRM provider specifications.
//
// Provider parsers throw a typed ``DRMSystemError`` when the
// supplied bytes do not conform to the provider's wire format.
// Each case carries the offending system identifier so callers
// can branch on the provider.

import Foundation

/// Typed error surfaced by the CMAFKitDRM parsing path.
public enum DRMSystemError: Error, Sendable, Equatable {
    /// The pssh `systemID` is not a registered DRM system and no
    /// provider parser is wired up.
    case unsupportedSystem(systemID: UUID)
    /// The pssh.data bytes do not conform to the provider's
    /// expected layout (e.g., protobuf schema mismatch, XML root
    /// element wrong, magic-bytes prefix absent).
    case malformedInitData(systemID: KnownDRMSystemID, reason: String)
    /// `encode(parse(bytes)) == bytes` failed for the provider —
    /// indicates a bug in the parser, not in the supplied data.
    case roundTripFailure(systemID: KnownDRMSystemID, reason: String)
    /// The parser consumed every required field but the supplied
    /// buffer contains additional bytes the spec does not allow.
    case unexpectedTrailingBytes(systemID: KnownDRMSystemID, byteCount: Int)
    /// The provider's wire format declares a version number the
    /// parser does not implement.
    case wireFormatVersionUnsupported(systemID: KnownDRMSystemID, version: UInt32)
}

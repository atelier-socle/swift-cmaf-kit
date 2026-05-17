// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ISOBoxError
//
// Typed error surface for ISOBMFF box parsing and writing.

import Foundation

/// Errors thrown during ISOBMFF box parsing or writing.
public enum ISOBoxError: Error, Equatable, Sendable {
    /// The box's declared size is smaller than the header it requires.
    case sizeSmallerThanHeader(declared: UInt64, headerSize: Int, type: FourCC)

    /// A box whose declared size exceeds the available bytes.
    case sizeExceedsAvailable(declared: UInt64, available: UInt64, type: FourCC)

    /// The on-wire value for a `version` field is not one this code accepts.
    case unsupportedVersion(type: FourCC, version: UInt8)

    /// A full box's flags value falls outside the permitted lower 24 bits.
    case invalidFlags(type: FourCC, flags: UInt32)

    /// A box of declared type was expected but a different type was found.
    case unexpectedType(expected: FourCC, found: FourCC)

    /// A path-based lookup (e.g. `moov/trak/mdia/...`) did not resolve.
    case pathNotFound(path: String)

    /// A child container could not be parsed.
    case malformedChild(parent: FourCC, child: FourCC, underlyingDescription: String)

    /// A handler box `name` field could not be decoded as UTF-8 in either
    /// C-style or Pascal-style.
    case malformedHandlerName

    /// A matrix field did not have the required 9 elements
    /// (6 × 16.16 + 3 × 2.30).
    case malformedMatrix
}

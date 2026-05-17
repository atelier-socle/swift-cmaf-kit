// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - BinaryIOError
//
// Typed error surface for BinaryReader / BinaryWriter operations.

import Foundation

/// Errors thrown by `BinaryReader` and `BinaryWriter`.
public enum BinaryIOError: Error, Equatable, Sendable {
    /// Not enough bytes remaining for the requested read.
    case insufficientData(expected: Int, available: Int)

    /// FourCC parsing failed (non-ASCII or wrong byte count).
    case invalidFourCC(bytes: [UInt8])

    /// String decoding failed for the requested encoding.
    ///
    /// `encodingRawValue` is `String.Encoding.rawValue` (`UInt`). The raw value
    /// keeps the error `Sendable` across Swift 6.2 concurrency boundaries on
    /// both Apple and Linux platforms.
    case invalidString(encodingRawValue: UInt)

    /// A fixed-point read or write produced a non-representable value.
    case invalidFixedPoint

    /// Matrix decoding got the wrong number of elements (must be 9 for the
    /// ISO/IEC 14496-12 §8.3 transformation matrix).
    case invalidMatrix(elementCount: Int)
}

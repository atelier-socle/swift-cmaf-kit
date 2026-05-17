// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MediaTimestamp
//
// A `(value, timescale)` rational timestamp suitable for sample-accurate media
// arithmetic. All boundary arithmetic uses integer rationals; `Double`-based
// `seconds` is for display only. Reference: ISO/IEC 14496-12 §8.4.2 (media
// timescale).

import Foundation

/// A media timestamp expressed as the rational `(value / timescale)`.
///
/// Used pervasively for sample-accurate timing in ISOBMFF and CMAF. Arithmetic
/// (`+`, `-`) requires matching `timescale`s — mismatched timescales trap via
/// `precondition`. To combine timestamps with different timescales, rescale
/// one of them first with ``rescale(_:to:)``.
///
/// ## Reference
///
/// Aligns with ISO/IEC 14496-12 §8.4.2 (media timescale).
public struct MediaTimestamp: Hashable, Sendable {
    /// Numerator: tick count.
    public let value: Int64

    /// Denominator: ticks per second.
    public let timescale: UInt32

    /// Approximate seconds — for **display only**. Boundary arithmetic must use
    /// the integer `value` / `timescale` pair, never this `Double` accessor.
    public var seconds: Double {
        Double(value) / Double(timescale)
    }

    public init(value: Int64, timescale: UInt32) {
        precondition(timescale > 0, "MediaTimestamp timescale must be > 0")
        self.value = value
        self.timescale = timescale
    }

    /// Convenience: construct from a `Double` seconds + `timescale`. Rounds to
    /// the nearest tick.
    public init(seconds: Double, timescale: UInt32) {
        precondition(timescale > 0, "MediaTimestamp timescale must be > 0")
        self.value = Int64((seconds * Double(timescale)).rounded())
        self.timescale = timescale
    }

    public static func + (lhs: MediaTimestamp, rhs: MediaTimestamp) -> MediaTimestamp {
        precondition(
            lhs.timescale == rhs.timescale,
            "MediaTimestamp arithmetic requires matching timescales; rescale one operand first"
        )
        return MediaTimestamp(value: lhs.value + rhs.value, timescale: lhs.timescale)
    }

    public static func - (lhs: MediaTimestamp, rhs: MediaTimestamp) -> MediaTimestamp {
        precondition(
            lhs.timescale == rhs.timescale,
            "MediaTimestamp arithmetic requires matching timescales; rescale one operand first"
        )
        return MediaTimestamp(value: lhs.value - rhs.value, timescale: lhs.timescale)
    }
}

/// Overflow-safe rescaling errors.
public enum MediaTimestampRescaleError: Error, Equatable, Sendable {
    /// Intermediate multiplication overflowed `Int64`. The caller must split
    /// the operation or accept reduced precision.
    case overflow(value: Int64, newTimescale: UInt32, oldTimescale: UInt32)
}

/// Rescale a `MediaTimestamp` to a new `timescale`, using exact integer
/// arithmetic. Throws on overflow rather than silently wrapping.
///
/// Implementation discipline (per addendum F.9):
///   - The intermediate product is checked via
///     `Int64.multipliedReportingOverflow(by:)`; on overflow, this function
///     throws ``MediaTimestampRescaleError/overflow(value:newTimescale:oldTimescale:)``.
///     **No silent wrap.**
///   - The division is exact integer division: `(value * newTimescale) / oldTimescale`.
///
/// Callers that need to rescue precision on overflow can split the timestamp
/// into chunks, rescale each, and sum. A future revision may add a rationals-based
/// `BigInt`-style overload; for 0.1.0 the throwing form is the stable contract.
///
/// - Parameters:
///   - timestamp: the timestamp to rescale.
///   - newTimescale: the destination timescale. MUST be > 0.
/// - Returns: a new `MediaTimestamp` at `newTimescale`.
/// - Throws: ``MediaTimestampRescaleError/overflow(value:newTimescale:oldTimescale:)``
///   when the intermediate multiplication exceeds `Int64.max`.
public func rescale(
    _ timestamp: MediaTimestamp,
    to newTimescale: UInt32
) throws -> MediaTimestamp {
    precondition(newTimescale > 0, "rescale destination timescale must be > 0")
    if timestamp.timescale == newTimescale {
        return timestamp
    }
    let (product, overflowed) = timestamp.value.multipliedReportingOverflow(by: Int64(newTimescale))
    if overflowed {
        throw MediaTimestampRescaleError.overflow(
            value: timestamp.value,
            newTimescale: newTimescale,
            oldTimescale: timestamp.timescale
        )
    }
    return MediaTimestamp(value: product / Int64(timestamp.timescale), timescale: newTimescale)
}

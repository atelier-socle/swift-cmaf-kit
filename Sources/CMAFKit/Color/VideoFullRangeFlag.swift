// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - VideoFullRangeFlag
//
// Reference: ISO/IEC 23001-8 §7.4 (video full-range flag).

import Foundation

/// Indicates whether luma and chroma signals occupy the limited
/// (broadcast) range or the full code range.
///
/// Reference: ISO/IEC 23001-8 §7.4.
public enum VideoFullRangeFlag: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Limited range (e.g., Y in 16..235 for 8-bit, scaled equivalents
    /// for higher bit-depths).
    case limited = 0
    /// Full range (0..255 for 8-bit, 0..1023 for 10-bit, etc.).
    case full = 1
}

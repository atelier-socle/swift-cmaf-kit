// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - PCMFormat
//
// Linear PCM sample formats. Maps to ISOBMFF sample entries `lpcm`, `sowt`,
// `twos`, `fl32`, `fl64`, `in24`, `in32` (per spec Annex C).

import Foundation

/// Linear PCM sample format.
public enum PCMFormat: Sendable, Hashable, CaseIterable {
    /// 16-bit signed integer, little-endian.
    case int16LE
    /// 16-bit signed integer, big-endian.
    case int16BE
    /// 24-bit signed integer, little-endian.
    case int24LE
    /// 24-bit signed integer, big-endian.
    case int24BE
    /// 32-bit signed integer, little-endian.
    case int32LE
    /// 32-bit signed integer, big-endian.
    case int32BE
    /// IEEE 754 32-bit float, little-endian.
    case float32LE
    /// IEEE 754 32-bit float, big-endian.
    case float32BE
    /// IEEE 754 64-bit float, little-endian.
    case float64LE
    /// IEEE 754 64-bit float, big-endian.
    case float64BE
}

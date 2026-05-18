// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCChromaFormat
//
// Reference: ISO/IEC 14496-10 §6.2 + ISO/IEC 14496-15 §5.3.3.1.

import Foundation

/// AVC chroma format indicator carried by the high-profile fields of
/// `AVCDecoderConfigurationRecord`.
///
/// Reference: ISO/IEC 14496-10 §6.2.
public enum AVCChromaFormat: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Monochrome.
    case monochrome = 0
    /// 4:2:0.
    case format420 = 1
    /// 4:2:2.
    case format422 = 2
    /// 4:4:4.
    case format444 = 3
}

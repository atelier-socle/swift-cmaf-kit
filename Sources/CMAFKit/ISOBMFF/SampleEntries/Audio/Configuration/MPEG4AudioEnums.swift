// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MPEG-4 Audio sampling frequency + channel configuration
//
// Reference: ISO/IEC 14496-3 §1.6.3 (sampling frequency index) +
// §1.6.3.4 Table 1.17 (channel configuration).

import Foundation

/// MPEG-4 Audio sampling frequency index per ISO/IEC 14496-3 §1.6.3.
///
/// The 4-bit field maps to one of the documented frequencies. Values
/// `escape` (15) and the reserved entries (13, 14) are present so the
/// parser surfaces them rather than collapsing them.
public enum MPEG4AudioSamplingFrequencyIndex: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case freq96000 = 0
    case freq88200 = 1
    case freq64000 = 2
    case freq48000 = 3
    case freq44100 = 4
    case freq32000 = 5
    case freq24000 = 6
    case freq22050 = 7
    case freq16000 = 8
    case freq12000 = 9
    case freq11025 = 10
    case freq8000 = 11
    case freq7350 = 12
    case reserved13 = 13
    case reserved14 = 14
    /// Escape value: the actual frequency follows as a 24-bit field in
    /// the AudioSpecificConfig.
    case escape = 15

    /// The frequency in Hz when the index maps to a documented value;
    /// `nil` for reserved / escape entries.
    public var hzValue: UInt32? {
        switch self {
        case .freq96000: return 96000
        case .freq88200: return 88200
        case .freq64000: return 64000
        case .freq48000: return 48000
        case .freq44100: return 44100
        case .freq32000: return 32000
        case .freq24000: return 24000
        case .freq22050: return 22050
        case .freq16000: return 16000
        case .freq12000: return 12000
        case .freq11025: return 11025
        case .freq8000: return 8000
        case .freq7350: return 7350
        case .reserved13, .reserved14, .escape: return nil
        }
    }
}

/// MPEG-4 Audio channel configuration per ISO/IEC 14496-3 §1.6.3.4
/// Table 1.17.
public enum MPEG4ChannelConfiguration: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Channel configuration is signalled inside the AudioSpecificConfig
    /// via a `program_config_element`.
    case definedInAOTConfig = 0
    case mono = 1
    case stereo = 2
    /// L + C + R.
    case threeZero = 3
    /// L + C + R + Cs.
    case fourZero = 4
    /// L + C + R + Ls + Rs.
    case fiveZero = 5
    /// L + C + R + Ls + Rs + LFE.
    case fiveOne = 6
    /// L + C + R + Ls + Rs + RsBack + LFE.
    case sevenOne = 7
}

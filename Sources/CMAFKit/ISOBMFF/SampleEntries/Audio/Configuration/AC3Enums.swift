// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AC-3 / E-AC-3 enums
//
// Reference: ETSI TS 102 366 Annex F + §4.4.2.

import Foundation

/// AC-3 / E-AC-3 sample-frequency code per ETSI TS 102 366 §4.4.2.1.
public enum AC3FrameSizeCode: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// 48 kHz.
    case freq48000 = 0
    /// 44.1 kHz.
    case freq44100 = 1
    /// 32 kHz.
    case freq32000 = 2
    /// Reserved; encountering this value triggers a parse error.
    case reserved = 3
}

/// AC-3 / E-AC-3 bit-stream mode per ETSI TS 102 366 §4.4.2.1.
public enum AC3BitStreamMode: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case completeMain = 0
    case musicAndEffects = 1
    case visuallyImpaired = 2
    case hearingImpaired = 3
    case dialogue = 4
    case commentary = 5
    case emergency = 6
    case voiceOverOrKaraoke = 7
}

/// AC-3 / E-AC-3 audio coding mode per ETSI TS 102 366 §4.4.2.2.
public enum AC3AudioCodingMode: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// 1+1: dual mono.
    case dualMono = 0
    /// 1/0: mono.
    case mono = 1
    /// 2/0: stereo (L, R).
    case stereo = 2
    /// 3/0: L, C, R.
    case threeZero = 3
    /// 2/1: L, R, S.
    case twoOne = 4
    /// 3/1: L, C, R, S.
    case threeOne = 5
    /// 2/2: L, R, Ls, Rs.
    case twoTwo = 6
    /// 3/2: L, C, R, Ls, Rs.
    case threeTwo = 7
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - PredefinedChannelLayout
//
// Reference: ISO/IEC 23001-8 §8 Table 8 (channel configuration).
//
// Predefined channel-layout identifiers used by the channel-layout box
// when the layout matches a documented combination. Value 0 reserves
// the explicit-positions path of the parent box.

import Foundation

/// Predefined channel-layout identifier per ISO/IEC 23001-8 §8 Table 8.
public enum PredefinedChannelLayout: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Layout signalled explicitly via per-channel speaker positions.
    case explicitlySignaled = 0
    /// Mono (1.0).
    case mono = 1
    /// Stereo (2.0).
    case stereo = 2
    /// 3.0 (L, R, C).
    case threeZero = 3
    /// 4.0 (L, R, C, Cs).
    case fourZero = 4
    /// 5.0 (L, R, C, Ls, Rs).
    case fiveZero = 5
    /// 5.1.
    case fiveOne = 6
    /// 7.1.
    case sevenOne = 7
    /// 7.1 (front) layout variant.
    case sevenOneFront = 8
    /// 7.1.4 top-height.
    case sevenOneFourTopHeight = 9
    /// 5.1.2.
    case fivePointOnePointTwo = 10
    /// 7.1.2.
    case sevenPointOnePointTwo = 11
    /// 3.1.
    case threePointOne = 12
    /// 5.1.4.
    case fivePointOnePointFour = 13
    /// 4.0.4.
    case fourPointOhPointFour = 14
    /// 9.0.
    case nineOh = 15
    /// 9.1.
    case nineOne = 16
    /// 22.2 (NHK).
    case twentyTwoPointTwo = 17
    /// 3.0 with split left/right rear.
    case threePointZeroLR = 18
    /// 5.1.3.
    case fivePointOnePointThree = 19
    /// 7.1.3.
    case sevenPointOnePointThree = 20
}

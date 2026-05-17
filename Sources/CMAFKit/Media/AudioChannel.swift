// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AudioChannel
//
// Reference: ISO/IEC 23001-8 §8 (channel layout / CICP channel positions).

import Foundation

/// A logical audio channel label per ISO/IEC 23001-8 §8 channel positions.
public enum AudioChannel: UInt8, Sendable, Hashable, CaseIterable {
    /// Front-left speaker.
    case frontLeft = 0
    /// Front-right speaker.
    case frontRight = 1
    /// Front-centre speaker.
    case frontCenter = 2
    /// Low-frequency effects (subwoofer).
    case lfe = 3
    /// Back-left speaker (surround).
    case backLeft = 4
    /// Back-right speaker (surround).
    case backRight = 5
    /// Side-left speaker.
    case sideLeft = 6
    /// Side-right speaker.
    case sideRight = 7
    /// Top-front-left (height) speaker.
    case topFrontLeft = 8
    /// Top-front-right (height) speaker.
    case topFrontRight = 9
    /// Top-back-left (height) speaker.
    case topBackLeft = 10
    /// Top-back-right (height) speaker.
    case topBackRight = 11
    /// Top-front-centre (height) speaker.
    case topFrontCenter = 12
    /// Top-back-centre (height) speaker.
    case topBackCenter = 13
    /// Back-centre speaker.
    case backCenter = 14
}

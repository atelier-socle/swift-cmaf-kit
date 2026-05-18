// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - SpeakerPosition
//
// Reference: ISO/IEC 23001-8 §8 Table 9 (loudspeaker positions).
//
// Exhaustive enumeration of the loudspeaker positions documented by
// the CICP standard. An unrecognised value on the wire causes a parse
// error; value 126 (`.explicit`) signals that the channel's azimuth /
// elevation are carried explicitly in the parent ``ChannelLayoutBox``.

import Foundation

/// Loudspeaker position per ISO/IEC 23001-8 §8 Table 9.
public enum SpeakerPosition: UInt8, Sendable, Hashable, CaseIterable, Codable {
    /// Left front.
    case leftFront = 0
    /// Right front.
    case rightFront = 1
    /// Center front.
    case centerFront = 2
    /// LFE.
    case lfe = 3
    /// Left surround (Ls).
    case leftSurround = 4
    /// Right surround (Rs).
    case rightSurround = 5
    /// Left front center.
    case leftFrontCenter = 6
    /// Right front center.
    case rightFrontCenter = 7
    /// Back center.
    case backCenter = 8
    /// Left side surround (Lss).
    case leftSideSurround = 9
    /// Right side surround (Rss).
    case rightSideSurround = 10
    /// Left back surround (Lsr).
    case leftBackSurround = 11
    /// Right back surround (Rsr).
    case rightBackSurround = 12
    /// Top center (Ts).
    case topCenter = 13
    /// Top front left.
    case topFrontLeft = 14
    /// Top front center.
    case topFrontCenter = 15
    /// Top front right.
    case topFrontRight = 16
    /// Top side left.
    case topSideLeft = 17
    /// Top side right.
    case topSideRight = 18
    /// Top back left.
    case topBackLeft = 19
    /// Top back center.
    case topBackCenter = 20
    /// Top back right.
    case topBackRight = 21
    /// LFE 2.
    case lfe2 = 22
    /// Bottom front center.
    case bottomFrontCenter = 23
    /// Bottom front left.
    case bottomFrontLeft = 24
    /// Bottom front right.
    case bottomFrontRight = 25
    /// Left wide front.
    case leftWideFront = 26
    /// Right wide front.
    case rightWideFront = 27
    /// Left front vertical height.
    case leftFrontVerticalHeight = 28
    /// Right front vertical height.
    case rightFrontVerticalHeight = 29
    /// Center front vertical height.
    case centerFrontVerticalHeight = 30
    /// Left surround direct.
    case leftSurroundDirect = 31
    /// Right surround direct.
    case rightSurroundDirect = 32
    /// Explicit angular position. The parent ``ChannelLayoutBox`` carries
    /// the channel's `azimuth` and `elevation` in adjacent bytes.
    case explicit = 126
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AC-4 substream enums
//
// Reference: ETSI TS 103 190-1 §6.2.1.2 / §6.2.1.4 / §6.2.1.5.

import Foundation

/// AC-4 substream codec identifier per ETSI TS 103 190-1 §6.2.1.4.
public enum AC4SubstreamCodec: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case ac4Audio = 0
    case ac4Metadata = 1
    case reserved2 = 2
    case reserved3 = 3
    case reserved4 = 4
    case reserved5 = 5
    case reserved6 = 6
    case reserved7 = 7
}

/// AC-4 content type per ETSI TS 103 190-1 §6.2.1.2.
public enum AC4ContentType: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case completeMain = 0
    case music = 1
    case dialog = 2
    case effects = 3
    case visuallyImpaired = 4
    case hearingImpaired = 5
    case voiceover = 6
    case reserved = 7
}

/// AC-4 channel mode for the audio substream per ETSI TS 103 190-1 §6.2.1.4.
public enum AC4ChannelMode: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case mono = 0
    case stereo = 1
    case three0 = 2
    case five0 = 3
    case five1 = 4
    case sevenZeroFront = 5
    case sevenOneFront = 6
    case sevenZeroSurround = 7
    case sevenOneSurround = 8
    case sevenZeroBack = 9
    case sevenOneBack = 10
    case sevenZeroFourPointTwo = 11
    case sevenOneFourPointTwo = 12
    case nineZero = 13
    case nineOne = 14
    case twentyTwoPointTwo = 15
}

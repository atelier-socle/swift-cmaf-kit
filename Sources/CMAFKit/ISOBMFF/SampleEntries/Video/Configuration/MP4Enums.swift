// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MP4 enums
//
// Reference: ISO/IEC 14496-1 §7.2.6.6 Tables 5 and 6.

import Foundation

/// MPEG-4 Systems object type indication per ISO/IEC 14496-1 §7.2.6.6
/// Table 5.
public enum MP4ObjectTypeIndication: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case systemsISO14496_1 = 0x01
    case systemsISO14496_1V2 = 0x02
    case interactionStream = 0x03
    case afx = 0x05
    case font = 0x06
    case synthesizedTexture = 0x07
    case streamingText = 0x08
    case lasr = 0x09
    case saf = 0x0A
    case visualISO14496_2 = 0x20
    /// AVC (H.264).
    case visualISO14496_10 = 0x21
    case parameterSetsISO14496_10 = 0x22
    /// HEVC (H.265).
    case visualISO23008_2 = 0x23
    /// MPEG-4 Audio (e.g. AAC, USAC).
    case audioISO14496_3 = 0x40
    case visualISO13818_2_SimpleProfile = 0x60
    case visualISO13818_2_MainProfile = 0x61
    case visualISO13818_2_SNRProfile = 0x62
    case visualISO13818_2_SpatialProfile = 0x63
    case visualISO13818_2_HighProfile = 0x64
    case visualISO13818_2_422Profile = 0x65
    case audioISO13818_7_MainProfile = 0x66
    case audioISO13818_7_LCProfile = 0x67
    case audioISO13818_7_SSRProfile = 0x68
    case audioISO13818_3 = 0x69
    case visualISO11172_2 = 0x6A
    case audioISO11172_3 = 0x6B
    case visualISO10918_1_JPEG = 0x6C
    case visualISO15444_1_JPEG2000 = 0x6E
    case audioISO13818_7_MPEG2AAC_LowComplexity = 0x6F
    case privateAudio = 0xC0
    case privateVideo = 0xD0
}

/// MPEG-4 Systems stream type per ISO/IEC 14496-1 §7.2.6.6 Table 6.
public enum MP4StreamType: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case objectDescriptor = 1
    case clockReference = 2
    case sceneDescription = 3
    case visualStream = 4
    case audioStream = 5
    case mpeg7Stream = 6
    case ipmpStream = 7
    case objectContentInfo = 8
    case mpegJStream = 9
    case interactionStream = 10
    case ipmpToolStream = 11
}

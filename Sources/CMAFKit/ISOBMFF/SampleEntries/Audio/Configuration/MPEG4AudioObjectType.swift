// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - MPEG4AudioObjectType
//
// Reference: ISO/IEC 14496-3 §1.5.1 Table 1.16 (Audio Object Type).

import Foundation

/// MPEG-4 Audio Object Type per ISO/IEC 14496-3 §1.5.1 Table 1.16.
public enum MPEG4AudioObjectType: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case aacMain = 1
    case aacLC = 2
    case aacSSR = 3
    case aacLTP = 4
    case sbr = 5
    case aacScalable = 6
    case twinVQ = 7
    case celp = 8
    case hvxc = 9
    /// 10–11 reserved.
    case ttsi = 12
    case mainSynthetic = 13
    case wavetableSynthesis = 14
    case generalMIDI = 15
    case algorithmicSynthesisAudioFX = 16
    case erAACLC = 17
    /// 18 reserved.
    case erAACLTP = 19
    case erAACScalable = 20
    case erTwinVQ = 21
    case erBSAC = 22
    case erAACLD = 23
    case errorResilientCELP = 24
    case errorResilientHVXC = 25
    case errorResilientHILN = 26
    case errorResilientParametric = 27
    case ssc = 28
    case ps = 29
    case mpegSurround = 30
    /// 31 = escape: the actual value follows as an additional 6-bit field
    /// in the audio specific config. CMAFKit encodes this case verbatim.
    case escape = 31
    case layer1 = 32
    case layer2 = 33
    case layer3 = 34
    case dst = 35
    case als = 36
    case sls = 37
    case slsNonCore = 38
    case erAACELD = 39
    case smrSimple = 40
    case smrMain = 41
    case usacNoSBR = 42
    case saoc = 43
    case ldMPEGSurround = 44
    case usac = 45
}

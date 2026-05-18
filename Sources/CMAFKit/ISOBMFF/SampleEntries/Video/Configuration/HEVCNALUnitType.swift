// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCNALUnitType
//
// Reference: ISO/IEC 23008-2 §7.4.2.2 Table 7-1 (NAL unit type codes).
//
// 64 possible values (6-bit field). CMAFKit exposes the documented set
// and a handful of reserved cases. Unknown values on the wire throw.

import Foundation

/// HEVC NAL unit type codes per ISO/IEC 23008-2 §7.4.2.2 Table 7-1.
public enum HEVCNALUnitType: UInt8, Sendable, Hashable, CaseIterable, Codable {
    case trailN = 0
    case trailR = 1
    case tsaN = 2
    case tsaR = 3
    case stsaN = 4
    case stsaR = 5
    case radlN = 6
    case radlR = 7
    case raslN = 8
    case raslR = 9
    case rsvVclN10 = 10
    case rsvVclR11 = 11
    case rsvVclN12 = 12
    case rsvVclR13 = 13
    case rsvVclN14 = 14
    case rsvVclR15 = 15
    case blaWLP = 16
    case blaWRadl = 17
    case blaNLP = 18
    case idrWRadl = 19
    case idrNLP = 20
    case craNUT = 21
    case rsvIRAPVCL22 = 22
    case rsvIRAPVCL23 = 23
    case rsvVCL24 = 24
    case rsvVCL25 = 25
    case rsvVCL26 = 26
    case rsvVCL27 = 27
    case rsvVCL28 = 28
    case rsvVCL29 = 29
    case rsvVCL30 = 30
    case rsvVCL31 = 31
    /// Video parameter set.
    case vpsNUT = 32
    /// Sequence parameter set.
    case spsNUT = 33
    /// Picture parameter set.
    case ppsNUT = 34
    /// Access unit delimiter.
    case audNUT = 35
    /// End of sequence.
    case eosNUT = 36
    /// End of bitstream.
    case eobNUT = 37
    /// Filler data.
    case fdNUT = 38
    /// Prefix SEI.
    case prefixSEINUT = 39
    /// Suffix SEI.
    case suffixSEINUT = 40
    case rsvNVCL41 = 41
    case rsvNVCL42 = 42
    case rsvNVCL43 = 43
    case rsvNVCL44 = 44
    case rsvNVCL45 = 45
    case rsvNVCL46 = 46
    case rsvNVCL47 = 47
    case unspec48 = 48
    case unspec49 = 49
    case unspec50 = 50
    case unspec51 = 51
    case unspec52 = 52
    case unspec53 = 53
    case unspec54 = 54
    case unspec55 = 55
    case unspec56 = 56
    case unspec57 = 57
    case unspec58 = 58
    case unspec59 = 59
    case unspec60 = 60
    case unspec61 = 61
    case unspec62 = 62
    case unspec63 = 63
}

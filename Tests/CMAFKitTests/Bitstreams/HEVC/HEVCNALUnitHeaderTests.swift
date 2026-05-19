// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCNALUnitHeader")
struct HEVCNALUnitHeaderTests {

    @Test
    func parseIDR_W_RADLAtLayer0Tid0() throws {
        // forbidden=0, type=19 (idrWRadl), layer=0, tid+1=1 → 0010_0110_0000_0001
        // = 0x2601
        let header = try HEVCNALUnitHeader.parse(bytes: (0x26, 0x01))
        #expect(header.forbiddenZeroBit == false)
        #expect(header.nalUnitType == .idrWRadl)
        #expect(header.layerID == 0)
        #expect(header.temporalID == 0)
        #expect(header.isReference == true)
    }

    @Test
    func parseTrailNIsNonReference() throws {
        // forbidden=0, type=0 (trailN), layer=0, tid+1=2 → 0000_0000_0000_0010
        let header = try HEVCNALUnitHeader.parse(bytes: (0x00, 0x02))
        #expect(header.nalUnitType == .trailN)
        #expect(header.temporalID == 1)
        #expect(header.isReference == false)
    }

    @Test
    func parseTrailRIsReference() throws {
        let header = try HEVCNALUnitHeader.parse(bytes: (0x02, 0x01))
        #expect(header.nalUnitType == .trailR)
        #expect(header.isReference == true)
    }

    @Test
    func parseLayerIDPreserved() throws {
        // type=0, layer=15 (0x0F), tid+1=1 → bytes: 0000_0000 0111_1001 = (0x00, 0x79)
        let header = try HEVCNALUnitHeader.parse(bytes: (0x00, 0x79))
        #expect(header.layerID == 0x0F)
    }

    @Test
    func parseHighestTemporalID() throws {
        // type=0, layer=0, tid+1=7 → 0000_0000_0000_0111
        let header = try HEVCNALUnitHeader.parse(bytes: (0x00, 0x07))
        #expect(header.temporalID == 6)
    }

    @Test
    func parseRejectsZeroTemporalIDPlus1() {
        // type=0, layer=0, tid+1=0 → invalid per spec.
        #expect(throws: BitstreamError.self) {
            _ = try HEVCNALUnitHeader.parse(bytes: (0x00, 0x00))
        }
    }

    @Test
    func encodeMatchesParseInputForIDR() throws {
        let bytes: (UInt8, UInt8) = (0x26, 0x01)
        let header = try HEVCNALUnitHeader.parse(bytes: bytes)
        let encoded = header.encode()
        #expect(encoded == bytes)
    }

    @Test
    func vpsSpsPpsAtLayer0Tid0() throws {
        for (raw, expected) in [
            (UInt8(32), HEVCNALUnitType.vpsNUT),
            (UInt8(33), HEVCNALUnitType.spsNUT),
            (UInt8(34), HEVCNALUnitType.ppsNUT)
        ] {
            let highByte = (raw & 0x3F) << 1  // bits 14..9
            let header = try HEVCNALUnitHeader.parse(bytes: (highByte, 0x01))
            #expect(header.nalUnitType == expected)
            #expect(header.isReference == true)
        }
    }

    @Test
    func isReferenceForReservedVCL() throws {
        // rsvVclN10, rsvVclN12, rsvVclN14 are non-reference; the _R
        // counterparts are reference.
        #expect(HEVCNALUnitType.rsvVclN10.rawValue == 10)
        let n10 = HEVCNALUnitHeader(nalUnitType: .rsvVclN10, temporalID: 0)
        #expect(n10.isReference == false)
        let r11 = HEVCNALUnitHeader(nalUnitType: .rsvVclR11, temporalID: 0)
        #expect(r11.isReference == true)
        let n12 = HEVCNALUnitHeader(nalUnitType: .rsvVclN12, temporalID: 0)
        #expect(n12.isReference == false)
        let r13 = HEVCNALUnitHeader(nalUnitType: .rsvVclR13, temporalID: 0)
        #expect(r13.isReference == true)
        let n14 = HEVCNALUnitHeader(nalUnitType: .rsvVclN14, temporalID: 0)
        #expect(n14.isReference == false)
        let r15 = HEVCNALUnitHeader(nalUnitType: .rsvVclR15, temporalID: 0)
        #expect(r15.isReference == true)
    }

    @Test
    func radlAndRaslReferenceVsNonReference() {
        #expect(HEVCNALUnitHeader(nalUnitType: .radlN, temporalID: 0).isReference == false)
        #expect(HEVCNALUnitHeader(nalUnitType: .radlR, temporalID: 0).isReference == true)
        #expect(HEVCNALUnitHeader(nalUnitType: .raslN, temporalID: 0).isReference == false)
        #expect(HEVCNALUnitHeader(nalUnitType: .raslR, temporalID: 0).isReference == true)
    }

    @Test
    func tsaAndStsaReferenceVsNonReference() {
        #expect(HEVCNALUnitHeader(nalUnitType: .tsaN, temporalID: 0).isReference == false)
        #expect(HEVCNALUnitHeader(nalUnitType: .tsaR, temporalID: 0).isReference == true)
        #expect(HEVCNALUnitHeader(nalUnitType: .stsaN, temporalID: 0).isReference == false)
        #expect(HEVCNALUnitHeader(nalUnitType: .stsaR, temporalID: 0).isReference == true)
    }

    @Test
    func roundTripAllTypesLayer0Tid0() throws {
        for type in HEVCNALUnitType.allCases {
            let header = HEVCNALUnitHeader(nalUnitType: type, layerID: 0, temporalID: 0)
            let bytes = header.encode()
            let parsed = try HEVCNALUnitHeader.parse(bytes: bytes)
            #expect(parsed == header)
        }
    }

    @Test
    func roundTripWithLayerAndTemporalID() throws {
        for layer: UInt8 in [0, 1, 31, 63] {
            for tid: UInt8 in 0...6 {
                let header = HEVCNALUnitHeader(
                    nalUnitType: .spsNUT, layerID: layer, temporalID: tid
                )
                let bytes = header.encode()
                let parsed = try HEVCNALUnitHeader.parse(bytes: bytes)
                #expect(parsed == header)
            }
        }
    }

    @Test
    func equalityAndHashing() {
        let a = HEVCNALUnitHeader(nalUnitType: .spsNUT)
        let b = HEVCNALUnitHeader(nalUnitType: .spsNUT)
        let c = HEVCNALUnitHeader(nalUnitType: .ppsNUT)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }
}

@Suite("HEVCNALUnitType helpers")
struct HEVCNALUnitTypeHelperTests {

    @Test
    func isVCLForRawBelow32() {
        for raw: UInt8 in 0..<32 {
            #expect(HEVCNALUnitType(rawValue: raw)?.isVCL == true)
        }
    }

    @Test
    func isVCLFalseForRaw32AndAbove() {
        for raw: UInt8 in 32..<64 {
            #expect(HEVCNALUnitType(rawValue: raw)?.isVCL == false)
        }
    }

    @Test
    func isIRAPForRaw16Through23() {
        for raw: UInt8 in 16...23 {
            #expect(HEVCNALUnitType(rawValue: raw)?.isIRAP == true)
        }
        #expect(HEVCNALUnitType.trailR.isIRAP == false)
        #expect(HEVCNALUnitType.spsNUT.isIRAP == false)
    }

    @Test
    func isParameterSetForVpsSpsPps() {
        #expect(HEVCNALUnitType.vpsNUT.isParameterSet == true)
        #expect(HEVCNALUnitType.spsNUT.isParameterSet == true)
        #expect(HEVCNALUnitType.ppsNUT.isParameterSet == true)
        #expect(HEVCNALUnitType.idrWRadl.isParameterSet == false)
    }

    @Test
    func isSEIForPrefixAndSuffix() {
        #expect(HEVCNALUnitType.prefixSEINUT.isSEI == true)
        #expect(HEVCNALUnitType.suffixSEINUT.isSEI == true)
        #expect(HEVCNALUnitType.spsNUT.isSEI == false)
    }

    @Test
    func isUnspecifiedForRaw48Through63() {
        for raw: UInt8 in 48..<64 {
            #expect(HEVCNALUnitType(rawValue: raw)?.isUnspecified == true)
        }
        #expect(HEVCNALUnitType.idrWRadl.isUnspecified == false)
    }

    @Test
    func allCasesHas64Values() {
        #expect(HEVCNALUnitType.allCases.count == 64)
    }
}

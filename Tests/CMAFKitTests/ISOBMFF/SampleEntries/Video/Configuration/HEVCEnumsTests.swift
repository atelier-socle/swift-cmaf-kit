// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCProfileSpace")
struct HEVCProfileSpaceTests {

    @Test
    func zeroIsZero() {
        #expect(HEVCProfileSpace.zero.rawValue == 0)
    }

    @Test
    func threeIsThree() {
        #expect(HEVCProfileSpace.three.rawValue == 3)
    }

    @Test
    func unknownRejected() {
        #expect(HEVCProfileSpace(rawValue: 4) == nil)
    }

    @Test
    func fourCases() {
        #expect(HEVCProfileSpace.allCases.count == 4)
    }
}

@Suite("HEVCTierFlag")
struct HEVCTierFlagTests {

    @Test
    func mainIsZero() {
        #expect(HEVCTierFlag.main.rawValue == 0)
    }

    @Test
    func highIsOne() {
        #expect(HEVCTierFlag.high.rawValue == 1)
    }

    @Test
    func twoCases() {
        #expect(HEVCTierFlag.allCases.count == 2)
    }
}

@Suite("HEVCProfileIDC")
struct HEVCProfileIDCTests {

    @Test
    func mainIsOne() {
        #expect(HEVCProfileIDC.main.rawValue == 1)
    }

    @Test
    func main10IsTwo() {
        #expect(HEVCProfileIDC.main10.rawValue == 2)
    }

    @Test
    func mainStillPictureIsThree() {
        #expect(HEVCProfileIDC.mainStillPicture.rawValue == 3)
    }

    @Test
    func rangeExtensionsIsFour() {
        #expect(HEVCProfileIDC.rangeExtensions.rawValue == 4)
    }

    @Test
    func highThroughputIsFive() {
        #expect(HEVCProfileIDC.highThroughput.rawValue == 5)
    }

    @Test
    func multiviewMainIsSix() {
        #expect(HEVCProfileIDC.multiviewMain.rawValue == 6)
    }

    @Test
    func scalableMainIsSeven() {
        #expect(HEVCProfileIDC.scalableMain.rawValue == 7)
    }

    @Test
    func threeDMainIsEight() {
        #expect(HEVCProfileIDC.threeDMain.rawValue == 8)
    }

    @Test
    func screenContentCodingIsNine() {
        #expect(HEVCProfileIDC.screenContentCoding.rawValue == 9)
    }

    @Test
    func scalableRangeExtensionsIsTen() {
        #expect(HEVCProfileIDC.scalableRangeExtensions.rawValue == 10)
    }

    @Test
    func highThroughputScreenContentCodingIsEleven() {
        #expect(HEVCProfileIDC.highThroughputScreenContentCoding.rawValue == 11)
    }

    @Test
    func elevenCases() {
        #expect(HEVCProfileIDC.allCases.count == 11)
    }
}

@Suite("HEVCLevelIDC")
struct HEVCLevelIDCTests {

    @Test
    func level1IsThirty() {
        #expect(HEVCLevelIDC.level1.rawValue == 30)
    }

    @Test
    func level3IsNinety() {
        #expect(HEVCLevelIDC.level3.rawValue == 90)
    }

    @Test
    func level5_1Is153() {
        #expect(HEVCLevelIDC.level5_1.rawValue == 153)
    }

    @Test
    func level6_2Is186() {
        #expect(HEVCLevelIDC.level6_2.rawValue == 186)
    }

    @Test
    func unknownLevelRejected() {
        #expect(HEVCLevelIDC(rawValue: 99) == nil)
    }

    @Test
    func thirteenLevels() {
        #expect(HEVCLevelIDC.allCases.count == 13)
    }
}

@Suite("HEVCChromaFormatIDC")
struct HEVCChromaFormatIDCTests {

    @Test
    func monoIsZero() {
        #expect(HEVCChromaFormatIDC.monochrome.rawValue == 0)
    }

    @Test
    func format420IsOne() {
        #expect(HEVCChromaFormatIDC.format420.rawValue == 1)
    }

    @Test
    func format444IsThree() {
        #expect(HEVCChromaFormatIDC.format444.rawValue == 3)
    }

    @Test
    func fourCases() {
        #expect(HEVCChromaFormatIDC.allCases.count == 4)
    }
}

@Suite("HEVCParallelismType")
struct HEVCParallelismTypeTests {

    @Test
    func mixedOrUnknownIsZero() {
        #expect(HEVCParallelismType.mixedOrUnknown.rawValue == 0)
    }

    @Test
    func sliceIsOne() {
        #expect(HEVCParallelismType.slice.rawValue == 1)
    }

    @Test
    func waveFrontIsThree() {
        #expect(HEVCParallelismType.waveFront.rawValue == 3)
    }

    @Test
    func fourCases() {
        #expect(HEVCParallelismType.allCases.count == 4)
    }
}

@Suite("HEVCConstantFrameRate")
struct HEVCConstantFrameRateTests {

    @Test
    func unknownIsZero() {
        #expect(HEVCConstantFrameRate.unknown.rawValue == 0)
    }

    @Test
    func constantIsOne() {
        #expect(HEVCConstantFrameRate.constant.rawValue == 1)
    }

    @Test
    func reservedIsThree() {
        #expect(HEVCConstantFrameRate.reserved.rawValue == 3)
    }

    @Test
    func fourCases() {
        #expect(HEVCConstantFrameRate.allCases.count == 4)
    }
}

@Suite("HEVCConstraintIndicatorFlags")
struct HEVCConstraintIndicatorFlagsTests {

    @Test
    func constructFromExplicitFlags() {
        let flags = HEVCConstraintIndicatorFlags(
            progressiveSourceFlag: true,
            interlacedSourceFlag: false,
            nonPackedConstraintFlag: true,
            frameOnlyConstraintFlag: true,
            extendedConstraintBits: 0
        )
        #expect(flags.progressiveSourceFlag)
        #expect(!flags.interlacedSourceFlag)
        #expect(flags.nonPackedConstraintFlag)
        #expect(flags.frameOnlyConstraintFlag)
    }

    @Test
    func progressiveBitMapsToHighestBit() {
        let flags = HEVCConstraintIndicatorFlags(
            progressiveSourceFlag: true,
            interlacedSourceFlag: false,
            nonPackedConstraintFlag: false,
            frameOnlyConstraintFlag: false
        )
        #expect(flags.rawValueBigEndian == (UInt64(1) << 47))
    }

    @Test
    func interlacedBitMapsToBit46() {
        let flags = HEVCConstraintIndicatorFlags(
            progressiveSourceFlag: false,
            interlacedSourceFlag: true,
            nonPackedConstraintFlag: false,
            frameOnlyConstraintFlag: false
        )
        #expect(flags.rawValueBigEndian == (UInt64(1) << 46))
    }

    @Test
    func rawValueRoundTrip() {
        let raw: UInt64 = 0x0000_C123_4567_89AB & 0x0000_FFFF_FFFF_FFFF
        let flags = HEVCConstraintIndicatorFlags(rawValueBigEndian: raw)
        #expect(flags.rawValueBigEndian == raw)
    }

    @Test
    func zeroFlagsAllFalse() {
        let flags = HEVCConstraintIndicatorFlags(rawValueBigEndian: 0)
        #expect(!flags.progressiveSourceFlag)
        #expect(!flags.interlacedSourceFlag)
        #expect(!flags.nonPackedConstraintFlag)
        #expect(!flags.frameOnlyConstraintFlag)
        #expect(flags.extendedConstraintBits == 0)
    }

    @Test
    func extendedBitsMasked() {
        let flags = HEVCConstraintIndicatorFlags(
            progressiveSourceFlag: false,
            interlacedSourceFlag: false,
            nonPackedConstraintFlag: false,
            frameOnlyConstraintFlag: false,
            extendedConstraintBits: 0x0FFF_FFFF_FFFF
        )
        #expect(flags.extendedConstraintBits == 0x0FFF_FFFF_FFFF)
    }

    @Test
    func allFourNamedFlagsTrue() {
        let flags = HEVCConstraintIndicatorFlags(
            progressiveSourceFlag: true,
            interlacedSourceFlag: true,
            nonPackedConstraintFlag: true,
            frameOnlyConstraintFlag: true
        )
        let expected: UInt64 =
            (UInt64(1) << 47) | (UInt64(1) << 46)
            | (UInt64(1) << 45) | (UInt64(1) << 44)
        #expect(flags.rawValueBigEndian == expected)
    }

    @Test
    func equalityHashable() {
        let a = HEVCConstraintIndicatorFlags(rawValueBigEndian: 0x0000_F000_0000_0000)
        let b = HEVCConstraintIndicatorFlags(rawValueBigEndian: 0x0000_F000_0000_0000)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}

@Suite("HEVCProfileCompatibilityFlags")
struct HEVCProfileCompatibilityFlagsTests {

    @Test
    func bitZeroIsMSB() {
        let flags = HEVCProfileCompatibilityFlags(rawValue: 0x8000_0000)
        #expect(flags.isCompatible(profileIDC: 0))
        #expect(!flags.isCompatible(profileIDC: 1))
    }

    @Test
    func bit31IsLSB() {
        let flags = HEVCProfileCompatibilityFlags(rawValue: 0x0000_0001)
        #expect(flags.isCompatible(profileIDC: 31))
    }

    @Test
    func allZeroNoneCompatible() {
        let flags = HEVCProfileCompatibilityFlags(rawValue: 0)
        for i in 0..<32 {
            #expect(!flags.isCompatible(profileIDC: i))
        }
    }

    @Test
    func allOneAllCompatible() {
        let flags = HEVCProfileCompatibilityFlags(rawValue: 0xFFFF_FFFF)
        for i in 0..<32 {
            #expect(flags.isCompatible(profileIDC: i))
        }
    }

    @Test
    func equatable() {
        let a = HEVCProfileCompatibilityFlags(rawValue: 0x1234_5678)
        let b = HEVCProfileCompatibilityFlags(rawValue: 0x1234_5678)
        #expect(a == b)
    }

    @Test
    func rawValuePreserved() {
        let flags = HEVCProfileCompatibilityFlags(rawValue: 0xDEAD_BEEF)
        #expect(flags.rawValue == 0xDEAD_BEEF)
    }
}

@Suite("HEVCNALUnitType")
struct HEVCNALUnitTypeTests {

    @Test
    func vpsIs32() {
        #expect(HEVCNALUnitType.vpsNUT.rawValue == 32)
    }

    @Test
    func spsIs33() {
        #expect(HEVCNALUnitType.spsNUT.rawValue == 33)
    }

    @Test
    func ppsIs34() {
        #expect(HEVCNALUnitType.ppsNUT.rawValue == 34)
    }

    @Test
    func idrIs19() {
        #expect(HEVCNALUnitType.idrWRadl.rawValue == 19)
    }

    @Test
    func sixtyFourCases() {
        #expect(HEVCNALUnitType.allCases.count == 64)
    }
}

@Suite("HEVCParameterSet")
struct HEVCParameterSetTests {

    @Test
    func vpsNalTypeDecoded() {
        // First byte: type=32 (vpsNUT), so byte 0 = (32 << 1) | 0 = 0x40.
        // Second byte arbitrary.
        let vps = HEVCParameterSet(rbspBytes: Data([0x40, 0x01, 0x0C, 0x01]))
        #expect(vps.nalUnitType == .vpsNUT)
    }

    @Test
    func spsNalTypeDecoded() {
        let sps = HEVCParameterSet(rbspBytes: Data([0x42, 0x01, 0x01, 0x01]))
        #expect(sps.nalUnitType == .spsNUT)
    }

    @Test
    func ppsNalTypeDecoded() {
        let pps = HEVCParameterSet(rbspBytes: Data([0x44, 0x01, 0xC0, 0xF3]))
        #expect(pps.nalUnitType == .ppsNUT)
    }

    @Test
    func layerIDIsZeroByDefault() {
        let sps = HEVCParameterSet(rbspBytes: Data([0x42, 0x01, 0xC0, 0xF3]))
        #expect(sps.layerID == 0)
    }

    @Test
    func temporalIDDecoded() {
        // Second byte 0x01 = nuh_temporal_id_plus1 = 1 → temporalID = 0.
        let sps = HEVCParameterSet(rbspBytes: Data([0x42, 0x01, 0xC0, 0xF3]))
        #expect(sps.temporalID == 0)
    }

    @Test
    func rbspPreserved() {
        let bytes = Data([0x40, 0x01, 0x0C, 0x01, 0x02, 0x03, 0x04])
        let ps = HEVCParameterSet(rbspBytes: bytes)
        #expect(ps.rbspBytes == bytes)
    }
}

@Suite("HEVCParameterSetArray")
struct HEVCParameterSetArrayTests {

    @Test
    func completenessRoundTrips() {
        let array = HEVCParameterSetArray(
            arrayCompleteness: true,
            nalUnitType: .vpsNUT,
            parameterSets: [HEVCParameterSet(rbspBytes: Data([0x40, 0x01]))]
        )
        #expect(array.arrayCompleteness)
    }

    @Test
    func vpsTypeArray() {
        let array = HEVCParameterSetArray(
            arrayCompleteness: true,
            nalUnitType: .vpsNUT,
            parameterSets: []
        )
        #expect(array.nalUnitType == .vpsNUT)
    }

    @Test
    func spsTypeArray() {
        let array = HEVCParameterSetArray(
            arrayCompleteness: true,
            nalUnitType: .spsNUT,
            parameterSets: []
        )
        #expect(array.nalUnitType == .spsNUT)
    }

    @Test
    func ppsTypeArray() {
        let array = HEVCParameterSetArray(
            arrayCompleteness: true,
            nalUnitType: .ppsNUT,
            parameterSets: []
        )
        #expect(array.nalUnitType == .ppsNUT)
    }

    @Test
    func emptyParameterSets() {
        let array = HEVCParameterSetArray(
            arrayCompleteness: false,
            nalUnitType: .vpsNUT,
            parameterSets: []
        )
        #expect(array.parameterSets.isEmpty)
    }

    @Test
    func multipleParameterSets() {
        let array = HEVCParameterSetArray(
            arrayCompleteness: true,
            nalUnitType: .spsNUT,
            parameterSets: [
                HEVCParameterSet(rbspBytes: Data([0x42, 0x01])),
                HEVCParameterSet(rbspBytes: Data([0x42, 0x02]))
            ]
        )
        #expect(array.parameterSets.count == 2)
    }

    @Test
    func equatable() {
        let a = HEVCParameterSetArray(
            arrayCompleteness: true,
            nalUnitType: .vpsNUT,
            parameterSets: []
        )
        let b = HEVCParameterSetArray(
            arrayCompleteness: true,
            nalUnitType: .vpsNUT,
            parameterSets: []
        )
        #expect(a == b)
    }

    @Test
    func incompletenessDistinguishesEquality() {
        let a = HEVCParameterSetArray(
            arrayCompleteness: true,
            nalUnitType: .vpsNUT,
            parameterSets: []
        )
        let b = HEVCParameterSetArray(
            arrayCompleteness: false,
            nalUnitType: .vpsNUT,
            parameterSets: []
        )
        #expect(a != b)
    }
}

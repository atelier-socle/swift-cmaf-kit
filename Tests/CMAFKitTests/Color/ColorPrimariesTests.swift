// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for ColorPrimaries — ISO/IEC 23001-8 §7.1 Table 2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ColorPrimaries")
struct ColorPrimariesTests {

    @Test
    func bt709IsOne() {
        #expect(ColorPrimaries.bt709.rawValue == 1)
    }

    @Test
    func unspecifiedIsTwo() {
        #expect(ColorPrimaries.unspecified.rawValue == 2)
    }

    @Test
    func bt470MIsFour() {
        #expect(ColorPrimaries.bt470M.rawValue == 4)
    }

    @Test
    func bt470BGIsFive() {
        #expect(ColorPrimaries.bt470BG.rawValue == 5)
    }

    @Test
    func bt601IsSix() {
        #expect(ColorPrimaries.bt601.rawValue == 6)
    }

    @Test
    func smpte240MIsSeven() {
        #expect(ColorPrimaries.smpte240M.rawValue == 7)
    }

    @Test
    func bt2020IsNine() {
        #expect(ColorPrimaries.bt2020.rawValue == 9)
    }

    @Test
    func dciP3IsEleven() {
        #expect(ColorPrimaries.smpteRP431.rawValue == 11)
    }

    @Test
    func displayP3IsTwelve() {
        #expect(ColorPrimaries.smpteEG432_P3D65.rawValue == 12)
    }

    @Test
    func ebu3213IsTwentyTwo() {
        #expect(ColorPrimaries.ebu3213.rawValue == 22)
    }

    @Test
    func p3D65AliasResolvesCorrectly() {
        #expect(ColorPrimaries.p3D65 == .smpteEG432_P3D65)
    }

    @Test
    func reservedValueThreeIsRejected() {
        #expect(ColorPrimaries(rawValue: 3) == nil)
    }
}

@Suite("TransferCharacteristics")
struct TransferCharacteristicsTests {

    @Test
    func bt709IsOne() {
        #expect(TransferCharacteristics.bt709.rawValue == 1)
    }

    @Test
    func smpteST2084_PQIsSixteen() {
        #expect(TransferCharacteristics.smpteST2084_PQ.rawValue == 16)
    }

    @Test
    func aribSTDB67_HLGIsEighteen() {
        #expect(TransferCharacteristics.aribSTDB67_HLG.rawValue == 18)
    }

    @Test
    func iec61966_2_1_sRGBIsThirteen() {
        #expect(TransferCharacteristics.iec61966_2_1_sRGB.rawValue == 13)
    }

    @Test
    func bt2020_10bitIsFourteen() {
        #expect(TransferCharacteristics.bt2020_10bit.rawValue == 14)
    }

    @Test
    func bt2020_12bitIsFifteen() {
        #expect(TransferCharacteristics.bt2020_12bit.rawValue == 15)
    }

    @Test
    func linearIsEight() {
        #expect(TransferCharacteristics.linear.rawValue == 8)
    }

    @Test
    func bt470M_gamma22IsFour() {
        #expect(TransferCharacteristics.bt470M_gamma22.rawValue == 4)
    }

    @Test
    func bt470BG_gamma28IsFive() {
        #expect(TransferCharacteristics.bt470BG_gamma28.rawValue == 5)
    }

    @Test
    func bt601IsSix() {
        #expect(TransferCharacteristics.bt601.rawValue == 6)
    }

    @Test
    func unspecifiedIsTwo() {
        #expect(TransferCharacteristics.unspecified.rawValue == 2)
    }

    @Test
    func reservedValueThreeIsRejected() {
        #expect(TransferCharacteristics(rawValue: 3) == nil)
    }

    @Test
    func reservedValueZeroIsRejected() {
        #expect(TransferCharacteristics(rawValue: 0) == nil)
    }

    @Test
    func iec61966_2_4IsEleven() {
        #expect(TransferCharacteristics.iec61966_2_4.rawValue == 11)
    }

    @Test
    func bt1361ExtendedIsTwelve() {
        #expect(TransferCharacteristics.bt1361Extended.rawValue == 12)
    }
}

@Suite("MatrixCoefficients")
struct MatrixCoefficientsTests {

    @Test
    func identityRGBIsZero() {
        #expect(MatrixCoefficients.identityRGB.rawValue == 0)
    }

    @Test
    func bt709IsOne() {
        #expect(MatrixCoefficients.bt709.rawValue == 1)
    }

    @Test
    func unspecifiedIsTwo() {
        #expect(MatrixCoefficients.unspecified.rawValue == 2)
    }

    @Test
    func fccIsFour() {
        #expect(MatrixCoefficients.fcc.rawValue == 4)
    }

    @Test
    func bt2020NCLIsNine() {
        #expect(MatrixCoefficients.bt2020NCL.rawValue == 9)
    }

    @Test
    func bt2020CLIsTen() {
        #expect(MatrixCoefficients.bt2020CL.rawValue == 10)
    }

    @Test
    func smpteST2085IsEleven() {
        #expect(MatrixCoefficients.smpteST2085.rawValue == 11)
    }

    @Test
    func ictcpIsFourteen() {
        #expect(MatrixCoefficients.ictcp.rawValue == 14)
    }

    @Test
    func yCgCoIsEight() {
        #expect(MatrixCoefficients.yCgCo.rawValue == 8)
    }

    @Test
    func chromaticityDerivedNCLIsTwelve() {
        #expect(MatrixCoefficients.chromaticityDerivedNCL.rawValue == 12)
    }

    @Test
    func chromaticityDerivedCLIsThirteen() {
        #expect(MatrixCoefficients.chromaticityDerivedCL.rawValue == 13)
    }

    @Test
    func reservedValueThreeIsRejected() {
        #expect(MatrixCoefficients(rawValue: 3) == nil)
    }
}

@Suite("VideoFullRangeFlag")
struct VideoFullRangeFlagTests {

    @Test
    func limitedIsZero() {
        #expect(VideoFullRangeFlag.limited.rawValue == 0)
    }

    @Test
    func fullIsOne() {
        #expect(VideoFullRangeFlag.full.rawValue == 1)
    }

    @Test
    func caseIterableHasTwoCases() {
        #expect(VideoFullRangeFlag.allCases.count == 2)
    }

    @Test
    func reservedValueTwoIsRejected() {
        #expect(VideoFullRangeFlag(rawValue: 2) == nil)
    }
}

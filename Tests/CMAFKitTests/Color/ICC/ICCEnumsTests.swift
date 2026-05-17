// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ICCProfileClass")
struct ICCProfileClassTests {

    @Test
    func displayDeviceIsMntr() {
        #expect(ICCProfileClass.displayDevice.rawValue == 0x6D6E_7472)
    }

    @Test
    func outputDeviceIsPrtr() {
        #expect(ICCProfileClass.outputDevice.rawValue == 0x7072_7472)
    }

    @Test
    func allSevenClassesPresent() {
        #expect(ICCProfileClass.allCases.count == 7)
    }

    @Test
    func unknownValueIsRejected() {
        #expect(ICCProfileClass(rawValue: 0xDEAD_BEEF) == nil)
    }
}

@Suite("ICCColorSpace")
struct ICCColorSpaceTests {

    @Test
    func rgbSpaceSignature() {
        #expect(ICCColorSpace.rgb.rawValue == 0x5247_4220)
    }

    @Test
    func cmykSpaceSignature() {
        #expect(ICCColorSpace.cmyk.rawValue == 0x434D_594B)
    }

    @Test
    func graySpaceSignature() {
        #expect(ICCColorSpace.gray.rawValue == 0x4752_4159)
    }

    @Test
    func xyzSpaceSignature() {
        #expect(ICCColorSpace.xyz.rawValue == 0x5859_5A20)
    }

    @Test
    func nclr2ThroughNclrFCovered() {
        #expect(ICCColorSpace.nclr2.rawValue == 0x3243_4C52)
        #expect(ICCColorSpace.nclrF.rawValue == 0x4643_4C52)
    }

    @Test
    func unknownValueIsRejected() {
        #expect(ICCColorSpace(rawValue: 0x1234_5678) == nil)
    }
}

@Suite("ICCPrimaryPlatform")
struct ICCPrimaryPlatformTests {

    @Test
    func appleIsAPPL() {
        #expect(ICCPrimaryPlatform.apple.rawValue == 0x4150_504C)
    }

    @Test
    func microsoftIsMSFT() {
        #expect(ICCPrimaryPlatform.microsoft.rawValue == 0x4D53_4654)
    }

    @Test
    func unspecifiedIsZero() {
        #expect(ICCPrimaryPlatform.unspecified.rawValue == 0)
    }

    @Test
    func allFiveCasesPresent() {
        #expect(ICCPrimaryPlatform.allCases.count == 5)
    }
}

@Suite("ICCRenderingIntent")
struct ICCRenderingIntentTests {

    @Test
    func perceptualIsZero() {
        #expect(ICCRenderingIntent.perceptual.rawValue == 0)
    }

    @Test
    func mediaRelativeColorimetricIsOne() {
        #expect(ICCRenderingIntent.mediaRelativeColorimetric.rawValue == 1)
    }

    @Test
    func saturationIsTwo() {
        #expect(ICCRenderingIntent.saturation.rawValue == 2)
    }

    @Test
    func iccAbsoluteColorimetricIsThree() {
        #expect(ICCRenderingIntent.iccAbsoluteColorimetric.rawValue == 3)
    }
}

@Suite("ICCTagSignature")
struct ICCTagSignatureTests {

    @Test
    func mediaWhitePointIsWtpt() {
        #expect(ICCTagSignature.mediaWhitePoint.rawValue == 0x7774_7074)
    }

    @Test
    func copyrightIsCprt() {
        #expect(ICCTagSignature.copyright.rawValue == 0x6370_7274)
    }

    @Test
    func profileDescriptionIsDesc() {
        #expect(ICCTagSignature.profileDescription.rawValue == 0x6465_7363)
    }

    @Test
    func aToB0IsA2B0() {
        #expect(ICCTagSignature.aToB0.rawValue == 0x4132_4230)
    }

    @Test
    func redTRCIsRTRC() {
        #expect(ICCTagSignature.redTRC.rawValue == 0x7254_5243)
    }

    @Test
    func allSignaturesUnique() {
        let rawValues = ICCTagSignature.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == rawValues.count)
    }
}

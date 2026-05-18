// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AVCProfileIndication")
struct AVCProfileIndicationTests {

    @Test
    func baselineIs66() {
        #expect(AVCProfileIndication.baseline.rawValue == 66)
    }

    @Test
    func mainIs77() {
        #expect(AVCProfileIndication.main.rawValue == 77)
    }

    @Test
    func highIs100() {
        #expect(AVCProfileIndication.high.rawValue == 100)
    }

    @Test
    func high10Is110() {
        #expect(AVCProfileIndication.high10.rawValue == 110)
    }

    @Test
    func highTriggersHighProfileFields() {
        #expect(AVCProfileIndication.high.requiresHighProfileFields)
        #expect(AVCProfileIndication.high10.requiresHighProfileFields)
        #expect(AVCProfileIndication.high422.requiresHighProfileFields)
    }

    @Test
    func baselineDoesNotTriggerHighProfileFields() {
        #expect(!AVCProfileIndication.baseline.requiresHighProfileFields)
        #expect(!AVCProfileIndication.main.requiresHighProfileFields)
        #expect(!AVCProfileIndication.extended.requiresHighProfileFields)
    }

    @Test
    func unknownValueRejected() {
        #expect(AVCProfileIndication(rawValue: 200) == nil)
    }

    @Test
    func staticHighProfileFieldsHelper() {
        #expect(AVCProfileIndication.requiresHighProfileFields(profileIDC: 100))
        #expect(AVCProfileIndication.requiresHighProfileFields(profileIDC: 122))
        #expect(!AVCProfileIndication.requiresHighProfileFields(profileIDC: 66))
    }
}

@Suite("AVCLevelIndication")
struct AVCLevelIndicationTests {

    @Test
    func level3IsThirty() {
        #expect(AVCLevelIndication.level3.rawValue == 30)
    }

    @Test
    func level4_1IsFortyOne() {
        #expect(AVCLevelIndication.level4_1.rawValue == 41)
    }

    @Test
    func level6_2IsSixtyTwo() {
        #expect(AVCLevelIndication.level6_2.rawValue == 62)
    }

    @Test
    func unknownLevelRejected() {
        #expect(AVCLevelIndication(rawValue: 99) == nil)
    }

    @Test
    func level9LegacyPreserved() {
        #expect(AVCLevelIndication.level9.rawValue == 9)
    }

    @Test
    func twentyDocumentedLevels() {
        // 20 standardised entries (10..62 plus reserved 9).
        #expect(AVCLevelIndication.allCases.count == 20)
    }
}

@Suite("AVCChromaFormat")
struct AVCChromaFormatTests {

    @Test
    func monochromeIsZero() {
        #expect(AVCChromaFormat.monochrome.rawValue == 0)
    }

    @Test
    func format420IsOne() {
        #expect(AVCChromaFormat.format420.rawValue == 1)
    }

    @Test
    func format444IsThree() {
        #expect(AVCChromaFormat.format444.rawValue == 3)
    }

    @Test
    func unknownRejected() {
        #expect(AVCChromaFormat(rawValue: 4) == nil)
    }
}

@Suite("AVCNALUnitType")
struct AVCNALUnitTypeTests {

    @Test
    func idrIsFive() {
        #expect(AVCNALUnitType.codedSliceIDR.rawValue == 5)
    }

    @Test
    func spsIsSeven() {
        #expect(AVCNALUnitType.sequenceParameterSet.rawValue == 7)
    }

    @Test
    func ppsIsEight() {
        #expect(AVCNALUnitType.pictureParameterSet.rawValue == 8)
    }

    @Test
    func count32Cases() {
        #expect(AVCNALUnitType.allCases.count == 32)
    }
}

@Suite("AVCProfileCompatibility")
struct AVCProfileCompatibilityTests {

    @Test
    func constructFromRawValueAllSet() {
        let c = AVCProfileCompatibility(rawValue: 0xFF)
        #expect(c.constraintSet0)
        #expect(c.constraintSet1)
        #expect(c.constraintSet5)
        #expect(c.reserved7)
        #expect(c.rawValue == 0xFF)
    }

    @Test
    func constructFromRawValueZero() {
        let c = AVCProfileCompatibility(rawValue: 0x00)
        #expect(!c.constraintSet0)
        #expect(c.rawValue == 0x00)
    }

    @Test
    func roundTripRawValue() {
        for raw in stride(from: 0, to: 256, by: 17) {
            let c = AVCProfileCompatibility(rawValue: UInt8(raw))
            #expect(c.rawValue == UInt8(raw))
        }
    }

    @Test
    func constraintSet0Maps0x80() {
        let c = AVCProfileCompatibility(constraintSet0: true)
        #expect(c.rawValue == 0x80)
    }

    @Test
    func constraintSet5Maps0x04() {
        let c = AVCProfileCompatibility(constraintSet5: true)
        #expect(c.rawValue == 0x04)
    }

    @Test
    func equatableHashableConformance() {
        let a = AVCProfileCompatibility(rawValue: 0x42)
        let b = AVCProfileCompatibility(rawValue: 0x42)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("AVCNALUnitHeader")
struct AVCNALUnitHeaderTests {

    @Test
    func parseIDRSliceWithHighestRefIdc() throws {
        // forbidden=0, refIdc=3 (11), type=5 (codedSliceIDR) → 0110_0101 = 0x65
        let header = try AVCNALUnitHeader.parse(byte: 0x65)
        #expect(header.forbiddenZeroBit == false)
        #expect(header.nalRefIdc == 3)
        #expect(header.nalUnitType == .codedSliceIDR)
        #expect(header.isReference == true)
    }

    @Test
    func parseNonIDRWithZeroRefIdc() throws {
        // forbidden=0, refIdc=0, type=1 → 0000_0001 = 0x01
        let header = try AVCNALUnitHeader.parse(byte: 0x01)
        #expect(header.nalRefIdc == 0)
        #expect(header.isReference == false)
        #expect(header.nalUnitType == .codedSliceNonIDR)
    }

    @Test
    func parseSequenceParameterSet() throws {
        // forbidden=0, refIdc=3, type=7 → 0110_0111 = 0x67
        let header = try AVCNALUnitHeader.parse(byte: 0x67)
        #expect(header.nalUnitType == .sequenceParameterSet)
        #expect(header.isReference == true)
    }

    @Test
    func parsePictureParameterSet() throws {
        // forbidden=0, refIdc=3, type=8 → 0110_1000 = 0x68
        let header = try AVCNALUnitHeader.parse(byte: 0x68)
        #expect(header.nalUnitType == .pictureParameterSet)
    }

    @Test
    func parseSEIWithZeroRefIdc() throws {
        // forbidden=0, refIdc=0, type=6 → 0000_0110 = 0x06
        let header = try AVCNALUnitHeader.parse(byte: 0x06)
        #expect(header.nalUnitType == .sei)
        #expect(header.isReference == false)
    }

    @Test
    func forbiddenZeroBitPreserved() throws {
        let header = try AVCNALUnitHeader.parse(byte: 0x80 | 0x07)  // SPS + forbidden=1
        #expect(header.forbiddenZeroBit == true)
        #expect(header.nalUnitType == .sequenceParameterSet)
    }

    @Test
    func encodeMatchesParseInput() throws {
        for byte: UInt8 in 0...0x1F where AVCNALUnitType(rawValue: byte) != nil {
            let header = try AVCNALUnitHeader.parse(byte: byte)
            #expect(header.encode() == byte)
        }
    }

    @Test
    func encodeWithAllRefIdcValues() throws {
        for refIdc: UInt8 in 0...3 {
            let header = AVCNALUnitHeader(
                nalRefIdc: refIdc,
                nalUnitType: .codedSliceNonIDR
            )
            let byte = header.encode()
            let parsed = try AVCNALUnitHeader.parse(byte: byte)
            #expect(parsed == header)
            #expect(parsed.isReference == (refIdc != 0))
        }
    }

    @Test
    func isReferenceFalseOnlyForZeroRefIdc() {
        for refIdc: UInt8 in 0...3 {
            let header = AVCNALUnitHeader(
                nalRefIdc: refIdc,
                nalUnitType: .codedSliceNonIDR
            )
            #expect(header.isReference == (refIdc != 0))
        }
    }

    @Test
    func parseAccessUnitDelimiter() throws {
        // refIdc=0, type=9 → 0000_1001 = 0x09
        let header = try AVCNALUnitHeader.parse(byte: 0x09)
        #expect(header.nalUnitType == .accessUnitDelimiter)
    }

    @Test
    func roundTripAllValidTypes() throws {
        for type in AVCNALUnitType.allCases {
            for refIdc: UInt8 in 0...3 {
                let header = AVCNALUnitHeader(nalRefIdc: refIdc, nalUnitType: type)
                let byte = header.encode()
                let parsed = try AVCNALUnitHeader.parse(byte: byte)
                #expect(parsed == header)
            }
        }
    }

    @Test
    func hashableEquatable() {
        let a = AVCNALUnitHeader(nalRefIdc: 3, nalUnitType: .codedSliceIDR)
        let b = AVCNALUnitHeader(nalRefIdc: 3, nalUnitType: .codedSliceIDR)
        let c = AVCNALUnitHeader(nalRefIdc: 0, nalUnitType: .codedSliceIDR)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }
}

@Suite("AVCNALUnitType helpers")
struct AVCNALUnitTypeHelperTests {

    @Test
    func isVCLForSlicesAndPartitions() {
        #expect(AVCNALUnitType.codedSliceNonIDR.isVCL == true)
        #expect(AVCNALUnitType.codedSliceIDR.isVCL == true)
        #expect(AVCNALUnitType.codedSliceDataPartitionA.isVCL == true)
        #expect(AVCNALUnitType.codedSliceDataPartitionB.isVCL == true)
        #expect(AVCNALUnitType.codedSliceDataPartitionC.isVCL == true)
    }

    @Test
    func isVCLFalseForNonVCL() {
        #expect(AVCNALUnitType.sei.isVCL == false)
        #expect(AVCNALUnitType.sequenceParameterSet.isVCL == false)
        #expect(AVCNALUnitType.pictureParameterSet.isVCL == false)
        #expect(AVCNALUnitType.accessUnitDelimiter.isVCL == false)
        #expect(AVCNALUnitType.endOfSequence.isVCL == false)
        #expect(AVCNALUnitType.endOfStream.isVCL == false)
        #expect(AVCNALUnitType.fillerData.isVCL == false)
    }

    @Test
    func isIDROnlyForIDRSlice() {
        for type in AVCNALUnitType.allCases {
            #expect(type.isIDR == (type == .codedSliceIDR))
        }
    }

    @Test
    func isParameterSetFamily() {
        #expect(AVCNALUnitType.sequenceParameterSet.isParameterSet == true)
        #expect(AVCNALUnitType.pictureParameterSet.isParameterSet == true)
        #expect(AVCNALUnitType.sequenceParameterSetExtension.isParameterSet == true)
        #expect(AVCNALUnitType.subsetSequenceParameterSet.isParameterSet == true)
        #expect(AVCNALUnitType.depthParameterSet.isParameterSet == true)
        #expect(AVCNALUnitType.codedSliceIDR.isParameterSet == false)
    }

    @Test
    func isReservedFlagsReserved17_18_22_23() {
        #expect(AVCNALUnitType.reserved17.isReserved == true)
        #expect(AVCNALUnitType.reserved18.isReserved == true)
        #expect(AVCNALUnitType.reserved22.isReserved == true)
        #expect(AVCNALUnitType.reserved23.isReserved == true)
        #expect(AVCNALUnitType.sei.isReserved == false)
    }

    @Test
    func isUnspecifiedFlagsZeroAnd24Through31() {
        #expect(AVCNALUnitType.unspecified0.isUnspecified == true)
        for raw: UInt8 in 24...31 {
            let type = AVCNALUnitType(rawValue: raw)
            #expect(type?.isUnspecified == true)
        }
        #expect(AVCNALUnitType.codedSliceIDR.isUnspecified == false)
    }

    @Test
    func allCasesHas32Values() {
        #expect(AVCNALUnitType.allCases.count == 32)
    }
}

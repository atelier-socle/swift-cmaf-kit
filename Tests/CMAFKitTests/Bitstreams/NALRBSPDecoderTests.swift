// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("NALRBSPDecoder")
struct NALRBSPDecoderTests {

    @Test
    func noEscapeSequencePassesThrough() {
        let bytes = Data([0x12, 0x34, 0x56, 0x78])
        #expect(NALRBSPDecoder.ebspToRBSP(bytes) == bytes)
        #expect(NALRBSPDecoder.rbspToEBSP(bytes) == bytes)
    }

    @Test
    func emptyDataRoundTrip() {
        let empty = Data()
        #expect(NALRBSPDecoder.ebspToRBSP(empty) == empty)
        #expect(NALRBSPDecoder.rbspToEBSP(empty) == empty)
    }

    @Test
    func ebspStripsEmulationByte() {
        // 0x00 0x00 0x03 0x01 → 0x00 0x00 0x01
        let ebsp = Data([0x00, 0x00, 0x03, 0x01])
        #expect(NALRBSPDecoder.ebspToRBSP(ebsp) == Data([0x00, 0x00, 0x01]))
    }

    @Test
    func rbspInsertsEmulationByte() {
        // 0x00 0x00 0x01 → 0x00 0x00 0x03 0x01
        let rbsp = Data([0x00, 0x00, 0x01])
        #expect(NALRBSPDecoder.rbspToEBSP(rbsp) == Data([0x00, 0x00, 0x03, 0x01]))
    }

    @Test
    func roundTripPreservesPayload() {
        let rbsp = Data([0x67, 0x42, 0x00, 0x00, 0x01, 0x00, 0x00, 0x02, 0x00, 0x00, 0x03])
        let ebsp = NALRBSPDecoder.rbspToEBSP(rbsp)
        let recovered = NALRBSPDecoder.ebspToRBSP(ebsp)
        #expect(recovered == rbsp)
    }

    @Test
    func roundTripWithDoubleZeros() {
        // 0x00 0x00 0x00 must escape the third zero.
        let rbsp = Data([0x00, 0x00, 0x00])
        let ebsp = NALRBSPDecoder.rbspToEBSP(rbsp)
        #expect(ebsp == Data([0x00, 0x00, 0x03, 0x00]))
        #expect(NALRBSPDecoder.ebspToRBSP(ebsp) == rbsp)
    }

    @Test
    func roundTripWithEscapedThree() {
        let rbsp = Data([0x00, 0x00, 0x03])
        let ebsp = NALRBSPDecoder.rbspToEBSP(rbsp)
        #expect(ebsp == Data([0x00, 0x00, 0x03, 0x03]))
        #expect(NALRBSPDecoder.ebspToRBSP(ebsp) == rbsp)
    }

    @Test
    func consecutiveZerosResetAfterNonZero() {
        // 0x00 0x00 0x42 0x00 0x00 0x01 → second 00 00 01 escapes
        let rbsp = Data([0x00, 0x00, 0x42, 0x00, 0x00, 0x01])
        let ebsp = NALRBSPDecoder.rbspToEBSP(rbsp)
        #expect(ebsp == Data([0x00, 0x00, 0x42, 0x00, 0x00, 0x03, 0x01]))
        #expect(NALRBSPDecoder.ebspToRBSP(ebsp) == rbsp)
    }

    @Test
    func consecutiveEscapeSequences() {
        // 0x00 0x00 0x00 0x00 0x01 → 0x00 0x00 0x03 0x00 0x00 0x01 (but
        // the trailing 0x00 0x00 0x01 still triggers an escape).
        let rbsp = Data([0x00, 0x00, 0x00, 0x00, 0x01])
        let ebsp = NALRBSPDecoder.rbspToEBSP(rbsp)
        let recovered = NALRBSPDecoder.ebspToRBSP(ebsp)
        #expect(recovered == rbsp)
    }

    @Test
    func longerSequencePreservesIntegrity() {
        var rbsp = Data()
        for byte in 0..<256 {
            rbsp.append(UInt8(byte))
        }
        let ebsp = NALRBSPDecoder.rbspToEBSP(rbsp)
        #expect(NALRBSPDecoder.ebspToRBSP(ebsp) == rbsp)
    }

    @Test
    func realWorldAVCSPSPrefixIsByteIdentical() {
        // First few bytes of a typical 1080p Baseline SPS without any
        // 0x00 0x00 0xXX runs in the prefix — passes through unchanged.
        let bytes = Data([0x67, 0x42, 0xC0, 0x1F, 0xDA, 0x01, 0x40, 0x16])
        #expect(NALRBSPDecoder.rbspToEBSP(bytes) == bytes)
        #expect(NALRBSPDecoder.ebspToRBSP(bytes) == bytes)
    }

    @Test
    func zeroAlone() {
        let bytes = Data([0x00])
        #expect(NALRBSPDecoder.rbspToEBSP(bytes) == bytes)
        #expect(NALRBSPDecoder.ebspToRBSP(bytes) == bytes)
    }
}

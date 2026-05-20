// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage lift for ``HEVCPPS3DExtension``. The parser has four
// branches: not present, present with single DLT entry where
// dltFlag=false, present with dltFlag=true (with predFlag true/false),
// and multi-layer (depthLayerCount > 1).

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCPPS3DExtension — coverage lift")
struct HEVCPPS3DExtensionCoverageLiftTests {

    @Test
    func dltsAbsentRoundTrip() throws {
        let ext = HEVCPPS3DExtension(dltsPresentFlag: false)
        var writer = BitWriter()
        ext.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try HEVCPPS3DExtension.parse(reader: &reader)
        #expect(decoded.dltsPresentFlag == false)
        #expect(decoded.dlts == nil)
    }

    @Test
    func dltsPresentSingleEntryDltFlagFalse() throws {
        let ext = HEVCPPS3DExtension(
            dltsPresentFlag: true,
            dlts: [HEVCPPS3DExtension.DLTEntry(dltFlag: false)]
        )
        var writer = BitWriter()
        ext.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try HEVCPPS3DExtension.parse(reader: &reader)
        #expect(decoded.dltsPresentFlag)
        #expect(decoded.dlts?.count == 1)
        #expect(decoded.dlts?[0].dltFlag == false)
    }

    @Test
    func dltsPresentSingleEntryDltFlagTruePredFlagTrue() throws {
        let ext = HEVCPPS3DExtension(
            dltsPresentFlag: true,
            dlts: [
                HEVCPPS3DExtension.DLTEntry(
                    dltFlag: true,
                    dltPredFlag: true
                )
            ]
        )
        var writer = BitWriter()
        ext.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try HEVCPPS3DExtension.parse(reader: &reader)
        #expect(decoded.dlts?.first?.dltFlag == true)
        #expect(decoded.dlts?.first?.dltPredFlag == true)
    }

    @Test
    func dltsPresentSingleEntryDltFlagTruePredFlagFalse() throws {
        let ext = HEVCPPS3DExtension(
            dltsPresentFlag: true,
            dlts: [
                HEVCPPS3DExtension.DLTEntry(
                    dltFlag: true,
                    dltPredFlag: false
                )
            ]
        )
        var writer = BitWriter()
        ext.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try HEVCPPS3DExtension.parse(reader: &reader)
        #expect(decoded.dlts?.first?.dltFlag == true)
        #expect(decoded.dlts?.first?.dltPredFlag == false)
    }

    @Test
    func multiLayerWithMixedFlags() throws {
        let ext = HEVCPPS3DExtension(
            dltsPresentFlag: true,
            dlts: [
                HEVCPPS3DExtension.DLTEntry(dltFlag: false),
                HEVCPPS3DExtension.DLTEntry(dltFlag: true, dltPredFlag: true),
                HEVCPPS3DExtension.DLTEntry(dltFlag: true, dltPredFlag: false)
            ]
        )
        var writer = BitWriter()
        ext.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        let decoded = try HEVCPPS3DExtension.parse(reader: &reader, depthLayerCount: 3)
        try #require(decoded.dlts?.count == 3)
        #expect(decoded.dlts?[0].dltFlag == false)
        #expect(decoded.dlts?[1].dltFlag == true)
        #expect(decoded.dlts?[1].dltPredFlag == true)
        #expect(decoded.dlts?[2].dltFlag == true)
        #expect(decoded.dlts?[2].dltPredFlag == false)
    }

    @Test
    func equatable() {
        let a = HEVCPPS3DExtension(dltsPresentFlag: false)
        let b = HEVCPPS3DExtension(dltsPresentFlag: false)
        #expect(a == b)
    }
}

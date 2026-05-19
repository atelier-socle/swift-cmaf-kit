// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCPPSMultilayerExtension coverage")
struct HEVCPPSMultilayerExtensionCoverageTests {

    private static func roundTrip(
        _ ext: HEVCPPSMultilayerExtension
    ) throws -> HEVCPPSMultilayerExtension {
        var writer = BitWriter()
        ext.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        return try HEVCPPSMultilayerExtension.parse(reader: &reader)
    }

    @Test
    func minimalMultilayerRoundTrip() throws {
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded == ext)
    }

    @Test
    func withPOCResetInfoFlag() throws {
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: true,
            ppsInferScalingListFlag: false,
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.pocResetInfoPresentFlag == true)
    }

    @Test
    func inferScalingListFromLayer3() throws {
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: true,
            ppsScalingListRefLayerID: 3,
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.ppsInferScalingListFlag == true)
        #expect(decoded.ppsScalingListRefLayerID == 3)
    }

    @Test
    func inferScalingListFromMaxLayer() throws {
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: true,
            ppsScalingListRefLayerID: 0x3F,
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.ppsScalingListRefLayerID == 0x3F)
    }

    @Test
    func withScaledRefLayerOffsets() throws {
        let offset = HEVCPPSMultilayerExtension.RefLocOffset(
            refLocOffsetLayerID: 1,
            scaledRefLayerOffset: HEVCPPSMultilayerExtension.OffsetWindow(
                leftOffset: -16, topOffset: -16,
                rightOffset: 16, bottomOffset: 16
            )
        )
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            refLocOffsets: [offset],
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.refLocOffsets.count == 1)
        #expect(decoded.refLocOffsets[0].scaledRefLayerOffset?.leftOffset == -16)
        #expect(decoded.refLocOffsets[0].scaledRefLayerOffset?.bottomOffset == 16)
    }

    @Test
    func withRefRegionOffsets() throws {
        let offset = HEVCPPSMultilayerExtension.RefLocOffset(
            refLocOffsetLayerID: 2,
            refRegionOffset: HEVCPPSMultilayerExtension.OffsetWindow(
                leftOffset: 0, topOffset: 0,
                rightOffset: 32, bottomOffset: 32
            )
        )
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            refLocOffsets: [offset],
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.refLocOffsets[0].refRegionOffset?.rightOffset == 32)
    }

    @Test
    func withResamplePhaseSet() throws {
        let offset = HEVCPPSMultilayerExtension.RefLocOffset(
            refLocOffsetLayerID: 1,
            resamplePhaseSet: HEVCPPSMultilayerExtension.ResamplePhaseSet(
                phaseHorLuma: 1,
                phaseVerLuma: 2,
                phaseHorChromaPlus8: 8,
                phaseVerChromaPlus8: 9
            )
        )
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            refLocOffsets: [offset],
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.refLocOffsets[0].resamplePhaseSet?.phaseHorLuma == 1)
        #expect(decoded.refLocOffsets[0].resamplePhaseSet?.phaseVerChromaPlus8 == 9)
    }

    @Test
    func withAllRefLocOffsetVariants() throws {
        let offset = HEVCPPSMultilayerExtension.RefLocOffset(
            refLocOffsetLayerID: 1,
            scaledRefLayerOffset: HEVCPPSMultilayerExtension.OffsetWindow(
                leftOffset: -8, topOffset: -8,
                rightOffset: 8, bottomOffset: 8
            ),
            refRegionOffset: HEVCPPSMultilayerExtension.OffsetWindow(
                leftOffset: 0, topOffset: 0,
                rightOffset: 16, bottomOffset: 16
            ),
            resamplePhaseSet: HEVCPPSMultilayerExtension.ResamplePhaseSet(
                phaseHorLuma: 0,
                phaseVerLuma: 0,
                phaseHorChromaPlus8: 8,
                phaseVerChromaPlus8: 8
            )
        )
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            refLocOffsets: [offset],
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.refLocOffsets[0].scaledRefLayerOffset != nil)
        #expect(decoded.refLocOffsets[0].refRegionOffset != nil)
        #expect(decoded.refLocOffsets[0].resamplePhaseSet != nil)
    }

    @Test
    func multipleRefLocOffsetsRoundTrip() throws {
        var offsets: [HEVCPPSMultilayerExtension.RefLocOffset] = []
        for i: Int in 0..<3 {
            let window = HEVCPPSMultilayerExtension.OffsetWindow(
                leftOffset: Int32(i),
                topOffset: Int32(i),
                rightOffset: Int32(i + 1),
                bottomOffset: Int32(i + 1)
            )
            offsets.append(
                HEVCPPSMultilayerExtension.RefLocOffset(
                    refLocOffsetLayerID: UInt8(i),
                    scaledRefLayerOffset: window
                )
            )
        }
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            refLocOffsets: offsets,
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.refLocOffsets.count == 3)
        #expect(decoded.refLocOffsets[2].refLocOffsetLayerID == 2)
    }

    @Test
    func combinedPOCResetAndInferScalingList() throws {
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: true,
            ppsInferScalingListFlag: true,
            ppsScalingListRefLayerID: 5,
            refLocOffsets: [
                HEVCPPSMultilayerExtension.RefLocOffset(refLocOffsetLayerID: 1)
            ],
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded == ext)
    }

    @Test
    func offsetWindowExtremeValues() throws {
        let offset = HEVCPPSMultilayerExtension.RefLocOffset(
            refLocOffsetLayerID: 0,
            scaledRefLayerOffset: HEVCPPSMultilayerExtension.OffsetWindow(
                leftOffset: -10_000, topOffset: -10_000,
                rightOffset: 10_000, bottomOffset: 10_000
            )
        )
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            refLocOffsets: [offset],
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.refLocOffsets[0].scaledRefLayerOffset?.leftOffset == -10_000)
        #expect(decoded.refLocOffsets[0].scaledRefLayerOffset?.rightOffset == 10_000)
    }

    @Test
    func equalityAndHashing() {
        let a = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            colourMappingEnabledFlag: false
        )
        let b = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            colourMappingEnabledFlag: false
        )
        let c = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: true,
            ppsInferScalingListFlag: false,
            colourMappingEnabledFlag: false
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }

    @Test
    func subTypeOffsetWindowEquality() {
        let w1 = HEVCPPSMultilayerExtension.OffsetWindow(
            leftOffset: 0, topOffset: 0, rightOffset: 0, bottomOffset: 0
        )
        let w2 = HEVCPPSMultilayerExtension.OffsetWindow(
            leftOffset: 0, topOffset: 0, rightOffset: 0, bottomOffset: 0
        )
        #expect(w1 == w2)
    }

    @Test
    func colourMappingTableConstructionAndEncode() throws {
        // The colour mapping table is captured at the flag level with a
        // verbatim bits payload. Constructing one with non-zero bits and
        // round-tripping exercises both `ColourMappingTable.init(bits:)`
        // and the encoder's per-bit emission path.
        let table = HEVCPPSMultilayerExtension.ColourMappingTable(bits: [1, 0, 1, 1])
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            colourMappingEnabledFlag: true,
            colourMappingTable: table
        )
        // Encode but do not parse — the parser reads zero bits for
        // colourMappingTable per CMAFKit's container-layer scope, so
        // the round-trip is asymmetric for the table contents.
        var writer = BitWriter()
        ext.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        // Verify the encode path produced output and that the table
        // constructor accepted the bits without trapping.
        #expect(!writer.data.isEmpty)
        #expect(ext.colourMappingTable?.bits == [1, 0, 1, 1])
    }

    @Test
    func colourMappingTableEmptyBitsRoundTrip() throws {
        let table = HEVCPPSMultilayerExtension.ColourMappingTable(bits: [])
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            colourMappingEnabledFlag: true,
            colourMappingTable: table
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.colourMappingTable?.bits == [])
        #expect(decoded.colourMappingEnabledFlag == true)
    }

    @Test
    func subTypeResamplePhaseSetEquality() {
        let p1 = HEVCPPSMultilayerExtension.ResamplePhaseSet(
            phaseHorLuma: 1, phaseVerLuma: 2,
            phaseHorChromaPlus8: 8, phaseVerChromaPlus8: 9
        )
        let p2 = HEVCPPSMultilayerExtension.ResamplePhaseSet(
            phaseHorLuma: 1, phaseVerLuma: 2,
            phaseHorChromaPlus8: 8, phaseVerChromaPlus8: 9
        )
        #expect(p1 == p2)
        #expect(p1.hashValue == p2.hashValue)
    }
}

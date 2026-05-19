// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCPPSRangeExtension")
struct HEVCPPSRangeExtensionTests {

    private static func roundTrip(
        _ ext: HEVCPPSRangeExtension,
        transformSkipEnabledFlag: Bool
    ) throws -> HEVCPPSRangeExtension {
        var writer = BitWriter()
        ext.encode(to: &writer, transformSkipEnabledFlag: transformSkipEnabledFlag)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        return try HEVCPPSRangeExtension.parse(
            reader: &reader, transformSkipEnabledFlag: transformSkipEnabledFlag
        )
    }

    @Test
    func minimalRoundTrip() throws {
        let ext = HEVCPPSRangeExtension(
            crossComponentPredictionEnabledFlag: false,
            chromaQPOffsetListEnabledFlag: false,
            log2SAOOffsetScaleLuma: 0,
            log2SAOOffsetScaleChroma: 0
        )
        let decoded = try Self.roundTrip(ext, transformSkipEnabledFlag: false)
        #expect(decoded == ext)
    }

    @Test
    func withTransformSkipMaxSize() throws {
        let ext = HEVCPPSRangeExtension(
            log2MaxTransformSkipBlockSizeMinus2: 3,
            crossComponentPredictionEnabledFlag: false,
            chromaQPOffsetListEnabledFlag: false,
            log2SAOOffsetScaleLuma: 0,
            log2SAOOffsetScaleChroma: 0
        )
        let decoded = try Self.roundTrip(ext, transformSkipEnabledFlag: true)
        #expect(decoded.log2MaxTransformSkipBlockSizeMinus2 == 3)
    }

    @Test
    func withChromaQPOffsetList() throws {
        let ext = HEVCPPSRangeExtension(
            crossComponentPredictionEnabledFlag: true,
            chromaQPOffsetListEnabledFlag: true,
            chromaQPOffsetList: HEVCPPSRangeExtension.ChromaQPOffsetList(
                diffCuChromaQPOffsetDepth: 0,
                chromaQPOffsetListLenMinus1: 1,
                cbQPOffsetList: [-2, 2],
                crQPOffsetList: [-1, 1]
            ),
            log2SAOOffsetScaleLuma: 2,
            log2SAOOffsetScaleChroma: 1
        )
        let decoded = try Self.roundTrip(ext, transformSkipEnabledFlag: false)
        #expect(decoded == ext)
        #expect(decoded.chromaQPOffsetList?.cbQPOffsetList == [-2, 2])
    }
}

@Suite("HEVCPPSSCCExtension")
struct HEVCPPSSCCExtensionTests {

    private static func roundTrip(_ ext: HEVCPPSSCCExtension) throws -> HEVCPPSSCCExtension {
        var writer = BitWriter()
        ext.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        return try HEVCPPSSCCExtension.parse(reader: &reader)
    }

    @Test
    func minimalRoundTrip() throws {
        let ext = HEVCPPSSCCExtension(
            ppsCurrPicRefEnabledFlag: false,
            residualAdaptiveColourTransformEnabledFlag: false,
            palettePredictorInitializersPresentFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded == ext)
    }

    @Test
    func colourTransformRoundTrip() throws {
        let ext = HEVCPPSSCCExtension(
            ppsCurrPicRefEnabledFlag: true,
            residualAdaptiveColourTransformEnabledFlag: true,
            colourTransform: HEVCPPSSCCExtension.ColourTransform(
                ppsSliceActQPOffsetsPresentFlag: true,
                actYQPOffsetPlus5: 0,
                actCbQPOffsetPlus5: 0,
                actCrQPOffsetPlus3: 0
            ),
            palettePredictorInitializersPresentFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded == ext)
    }

    @Test
    func monochromePaletteRoundTrip() throws {
        let ext = HEVCPPSSCCExtension(
            ppsCurrPicRefEnabledFlag: true,
            residualAdaptiveColourTransformEnabledFlag: false,
            palettePredictorInitializersPresentFlag: true,
            palettePredictorInitializers: HEVCPPSSCCExtension.PalettePredictorInitializers(
                monochromePaletteFlag: true,
                lumaBitDepthEntryMinus8: 0,
                numPalettePredictorInitializerMinus1: 1,
                initializers: [[100, 200]]
            )
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded == ext)
    }

    @Test
    func colorPaletteRoundTrip() throws {
        let ext = HEVCPPSSCCExtension(
            ppsCurrPicRefEnabledFlag: true,
            residualAdaptiveColourTransformEnabledFlag: false,
            palettePredictorInitializersPresentFlag: true,
            palettePredictorInitializers: HEVCPPSSCCExtension.PalettePredictorInitializers(
                monochromePaletteFlag: false,
                lumaBitDepthEntryMinus8: 0,
                chromaBitDepthEntryMinus8: 0,
                numPalettePredictorInitializerMinus1: 1,
                initializers: [[100, 200], [50, 60], [30, 40]]
            )
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded == ext)
    }
}

@Suite("HEVCPPSMultilayerExtension")
struct HEVCPPSMultilayerExtensionTests {

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
    func minimalRoundTrip() throws {
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: false,
            ppsInferScalingListFlag: false,
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded == ext)
    }

    @Test
    func withScalingListRefLayer() throws {
        let ext = HEVCPPSMultilayerExtension(
            pocResetInfoPresentFlag: true,
            ppsInferScalingListFlag: true,
            ppsScalingListRefLayerID: 3,
            colourMappingEnabledFlag: false
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded.ppsScalingListRefLayerID == 3)
    }

    @Test
    func withRefLocOffsetsRoundTrip() throws {
        let offset = HEVCPPSMultilayerExtension.RefLocOffset(
            refLocOffsetLayerID: 1,
            scaledRefLayerOffset: HEVCPPSMultilayerExtension.OffsetWindow(
                leftOffset: 0, topOffset: 0, rightOffset: 0, bottomOffset: 0
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
    }
}

@Suite("HEVCPPS3DExtension")
struct HEVCPPS3DExtensionTests {

    private static func roundTrip(_ ext: HEVCPPS3DExtension) throws -> HEVCPPS3DExtension {
        var writer = BitWriter()
        ext.encode(to: &writer)
        writer.writeBit(1)
        writer.byteAlign()
        var reader = BitReader(writer.data)
        return try HEVCPPS3DExtension.parse(reader: &reader)
    }

    @Test
    func noDLTsRoundTrip() throws {
        let ext = HEVCPPS3DExtension(dltsPresentFlag: false)
        let decoded = try Self.roundTrip(ext)
        #expect(decoded == ext)
    }

    @Test
    func dltsFlagSetSingleLayerRoundTrip() throws {
        let ext = HEVCPPS3DExtension(
            dltsPresentFlag: true,
            dlts: [HEVCPPS3DExtension.DLTEntry(dltFlag: false)]
        )
        let decoded = try Self.roundTrip(ext)
        #expect(decoded == ext)
    }
}

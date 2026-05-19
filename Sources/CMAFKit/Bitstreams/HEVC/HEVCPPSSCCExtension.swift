// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCPPSSCCExtension
//
// Reference: ITU-T H.265 §7.3.2.3.3 (pps_scc_extension).

import Foundation

/// HEVC PPS screen-content-coding extension per ITU-T H.265 §7.3.2.3.3.
public struct HEVCPPSSCCExtension: Sendable, Hashable, Equatable {

    /// Adaptive colour transform fields, present iff
    /// `residual_adaptive_colour_transform_enabled_flag == 1`.
    public struct ColourTransform: Sendable, Hashable, Equatable {
        public let ppsSliceActQPOffsetsPresentFlag: Bool
        public let actYQPOffsetPlus5: Int32
        public let actCbQPOffsetPlus5: Int32
        public let actCrQPOffsetPlus3: Int32

        public init(
            ppsSliceActQPOffsetsPresentFlag: Bool,
            actYQPOffsetPlus5: Int32,
            actCbQPOffsetPlus5: Int32,
            actCrQPOffsetPlus3: Int32
        ) {
            self.ppsSliceActQPOffsetsPresentFlag = ppsSliceActQPOffsetsPresentFlag
            self.actYQPOffsetPlus5 = actYQPOffsetPlus5
            self.actCbQPOffsetPlus5 = actCbQPOffsetPlus5
            self.actCrQPOffsetPlus3 = actCrQPOffsetPlus3
        }
    }

    /// Palette predictor initialisers, present iff
    /// `pps_palette_predictor_initializers_present_flag == 1`.
    public struct PalettePredictorInitializers: Sendable, Hashable, Equatable {
        public let monochromePaletteFlag: Bool
        public let lumaBitDepthEntryMinus8: UInt32
        /// Present iff `!monochromePaletteFlag`.
        public let chromaBitDepthEntryMinus8: UInt32?
        public let numPalettePredictorInitializerMinus1: UInt32
        /// `initializers[componentIndex][initIndex]`. Outer count is 1
        /// for monochrome and 3 otherwise; inner count is
        /// `numPalettePredictorInitializerMinus1 + 1`.
        public let initializers: [[UInt32]]

        public init(
            monochromePaletteFlag: Bool,
            lumaBitDepthEntryMinus8: UInt32,
            chromaBitDepthEntryMinus8: UInt32? = nil,
            numPalettePredictorInitializerMinus1: UInt32,
            initializers: [[UInt32]]
        ) {
            precondition(
                monochromePaletteFlag == (chromaBitDepthEntryMinus8 == nil),
                "chromaBitDepthEntryMinus8 presence must match !monochromePaletteFlag"
            )
            self.monochromePaletteFlag = monochromePaletteFlag
            self.lumaBitDepthEntryMinus8 = lumaBitDepthEntryMinus8
            self.chromaBitDepthEntryMinus8 = chromaBitDepthEntryMinus8
            self.numPalettePredictorInitializerMinus1 = numPalettePredictorInitializerMinus1
            self.initializers = initializers
        }
    }

    public let ppsCurrPicRefEnabledFlag: Bool
    public let residualAdaptiveColourTransformEnabledFlag: Bool
    public let colourTransform: ColourTransform?
    public let palettePredictorInitializersPresentFlag: Bool
    public let palettePredictorInitializers: PalettePredictorInitializers?

    public init(
        ppsCurrPicRefEnabledFlag: Bool,
        residualAdaptiveColourTransformEnabledFlag: Bool,
        colourTransform: ColourTransform? = nil,
        palettePredictorInitializersPresentFlag: Bool,
        palettePredictorInitializers: PalettePredictorInitializers? = nil
    ) {
        precondition(
            residualAdaptiveColourTransformEnabledFlag == (colourTransform != nil),
            "colourTransform presence must match residualAdaptiveColourTransformEnabledFlag"
        )
        precondition(
            palettePredictorInitializersPresentFlag == (palettePredictorInitializers != nil),
            "palettePredictorInitializers presence must match the flag"
        )
        self.ppsCurrPicRefEnabledFlag = ppsCurrPicRefEnabledFlag
        self.residualAdaptiveColourTransformEnabledFlag = residualAdaptiveColourTransformEnabledFlag
        self.colourTransform = colourTransform
        self.palettePredictorInitializersPresentFlag = palettePredictorInitializersPresentFlag
        self.palettePredictorInitializers = palettePredictorInitializers
    }

    public static func parse(reader: inout BitReader) throws -> HEVCPPSSCCExtension {
        let currPicRef = try reader.readBool()
        let residualEnabled = try reader.readBool()
        var transform: ColourTransform?
        if residualEnabled {
            let actQPPresent = try reader.readBool()
            let actY = try reader.readSignedExpGolomb()
            let actCb = try reader.readSignedExpGolomb()
            let actCr = try reader.readSignedExpGolomb()
            transform = ColourTransform(
                ppsSliceActQPOffsetsPresentFlag: actQPPresent,
                actYQPOffsetPlus5: actY,
                actCbQPOffsetPlus5: actCb,
                actCrQPOffsetPlus3: actCr
            )
        }
        let predPresent = try reader.readBool()
        var palette: PalettePredictorInitializers?
        if predPresent {
            palette = try parsePalette(reader: &reader)
        }
        return HEVCPPSSCCExtension(
            ppsCurrPicRefEnabledFlag: currPicRef,
            residualAdaptiveColourTransformEnabledFlag: residualEnabled,
            colourTransform: transform,
            palettePredictorInitializersPresentFlag: predPresent,
            palettePredictorInitializers: palette
        )
    }

    private static func parsePalette(
        reader: inout BitReader
    ) throws -> PalettePredictorInitializers {
        let mono = try reader.readBool()
        let lumaBitDepth = try reader.readUnsignedExpGolomb()
        var chromaBitDepth: UInt32?
        if !mono {
            chromaBitDepth = try reader.readUnsignedExpGolomb()
        }
        let numMinus1 = try reader.readUnsignedExpGolomb()
        let componentCount = mono ? 1 : 3
        var inits: [[UInt32]] = []
        inits.reserveCapacity(componentCount)
        for component in 0..<componentCount {
            let bits =
                component == 0
                ? Int(lumaBitDepth) + 8
                : Int(chromaBitDepth ?? 0) + 8
            var entries: [UInt32] = []
            entries.reserveCapacity(Int(numMinus1) + 1)
            for _ in 0...numMinus1 {
                entries.append(UInt32(try reader.readBits(bits)))
            }
            inits.append(entries)
        }
        return PalettePredictorInitializers(
            monochromePaletteFlag: mono,
            lumaBitDepthEntryMinus8: lumaBitDepth,
            chromaBitDepthEntryMinus8: chromaBitDepth,
            numPalettePredictorInitializerMinus1: numMinus1,
            initializers: inits
        )
    }

    public func encode(to writer: inout BitWriter) {
        writer.writeBool(ppsCurrPicRefEnabledFlag)
        writer.writeBool(residualAdaptiveColourTransformEnabledFlag)
        if let t = colourTransform {
            writer.writeBool(t.ppsSliceActQPOffsetsPresentFlag)
            writer.writeSignedExpGolomb(t.actYQPOffsetPlus5)
            writer.writeSignedExpGolomb(t.actCbQPOffsetPlus5)
            writer.writeSignedExpGolomb(t.actCrQPOffsetPlus3)
        }
        writer.writeBool(palettePredictorInitializersPresentFlag)
        if let palette = palettePredictorInitializers {
            writer.writeBool(palette.monochromePaletteFlag)
            writer.writeUnsignedExpGolomb(palette.lumaBitDepthEntryMinus8)
            if !palette.monochromePaletteFlag {
                writer.writeUnsignedExpGolomb(palette.chromaBitDepthEntryMinus8 ?? 0)
            }
            writer.writeUnsignedExpGolomb(palette.numPalettePredictorInitializerMinus1)
            for (component, entries) in palette.initializers.enumerated() {
                let bits =
                    component == 0
                    ? Int(palette.lumaBitDepthEntryMinus8) + 8
                    : Int(palette.chromaBitDepthEntryMinus8 ?? 0) + 8
                for v in entries {
                    writer.writeBits(UInt64(v), count: bits)
                }
            }
        }
    }
}

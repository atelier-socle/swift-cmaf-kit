// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCPictureParameterSet
//
// Reference: ITU-T H.265 §7.3.2.3 (pic_parameter_set_rbsp).

import Foundation

/// HEVC picture parameter set per ITU-T H.265 §7.3.2.3.
public struct HEVCPictureParameterSet: Sendable, Hashable, Equatable {

    /// Tile layout subtree present iff `tilesEnabledFlag == true`.
    public struct TileInfo: Sendable, Hashable, Equatable {
        public let numTileColumnsMinus1: UInt32
        public let numTileRowsMinus1: UInt32
        public let uniformSpacingFlag: Bool
        public let columnWidthMinus1: [UInt32]
        public let rowHeightMinus1: [UInt32]
        public let loopFilterAcrossTilesEnabledFlag: Bool

        public init(
            numTileColumnsMinus1: UInt32,
            numTileRowsMinus1: UInt32,
            uniformSpacingFlag: Bool,
            columnWidthMinus1: [UInt32] = [],
            rowHeightMinus1: [UInt32] = [],
            loopFilterAcrossTilesEnabledFlag: Bool
        ) {
            self.numTileColumnsMinus1 = numTileColumnsMinus1
            self.numTileRowsMinus1 = numTileRowsMinus1
            self.uniformSpacingFlag = uniformSpacingFlag
            self.columnWidthMinus1 = columnWidthMinus1
            self.rowHeightMinus1 = rowHeightMinus1
            self.loopFilterAcrossTilesEnabledFlag = loopFilterAcrossTilesEnabledFlag
        }
    }

    /// Deblocking filter control subtree.
    public struct DeblockingControl: Sendable, Hashable, Equatable {
        public let overrideEnabledFlag: Bool
        public let disabledFlag: Bool
        public let betaOffsetDiv2: Int32?
        public let tcOffsetDiv2: Int32?

        public init(
            overrideEnabledFlag: Bool,
            disabledFlag: Bool,
            betaOffsetDiv2: Int32? = nil,
            tcOffsetDiv2: Int32? = nil
        ) {
            self.overrideEnabledFlag = overrideEnabledFlag
            self.disabledFlag = disabledFlag
            self.betaOffsetDiv2 = betaOffsetDiv2
            self.tcOffsetDiv2 = tcOffsetDiv2
        }
    }

    /// Extension flag set (5 single-bit flags + 3 reserved bits).
    public struct ExtensionFlags: Sendable, Hashable, Equatable {
        public let rangeExtensionFlag: Bool
        public let multilayerExtensionFlag: Bool
        public let threeDExtensionFlag: Bool
        public let screenContentExtensionFlag: Bool
        public let reservedBits: UInt8

        public init(
            rangeExtensionFlag: Bool,
            multilayerExtensionFlag: Bool,
            threeDExtensionFlag: Bool,
            screenContentExtensionFlag: Bool,
            reservedBits: UInt8 = 0
        ) {
            precondition(reservedBits <= 0x0F, "reservedBits must fit 4 bits")
            self.rangeExtensionFlag = rangeExtensionFlag
            self.multilayerExtensionFlag = multilayerExtensionFlag
            self.threeDExtensionFlag = threeDExtensionFlag
            self.screenContentExtensionFlag = screenContentExtensionFlag
            self.reservedBits = reservedBits
        }
    }

    public let ppsID: UInt32
    public let spsID: UInt32
    public let dependentSliceSegmentsEnabledFlag: Bool
    public let outputFlagPresentFlag: Bool
    public let numExtraSliceHeaderBits: UInt8
    public let signDataHidingEnabledFlag: Bool
    public let cabacInitPresentFlag: Bool
    public let numRefIdxL0DefaultActiveMinus1: UInt32
    public let numRefIdxL1DefaultActiveMinus1: UInt32
    public let initQPMinus26: Int32
    public let constrainedIntraPredFlag: Bool
    public let transformSkipEnabledFlag: Bool
    public let cuQPDeltaEnabledFlag: Bool
    public let diffCuQPDeltaDepth: UInt32?
    public let cbQPOffset: Int32
    public let crQPOffset: Int32
    public let sliceChromaQPOffsetsPresentFlag: Bool
    public let weightedPredFlag: Bool
    public let weightedBipredFlag: Bool
    public let transquantBypassEnabledFlag: Bool
    public let entropyCodingSyncEnabledFlag: Bool
    public let tileInfo: TileInfo?
    public let loopFilterAcrossSlicesEnabledFlag: Bool
    public let deblockingControl: DeblockingControl?
    public let scalingListData: HEVCScalingListData?
    public let listsModificationPresentFlag: Bool
    public let log2ParallelMergeLevelMinus2: UInt32
    public let sliceSegmentHeaderExtensionPresentFlag: Bool
    public let extensionFlags: ExtensionFlags?
    /// Range Extension body — present iff `extensionFlags?.rangeExtensionFlag == true`.
    public let rangeExtension: HEVCPPSRangeExtension?
    /// Multilayer Extension body (SHVC / MV-HEVC) — present iff
    /// `extensionFlags?.multilayerExtensionFlag == true`.
    public let multilayerExtension: HEVCPPSMultilayerExtension?
    /// 3D-HEVC Extension body — present iff
    /// `extensionFlags?.threeDExtensionFlag == true`.
    public let threeDExtension: HEVCPPS3DExtension?
    /// Screen Content Coding Extension body — present iff
    /// `extensionFlags?.screenContentExtensionFlag == true`.
    public let sccExtension: HEVCPPSSCCExtension?

    public init(
        ppsID: UInt32,
        spsID: UInt32,
        dependentSliceSegmentsEnabledFlag: Bool,
        outputFlagPresentFlag: Bool,
        numExtraSliceHeaderBits: UInt8,
        signDataHidingEnabledFlag: Bool,
        cabacInitPresentFlag: Bool,
        numRefIdxL0DefaultActiveMinus1: UInt32,
        numRefIdxL1DefaultActiveMinus1: UInt32,
        initQPMinus26: Int32,
        constrainedIntraPredFlag: Bool,
        transformSkipEnabledFlag: Bool,
        cuQPDeltaEnabledFlag: Bool,
        diffCuQPDeltaDepth: UInt32? = nil,
        cbQPOffset: Int32,
        crQPOffset: Int32,
        sliceChromaQPOffsetsPresentFlag: Bool,
        weightedPredFlag: Bool,
        weightedBipredFlag: Bool,
        transquantBypassEnabledFlag: Bool,
        entropyCodingSyncEnabledFlag: Bool,
        tileInfo: TileInfo? = nil,
        loopFilterAcrossSlicesEnabledFlag: Bool,
        deblockingControl: DeblockingControl? = nil,
        scalingListData: HEVCScalingListData? = nil,
        listsModificationPresentFlag: Bool,
        log2ParallelMergeLevelMinus2: UInt32,
        sliceSegmentHeaderExtensionPresentFlag: Bool,
        extensionFlags: ExtensionFlags? = nil,
        rangeExtension: HEVCPPSRangeExtension? = nil,
        multilayerExtension: HEVCPPSMultilayerExtension? = nil,
        threeDExtension: HEVCPPS3DExtension? = nil,
        sccExtension: HEVCPPSSCCExtension? = nil
    ) {
        precondition(numExtraSliceHeaderBits <= 0x07, "numExtraSliceHeaderBits must fit 3 bits")
        precondition(
            cuQPDeltaEnabledFlag == (diffCuQPDeltaDepth != nil),
            "diffCuQPDeltaDepth presence must match cuQPDeltaEnabledFlag"
        )
        self.ppsID = ppsID
        self.spsID = spsID
        self.dependentSliceSegmentsEnabledFlag = dependentSliceSegmentsEnabledFlag
        self.outputFlagPresentFlag = outputFlagPresentFlag
        self.numExtraSliceHeaderBits = numExtraSliceHeaderBits
        self.signDataHidingEnabledFlag = signDataHidingEnabledFlag
        self.cabacInitPresentFlag = cabacInitPresentFlag
        self.numRefIdxL0DefaultActiveMinus1 = numRefIdxL0DefaultActiveMinus1
        self.numRefIdxL1DefaultActiveMinus1 = numRefIdxL1DefaultActiveMinus1
        self.initQPMinus26 = initQPMinus26
        self.constrainedIntraPredFlag = constrainedIntraPredFlag
        self.transformSkipEnabledFlag = transformSkipEnabledFlag
        self.cuQPDeltaEnabledFlag = cuQPDeltaEnabledFlag
        self.diffCuQPDeltaDepth = diffCuQPDeltaDepth
        self.cbQPOffset = cbQPOffset
        self.crQPOffset = crQPOffset
        self.sliceChromaQPOffsetsPresentFlag = sliceChromaQPOffsetsPresentFlag
        self.weightedPredFlag = weightedPredFlag
        self.weightedBipredFlag = weightedBipredFlag
        self.transquantBypassEnabledFlag = transquantBypassEnabledFlag
        self.entropyCodingSyncEnabledFlag = entropyCodingSyncEnabledFlag
        self.tileInfo = tileInfo
        self.loopFilterAcrossSlicesEnabledFlag = loopFilterAcrossSlicesEnabledFlag
        self.deblockingControl = deblockingControl
        self.scalingListData = scalingListData
        self.listsModificationPresentFlag = listsModificationPresentFlag
        self.log2ParallelMergeLevelMinus2 = log2ParallelMergeLevelMinus2
        self.sliceSegmentHeaderExtensionPresentFlag = sliceSegmentHeaderExtensionPresentFlag
        self.extensionFlags = extensionFlags
        self.rangeExtension = rangeExtension
        self.multilayerExtension = multilayerExtension
        self.threeDExtension = threeDExtension
        self.sccExtension = sccExtension
    }

    public static func parse(rbsp: Data) throws -> HEVCPictureParameterSet {
        var reader = BitReader(rbsp)
        let ppsID = try reader.readUnsignedExpGolomb()
        let spsID = try reader.readUnsignedExpGolomb()
        let depSlice = try reader.readBool()
        let outputFlagPresent = try reader.readBool()
        let extraSliceBits = UInt8(try reader.readBits(3))
        let signHiding = try reader.readBool()
        let cabacInit = try reader.readBool()
        let l0Default = try reader.readUnsignedExpGolomb()
        let l1Default = try reader.readUnsignedExpGolomb()
        let initQP = try reader.readSignedExpGolomb()
        let constrainedIntra = try reader.readBool()
        let transformSkip = try reader.readBool()
        let cuQPDelta = try reader.readBool()
        var diffCuQPDelta: UInt32?
        if cuQPDelta { diffCuQPDelta = try reader.readUnsignedExpGolomb() }
        let cbQP = try reader.readSignedExpGolomb()
        let crQP = try reader.readSignedExpGolomb()
        let sliceChromaQP = try reader.readBool()
        let weightedPred = try reader.readBool()
        let weightedBipred = try reader.readBool()
        let transquantBypass = try reader.readBool()
        let tilesEnabled = try reader.readBool()
        let entropySync = try reader.readBool()
        var tileInfo: TileInfo?
        if tilesEnabled {
            let cols = try reader.readUnsignedExpGolomb()
            let rows = try reader.readUnsignedExpGolomb()
            let uniform = try reader.readBool()
            var colW: [UInt32] = []
            var rowH: [UInt32] = []
            if !uniform {
                for _ in 0..<cols { colW.append(try reader.readUnsignedExpGolomb()) }
                for _ in 0..<rows { rowH.append(try reader.readUnsignedExpGolomb()) }
            }
            let loopFilterAcrossTiles = try reader.readBool()
            tileInfo = TileInfo(
                numTileColumnsMinus1: cols,
                numTileRowsMinus1: rows,
                uniformSpacingFlag: uniform,
                columnWidthMinus1: colW,
                rowHeightMinus1: rowH,
                loopFilterAcrossTilesEnabledFlag: loopFilterAcrossTiles
            )
        }
        let loopFilterAcrossSlices = try reader.readBool()
        var deblock: DeblockingControl?
        if try reader.readBool() {
            let overrideEnabled = try reader.readBool()
            let disabled = try reader.readBool()
            var beta: Int32?
            var tc: Int32?
            if !disabled {
                beta = try reader.readSignedExpGolomb()
                tc = try reader.readSignedExpGolomb()
            }
            deblock = DeblockingControl(
                overrideEnabledFlag: overrideEnabled,
                disabledFlag: disabled,
                betaOffsetDiv2: beta,
                tcOffsetDiv2: tc
            )
        }
        var scaling: HEVCScalingListData?
        if try reader.readBool() {
            scaling = try HEVCScalingListData.parse(reader: &reader)
        }
        let listsMod = try reader.readBool()
        let log2Merge = try reader.readUnsignedExpGolomb()
        let sliceSegmentExt = try reader.readBool()
        var extFlags: ExtensionFlags?
        var rangeExt: HEVCPPSRangeExtension?
        var multilayerExt: HEVCPPSMultilayerExtension?
        var threeDExt: HEVCPPS3DExtension?
        var sccExt: HEVCPPSSCCExtension?
        if try reader.readBool() {
            let r = try reader.readBool()
            let m = try reader.readBool()
            let t = try reader.readBool()
            let s = try reader.readBool()
            let reserved = UInt8(try reader.readBits(4))
            extFlags = ExtensionFlags(
                rangeExtensionFlag: r,
                multilayerExtensionFlag: m,
                threeDExtensionFlag: t,
                screenContentExtensionFlag: s,
                reservedBits: reserved
            )
            if r {
                rangeExt = try HEVCPPSRangeExtension.parse(
                    reader: &reader,
                    transformSkipEnabledFlag: transformSkip
                )
            }
            if m {
                multilayerExt = try HEVCPPSMultilayerExtension.parse(reader: &reader)
            }
            if t {
                threeDExt = try HEVCPPS3DExtension.parse(reader: &reader)
            }
            if s {
                sccExt = try HEVCPPSSCCExtension.parse(reader: &reader)
            }
        }
        return HEVCPictureParameterSet(
            ppsID: ppsID,
            spsID: spsID,
            dependentSliceSegmentsEnabledFlag: depSlice,
            outputFlagPresentFlag: outputFlagPresent,
            numExtraSliceHeaderBits: extraSliceBits,
            signDataHidingEnabledFlag: signHiding,
            cabacInitPresentFlag: cabacInit,
            numRefIdxL0DefaultActiveMinus1: l0Default,
            numRefIdxL1DefaultActiveMinus1: l1Default,
            initQPMinus26: initQP,
            constrainedIntraPredFlag: constrainedIntra,
            transformSkipEnabledFlag: transformSkip,
            cuQPDeltaEnabledFlag: cuQPDelta,
            diffCuQPDeltaDepth: diffCuQPDelta,
            cbQPOffset: cbQP,
            crQPOffset: crQP,
            sliceChromaQPOffsetsPresentFlag: sliceChromaQP,
            weightedPredFlag: weightedPred,
            weightedBipredFlag: weightedBipred,
            transquantBypassEnabledFlag: transquantBypass,
            entropyCodingSyncEnabledFlag: entropySync,
            tileInfo: tileInfo,
            loopFilterAcrossSlicesEnabledFlag: loopFilterAcrossSlices,
            deblockingControl: deblock,
            scalingListData: scaling,
            listsModificationPresentFlag: listsMod,
            log2ParallelMergeLevelMinus2: log2Merge,
            sliceSegmentHeaderExtensionPresentFlag: sliceSegmentExt,
            extensionFlags: extFlags,
            rangeExtension: rangeExt,
            multilayerExtension: multilayerExt,
            threeDExtension: threeDExt,
            sccExtension: sccExt
        )
    }

    public func encode() -> Data {
        var writer = BitWriter()
        writer.writeUnsignedExpGolomb(ppsID)
        writer.writeUnsignedExpGolomb(spsID)
        writer.writeBool(dependentSliceSegmentsEnabledFlag)
        writer.writeBool(outputFlagPresentFlag)
        writer.writeBits(UInt64(numExtraSliceHeaderBits & 0x07), count: 3)
        writer.writeBool(signDataHidingEnabledFlag)
        writer.writeBool(cabacInitPresentFlag)
        writer.writeUnsignedExpGolomb(numRefIdxL0DefaultActiveMinus1)
        writer.writeUnsignedExpGolomb(numRefIdxL1DefaultActiveMinus1)
        writer.writeSignedExpGolomb(initQPMinus26)
        writer.writeBool(constrainedIntraPredFlag)
        writer.writeBool(transformSkipEnabledFlag)
        writer.writeBool(cuQPDeltaEnabledFlag)
        if cuQPDeltaEnabledFlag { writer.writeUnsignedExpGolomb(diffCuQPDeltaDepth ?? 0) }
        writer.writeSignedExpGolomb(cbQPOffset)
        writer.writeSignedExpGolomb(crQPOffset)
        writer.writeBool(sliceChromaQPOffsetsPresentFlag)
        writer.writeBool(weightedPredFlag)
        writer.writeBool(weightedBipredFlag)
        writer.writeBool(transquantBypassEnabledFlag)
        writer.writeBool(tileInfo != nil)
        writer.writeBool(entropyCodingSyncEnabledFlag)
        if let t = tileInfo {
            writer.writeUnsignedExpGolomb(t.numTileColumnsMinus1)
            writer.writeUnsignedExpGolomb(t.numTileRowsMinus1)
            writer.writeBool(t.uniformSpacingFlag)
            if !t.uniformSpacingFlag {
                for w in t.columnWidthMinus1 { writer.writeUnsignedExpGolomb(w) }
                for h in t.rowHeightMinus1 { writer.writeUnsignedExpGolomb(h) }
            }
            writer.writeBool(t.loopFilterAcrossTilesEnabledFlag)
        }
        writer.writeBool(loopFilterAcrossSlicesEnabledFlag)
        writer.writeBool(deblockingControl != nil)
        if let d = deblockingControl {
            writer.writeBool(d.overrideEnabledFlag)
            writer.writeBool(d.disabledFlag)
            if !d.disabledFlag {
                writer.writeSignedExpGolomb(d.betaOffsetDiv2 ?? 0)
                writer.writeSignedExpGolomb(d.tcOffsetDiv2 ?? 0)
            }
        }
        writer.writeBool(scalingListData != nil)
        scalingListData?.encode(to: &writer)
        writer.writeBool(listsModificationPresentFlag)
        writer.writeUnsignedExpGolomb(log2ParallelMergeLevelMinus2)
        writer.writeBool(sliceSegmentHeaderExtensionPresentFlag)
        writer.writeBool(extensionFlags != nil)
        if let ef = extensionFlags {
            writer.writeBool(ef.rangeExtensionFlag)
            writer.writeBool(ef.multilayerExtensionFlag)
            writer.writeBool(ef.threeDExtensionFlag)
            writer.writeBool(ef.screenContentExtensionFlag)
            writer.writeBits(UInt64(ef.reservedBits & 0x0F), count: 4)
            if ef.rangeExtensionFlag, let r = rangeExtension {
                r.encode(to: &writer, transformSkipEnabledFlag: transformSkipEnabledFlag)
            }
            if ef.multilayerExtensionFlag, let m = multilayerExtension {
                m.encode(to: &writer)
            }
            if ef.threeDExtensionFlag, let t = threeDExtension {
                t.encode(to: &writer)
            }
            if ef.screenContentExtensionFlag, let s = sccExtension {
                s.encode(to: &writer)
            }
        }
        writer.writeBit(1)
        writer.byteAlign()
        return writer.data
    }
}

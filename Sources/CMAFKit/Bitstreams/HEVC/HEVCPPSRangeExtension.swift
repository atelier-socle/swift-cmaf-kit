// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCPPSRangeExtension
//
// Reference: ITU-T H.265 §7.3.2.3.2 (pps_range_extension).

import Foundation

/// HEVC PPS range extension per ITU-T H.265 §7.3.2.3.2.
public struct HEVCPPSRangeExtension: Sendable, Hashable, Equatable {

    /// Per-CU chroma QP offset list, present iff
    /// `chroma_qp_offset_list_enabled_flag == 1`.
    public struct ChromaQPOffsetList: Sendable, Hashable, Equatable {
        public let diffCuChromaQPOffsetDepth: UInt32
        public let chromaQPOffsetListLenMinus1: UInt32
        public let cbQPOffsetList: [Int32]
        public let crQPOffsetList: [Int32]

        public init(
            diffCuChromaQPOffsetDepth: UInt32,
            chromaQPOffsetListLenMinus1: UInt32,
            cbQPOffsetList: [Int32],
            crQPOffsetList: [Int32]
        ) {
            self.diffCuChromaQPOffsetDepth = diffCuChromaQPOffsetDepth
            self.chromaQPOffsetListLenMinus1 = chromaQPOffsetListLenMinus1
            self.cbQPOffsetList = cbQPOffsetList
            self.crQPOffsetList = crQPOffsetList
        }
    }

    /// `log2_max_transform_skip_block_size_minus2`. Present iff the
    /// outer PPS's `transform_skip_enabled_flag == 1`.
    public let log2MaxTransformSkipBlockSizeMinus2: UInt32?
    public let crossComponentPredictionEnabledFlag: Bool
    public let chromaQPOffsetListEnabledFlag: Bool
    public let chromaQPOffsetList: ChromaQPOffsetList?
    public let log2SAOOffsetScaleLuma: UInt32
    public let log2SAOOffsetScaleChroma: UInt32

    public init(
        log2MaxTransformSkipBlockSizeMinus2: UInt32? = nil,
        crossComponentPredictionEnabledFlag: Bool,
        chromaQPOffsetListEnabledFlag: Bool,
        chromaQPOffsetList: ChromaQPOffsetList? = nil,
        log2SAOOffsetScaleLuma: UInt32,
        log2SAOOffsetScaleChroma: UInt32
    ) {
        precondition(
            chromaQPOffsetListEnabledFlag == (chromaQPOffsetList != nil),
            "chromaQPOffsetList presence must match chromaQPOffsetListEnabledFlag"
        )
        self.log2MaxTransformSkipBlockSizeMinus2 = log2MaxTransformSkipBlockSizeMinus2
        self.crossComponentPredictionEnabledFlag = crossComponentPredictionEnabledFlag
        self.chromaQPOffsetListEnabledFlag = chromaQPOffsetListEnabledFlag
        self.chromaQPOffsetList = chromaQPOffsetList
        self.log2SAOOffsetScaleLuma = log2SAOOffsetScaleLuma
        self.log2SAOOffsetScaleChroma = log2SAOOffsetScaleChroma
    }

    public static func parse(
        reader: inout BitReader,
        transformSkipEnabledFlag: Bool
    ) throws -> HEVCPPSRangeExtension {
        var log2MaxTransformSkip: UInt32?
        if transformSkipEnabledFlag {
            log2MaxTransformSkip = try reader.readUnsignedExpGolomb()
        }
        let crossComp = try reader.readBool()
        let chromaListEnabled = try reader.readBool()
        var qpList: ChromaQPOffsetList?
        if chromaListEnabled {
            let depth = try reader.readUnsignedExpGolomb()
            let lenMinus1 = try reader.readUnsignedExpGolomb()
            let count = Int(lenMinus1) + 1
            var cb: [Int32] = []
            var cr: [Int32] = []
            cb.reserveCapacity(count)
            cr.reserveCapacity(count)
            for _ in 0..<count {
                cb.append(try reader.readSignedExpGolomb())
            }
            for _ in 0..<count {
                cr.append(try reader.readSignedExpGolomb())
            }
            qpList = ChromaQPOffsetList(
                diffCuChromaQPOffsetDepth: depth,
                chromaQPOffsetListLenMinus1: lenMinus1,
                cbQPOffsetList: cb,
                crQPOffsetList: cr
            )
        }
        let saoLuma = try reader.readUnsignedExpGolomb()
        let saoChroma = try reader.readUnsignedExpGolomb()
        return HEVCPPSRangeExtension(
            log2MaxTransformSkipBlockSizeMinus2: log2MaxTransformSkip,
            crossComponentPredictionEnabledFlag: crossComp,
            chromaQPOffsetListEnabledFlag: chromaListEnabled,
            chromaQPOffsetList: qpList,
            log2SAOOffsetScaleLuma: saoLuma,
            log2SAOOffsetScaleChroma: saoChroma
        )
    }

    public func encode(
        to writer: inout BitWriter,
        transformSkipEnabledFlag: Bool
    ) {
        if transformSkipEnabledFlag {
            writer.writeUnsignedExpGolomb(log2MaxTransformSkipBlockSizeMinus2 ?? 0)
        }
        writer.writeBool(crossComponentPredictionEnabledFlag)
        writer.writeBool(chromaQPOffsetListEnabledFlag)
        if let list = chromaQPOffsetList {
            writer.writeUnsignedExpGolomb(list.diffCuChromaQPOffsetDepth)
            writer.writeUnsignedExpGolomb(list.chromaQPOffsetListLenMinus1)
            for v in list.cbQPOffsetList { writer.writeSignedExpGolomb(v) }
            for v in list.crQPOffsetList { writer.writeSignedExpGolomb(v) }
        }
        writer.writeUnsignedExpGolomb(log2SAOOffsetScaleLuma)
        writer.writeUnsignedExpGolomb(log2SAOOffsetScaleChroma)
    }
}

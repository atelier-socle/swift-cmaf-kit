// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCSequenceParameterSet
//
// Reference: ITU-T H.265 §7.3.2.2 (seq_parameter_set_rbsp).

import Foundation

/// HEVC sequence parameter set per ITU-T H.265 §7.3.2.2.
public struct HEVCSequenceParameterSet: Sendable, Hashable, Equatable {

    /// Conformance window applied to the coded picture dimensions
    /// (§7.4.3.2.1).
    public struct ConformanceWindow: Sendable, Hashable, Equatable {
        public let leftOffset: UInt32
        public let rightOffset: UInt32
        public let topOffset: UInt32
        public let bottomOffset: UInt32

        public init(leftOffset: UInt32, rightOffset: UInt32, topOffset: UInt32, bottomOffset: UInt32) {
            self.leftOffset = leftOffset
            self.rightOffset = rightOffset
            self.topOffset = topOffset
            self.bottomOffset = bottomOffset
        }
    }

    /// PCM info present iff `pcmEnabledFlag` is true.
    public struct PCMInfo: Sendable, Hashable, Equatable {
        public let pcmSampleBitDepthLumaMinus1: UInt8
        public let pcmSampleBitDepthChromaMinus1: UInt8
        public let log2MinPcmLumaCodingBlockSizeMinus3: UInt32
        public let log2DiffMaxMinPcmLumaCodingBlockSize: UInt32
        public let pcmLoopFilterDisabledFlag: Bool

        public init(
            pcmSampleBitDepthLumaMinus1: UInt8,
            pcmSampleBitDepthChromaMinus1: UInt8,
            log2MinPcmLumaCodingBlockSizeMinus3: UInt32,
            log2DiffMaxMinPcmLumaCodingBlockSize: UInt32,
            pcmLoopFilterDisabledFlag: Bool
        ) {
            self.pcmSampleBitDepthLumaMinus1 = pcmSampleBitDepthLumaMinus1
            self.pcmSampleBitDepthChromaMinus1 = pcmSampleBitDepthChromaMinus1
            self.log2MinPcmLumaCodingBlockSizeMinus3 = log2MinPcmLumaCodingBlockSizeMinus3
            self.log2DiffMaxMinPcmLumaCodingBlockSize = log2DiffMaxMinPcmLumaCodingBlockSize
            self.pcmLoopFilterDisabledFlag = pcmLoopFilterDisabledFlag
        }
    }

    /// Long-term reference picture info (§7.4.3.2.1).
    public struct LongTermRefPicsInfo: Sendable, Hashable, Equatable {
        public struct Entry: Sendable, Hashable, Equatable {
            public let ltRefPicPocLsbSPS: UInt32
            public let usedByCurrPicLTSPSFlag: Bool

            public init(ltRefPicPocLsbSPS: UInt32, usedByCurrPicLTSPSFlag: Bool) {
                self.ltRefPicPocLsbSPS = ltRefPicPocLsbSPS
                self.usedByCurrPicLTSPSFlag = usedByCurrPicLTSPSFlag
            }
        }
        public let log2MaxPicOrderCntLsbMinus4: UInt32
        public let entries: [Entry]

        public init(log2MaxPicOrderCntLsbMinus4: UInt32, entries: [Entry]) {
            self.log2MaxPicOrderCntLsbMinus4 = log2MaxPicOrderCntLsbMinus4
            self.entries = entries
        }
    }

    public let vpsID: UInt8
    public let maxSubLayersMinus1: UInt8
    public let temporalIDNestingFlag: Bool
    public let profileTierLevel: HEVCProfileTierLevel
    public let spsID: UInt32
    public let chromaFormatIDC: HEVCChromaFormatIDC
    public let separateColourPlaneFlag: Bool?
    public let picWidthInLumaSamples: UInt32
    public let picHeightInLumaSamples: UInt32
    public let conformanceWindow: ConformanceWindow?
    public let bitDepthYMinus8: UInt32
    public let bitDepthCMinus8: UInt32
    public let log2MaxPicOrderCntLsbMinus4: UInt32
    public let subLayerOrderingInfoPresentFlag: Bool
    public let subLayerOrderingInfo: [HEVCVideoParameterSet.SubLayerOrderingInfo]
    public let log2MinLumaCodingBlockSizeMinus3: UInt32
    public let log2DiffMaxMinLumaCodingBlockSize: UInt32
    public let log2MinLumaTransformBlockSizeMinus2: UInt32
    public let log2DiffMaxMinLumaTransformBlockSize: UInt32
    public let maxTransformHierarchyDepthInter: UInt32
    public let maxTransformHierarchyDepthIntra: UInt32
    public let scalingListData: HEVCScalingListData?
    public let amplificationEnabledFlag: Bool
    public let sampleAdaptiveOffsetEnabledFlag: Bool
    public let pcmInfo: PCMInfo?
    public let shortTermRefPicSets: [HEVCShortTermRefPicSet]
    public let longTermRefPicsInfo: LongTermRefPicsInfo?
    public let spsTemporalMVPEnabledFlag: Bool
    public let strongIntraSmoothingEnabledFlag: Bool
    public let vuiParameters: HEVCVUIParameters?
    public let spsExtensionFlag: Bool

    public init(
        vpsID: UInt8,
        maxSubLayersMinus1: UInt8,
        temporalIDNestingFlag: Bool,
        profileTierLevel: HEVCProfileTierLevel,
        spsID: UInt32,
        chromaFormatIDC: HEVCChromaFormatIDC,
        separateColourPlaneFlag: Bool? = nil,
        picWidthInLumaSamples: UInt32,
        picHeightInLumaSamples: UInt32,
        conformanceWindow: ConformanceWindow? = nil,
        bitDepthYMinus8: UInt32,
        bitDepthCMinus8: UInt32,
        log2MaxPicOrderCntLsbMinus4: UInt32,
        subLayerOrderingInfoPresentFlag: Bool,
        subLayerOrderingInfo: [HEVCVideoParameterSet.SubLayerOrderingInfo],
        log2MinLumaCodingBlockSizeMinus3: UInt32,
        log2DiffMaxMinLumaCodingBlockSize: UInt32,
        log2MinLumaTransformBlockSizeMinus2: UInt32,
        log2DiffMaxMinLumaTransformBlockSize: UInt32,
        maxTransformHierarchyDepthInter: UInt32,
        maxTransformHierarchyDepthIntra: UInt32,
        scalingListData: HEVCScalingListData? = nil,
        amplificationEnabledFlag: Bool,
        sampleAdaptiveOffsetEnabledFlag: Bool,
        pcmInfo: PCMInfo? = nil,
        shortTermRefPicSets: [HEVCShortTermRefPicSet] = [],
        longTermRefPicsInfo: LongTermRefPicsInfo? = nil,
        spsTemporalMVPEnabledFlag: Bool,
        strongIntraSmoothingEnabledFlag: Bool,
        vuiParameters: HEVCVUIParameters? = nil,
        spsExtensionFlag: Bool = false
    ) {
        self.vpsID = vpsID
        self.maxSubLayersMinus1 = maxSubLayersMinus1
        self.temporalIDNestingFlag = temporalIDNestingFlag
        self.profileTierLevel = profileTierLevel
        self.spsID = spsID
        self.chromaFormatIDC = chromaFormatIDC
        self.separateColourPlaneFlag = separateColourPlaneFlag
        self.picWidthInLumaSamples = picWidthInLumaSamples
        self.picHeightInLumaSamples = picHeightInLumaSamples
        self.conformanceWindow = conformanceWindow
        self.bitDepthYMinus8 = bitDepthYMinus8
        self.bitDepthCMinus8 = bitDepthCMinus8
        self.log2MaxPicOrderCntLsbMinus4 = log2MaxPicOrderCntLsbMinus4
        self.subLayerOrderingInfoPresentFlag = subLayerOrderingInfoPresentFlag
        self.subLayerOrderingInfo = subLayerOrderingInfo
        self.log2MinLumaCodingBlockSizeMinus3 = log2MinLumaCodingBlockSizeMinus3
        self.log2DiffMaxMinLumaCodingBlockSize = log2DiffMaxMinLumaCodingBlockSize
        self.log2MinLumaTransformBlockSizeMinus2 = log2MinLumaTransformBlockSizeMinus2
        self.log2DiffMaxMinLumaTransformBlockSize = log2DiffMaxMinLumaTransformBlockSize
        self.maxTransformHierarchyDepthInter = maxTransformHierarchyDepthInter
        self.maxTransformHierarchyDepthIntra = maxTransformHierarchyDepthIntra
        self.scalingListData = scalingListData
        self.amplificationEnabledFlag = amplificationEnabledFlag
        self.sampleAdaptiveOffsetEnabledFlag = sampleAdaptiveOffsetEnabledFlag
        self.pcmInfo = pcmInfo
        self.shortTermRefPicSets = shortTermRefPicSets
        self.longTermRefPicsInfo = longTermRefPicsInfo
        self.spsTemporalMVPEnabledFlag = spsTemporalMVPEnabledFlag
        self.strongIntraSmoothingEnabledFlag = strongIntraSmoothingEnabledFlag
        self.vuiParameters = vuiParameters
        self.spsExtensionFlag = spsExtensionFlag
    }

    /// Coded width × height in luma samples after conformance-window
    /// cropping per §7.4.3.2.1. `subWidthC`/`subHeightC` per §6.2.
    public var codedDimensions: (width: Int, height: Int) {
        let subWidthC: Int
        let subHeightC: Int
        switch chromaFormatIDC {
        case .monochrome:
            subWidthC = 1
            subHeightC = 1
        case .format420:
            subWidthC = 2
            subHeightC = 2
        case .format422:
            subWidthC = 2
            subHeightC = 1
        case .format444:
            subWidthC = 1
            subHeightC = 1
        }
        let w = Int(picWidthInLumaSamples)
        let h = Int(picHeightInLumaSamples)
        guard let cw = conformanceWindow else { return (w, h) }
        let cropX = subWidthC * Int(cw.leftOffset + cw.rightOffset)
        let cropY = subHeightC * Int(cw.topOffset + cw.bottomOffset)
        return (w - cropX, h - cropY)
    }

    public static func parse(rbsp: Data) throws -> HEVCSequenceParameterSet {
        var reader = BitReader(rbsp)
        let vpsID = UInt8(try reader.readBits(4))
        let maxSub = UInt8(try reader.readBits(3))
        let tidNesting = try reader.readBool()
        let ptl = try HEVCProfileTierLevel.parse(
            reader: &reader, profilePresentFlag: true, maxNumSubLayersMinus1: maxSub
        )
        let spsID = try reader.readUnsignedExpGolomb()
        let cfRaw = try reader.readUnsignedExpGolomb()
        guard let cf = HEVCChromaFormatIDC(rawValue: UInt8(cfRaw)) else {
            throw BitstreamError.unsupportedValue(
                codec: "HEVC", field: "chroma_format_idc", value: UInt64(cfRaw)
            )
        }
        var separate: Bool?
        if cf == .format444 { separate = try reader.readBool() }
        let width = try reader.readUnsignedExpGolomb()
        let height = try reader.readUnsignedExpGolomb()
        var conformance: ConformanceWindow?
        if try reader.readBool() {
            conformance = ConformanceWindow(
                leftOffset: try reader.readUnsignedExpGolomb(),
                rightOffset: try reader.readUnsignedExpGolomb(),
                topOffset: try reader.readUnsignedExpGolomb(),
                bottomOffset: try reader.readUnsignedExpGolomb()
            )
        }
        let bdY = try reader.readUnsignedExpGolomb()
        let bdC = try reader.readUnsignedExpGolomb()
        let log2MaxPocLsb = try reader.readUnsignedExpGolomb()
        let subOrderingPresent = try reader.readBool()
        var ordering: [HEVCVideoParameterSet.SubLayerOrderingInfo] = []
        let startI = subOrderingPresent ? 0 : Int(maxSub)
        for _ in startI...Int(maxSub) {
            ordering.append(
                HEVCVideoParameterSet.SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: try reader.readUnsignedExpGolomb(),
                    maxNumReorderPics: try reader.readUnsignedExpGolomb(),
                    maxLatencyIncreasePlus1: try reader.readUnsignedExpGolomb()
                )
            )
        }
        let log2MinCB = try reader.readUnsignedExpGolomb()
        let log2DiffMaxMinCB = try reader.readUnsignedExpGolomb()
        let log2MinTB = try reader.readUnsignedExpGolomb()
        let log2DiffMaxMinTB = try reader.readUnsignedExpGolomb()
        let maxHierInter = try reader.readUnsignedExpGolomb()
        let maxHierIntra = try reader.readUnsignedExpGolomb()
        var scaling: HEVCScalingListData?
        if try reader.readBool() {
            if try reader.readBool() {
                scaling = try HEVCScalingListData.parse(reader: &reader)
            }
        }
        let amp = try reader.readBool()
        let sao = try reader.readBool()
        var pcm: PCMInfo?
        if try reader.readBool() {
            pcm = PCMInfo(
                pcmSampleBitDepthLumaMinus1: UInt8(try reader.readBits(4)),
                pcmSampleBitDepthChromaMinus1: UInt8(try reader.readBits(4)),
                log2MinPcmLumaCodingBlockSizeMinus3: try reader.readUnsignedExpGolomb(),
                log2DiffMaxMinPcmLumaCodingBlockSize: try reader.readUnsignedExpGolomb(),
                pcmLoopFilterDisabledFlag: try reader.readBool()
            )
        }
        let numShortTerm = try reader.readUnsignedExpGolomb()
        var shortTerms: [HEVCShortTermRefPicSet] = []
        shortTerms.reserveCapacity(Int(numShortTerm))
        for i in 0..<numShortTerm {
            let rps = try HEVCShortTermRefPicSet.parse(
                reader: &reader,
                indexInSPS: i,
                previousRefPicSets: shortTerms
            )
            shortTerms.append(rps)
        }
        var longTerm: LongTermRefPicsInfo?
        if try reader.readBool() {
            let n = try reader.readUnsignedExpGolomb()
            var entries: [LongTermRefPicsInfo.Entry] = []
            let lsbBits = Int(log2MaxPocLsb + 4)
            for _ in 0..<n {
                entries.append(
                    LongTermRefPicsInfo.Entry(
                        ltRefPicPocLsbSPS: UInt32(try reader.readBits(lsbBits)),
                        usedByCurrPicLTSPSFlag: try reader.readBool()
                    )
                )
            }
            longTerm = LongTermRefPicsInfo(
                log2MaxPicOrderCntLsbMinus4: log2MaxPocLsb,
                entries: entries
            )
        }
        let mvp = try reader.readBool()
        let strongIntra = try reader.readBool()
        var vui: HEVCVUIParameters?
        if try reader.readBool() {
            vui = try HEVCVUIParameters.parse(
                reader: &reader, maxNumSubLayersMinus1: maxSub
            )
        }
        let extFlag = try reader.readBool()
        return HEVCSequenceParameterSet(
            vpsID: vpsID,
            maxSubLayersMinus1: maxSub,
            temporalIDNestingFlag: tidNesting,
            profileTierLevel: ptl,
            spsID: spsID,
            chromaFormatIDC: cf,
            separateColourPlaneFlag: separate,
            picWidthInLumaSamples: width,
            picHeightInLumaSamples: height,
            conformanceWindow: conformance,
            bitDepthYMinus8: bdY,
            bitDepthCMinus8: bdC,
            log2MaxPicOrderCntLsbMinus4: log2MaxPocLsb,
            subLayerOrderingInfoPresentFlag: subOrderingPresent,
            subLayerOrderingInfo: ordering,
            log2MinLumaCodingBlockSizeMinus3: log2MinCB,
            log2DiffMaxMinLumaCodingBlockSize: log2DiffMaxMinCB,
            log2MinLumaTransformBlockSizeMinus2: log2MinTB,
            log2DiffMaxMinLumaTransformBlockSize: log2DiffMaxMinTB,
            maxTransformHierarchyDepthInter: maxHierInter,
            maxTransformHierarchyDepthIntra: maxHierIntra,
            scalingListData: scaling,
            amplificationEnabledFlag: amp,
            sampleAdaptiveOffsetEnabledFlag: sao,
            pcmInfo: pcm,
            shortTermRefPicSets: shortTerms,
            longTermRefPicsInfo: longTerm,
            spsTemporalMVPEnabledFlag: mvp,
            strongIntraSmoothingEnabledFlag: strongIntra,
            vuiParameters: vui,
            spsExtensionFlag: extFlag
        )
    }

    public func encode() -> Data {
        var writer = BitWriter()
        writer.writeBits(UInt64(vpsID & 0x0F), count: 4)
        writer.writeBits(UInt64(maxSubLayersMinus1 & 0x07), count: 3)
        writer.writeBool(temporalIDNestingFlag)
        profileTierLevel.encode(
            to: &writer, profilePresentFlag: true, maxNumSubLayersMinus1: maxSubLayersMinus1
        )
        writer.writeUnsignedExpGolomb(spsID)
        writer.writeUnsignedExpGolomb(UInt32(chromaFormatIDC.rawValue))
        if chromaFormatIDC == .format444 {
            writer.writeBool(separateColourPlaneFlag ?? false)
        }
        writer.writeUnsignedExpGolomb(picWidthInLumaSamples)
        writer.writeUnsignedExpGolomb(picHeightInLumaSamples)
        writer.writeBool(conformanceWindow != nil)
        if let cw = conformanceWindow {
            writer.writeUnsignedExpGolomb(cw.leftOffset)
            writer.writeUnsignedExpGolomb(cw.rightOffset)
            writer.writeUnsignedExpGolomb(cw.topOffset)
            writer.writeUnsignedExpGolomb(cw.bottomOffset)
        }
        writer.writeUnsignedExpGolomb(bitDepthYMinus8)
        writer.writeUnsignedExpGolomb(bitDepthCMinus8)
        writer.writeUnsignedExpGolomb(log2MaxPicOrderCntLsbMinus4)
        writer.writeBool(subLayerOrderingInfoPresentFlag)
        for info in subLayerOrderingInfo {
            writer.writeUnsignedExpGolomb(info.maxDecPicBufferingMinus1)
            writer.writeUnsignedExpGolomb(info.maxNumReorderPics)
            writer.writeUnsignedExpGolomb(info.maxLatencyIncreasePlus1)
        }
        writer.writeUnsignedExpGolomb(log2MinLumaCodingBlockSizeMinus3)
        writer.writeUnsignedExpGolomb(log2DiffMaxMinLumaCodingBlockSize)
        writer.writeUnsignedExpGolomb(log2MinLumaTransformBlockSizeMinus2)
        writer.writeUnsignedExpGolomb(log2DiffMaxMinLumaTransformBlockSize)
        writer.writeUnsignedExpGolomb(maxTransformHierarchyDepthInter)
        writer.writeUnsignedExpGolomb(maxTransformHierarchyDepthIntra)
        writer.writeBool(scalingListData != nil)
        if let sl = scalingListData {
            writer.writeBool(true)
            sl.encode(to: &writer)
        }
        writer.writeBool(amplificationEnabledFlag)
        writer.writeBool(sampleAdaptiveOffsetEnabledFlag)
        writer.writeBool(pcmInfo != nil)
        if let pcm = pcmInfo {
            writer.writeBits(UInt64(pcm.pcmSampleBitDepthLumaMinus1 & 0x0F), count: 4)
            writer.writeBits(UInt64(pcm.pcmSampleBitDepthChromaMinus1 & 0x0F), count: 4)
            writer.writeUnsignedExpGolomb(pcm.log2MinPcmLumaCodingBlockSizeMinus3)
            writer.writeUnsignedExpGolomb(pcm.log2DiffMaxMinPcmLumaCodingBlockSize)
            writer.writeBool(pcm.pcmLoopFilterDisabledFlag)
        }
        writer.writeUnsignedExpGolomb(UInt32(shortTermRefPicSets.count))
        for (i, rps) in shortTermRefPicSets.enumerated() {
            let previous = Array(shortTermRefPicSets.prefix(i))
            rps.encode(
                to: &writer,
                indexInSPS: UInt32(i),
                previousRefPicSets: previous
            )
        }
        writer.writeBool(longTermRefPicsInfo != nil)
        if let lt = longTermRefPicsInfo {
            writer.writeUnsignedExpGolomb(UInt32(lt.entries.count))
            let lsbBits = Int(log2MaxPicOrderCntLsbMinus4 + 4)
            for entry in lt.entries {
                writer.writeBits(UInt64(entry.ltRefPicPocLsbSPS), count: lsbBits)
                writer.writeBool(entry.usedByCurrPicLTSPSFlag)
            }
        }
        writer.writeBool(spsTemporalMVPEnabledFlag)
        writer.writeBool(strongIntraSmoothingEnabledFlag)
        writer.writeBool(vuiParameters != nil)
        vuiParameters?.encode(to: &writer, maxNumSubLayersMinus1: maxSubLayersMinus1)
        writer.writeBool(spsExtensionFlag)
        writer.writeBit(1)
        writer.byteAlign()
        return writer.data
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCVideoParameterSet
//
// Reference: ITU-T H.265 §7.3.2.1 (video_parameter_set_rbsp).

import Foundation

/// HEVC video parameter set per ITU-T H.265 §7.3.2.1.
public struct HEVCVideoParameterSet: Sendable, Hashable, Equatable {

    /// Sub-layer ordering info entry (§7.3.2.1 / §7.4.3.1).
    public struct SubLayerOrderingInfo: Sendable, Hashable, Equatable {
        public let maxDecPicBufferingMinus1: UInt32
        public let maxNumReorderPics: UInt32
        public let maxLatencyIncreasePlus1: UInt32

        public init(
            maxDecPicBufferingMinus1: UInt32,
            maxNumReorderPics: UInt32,
            maxLatencyIncreasePlus1: UInt32
        ) {
            self.maxDecPicBufferingMinus1 = maxDecPicBufferingMinus1
            self.maxNumReorderPics = maxNumReorderPics
            self.maxLatencyIncreasePlus1 = maxLatencyIncreasePlus1
        }
    }

    public struct TimingInfo: Sendable, Hashable, Equatable {
        public let numUnitsInTick: UInt32
        public let timeScale: UInt32
        public let pocProportionalToTimingFlag: Bool
        public let numTicksPOCDiffOneMinus1: UInt32?
        public let hrdEntries: [HRDEntry]

        public init(
            numUnitsInTick: UInt32,
            timeScale: UInt32,
            pocProportionalToTimingFlag: Bool,
            numTicksPOCDiffOneMinus1: UInt32? = nil,
            hrdEntries: [HRDEntry] = []
        ) {
            self.numUnitsInTick = numUnitsInTick
            self.timeScale = timeScale
            self.pocProportionalToTimingFlag = pocProportionalToTimingFlag
            self.numTicksPOCDiffOneMinus1 = numTicksPOCDiffOneMinus1
            self.hrdEntries = hrdEntries
        }
    }

    public struct HRDEntry: Sendable, Hashable, Equatable {
        public let hrdLayerSetIDX: UInt32
        public let cprmsPresentFlag: Bool?
        public let hrdParameters: HEVCHRDParameters

        public init(hrdLayerSetIDX: UInt32, cprmsPresentFlag: Bool?, hrdParameters: HEVCHRDParameters) {
            self.hrdLayerSetIDX = hrdLayerSetIDX
            self.cprmsPresentFlag = cprmsPresentFlag
            self.hrdParameters = hrdParameters
        }
    }

    public let vpsID: UInt8
    public let baseLayerInternalFlag: Bool
    public let baseLayerAvailableFlag: Bool
    public let maxLayersMinus1: UInt8
    public let maxSubLayersMinus1: UInt8
    public let temporalIDNestingFlag: Bool
    public let profileTierLevel: HEVCProfileTierLevel
    public let subLayerOrderingInfoPresentFlag: Bool
    public let subLayerOrderingInfo: [SubLayerOrderingInfo]
    public let maxLayerID: UInt8
    public let numLayerSetsMinus1: UInt32
    public let layerIDIncludedFlag: [[Bool]]
    public let timingInfo: TimingInfo?
    public let extensionDataBits: [Bool]?

    public init(
        vpsID: UInt8,
        baseLayerInternalFlag: Bool,
        baseLayerAvailableFlag: Bool,
        maxLayersMinus1: UInt8,
        maxSubLayersMinus1: UInt8,
        temporalIDNestingFlag: Bool,
        profileTierLevel: HEVCProfileTierLevel,
        subLayerOrderingInfoPresentFlag: Bool,
        subLayerOrderingInfo: [SubLayerOrderingInfo],
        maxLayerID: UInt8,
        numLayerSetsMinus1: UInt32 = 0,
        layerIDIncludedFlag: [[Bool]] = [],
        timingInfo: TimingInfo? = nil,
        extensionDataBits: [Bool]? = nil
    ) {
        precondition(vpsID <= 0x0F, "vpsID must fit 4 bits")
        precondition(maxLayersMinus1 <= 0x3F, "maxLayersMinus1 must fit 6 bits")
        precondition(maxSubLayersMinus1 <= 0x07, "maxSubLayersMinus1 must fit 3 bits")
        precondition(maxLayerID <= 0x3F, "maxLayerID must fit 6 bits")
        self.vpsID = vpsID
        self.baseLayerInternalFlag = baseLayerInternalFlag
        self.baseLayerAvailableFlag = baseLayerAvailableFlag
        self.maxLayersMinus1 = maxLayersMinus1
        self.maxSubLayersMinus1 = maxSubLayersMinus1
        self.temporalIDNestingFlag = temporalIDNestingFlag
        self.profileTierLevel = profileTierLevel
        self.subLayerOrderingInfoPresentFlag = subLayerOrderingInfoPresentFlag
        self.subLayerOrderingInfo = subLayerOrderingInfo
        self.maxLayerID = maxLayerID
        self.numLayerSetsMinus1 = numLayerSetsMinus1
        self.layerIDIncludedFlag = layerIDIncludedFlag
        self.timingInfo = timingInfo
        self.extensionDataBits = extensionDataBits
    }

    public static func parse(rbsp: Data) throws -> HEVCVideoParameterSet {
        var reader = BitReader(rbsp)
        let vpsID = UInt8(try reader.readBits(4))
        let baseLayerInternal = try reader.readBool()
        let baseLayerAvailable = try reader.readBool()
        let maxLayers = UInt8(try reader.readBits(6))
        let maxSub = UInt8(try reader.readBits(3))
        let tidNesting = try reader.readBool()
        let reservedFFFF = try reader.readBits(16)
        guard reservedFFFF == 0xFFFF else {
            throw BitstreamError.reservedBitsNonZero(
                codec: "HEVC", field: "vps_reserved_0xffff_16bits"
            )
        }
        let ptl = try HEVCProfileTierLevel.parse(
            reader: &reader,
            profilePresentFlag: true,
            maxNumSubLayersMinus1: maxSub
        )
        let subLayerPresent = try reader.readBool()
        var subOrdering: [SubLayerOrderingInfo] = []
        let startI = subLayerPresent ? 0 : Int(maxSub)
        for _ in startI...Int(maxSub) {
            subOrdering.append(
                SubLayerOrderingInfo(
                    maxDecPicBufferingMinus1: try reader.readUnsignedExpGolomb(),
                    maxNumReorderPics: try reader.readUnsignedExpGolomb(),
                    maxLatencyIncreasePlus1: try reader.readUnsignedExpGolomb()
                )
            )
        }
        let maxLayerID = UInt8(try reader.readBits(6))
        let numLayerSets = try reader.readUnsignedExpGolomb()
        var layerIncluded: [[Bool]] = []
        if numLayerSets > 0 {
            for _ in 1...numLayerSets {
                var row: [Bool] = []
                for _ in 0...maxLayerID {
                    row.append(try reader.readBool())
                }
                layerIncluded.append(row)
            }
        }
        var timing: TimingInfo?
        if try reader.readBool() {
            let units = UInt32(try reader.readBits(32))
            let scale = UInt32(try reader.readBits(32))
            let pocProp = try reader.readBool()
            var ticks: UInt32?
            if pocProp { ticks = try reader.readUnsignedExpGolomb() }
            let hrdCount = try reader.readUnsignedExpGolomb()
            var hrdEntries: [HRDEntry] = []
            for i in 0..<hrdCount {
                let idx = try reader.readUnsignedExpGolomb()
                var cprms: Bool?
                if i > 0 {
                    cprms = try reader.readBool()
                }
                let hrd = try HEVCHRDParameters.parse(
                    reader: &reader,
                    commonInfPresentFlag: cprms ?? true,
                    maxNumSubLayersMinus1: maxSub
                )
                hrdEntries.append(
                    HRDEntry(hrdLayerSetIDX: idx, cprmsPresentFlag: cprms, hrdParameters: hrd)
                )
            }
            timing = TimingInfo(
                numUnitsInTick: units,
                timeScale: scale,
                pocProportionalToTimingFlag: pocProp,
                numTicksPOCDiffOneMinus1: ticks,
                hrdEntries: hrdEntries
            )
        }
        var extData: [Bool]?
        if try reader.readBool() {
            var bits: [Bool] = []
            while reader.hasMoreRBSPData() {
                bits.append(try reader.readBool())
            }
            extData = bits
        }
        return HEVCVideoParameterSet(
            vpsID: vpsID,
            baseLayerInternalFlag: baseLayerInternal,
            baseLayerAvailableFlag: baseLayerAvailable,
            maxLayersMinus1: maxLayers,
            maxSubLayersMinus1: maxSub,
            temporalIDNestingFlag: tidNesting,
            profileTierLevel: ptl,
            subLayerOrderingInfoPresentFlag: subLayerPresent,
            subLayerOrderingInfo: subOrdering,
            maxLayerID: maxLayerID,
            numLayerSetsMinus1: numLayerSets,
            layerIDIncludedFlag: layerIncluded,
            timingInfo: timing,
            extensionDataBits: extData
        )
    }

    public func encode() -> Data {
        var writer = BitWriter()
        writer.writeBits(UInt64(vpsID & 0x0F), count: 4)
        writer.writeBool(baseLayerInternalFlag)
        writer.writeBool(baseLayerAvailableFlag)
        writer.writeBits(UInt64(maxLayersMinus1 & 0x3F), count: 6)
        writer.writeBits(UInt64(maxSubLayersMinus1 & 0x07), count: 3)
        writer.writeBool(temporalIDNestingFlag)
        writer.writeBits(0xFFFF, count: 16)
        profileTierLevel.encode(
            to: &writer,
            profilePresentFlag: true,
            maxNumSubLayersMinus1: maxSubLayersMinus1
        )
        writer.writeBool(subLayerOrderingInfoPresentFlag)
        for info in subLayerOrderingInfo {
            writer.writeUnsignedExpGolomb(info.maxDecPicBufferingMinus1)
            writer.writeUnsignedExpGolomb(info.maxNumReorderPics)
            writer.writeUnsignedExpGolomb(info.maxLatencyIncreasePlus1)
        }
        writer.writeBits(UInt64(maxLayerID & 0x3F), count: 6)
        writer.writeUnsignedExpGolomb(numLayerSetsMinus1)
        for row in layerIDIncludedFlag {
            for v in row { writer.writeBool(v) }
        }
        writer.writeBool(timingInfo != nil)
        if let ti = timingInfo {
            writer.writeBits(UInt64(ti.numUnitsInTick), count: 32)
            writer.writeBits(UInt64(ti.timeScale), count: 32)
            writer.writeBool(ti.pocProportionalToTimingFlag)
            if ti.pocProportionalToTimingFlag {
                writer.writeUnsignedExpGolomb(ti.numTicksPOCDiffOneMinus1 ?? 0)
            }
            writer.writeUnsignedExpGolomb(UInt32(ti.hrdEntries.count))
            for (i, entry) in ti.hrdEntries.enumerated() {
                writer.writeUnsignedExpGolomb(entry.hrdLayerSetIDX)
                if i > 0 {
                    writer.writeBool(entry.cprmsPresentFlag ?? false)
                }
                entry.hrdParameters.encode(
                    to: &writer,
                    commonInfPresentFlag: entry.cprmsPresentFlag ?? true,
                    maxNumSubLayersMinus1: maxSubLayersMinus1
                )
            }
        }
        writer.writeBool(extensionDataBits != nil)
        if let bits = extensionDataBits {
            for b in bits { writer.writeBool(b) }
        }
        writer.writeBit(1)
        writer.byteAlign()
        return writer.data
    }
}

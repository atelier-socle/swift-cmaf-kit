// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCHRDParameters
//
// Reference: ITU-T H.265 §E.2.1 (hrd_parameters) + §E.2.2
// (sub_layer_hrd_parameters).

import Foundation

/// HEVC Hypothetical Reference Decoder parameters per ITU-T H.265
/// §E.2.1.
public struct HEVCHRDParameters: Sendable, Hashable, Equatable {

    /// Common info present in either NAL or VCL HRD variants.
    public struct CommonInfo: Sendable, Hashable, Equatable {
        public let nalHRDParametersPresentFlag: Bool
        public let vclHRDParametersPresentFlag: Bool
        public let subPicHRDParams: SubPicHRDParams?
        public let bitRateScale: UInt8
        public let cpbSizeScale: UInt8
        public let cpbSizeDUScale: UInt8?
        public let initialCPBRemovalDelayLengthMinus1: UInt8
        public let auCPBRemovalDelayLengthMinus1: UInt8
        public let dpbOutputDelayLengthMinus1: UInt8

        public init(
            nalHRDParametersPresentFlag: Bool,
            vclHRDParametersPresentFlag: Bool,
            subPicHRDParams: SubPicHRDParams? = nil,
            bitRateScale: UInt8 = 0,
            cpbSizeScale: UInt8 = 0,
            cpbSizeDUScale: UInt8? = nil,
            initialCPBRemovalDelayLengthMinus1: UInt8 = 23,
            auCPBRemovalDelayLengthMinus1: UInt8 = 23,
            dpbOutputDelayLengthMinus1: UInt8 = 23
        ) {
            self.nalHRDParametersPresentFlag = nalHRDParametersPresentFlag
            self.vclHRDParametersPresentFlag = vclHRDParametersPresentFlag
            self.subPicHRDParams = subPicHRDParams
            self.bitRateScale = bitRateScale
            self.cpbSizeScale = cpbSizeScale
            self.cpbSizeDUScale = cpbSizeDUScale
            self.initialCPBRemovalDelayLengthMinus1 = initialCPBRemovalDelayLengthMinus1
            self.auCPBRemovalDelayLengthMinus1 = auCPBRemovalDelayLengthMinus1
            self.dpbOutputDelayLengthMinus1 = dpbOutputDelayLengthMinus1
        }
    }

    /// Sub-picture HRD parameters (§E.2.1).
    public struct SubPicHRDParams: Sendable, Hashable, Equatable {
        public let tickDivisorMinus2: UInt8
        public let duCPBRemovalDelayIncrementLengthMinus1: UInt8
        public let subPicCPBParamsInPicTimingSEIFlag: Bool
        public let dpbOutputDelayDULengthMinus1: UInt8

        public init(
            tickDivisorMinus2: UInt8,
            duCPBRemovalDelayIncrementLengthMinus1: UInt8,
            subPicCPBParamsInPicTimingSEIFlag: Bool,
            dpbOutputDelayDULengthMinus1: UInt8
        ) {
            self.tickDivisorMinus2 = tickDivisorMinus2
            self.duCPBRemovalDelayIncrementLengthMinus1 = duCPBRemovalDelayIncrementLengthMinus1
            self.subPicCPBParamsInPicTimingSEIFlag = subPicCPBParamsInPicTimingSEIFlag
            self.dpbOutputDelayDULengthMinus1 = dpbOutputDelayDULengthMinus1
        }
    }

    /// Per-sub-layer entry.
    public struct SubLayerInfo: Sendable, Hashable, Equatable {
        public let fixedPicRateGeneralFlag: Bool
        public let fixedPicRateWithinCVSFlag: Bool?
        public let elementalDurationInTCMinus1: UInt32?
        public let lowDelayHRDFlag: Bool?
        public let cpbCountMinus1: UInt32?
        public let nalSubLayerHRD: [CPBEntry]
        public let vclSubLayerHRD: [CPBEntry]

        public init(
            fixedPicRateGeneralFlag: Bool,
            fixedPicRateWithinCVSFlag: Bool? = nil,
            elementalDurationInTCMinus1: UInt32? = nil,
            lowDelayHRDFlag: Bool? = nil,
            cpbCountMinus1: UInt32? = nil,
            nalSubLayerHRD: [CPBEntry] = [],
            vclSubLayerHRD: [CPBEntry] = []
        ) {
            self.fixedPicRateGeneralFlag = fixedPicRateGeneralFlag
            self.fixedPicRateWithinCVSFlag = fixedPicRateWithinCVSFlag
            self.elementalDurationInTCMinus1 = elementalDurationInTCMinus1
            self.lowDelayHRDFlag = lowDelayHRDFlag
            self.cpbCountMinus1 = cpbCountMinus1
            self.nalSubLayerHRD = nalSubLayerHRD
            self.vclSubLayerHRD = vclSubLayerHRD
        }
    }

    /// One CPB schedule entry. Sub-picture HRD adds two extra fields
    /// kept optional here for byte-perfect round-trip.
    public struct CPBEntry: Sendable, Hashable, Equatable {
        public let bitRateValueMinus1: UInt32
        public let cpbSizeValueMinus1: UInt32
        public let cpbSizeDUValueMinus1: UInt32?
        public let bitRateDUValueMinus1: UInt32?
        public let cbrFlag: Bool

        public init(
            bitRateValueMinus1: UInt32,
            cpbSizeValueMinus1: UInt32,
            cpbSizeDUValueMinus1: UInt32? = nil,
            bitRateDUValueMinus1: UInt32? = nil,
            cbrFlag: Bool
        ) {
            self.bitRateValueMinus1 = bitRateValueMinus1
            self.cpbSizeValueMinus1 = cpbSizeValueMinus1
            self.cpbSizeDUValueMinus1 = cpbSizeDUValueMinus1
            self.bitRateDUValueMinus1 = bitRateDUValueMinus1
            self.cbrFlag = cbrFlag
        }
    }

    public let commonInfo: CommonInfo?
    public let subLayers: [SubLayerInfo]

    public init(commonInfo: CommonInfo?, subLayers: [SubLayerInfo]) {
        self.commonInfo = commonInfo
        self.subLayers = subLayers
    }

    public static func parse(
        reader: inout BitReader,
        commonInfPresentFlag: Bool,
        maxNumSubLayersMinus1: UInt8
    ) throws -> HEVCHRDParameters {
        var common: CommonInfo?
        if commonInfPresentFlag {
            let nalPresent = try reader.readBool()
            let vclPresent = try reader.readBool()
            var subPic: SubPicHRDParams?
            var bitRateScale: UInt8 = 0
            var cpbSizeScale: UInt8 = 0
            var cpbSizeDU: UInt8?
            var initialCPB: UInt8 = 23
            var auCPB: UInt8 = 23
            var dpbOut: UInt8 = 23
            if nalPresent || vclPresent {
                if try reader.readBool() {
                    let tickDiv = UInt8(try reader.readBits(8))
                    let duIncr = UInt8(try reader.readBits(5))
                    let subPicCPB = try reader.readBool()
                    let dpbDU = UInt8(try reader.readBits(5))
                    subPic = SubPicHRDParams(
                        tickDivisorMinus2: tickDiv,
                        duCPBRemovalDelayIncrementLengthMinus1: duIncr,
                        subPicCPBParamsInPicTimingSEIFlag: subPicCPB,
                        dpbOutputDelayDULengthMinus1: dpbDU
                    )
                }
                bitRateScale = UInt8(try reader.readBits(4))
                cpbSizeScale = UInt8(try reader.readBits(4))
                if subPic != nil {
                    cpbSizeDU = UInt8(try reader.readBits(4))
                }
                initialCPB = UInt8(try reader.readBits(5))
                auCPB = UInt8(try reader.readBits(5))
                dpbOut = UInt8(try reader.readBits(5))
            }
            common = CommonInfo(
                nalHRDParametersPresentFlag: nalPresent,
                vclHRDParametersPresentFlag: vclPresent,
                subPicHRDParams: subPic,
                bitRateScale: bitRateScale,
                cpbSizeScale: cpbSizeScale,
                cpbSizeDUScale: cpbSizeDU,
                initialCPBRemovalDelayLengthMinus1: initialCPB,
                auCPBRemovalDelayLengthMinus1: auCPB,
                dpbOutputDelayLengthMinus1: dpbOut
            )
        }
        let subPicPresent = common?.subPicHRDParams != nil
        let nalPresent = common?.nalHRDParametersPresentFlag ?? false
        let vclPresent = common?.vclHRDParametersPresentFlag ?? false
        var subLayers: [SubLayerInfo] = []
        for _ in 0...maxNumSubLayersMinus1 {
            let fixedGeneral = try reader.readBool()
            var fixedWithinCVS: Bool?
            if !fixedGeneral {
                fixedWithinCVS = try reader.readBool()
            }
            var elemDuration: UInt32?
            var lowDelay: Bool?
            let effectiveFixed = fixedGeneral || (fixedWithinCVS == true)
            if effectiveFixed {
                elemDuration = try reader.readUnsignedExpGolomb()
            } else {
                lowDelay = try reader.readBool()
            }
            var cpbCount: UInt32?
            if lowDelay != true {
                cpbCount = try reader.readUnsignedExpGolomb()
            }
            let count = Int(cpbCount ?? 0) + 1
            var nalCPB: [CPBEntry] = []
            var vclCPB: [CPBEntry] = []
            if nalPresent {
                nalCPB = try Self.readSubLayerCPBs(
                    reader: &reader, count: count, subPicPresent: subPicPresent
                )
            }
            if vclPresent {
                vclCPB = try Self.readSubLayerCPBs(
                    reader: &reader, count: count, subPicPresent: subPicPresent
                )
            }
            subLayers.append(
                SubLayerInfo(
                    fixedPicRateGeneralFlag: fixedGeneral,
                    fixedPicRateWithinCVSFlag: fixedWithinCVS,
                    elementalDurationInTCMinus1: elemDuration,
                    lowDelayHRDFlag: lowDelay,
                    cpbCountMinus1: cpbCount,
                    nalSubLayerHRD: nalCPB,
                    vclSubLayerHRD: vclCPB
                )
            )
        }
        return HEVCHRDParameters(commonInfo: common, subLayers: subLayers)
    }

    public func encode(
        to writer: inout BitWriter,
        commonInfPresentFlag: Bool,
        maxNumSubLayersMinus1: UInt8
    ) {
        if commonInfPresentFlag, let common = commonInfo {
            writer.writeBool(common.nalHRDParametersPresentFlag)
            writer.writeBool(common.vclHRDParametersPresentFlag)
            if common.nalHRDParametersPresentFlag || common.vclHRDParametersPresentFlag {
                writer.writeBool(common.subPicHRDParams != nil)
                if let sp = common.subPicHRDParams {
                    writer.writeBits(UInt64(sp.tickDivisorMinus2), count: 8)
                    writer.writeBits(UInt64(sp.duCPBRemovalDelayIncrementLengthMinus1), count: 5)
                    writer.writeBool(sp.subPicCPBParamsInPicTimingSEIFlag)
                    writer.writeBits(UInt64(sp.dpbOutputDelayDULengthMinus1), count: 5)
                }
                writer.writeBits(UInt64(common.bitRateScale & 0x0F), count: 4)
                writer.writeBits(UInt64(common.cpbSizeScale & 0x0F), count: 4)
                if common.subPicHRDParams != nil {
                    writer.writeBits(UInt64(common.cpbSizeDUScale ?? 0), count: 4)
                }
                writer.writeBits(UInt64(common.initialCPBRemovalDelayLengthMinus1 & 0x1F), count: 5)
                writer.writeBits(UInt64(common.auCPBRemovalDelayLengthMinus1 & 0x1F), count: 5)
                writer.writeBits(UInt64(common.dpbOutputDelayLengthMinus1 & 0x1F), count: 5)
            }
        }
        let subPicPresent = commonInfo?.subPicHRDParams != nil
        let nalPresent = commonInfo?.nalHRDParametersPresentFlag ?? false
        let vclPresent = commonInfo?.vclHRDParametersPresentFlag ?? false
        for sub in subLayers {
            writer.writeBool(sub.fixedPicRateGeneralFlag)
            if !sub.fixedPicRateGeneralFlag {
                writer.writeBool(sub.fixedPicRateWithinCVSFlag ?? false)
            }
            let effectiveFixed =
                sub.fixedPicRateGeneralFlag
                || (sub.fixedPicRateWithinCVSFlag == true)
            if effectiveFixed {
                writer.writeUnsignedExpGolomb(sub.elementalDurationInTCMinus1 ?? 0)
            } else {
                writer.writeBool(sub.lowDelayHRDFlag ?? false)
            }
            if sub.lowDelayHRDFlag != true {
                writer.writeUnsignedExpGolomb(sub.cpbCountMinus1 ?? 0)
            }
            if nalPresent {
                Self.writeSubLayerCPBs(
                    to: &writer, entries: sub.nalSubLayerHRD, subPicPresent: subPicPresent
                )
            }
            if vclPresent {
                Self.writeSubLayerCPBs(
                    to: &writer, entries: sub.vclSubLayerHRD, subPicPresent: subPicPresent
                )
            }
        }
    }

    private static func readSubLayerCPBs(
        reader: inout BitReader,
        count: Int,
        subPicPresent: Bool
    ) throws -> [CPBEntry] {
        var entries: [CPBEntry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            let br = try reader.readUnsignedExpGolomb()
            let cpb = try reader.readUnsignedExpGolomb()
            var cpbDU: UInt32?
            var brDU: UInt32?
            if subPicPresent {
                cpbDU = try reader.readUnsignedExpGolomb()
                brDU = try reader.readUnsignedExpGolomb()
            }
            let cbr = try reader.readBool()
            entries.append(
                CPBEntry(
                    bitRateValueMinus1: br,
                    cpbSizeValueMinus1: cpb,
                    cpbSizeDUValueMinus1: cpbDU,
                    bitRateDUValueMinus1: brDU,
                    cbrFlag: cbr
                )
            )
        }
        return entries
    }

    private static func writeSubLayerCPBs(
        to writer: inout BitWriter,
        entries: [CPBEntry],
        subPicPresent: Bool
    ) {
        for entry in entries {
            writer.writeUnsignedExpGolomb(entry.bitRateValueMinus1)
            writer.writeUnsignedExpGolomb(entry.cpbSizeValueMinus1)
            if subPicPresent {
                writer.writeUnsignedExpGolomb(entry.cpbSizeDUValueMinus1 ?? 0)
                writer.writeUnsignedExpGolomb(entry.bitRateDUValueMinus1 ?? 0)
            }
            writer.writeBool(entry.cbrFlag)
        }
    }
}

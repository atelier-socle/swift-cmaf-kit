// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AV1SequenceHeader
//
// Reference: AOMedia AV1 Bitstream §5.5.1 (sequence_header_obu).
//
// Parses the sequence header OBU's payload (after the OBU header /
// extension header / size field). The non-reduced still-picture path
// is fully handled; the decoder-model variant is rejected with
// `unsupportedValue` (a container library does not need to model the
// internal decoder buffering schedule).

import Foundation

/// AV1 sequence header OBU per AOMedia AV1 Bitstream §5.5.1.
public struct AV1SequenceHeader: Sendable, Hashable, Equatable {

    /// Timing info subtree (§5.5.2).
    public struct TimingInfo: Sendable, Hashable, Equatable {
        public let numUnitsInDisplayTick: UInt32
        public let timeScale: UInt32
        public let equalPictureInterval: Bool
        public let numTicksPerPictureMinus1: UInt32?

        public init(
            numUnitsInDisplayTick: UInt32,
            timeScale: UInt32,
            equalPictureInterval: Bool,
            numTicksPerPictureMinus1: UInt32? = nil
        ) {
            self.numUnitsInDisplayTick = numUnitsInDisplayTick
            self.timeScale = timeScale
            self.equalPictureInterval = equalPictureInterval
            self.numTicksPerPictureMinus1 = numTicksPerPictureMinus1
        }
    }

    /// Color config subtree (§5.5.2).
    public struct ColorConfig: Sendable, Hashable, Equatable {
        public let highBitDepth: Bool
        public let twelveBit: Bool?
        public let monochrome: Bool
        public let colorDescription: ColorDescription?
        public let colorRange: VideoFullRangeFlag
        public let subsamplingX: Bool
        public let subsamplingY: Bool
        public let chromaSamplePosition: AV1ChromaSamplePosition?
        public let separateUVDeltaQ: Bool

        public struct ColorDescription: Sendable, Hashable, Equatable {
            public let colorPrimaries: ColorPrimaries
            public let transferCharacteristics: TransferCharacteristics
            public let matrixCoefficients: MatrixCoefficients

            public init(
                colorPrimaries: ColorPrimaries,
                transferCharacteristics: TransferCharacteristics,
                matrixCoefficients: MatrixCoefficients
            ) {
                self.colorPrimaries = colorPrimaries
                self.transferCharacteristics = transferCharacteristics
                self.matrixCoefficients = matrixCoefficients
            }
        }

        public init(
            highBitDepth: Bool,
            twelveBit: Bool? = nil,
            monochrome: Bool,
            colorDescription: ColorDescription? = nil,
            colorRange: VideoFullRangeFlag,
            subsamplingX: Bool,
            subsamplingY: Bool,
            chromaSamplePosition: AV1ChromaSamplePosition? = nil,
            separateUVDeltaQ: Bool
        ) {
            self.highBitDepth = highBitDepth
            self.twelveBit = twelveBit
            self.monochrome = monochrome
            self.colorDescription = colorDescription
            self.colorRange = colorRange
            self.subsamplingX = subsamplingX
            self.subsamplingY = subsamplingY
            self.chromaSamplePosition = chromaSamplePosition
            self.separateUVDeltaQ = separateUVDeltaQ
        }
    }

    public let seqProfile: AV1Profile
    public let stillPicture: Bool
    public let reducedStillPictureHeader: Bool
    public let timingInfo: TimingInfo?
    /// Decoder model info per AOMedia AV1 §5.5.4. Present iff
    /// `timing_info_present_flag == 1` AND
    /// `decoder_model_info_present_flag == 1`.
    public let decoderModelInfo: AV1DecoderModelInfo?
    public let initialDisplayDelayPresentFlag: Bool
    public let operatingPoints: [AV1OperatingPoint]
    public let frameWidthBitsMinus1: UInt8
    public let frameHeightBitsMinus1: UInt8
    public let maxFrameWidthMinus1: UInt32
    public let maxFrameHeightMinus1: UInt32
    public let frameIDNumbersPresentFlag: Bool
    public let deltaFrameIDLengthMinus2: UInt8?
    public let additionalFrameIDLengthMinus1: UInt8?
    public let use128x128Superblock: Bool
    public let enableFilterIntra: Bool
    public let enableIntraEdgeFilter: Bool
    public let enableInterIntraCompound: Bool
    public let enableMaskedCompound: Bool
    public let enableWarpedMotion: Bool
    public let enableDualFilter: Bool
    public let enableOrderHint: Bool
    public let enableJntComp: Bool
    public let enableRefFrameMVs: Bool
    public let seqChooseScreenContentTools: Bool
    public let seqForceScreenContentTools: UInt8
    public let seqChooseIntegerMV: Bool?
    public let seqForceIntegerMV: UInt8?
    public let orderHintBitsMinus1: UInt8?
    public let enableSuperRes: Bool
    public let enableCDEF: Bool
    public let enableRestoration: Bool
    public let colorConfig: ColorConfig
    public let filmGrainParamsPresent: Bool

    public init(
        seqProfile: AV1Profile,
        stillPicture: Bool,
        reducedStillPictureHeader: Bool,
        timingInfo: TimingInfo? = nil,
        decoderModelInfo: AV1DecoderModelInfo? = nil,
        initialDisplayDelayPresentFlag: Bool,
        operatingPoints: [AV1OperatingPoint],
        frameWidthBitsMinus1: UInt8,
        frameHeightBitsMinus1: UInt8,
        maxFrameWidthMinus1: UInt32,
        maxFrameHeightMinus1: UInt32,
        frameIDNumbersPresentFlag: Bool,
        deltaFrameIDLengthMinus2: UInt8? = nil,
        additionalFrameIDLengthMinus1: UInt8? = nil,
        use128x128Superblock: Bool,
        enableFilterIntra: Bool,
        enableIntraEdgeFilter: Bool,
        enableInterIntraCompound: Bool = false,
        enableMaskedCompound: Bool = false,
        enableWarpedMotion: Bool = false,
        enableDualFilter: Bool = false,
        enableOrderHint: Bool = false,
        enableJntComp: Bool = false,
        enableRefFrameMVs: Bool = false,
        seqChooseScreenContentTools: Bool = true,
        seqForceScreenContentTools: UInt8 = 2,
        seqChooseIntegerMV: Bool? = nil,
        seqForceIntegerMV: UInt8? = nil,
        orderHintBitsMinus1: UInt8? = nil,
        enableSuperRes: Bool,
        enableCDEF: Bool,
        enableRestoration: Bool,
        colorConfig: ColorConfig,
        filmGrainParamsPresent: Bool
    ) {
        self.seqProfile = seqProfile
        self.stillPicture = stillPicture
        self.reducedStillPictureHeader = reducedStillPictureHeader
        self.timingInfo = timingInfo
        self.decoderModelInfo = decoderModelInfo
        self.initialDisplayDelayPresentFlag = initialDisplayDelayPresentFlag
        self.operatingPoints = operatingPoints
        self.frameWidthBitsMinus1 = frameWidthBitsMinus1
        self.frameHeightBitsMinus1 = frameHeightBitsMinus1
        self.maxFrameWidthMinus1 = maxFrameWidthMinus1
        self.maxFrameHeightMinus1 = maxFrameHeightMinus1
        self.frameIDNumbersPresentFlag = frameIDNumbersPresentFlag
        self.deltaFrameIDLengthMinus2 = deltaFrameIDLengthMinus2
        self.additionalFrameIDLengthMinus1 = additionalFrameIDLengthMinus1
        self.use128x128Superblock = use128x128Superblock
        self.enableFilterIntra = enableFilterIntra
        self.enableIntraEdgeFilter = enableIntraEdgeFilter
        self.enableInterIntraCompound = enableInterIntraCompound
        self.enableMaskedCompound = enableMaskedCompound
        self.enableWarpedMotion = enableWarpedMotion
        self.enableDualFilter = enableDualFilter
        self.enableOrderHint = enableOrderHint
        self.enableJntComp = enableJntComp
        self.enableRefFrameMVs = enableRefFrameMVs
        self.seqChooseScreenContentTools = seqChooseScreenContentTools
        self.seqForceScreenContentTools = seqForceScreenContentTools
        self.seqChooseIntegerMV = seqChooseIntegerMV
        self.seqForceIntegerMV = seqForceIntegerMV
        self.orderHintBitsMinus1 = orderHintBitsMinus1
        self.enableSuperRes = enableSuperRes
        self.enableCDEF = enableCDEF
        self.enableRestoration = enableRestoration
        self.colorConfig = colorConfig
        self.filmGrainParamsPresent = filmGrainParamsPresent
    }
}

// MARK: - Parse / encode

extension AV1SequenceHeader {

    public static func parse(bitstream: Data) throws -> AV1SequenceHeader {
        var reader = BitReader(bitstream)
        let profileRaw = UInt8(try reader.readBits(3))
        guard let seqProfile = AV1Profile(rawValue: profileRaw) else {
            throw BitstreamError.unsupportedValue(
                codec: "AV1", field: "seq_profile", value: UInt64(profileRaw)
            )
        }
        let stillPicture = try reader.readBool()
        let reducedStillPicture = try reader.readBool()
        var timing: TimingInfo?
        var decoderModel: AV1DecoderModelInfo?
        var initialDisplayDelayPresent = false
        var operatingPoints: [AV1OperatingPoint] = []
        if reducedStillPicture {
            let levelRaw = UInt8(try reader.readBits(5))
            guard let level = AV1Level(rawValue: levelRaw) else {
                throw BitstreamError.unsupportedValue(
                    codec: "AV1", field: "seq_level_idx", value: UInt64(levelRaw)
                )
            }
            operatingPoints.append(
                AV1OperatingPoint(operatingPointIDC: 0, seqLevelIDX: level)
            )
        } else {
            let timingPresent = try reader.readBool()
            if timingPresent {
                let num = UInt32(try reader.readBits(32))
                let scale = UInt32(try reader.readBits(32))
                let equal = try reader.readBool()
                var ticks: UInt32?
                if equal {
                    ticks = try reader.readUnsignedExpGolomb()
                }
                timing = TimingInfo(
                    numUnitsInDisplayTick: num,
                    timeScale: scale,
                    equalPictureInterval: equal,
                    numTicksPerPictureMinus1: ticks
                )
                let decoderModelPresent = try reader.readBool()
                if decoderModelPresent {
                    decoderModel = try AV1DecoderModelInfo.parse(reader: &reader)
                }
            }
            initialDisplayDelayPresent = try reader.readBool()
            let opCountMinus1 = UInt8(try reader.readBits(5))
            for _ in 0...opCountMinus1 {
                let idc = UInt16(try reader.readBits(12))
                let levelRaw = UInt8(try reader.readBits(5))
                guard let level = AV1Level(rawValue: levelRaw) else {
                    throw BitstreamError.unsupportedValue(
                        codec: "AV1", field: "seq_level_idx", value: UInt64(levelRaw)
                    )
                }
                var tier: AV1Tier?
                if levelRaw > 7 {
                    let tierRaw = UInt8(try reader.readBits(1))
                    tier = AV1Tier(rawValue: tierRaw)
                }
                var opParams: AV1OperatingParametersInfo?
                if let model = decoderModel {
                    let opPresent = try reader.readBool()
                    if opPresent {
                        opParams = try AV1OperatingParametersInfo.parse(
                            reader: &reader,
                            bufferDelayLengthMinus1: model.bufferDelayLengthMinus1
                        )
                    }
                }
                var idd: UInt8?
                if initialDisplayDelayPresent {
                    let present = try reader.readBool()
                    if present { idd = UInt8(try reader.readBits(4)) }
                }
                operatingPoints.append(
                    AV1OperatingPoint(
                        operatingPointIDC: idc,
                        seqLevelIDX: level,
                        seqTier: tier,
                        operatingParametersInfo: opParams,
                        initialDisplayDelayMinus1: idd
                    )
                )
            }
        }
        let widthBits = UInt8(try reader.readBits(4))
        let heightBits = UInt8(try reader.readBits(4))
        let maxWidth = UInt32(try reader.readBits(Int(widthBits) + 1))
        let maxHeight = UInt32(try reader.readBits(Int(heightBits) + 1))
        var frameIDPresent = false
        var deltaFrameIDLength: UInt8?
        var additionalFrameIDLength: UInt8?
        if !reducedStillPicture {
            frameIDPresent = try reader.readBool()
            if frameIDPresent {
                deltaFrameIDLength = UInt8(try reader.readBits(4))
                additionalFrameIDLength = UInt8(try reader.readBits(3))
            }
        }
        let use128x128 = try reader.readBool()
        let enableFilterIntra = try reader.readBool()
        let enableIntraEdgeFilter = try reader.readBool()
        var enableInterIntraCompound = false
        var enableMaskedCompound = false
        var enableWarpedMotion = false
        var enableDualFilter = false
        var enableOrderHint = false
        var enableJntComp = false
        var enableRefFrameMVs = false
        var seqChooseSCT = true
        var seqForceSCT: UInt8 = 2  // SELECT_SCREEN_CONTENT_TOOLS
        var seqChooseIntegerMV: Bool?
        var seqForceIntegerMV: UInt8?
        var orderHintBits: UInt8?
        if !reducedStillPicture {
            enableInterIntraCompound = try reader.readBool()
            enableMaskedCompound = try reader.readBool()
            enableWarpedMotion = try reader.readBool()
            enableDualFilter = try reader.readBool()
            enableOrderHint = try reader.readBool()
            if enableOrderHint {
                enableJntComp = try reader.readBool()
                enableRefFrameMVs = try reader.readBool()
            }
            seqChooseSCT = try reader.readBool()
            if !seqChooseSCT {
                seqForceSCT = UInt8(try reader.readBits(1))
            }
            if seqForceSCT > 0 {
                let choose = try reader.readBool()
                seqChooseIntegerMV = choose
                if !choose {
                    seqForceIntegerMV = UInt8(try reader.readBits(1))
                }
            }
            if enableOrderHint {
                orderHintBits = UInt8(try reader.readBits(3))
            }
        }
        let enableSuperRes = try reader.readBool()
        let enableCDEF = try reader.readBool()
        let enableRestoration = try reader.readBool()
        let colorConfig = try parseColorConfig(reader: &reader, seqProfile: seqProfile)
        let filmGrain = try reader.readBool()
        return AV1SequenceHeader(
            seqProfile: seqProfile,
            stillPicture: stillPicture,
            reducedStillPictureHeader: reducedStillPicture,
            timingInfo: timing,
            decoderModelInfo: decoderModel,
            initialDisplayDelayPresentFlag: initialDisplayDelayPresent,
            operatingPoints: operatingPoints,
            frameWidthBitsMinus1: widthBits,
            frameHeightBitsMinus1: heightBits,
            maxFrameWidthMinus1: maxWidth,
            maxFrameHeightMinus1: maxHeight,
            frameIDNumbersPresentFlag: frameIDPresent,
            deltaFrameIDLengthMinus2: deltaFrameIDLength,
            additionalFrameIDLengthMinus1: additionalFrameIDLength,
            use128x128Superblock: use128x128,
            enableFilterIntra: enableFilterIntra,
            enableIntraEdgeFilter: enableIntraEdgeFilter,
            enableInterIntraCompound: enableInterIntraCompound,
            enableMaskedCompound: enableMaskedCompound,
            enableWarpedMotion: enableWarpedMotion,
            enableDualFilter: enableDualFilter,
            enableOrderHint: enableOrderHint,
            enableJntComp: enableJntComp,
            enableRefFrameMVs: enableRefFrameMVs,
            seqChooseScreenContentTools: seqChooseSCT,
            seqForceScreenContentTools: seqForceSCT,
            seqChooseIntegerMV: seqChooseIntegerMV,
            seqForceIntegerMV: seqForceIntegerMV,
            orderHintBitsMinus1: orderHintBits,
            enableSuperRes: enableSuperRes,
            enableCDEF: enableCDEF,
            enableRestoration: enableRestoration,
            colorConfig: colorConfig,
            filmGrainParamsPresent: filmGrain
        )
    }

    private static func parseColorConfig(
        reader: inout BitReader,
        seqProfile: AV1Profile
    ) throws -> ColorConfig {
        let highBitDepth = try reader.readBool()
        var twelveBit: Bool?
        if seqProfile == .professional, highBitDepth {
            twelveBit = try reader.readBool()
        }
        var monochrome = false
        if seqProfile == .high {
            monochrome = false
        } else {
            monochrome = try reader.readBool()
        }
        var cd: ColorConfig.ColorDescription?
        if try reader.readBool() {
            let cp = UInt8(try reader.readBits(8))
            let tc = UInt8(try reader.readBits(8))
            let mc = UInt8(try reader.readBits(8))
            guard let cpEnum = ColorPrimaries(rawValue: cp),
                let tcEnum = TransferCharacteristics(rawValue: tc),
                let mcEnum = MatrixCoefficients(rawValue: mc)
            else {
                throw BitstreamError.unsupportedValue(
                    codec: "AV1", field: "color_description",
                    value: (UInt64(cp) << 16) | (UInt64(tc) << 8) | UInt64(mc)
                )
            }
            cd = ColorConfig.ColorDescription(
                colorPrimaries: cpEnum,
                transferCharacteristics: tcEnum,
                matrixCoefficients: mcEnum
            )
        }
        var colorRange: VideoFullRangeFlag = .limited
        var subX = false
        var subY = false
        var chromaPos: AV1ChromaSamplePosition?
        if monochrome {
            colorRange = try reader.readBool() ? .full : .limited
            subX = true
            subY = true
        } else {
            colorRange = try reader.readBool() ? .full : .limited
            switch seqProfile {
            case .main:
                subX = true
                subY = true
            case .high:
                subX = false
                subY = false
            case .professional:
                let bitDepth = highBitDepth ? (twelveBit == true ? 12 : 10) : 8
                if bitDepth == 12 {
                    subX = try reader.readBool()
                    if subX { subY = try reader.readBool() } else { subY = false }
                } else {
                    subX = true
                    subY = false
                }
            }
            if subX && subY {
                let cpRaw = UInt8(try reader.readBits(2))
                chromaPos = AV1ChromaSamplePosition(rawValue: cpRaw)
            }
        }
        let sep = try reader.readBool()
        return ColorConfig(
            highBitDepth: highBitDepth,
            twelveBit: twelveBit,
            monochrome: monochrome,
            colorDescription: cd,
            colorRange: colorRange,
            subsamplingX: subX,
            subsamplingY: subY,
            chromaSamplePosition: chromaPos,
            separateUVDeltaQ: sep
        )
    }

    public func encode() -> Data {
        var writer = BitWriter()
        writer.writeBits(UInt64(seqProfile.rawValue & 0x07), count: 3)
        writer.writeBool(stillPicture)
        writer.writeBool(reducedStillPictureHeader)
        if reducedStillPictureHeader {
            writer.writeBits(UInt64(operatingPoints[0].seqLevelIDX.rawValue & 0x1F), count: 5)
        } else {
            writer.writeBool(timingInfo != nil)
            if let ti = timingInfo {
                writer.writeBits(UInt64(ti.numUnitsInDisplayTick), count: 32)
                writer.writeBits(UInt64(ti.timeScale), count: 32)
                writer.writeBool(ti.equalPictureInterval)
                if ti.equalPictureInterval {
                    writer.writeUnsignedExpGolomb(ti.numTicksPerPictureMinus1 ?? 0)
                }
                writer.writeBool(decoderModelInfo != nil)
                decoderModelInfo?.encode(to: &writer)
            }
            writer.writeBool(initialDisplayDelayPresentFlag)
            writer.writeBits(UInt64(operatingPoints.count - 1), count: 5)
            for op in operatingPoints {
                writer.writeBits(UInt64(op.operatingPointIDC), count: 12)
                writer.writeBits(UInt64(op.seqLevelIDX.rawValue & 0x1F), count: 5)
                if op.seqLevelIDX.rawValue > 7 {
                    writer.writeBits(UInt64(op.seqTier?.rawValue ?? 0), count: 1)
                }
                if let model = decoderModelInfo {
                    writer.writeBool(op.operatingParametersInfo != nil)
                    op.operatingParametersInfo?.encode(
                        to: &writer,
                        bufferDelayLengthMinus1: model.bufferDelayLengthMinus1
                    )
                }
                if initialDisplayDelayPresentFlag {
                    writer.writeBool(op.initialDisplayDelayMinus1 != nil)
                    if let idd = op.initialDisplayDelayMinus1 {
                        writer.writeBits(UInt64(idd), count: 4)
                    }
                }
            }
        }
        writer.writeBits(UInt64(frameWidthBitsMinus1 & 0x0F), count: 4)
        writer.writeBits(UInt64(frameHeightBitsMinus1 & 0x0F), count: 4)
        writer.writeBits(UInt64(maxFrameWidthMinus1), count: Int(frameWidthBitsMinus1) + 1)
        writer.writeBits(UInt64(maxFrameHeightMinus1), count: Int(frameHeightBitsMinus1) + 1)
        if !reducedStillPictureHeader {
            writer.writeBool(frameIDNumbersPresentFlag)
            if frameIDNumbersPresentFlag {
                writer.writeBits(UInt64(deltaFrameIDLengthMinus2 ?? 0), count: 4)
                writer.writeBits(UInt64(additionalFrameIDLengthMinus1 ?? 0), count: 3)
            }
        }
        writer.writeBool(use128x128Superblock)
        writer.writeBool(enableFilterIntra)
        writer.writeBool(enableIntraEdgeFilter)
        if !reducedStillPictureHeader {
            writer.writeBool(enableInterIntraCompound)
            writer.writeBool(enableMaskedCompound)
            writer.writeBool(enableWarpedMotion)
            writer.writeBool(enableDualFilter)
            writer.writeBool(enableOrderHint)
            if enableOrderHint {
                writer.writeBool(enableJntComp)
                writer.writeBool(enableRefFrameMVs)
            }
            writer.writeBool(seqChooseScreenContentTools)
            if !seqChooseScreenContentTools {
                writer.writeBits(UInt64(seqForceScreenContentTools & 0x01), count: 1)
            }
            if seqForceScreenContentTools > 0 {
                // When seqChooseIntegerMV is nil (caller didn't specify),
                // default to `true` (SELECT_INTEGER_MV) — the common case
                // — which obviates the forceIntegerMV bit.
                let chooseValue = seqChooseIntegerMV ?? true
                writer.writeBool(chooseValue)
                if !chooseValue {
                    writer.writeBits(UInt64(seqForceIntegerMV ?? 0), count: 1)
                }
            }
            if enableOrderHint {
                writer.writeBits(UInt64(orderHintBitsMinus1 ?? 0), count: 3)
            }
        }
        writer.writeBool(enableSuperRes)
        writer.writeBool(enableCDEF)
        writer.writeBool(enableRestoration)
        encodeColorConfig(to: &writer)
        writer.writeBool(filmGrainParamsPresent)
        writer.byteAlign()
        return writer.data
    }

    private func encodeColorConfig(to writer: inout BitWriter) {
        writer.writeBool(colorConfig.highBitDepth)
        if seqProfile == .professional, colorConfig.highBitDepth {
            writer.writeBool(colorConfig.twelveBit ?? false)
        }
        if seqProfile != .high {
            writer.writeBool(colorConfig.monochrome)
        }
        writer.writeBool(colorConfig.colorDescription != nil)
        if let cd = colorConfig.colorDescription {
            writer.writeBits(UInt64(cd.colorPrimaries.rawValue), count: 8)
            writer.writeBits(UInt64(cd.transferCharacteristics.rawValue), count: 8)
            writer.writeBits(UInt64(cd.matrixCoefficients.rawValue), count: 8)
        }
        if colorConfig.monochrome {
            writer.writeBool(colorConfig.colorRange == .full)
        } else {
            writer.writeBool(colorConfig.colorRange == .full)
            switch seqProfile {
            case .main, .high:
                break
            case .professional:
                let bitDepth =
                    colorConfig.highBitDepth
                    ? (colorConfig.twelveBit == true ? 12 : 10)
                    : 8
                if bitDepth == 12 {
                    writer.writeBool(colorConfig.subsamplingX)
                    if colorConfig.subsamplingX {
                        writer.writeBool(colorConfig.subsamplingY)
                    }
                }
            }
            if colorConfig.subsamplingX && colorConfig.subsamplingY {
                writer.writeBits(
                    UInt64(colorConfig.chromaSamplePosition?.rawValue ?? 0), count: 2
                )
            }
        }
        writer.writeBool(colorConfig.separateUVDeltaQ)
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - HEVCVUIParameters
//
// Reference: ITU-T H.265 §E.2.1 (vui_parameters).

import Foundation

/// HEVC Video Usability Information per ITU-T H.265 §E.2.1.
public struct HEVCVUIParameters: Sendable, Hashable, Equatable {

    public struct AspectRatioInfo: Sendable, Hashable, Equatable {
        public let aspectRatioIDC: UInt8
        public let sarWidth: UInt16?
        public let sarHeight: UInt16?

        public init(aspectRatioIDC: UInt8, sarWidth: UInt16? = nil, sarHeight: UInt16? = nil) {
            self.aspectRatioIDC = aspectRatioIDC
            self.sarWidth = sarWidth
            self.sarHeight = sarHeight
        }
    }

    public struct ColourDescription: Sendable, Hashable, Equatable {
        public let colourPrimaries: ColorPrimaries
        public let transferCharacteristics: TransferCharacteristics
        public let matrixCoefficients: MatrixCoefficients

        public init(
            colourPrimaries: ColorPrimaries,
            transferCharacteristics: TransferCharacteristics,
            matrixCoefficients: MatrixCoefficients
        ) {
            self.colourPrimaries = colourPrimaries
            self.transferCharacteristics = transferCharacteristics
            self.matrixCoefficients = matrixCoefficients
        }
    }

    public struct VideoSignal: Sendable, Hashable, Equatable {
        public let videoFormat: UInt8
        public let videoFullRangeFlag: VideoFullRangeFlag
        public let colourDescription: ColourDescription?

        public init(
            videoFormat: UInt8,
            videoFullRangeFlag: VideoFullRangeFlag,
            colourDescription: ColourDescription? = nil
        ) {
            self.videoFormat = videoFormat
            self.videoFullRangeFlag = videoFullRangeFlag
            self.colourDescription = colourDescription
        }
    }

    public struct ChromaLocInfo: Sendable, Hashable, Equatable {
        public let topFieldType: UInt32
        public let bottomFieldType: UInt32

        public init(topFieldType: UInt32, bottomFieldType: UInt32) {
            self.topFieldType = topFieldType
            self.bottomFieldType = bottomFieldType
        }
    }

    public struct DisplayWindow: Sendable, Hashable, Equatable {
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

    public struct TimingInfo: Sendable, Hashable, Equatable {
        public let numUnitsInTick: UInt32
        public let timeScale: UInt32
        public let pocProportionalToTimingFlag: Bool
        public let numTicksPOCDiffOneMinus1: UInt32?
        public let hrdParameters: HEVCHRDParameters?

        public init(
            numUnitsInTick: UInt32,
            timeScale: UInt32,
            pocProportionalToTimingFlag: Bool,
            numTicksPOCDiffOneMinus1: UInt32? = nil,
            hrdParameters: HEVCHRDParameters? = nil
        ) {
            self.numUnitsInTick = numUnitsInTick
            self.timeScale = timeScale
            self.pocProportionalToTimingFlag = pocProportionalToTimingFlag
            self.numTicksPOCDiffOneMinus1 = numTicksPOCDiffOneMinus1
            self.hrdParameters = hrdParameters
        }
    }

    public struct BitstreamRestrictions: Sendable, Hashable, Equatable {
        public let tilesFixedStructureFlag: Bool
        public let motionVectorsOverPicBoundariesFlag: Bool
        public let restrictedRefPicListsFlag: Bool
        public let minSpatialSegmentationIDC: UInt32
        public let maxBytesPerPicDenom: UInt32
        public let maxBitsPerMinCuDenom: UInt32
        public let log2MaxMvLengthHorizontal: UInt32
        public let log2MaxMvLengthVertical: UInt32

        public init(
            tilesFixedStructureFlag: Bool,
            motionVectorsOverPicBoundariesFlag: Bool,
            restrictedRefPicListsFlag: Bool,
            minSpatialSegmentationIDC: UInt32,
            maxBytesPerPicDenom: UInt32,
            maxBitsPerMinCuDenom: UInt32,
            log2MaxMvLengthHorizontal: UInt32,
            log2MaxMvLengthVertical: UInt32
        ) {
            self.tilesFixedStructureFlag = tilesFixedStructureFlag
            self.motionVectorsOverPicBoundariesFlag = motionVectorsOverPicBoundariesFlag
            self.restrictedRefPicListsFlag = restrictedRefPicListsFlag
            self.minSpatialSegmentationIDC = minSpatialSegmentationIDC
            self.maxBytesPerPicDenom = maxBytesPerPicDenom
            self.maxBitsPerMinCuDenom = maxBitsPerMinCuDenom
            self.log2MaxMvLengthHorizontal = log2MaxMvLengthHorizontal
            self.log2MaxMvLengthVertical = log2MaxMvLengthVertical
        }
    }

    public let aspectRatio: AspectRatioInfo?
    public let overscanAppropriateFlag: Bool?
    public let videoSignal: VideoSignal?
    public let chromaLocInfo: ChromaLocInfo?
    public let neutralChromaIndicationFlag: Bool
    public let fieldSeqFlag: Bool
    public let frameFieldInfoPresentFlag: Bool
    public let defaultDisplayWindow: DisplayWindow?
    public let timingInfo: TimingInfo?
    public let bitstreamRestrictions: BitstreamRestrictions?

    public init(
        aspectRatio: AspectRatioInfo? = nil,
        overscanAppropriateFlag: Bool? = nil,
        videoSignal: VideoSignal? = nil,
        chromaLocInfo: ChromaLocInfo? = nil,
        neutralChromaIndicationFlag: Bool = false,
        fieldSeqFlag: Bool = false,
        frameFieldInfoPresentFlag: Bool = false,
        defaultDisplayWindow: DisplayWindow? = nil,
        timingInfo: TimingInfo? = nil,
        bitstreamRestrictions: BitstreamRestrictions? = nil
    ) {
        self.aspectRatio = aspectRatio
        self.overscanAppropriateFlag = overscanAppropriateFlag
        self.videoSignal = videoSignal
        self.chromaLocInfo = chromaLocInfo
        self.neutralChromaIndicationFlag = neutralChromaIndicationFlag
        self.fieldSeqFlag = fieldSeqFlag
        self.frameFieldInfoPresentFlag = frameFieldInfoPresentFlag
        self.defaultDisplayWindow = defaultDisplayWindow
        self.timingInfo = timingInfo
        self.bitstreamRestrictions = bitstreamRestrictions
    }

    public static func parse(
        reader: inout BitReader,
        maxNumSubLayersMinus1: UInt8
    ) throws -> HEVCVUIParameters {
        var aspect: AspectRatioInfo?
        if try reader.readBool() {
            let idc = UInt8(try reader.readBits(8))
            if idc == 0xFF {
                let sw = UInt16(try reader.readBits(16))
                let sh = UInt16(try reader.readBits(16))
                aspect = AspectRatioInfo(aspectRatioIDC: idc, sarWidth: sw, sarHeight: sh)
            } else {
                aspect = AspectRatioInfo(aspectRatioIDC: idc)
            }
        }
        var overscan: Bool?
        if try reader.readBool() { overscan = try reader.readBool() }
        var videoSignal: VideoSignal?
        if try reader.readBool() {
            let fmt = UInt8(try reader.readBits(3))
            let range: VideoFullRangeFlag = try reader.readBool() ? .full : .limited
            var cd: ColourDescription?
            if try reader.readBool() {
                let cp = UInt8(try reader.readBits(8))
                let tc = UInt8(try reader.readBits(8))
                let mc = UInt8(try reader.readBits(8))
                guard let cpEnum = ColorPrimaries(rawValue: cp),
                    let tcEnum = TransferCharacteristics(rawValue: tc),
                    let mcEnum = MatrixCoefficients(rawValue: mc)
                else {
                    throw BitstreamError.unsupportedValue(
                        codec: "HEVC", field: "colour_description",
                        value: (UInt64(cp) << 16) | (UInt64(tc) << 8) | UInt64(mc)
                    )
                }
                cd = ColourDescription(
                    colourPrimaries: cpEnum,
                    transferCharacteristics: tcEnum,
                    matrixCoefficients: mcEnum
                )
            }
            videoSignal = VideoSignal(
                videoFormat: fmt, videoFullRangeFlag: range, colourDescription: cd
            )
        }
        var chromaLoc: ChromaLocInfo?
        if try reader.readBool() {
            chromaLoc = ChromaLocInfo(
                topFieldType: try reader.readUnsignedExpGolomb(),
                bottomFieldType: try reader.readUnsignedExpGolomb()
            )
        }
        let neutralChroma = try reader.readBool()
        let fieldSeq = try reader.readBool()
        let frameFieldInfo = try reader.readBool()
        var displayWindow: DisplayWindow?
        if try reader.readBool() {
            displayWindow = DisplayWindow(
                leftOffset: try reader.readUnsignedExpGolomb(),
                rightOffset: try reader.readUnsignedExpGolomb(),
                topOffset: try reader.readUnsignedExpGolomb(),
                bottomOffset: try reader.readUnsignedExpGolomb()
            )
        }
        var timing: TimingInfo?
        if try reader.readBool() {
            let units = UInt32(try reader.readBits(32))
            let scale = UInt32(try reader.readBits(32))
            let pocProp = try reader.readBool()
            var numTicks: UInt32?
            if pocProp { numTicks = try reader.readUnsignedExpGolomb() }
            var hrd: HEVCHRDParameters?
            if try reader.readBool() {
                hrd = try HEVCHRDParameters.parse(
                    reader: &reader,
                    commonInfPresentFlag: true,
                    maxNumSubLayersMinus1: maxNumSubLayersMinus1
                )
            }
            timing = TimingInfo(
                numUnitsInTick: units,
                timeScale: scale,
                pocProportionalToTimingFlag: pocProp,
                numTicksPOCDiffOneMinus1: numTicks,
                hrdParameters: hrd
            )
        }
        var restrictions: BitstreamRestrictions?
        if try reader.readBool() {
            restrictions = BitstreamRestrictions(
                tilesFixedStructureFlag: try reader.readBool(),
                motionVectorsOverPicBoundariesFlag: try reader.readBool(),
                restrictedRefPicListsFlag: try reader.readBool(),
                minSpatialSegmentationIDC: try reader.readUnsignedExpGolomb(),
                maxBytesPerPicDenom: try reader.readUnsignedExpGolomb(),
                maxBitsPerMinCuDenom: try reader.readUnsignedExpGolomb(),
                log2MaxMvLengthHorizontal: try reader.readUnsignedExpGolomb(),
                log2MaxMvLengthVertical: try reader.readUnsignedExpGolomb()
            )
        }
        return HEVCVUIParameters(
            aspectRatio: aspect,
            overscanAppropriateFlag: overscan,
            videoSignal: videoSignal,
            chromaLocInfo: chromaLoc,
            neutralChromaIndicationFlag: neutralChroma,
            fieldSeqFlag: fieldSeq,
            frameFieldInfoPresentFlag: frameFieldInfo,
            defaultDisplayWindow: displayWindow,
            timingInfo: timing,
            bitstreamRestrictions: restrictions
        )
    }

    public func encode(
        to writer: inout BitWriter,
        maxNumSubLayersMinus1: UInt8
    ) {
        writer.writeBool(aspectRatio != nil)
        if let ar = aspectRatio {
            writer.writeBits(UInt64(ar.aspectRatioIDC), count: 8)
            if ar.aspectRatioIDC == 0xFF {
                writer.writeBits(UInt64(ar.sarWidth ?? 0), count: 16)
                writer.writeBits(UInt64(ar.sarHeight ?? 0), count: 16)
            }
        }
        writer.writeBool(overscanAppropriateFlag != nil)
        if let v = overscanAppropriateFlag { writer.writeBool(v) }
        writer.writeBool(videoSignal != nil)
        if let vs = videoSignal {
            writer.writeBits(UInt64(vs.videoFormat & 0x07), count: 3)
            writer.writeBool(vs.videoFullRangeFlag == .full)
            writer.writeBool(vs.colourDescription != nil)
            if let cd = vs.colourDescription {
                writer.writeBits(UInt64(cd.colourPrimaries.rawValue), count: 8)
                writer.writeBits(UInt64(cd.transferCharacteristics.rawValue), count: 8)
                writer.writeBits(UInt64(cd.matrixCoefficients.rawValue), count: 8)
            }
        }
        writer.writeBool(chromaLocInfo != nil)
        if let cl = chromaLocInfo {
            writer.writeUnsignedExpGolomb(cl.topFieldType)
            writer.writeUnsignedExpGolomb(cl.bottomFieldType)
        }
        writer.writeBool(neutralChromaIndicationFlag)
        writer.writeBool(fieldSeqFlag)
        writer.writeBool(frameFieldInfoPresentFlag)
        writer.writeBool(defaultDisplayWindow != nil)
        if let dw = defaultDisplayWindow {
            writer.writeUnsignedExpGolomb(dw.leftOffset)
            writer.writeUnsignedExpGolomb(dw.rightOffset)
            writer.writeUnsignedExpGolomb(dw.topOffset)
            writer.writeUnsignedExpGolomb(dw.bottomOffset)
        }
        writer.writeBool(timingInfo != nil)
        if let ti = timingInfo {
            writer.writeBits(UInt64(ti.numUnitsInTick), count: 32)
            writer.writeBits(UInt64(ti.timeScale), count: 32)
            writer.writeBool(ti.pocProportionalToTimingFlag)
            if ti.pocProportionalToTimingFlag {
                writer.writeUnsignedExpGolomb(ti.numTicksPOCDiffOneMinus1 ?? 0)
            }
            writer.writeBool(ti.hrdParameters != nil)
            ti.hrdParameters?.encode(
                to: &writer,
                commonInfPresentFlag: true,
                maxNumSubLayersMinus1: maxNumSubLayersMinus1
            )
        }
        writer.writeBool(bitstreamRestrictions != nil)
        if let r = bitstreamRestrictions {
            writer.writeBool(r.tilesFixedStructureFlag)
            writer.writeBool(r.motionVectorsOverPicBoundariesFlag)
            writer.writeBool(r.restrictedRefPicListsFlag)
            writer.writeUnsignedExpGolomb(r.minSpatialSegmentationIDC)
            writer.writeUnsignedExpGolomb(r.maxBytesPerPicDenom)
            writer.writeUnsignedExpGolomb(r.maxBitsPerMinCuDenom)
            writer.writeUnsignedExpGolomb(r.log2MaxMvLengthHorizontal)
            writer.writeUnsignedExpGolomb(r.log2MaxMvLengthVertical)
        }
    }
}

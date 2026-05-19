// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCVUIParameters
//
// Reference: ITU-T H.264 §E.1.1 (vui_parameters).
//
// The VUI carries presentation metadata that complements the codec's
// own structural parameters. CMAFKit consumes the colour description
// fields as a fallback when no container-level `colr` box is present;
// the timing info informs frame-rate inference for the validator.

import Foundation

/// AVC Video Usability Information per ITU-T H.264 §E.1.1.
public struct AVCVUIParameters: Sendable, Hashable, Equatable, Codable {

    /// Sample aspect ratio info (§E.2.1).
    public struct AspectRatioInfo: Sendable, Hashable, Equatable, Codable {
        /// Sample aspect ratio indicator. Value `0xFF` is "Extended_SAR"
        /// and means the explicit `sarWidth`/`sarHeight` fields follow.
        public let aspectRatioIDC: UInt8
        /// Extended SAR width; present iff `aspectRatioIDC == 0xFF`.
        public let sarWidth: UInt16?
        /// Extended SAR height; present iff `aspectRatioIDC == 0xFF`.
        public let sarHeight: UInt16?

        public init(aspectRatioIDC: UInt8, sarWidth: UInt16? = nil, sarHeight: UInt16? = nil) {
            precondition(
                (aspectRatioIDC == 0xFF) == (sarWidth != nil && sarHeight != nil),
                "Extended SAR width/height must be present iff aspectRatioIDC == 255"
            )
            self.aspectRatioIDC = aspectRatioIDC
            self.sarWidth = sarWidth
            self.sarHeight = sarHeight
        }
    }

    /// Colour description sub-structure of VideoSignal (§E.2.1).
    public struct ColourDescription: Sendable, Hashable, Equatable, Codable {
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

    /// Video signal type sub-structure (§E.2.1).
    public struct VideoSignal: Sendable, Hashable, Equatable, Codable {
        public let videoFormat: UInt8
        public let videoFullRangeFlag: VideoFullRangeFlag
        public let colourDescription: ColourDescription?

        public init(
            videoFormat: UInt8,
            videoFullRangeFlag: VideoFullRangeFlag,
            colourDescription: ColourDescription? = nil
        ) {
            precondition(videoFormat <= 0x07, "videoFormat must fit 3 bits")
            self.videoFormat = videoFormat
            self.videoFullRangeFlag = videoFullRangeFlag
            self.colourDescription = colourDescription
        }
    }

    /// Chroma sample location (§E.2.1).
    public struct ChromaLocationInfo: Sendable, Hashable, Equatable, Codable {
        public let topFieldType: UInt32
        public let bottomFieldType: UInt32

        public init(topFieldType: UInt32, bottomFieldType: UInt32) {
            self.topFieldType = topFieldType
            self.bottomFieldType = bottomFieldType
        }
    }

    /// Timing info (§E.2.1).
    public struct TimingInfo: Sendable, Hashable, Equatable, Codable {
        public let numUnitsInTick: UInt32
        public let timeScale: UInt32
        public let fixedFrameRateFlag: Bool

        public init(numUnitsInTick: UInt32, timeScale: UInt32, fixedFrameRateFlag: Bool) {
            self.numUnitsInTick = numUnitsInTick
            self.timeScale = timeScale
            self.fixedFrameRateFlag = fixedFrameRateFlag
        }
    }

    /// Bitstream restriction info (§E.2.1).
    public struct BitstreamRestrictions: Sendable, Hashable, Equatable, Codable {
        public let motionVectorsOverPicBoundariesFlag: Bool
        public let maxBytesPerPicDenom: UInt32
        public let maxBitsPerMBDenom: UInt32
        public let log2MaxMvLengthHorizontal: UInt32
        public let log2MaxMvLengthVertical: UInt32
        public let maxNumReorderFrames: UInt32
        public let maxDecFrameBuffering: UInt32

        public init(
            motionVectorsOverPicBoundariesFlag: Bool,
            maxBytesPerPicDenom: UInt32,
            maxBitsPerMBDenom: UInt32,
            log2MaxMvLengthHorizontal: UInt32,
            log2MaxMvLengthVertical: UInt32,
            maxNumReorderFrames: UInt32,
            maxDecFrameBuffering: UInt32
        ) {
            self.motionVectorsOverPicBoundariesFlag = motionVectorsOverPicBoundariesFlag
            self.maxBytesPerPicDenom = maxBytesPerPicDenom
            self.maxBitsPerMBDenom = maxBitsPerMBDenom
            self.log2MaxMvLengthHorizontal = log2MaxMvLengthHorizontal
            self.log2MaxMvLengthVertical = log2MaxMvLengthVertical
            self.maxNumReorderFrames = maxNumReorderFrames
            self.maxDecFrameBuffering = maxDecFrameBuffering
        }
    }

    public let aspectRatio: AspectRatioInfo?
    public let overscanAppropriateFlag: Bool?
    public let videoSignal: VideoSignal?
    public let chromaLocInfo: ChromaLocationInfo?
    public let timingInfo: TimingInfo?
    public let nalHRDParameters: AVCHRDParameters?
    public let vclHRDParameters: AVCHRDParameters?
    public let lowDelayHRDFlag: Bool?
    public let picStructPresentFlag: Bool
    public let bitstreamRestrictions: BitstreamRestrictions?

    public init(
        aspectRatio: AspectRatioInfo? = nil,
        overscanAppropriateFlag: Bool? = nil,
        videoSignal: VideoSignal? = nil,
        chromaLocInfo: ChromaLocationInfo? = nil,
        timingInfo: TimingInfo? = nil,
        nalHRDParameters: AVCHRDParameters? = nil,
        vclHRDParameters: AVCHRDParameters? = nil,
        lowDelayHRDFlag: Bool? = nil,
        picStructPresentFlag: Bool = false,
        bitstreamRestrictions: BitstreamRestrictions? = nil
    ) {
        precondition(
            (nalHRDParameters != nil || vclHRDParameters != nil) == (lowDelayHRDFlag != nil),
            "low_delay_hrd_flag is present iff at least one HRD set is present"
        )
        self.aspectRatio = aspectRatio
        self.overscanAppropriateFlag = overscanAppropriateFlag
        self.videoSignal = videoSignal
        self.chromaLocInfo = chromaLocInfo
        self.timingInfo = timingInfo
        self.nalHRDParameters = nalHRDParameters
        self.vclHRDParameters = vclHRDParameters
        self.lowDelayHRDFlag = lowDelayHRDFlag
        self.picStructPresentFlag = picStructPresentFlag
        self.bitstreamRestrictions = bitstreamRestrictions
    }

    public static func parse(reader: inout BitReader) throws -> AVCVUIParameters {
        let aspectPresent = try reader.readBool()
        var aspectRatio: AspectRatioInfo?
        if aspectPresent {
            let idc = UInt8(try reader.readBits(8))
            if idc == 0xFF {
                let sw = UInt16(try reader.readBits(16))
                let sh = UInt16(try reader.readBits(16))
                aspectRatio = AspectRatioInfo(aspectRatioIDC: idc, sarWidth: sw, sarHeight: sh)
            } else {
                aspectRatio = AspectRatioInfo(aspectRatioIDC: idc)
            }
        }
        let overscanPresent = try reader.readBool()
        let overscanAppropriate: Bool? = overscanPresent ? try reader.readBool() : nil

        var videoSignal: VideoSignal?
        if try reader.readBool() {
            let videoFormat = UInt8(try reader.readBits(3))
            let videoFullRangeFlag: VideoFullRangeFlag = try reader.readBool() ? .full : .limited
            var colourDescription: ColourDescription?
            if try reader.readBool() {
                let cpRaw = UInt8(try reader.readBits(8))
                let tcRaw = UInt8(try reader.readBits(8))
                let mcRaw = UInt8(try reader.readBits(8))
                guard let cp = ColorPrimaries(rawValue: cpRaw) else {
                    throw BitstreamError.unsupportedValue(
                        codec: "AVC", field: "colour_primaries", value: UInt64(cpRaw)
                    )
                }
                guard let tc = TransferCharacteristics(rawValue: tcRaw) else {
                    throw BitstreamError.unsupportedValue(
                        codec: "AVC", field: "transfer_characteristics", value: UInt64(tcRaw)
                    )
                }
                guard let mc = MatrixCoefficients(rawValue: mcRaw) else {
                    throw BitstreamError.unsupportedValue(
                        codec: "AVC", field: "matrix_coefficients", value: UInt64(mcRaw)
                    )
                }
                colourDescription = ColourDescription(
                    colourPrimaries: cp,
                    transferCharacteristics: tc,
                    matrixCoefficients: mc
                )
            }
            videoSignal = VideoSignal(
                videoFormat: videoFormat,
                videoFullRangeFlag: videoFullRangeFlag,
                colourDescription: colourDescription
            )
        }

        var chromaLocInfo: ChromaLocationInfo?
        if try reader.readBool() {
            let top = try reader.readUnsignedExpGolomb()
            let bottom = try reader.readUnsignedExpGolomb()
            chromaLocInfo = ChromaLocationInfo(topFieldType: top, bottomFieldType: bottom)
        }

        var timingInfo: TimingInfo?
        if try reader.readBool() {
            let n = UInt32(try reader.readBits(32))
            let ts = UInt32(try reader.readBits(32))
            let fixed = try reader.readBool()
            timingInfo = TimingInfo(
                numUnitsInTick: n, timeScale: ts, fixedFrameRateFlag: fixed
            )
        }

        var nalHRD: AVCHRDParameters?
        if try reader.readBool() {
            nalHRD = try AVCHRDParameters.parse(reader: &reader)
        }
        var vclHRD: AVCHRDParameters?
        if try reader.readBool() {
            vclHRD = try AVCHRDParameters.parse(reader: &reader)
        }
        var lowDelayHRD: Bool?
        if nalHRD != nil || vclHRD != nil {
            lowDelayHRD = try reader.readBool()
        }
        let picStruct = try reader.readBool()
        var restrictions: BitstreamRestrictions?
        if try reader.readBool() {
            restrictions = BitstreamRestrictions(
                motionVectorsOverPicBoundariesFlag: try reader.readBool(),
                maxBytesPerPicDenom: try reader.readUnsignedExpGolomb(),
                maxBitsPerMBDenom: try reader.readUnsignedExpGolomb(),
                log2MaxMvLengthHorizontal: try reader.readUnsignedExpGolomb(),
                log2MaxMvLengthVertical: try reader.readUnsignedExpGolomb(),
                maxNumReorderFrames: try reader.readUnsignedExpGolomb(),
                maxDecFrameBuffering: try reader.readUnsignedExpGolomb()
            )
        }
        return AVCVUIParameters(
            aspectRatio: aspectRatio,
            overscanAppropriateFlag: overscanAppropriate,
            videoSignal: videoSignal,
            chromaLocInfo: chromaLocInfo,
            timingInfo: timingInfo,
            nalHRDParameters: nalHRD,
            vclHRDParameters: vclHRD,
            lowDelayHRDFlag: lowDelayHRD,
            picStructPresentFlag: picStruct,
            bitstreamRestrictions: restrictions
        )
    }

    public func encode(to writer: inout BitWriter) {
        writer.writeBool(aspectRatio != nil)
        if let ar = aspectRatio {
            writer.writeBits(UInt64(ar.aspectRatioIDC), count: 8)
            if ar.aspectRatioIDC == 0xFF {
                writer.writeBits(UInt64(ar.sarWidth ?? 0), count: 16)
                writer.writeBits(UInt64(ar.sarHeight ?? 0), count: 16)
            }
        }
        writer.writeBool(overscanAppropriateFlag != nil)
        if let v = overscanAppropriateFlag {
            writer.writeBool(v)
        }
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
        writer.writeBool(timingInfo != nil)
        if let ti = timingInfo {
            writer.writeBits(UInt64(ti.numUnitsInTick), count: 32)
            writer.writeBits(UInt64(ti.timeScale), count: 32)
            writer.writeBool(ti.fixedFrameRateFlag)
        }
        writer.writeBool(nalHRDParameters != nil)
        nalHRDParameters?.encode(to: &writer)
        writer.writeBool(vclHRDParameters != nil)
        vclHRDParameters?.encode(to: &writer)
        if nalHRDParameters != nil || vclHRDParameters != nil {
            writer.writeBool(lowDelayHRDFlag ?? false)
        }
        writer.writeBool(picStructPresentFlag)
        writer.writeBool(bitstreamRestrictions != nil)
        if let r = bitstreamRestrictions {
            writer.writeBool(r.motionVectorsOverPicBoundariesFlag)
            writer.writeUnsignedExpGolomb(r.maxBytesPerPicDenom)
            writer.writeUnsignedExpGolomb(r.maxBitsPerMBDenom)
            writer.writeUnsignedExpGolomb(r.log2MaxMvLengthHorizontal)
            writer.writeUnsignedExpGolomb(r.log2MaxMvLengthVertical)
            writer.writeUnsignedExpGolomb(r.maxNumReorderFrames)
            writer.writeUnsignedExpGolomb(r.maxDecFrameBuffering)
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCSequenceParameterSet
//
// Reference: ITU-T H.264 §7.3.2.1.1 (seq_parameter_set_data) + §7.4.2.1.
//
// Parses the SPS NAL unit's RBSP payload (without the 1-byte NAL unit
// header). The trailing `rbsp_trailing_bits()` is emitted on encode and
// tolerated (but not required) on parse.

import Foundation

/// AVC sequence parameter set per ITU-T H.264 §7.3.2.1.1.
public struct AVCSequenceParameterSet: Sendable, Hashable, Equatable {

    /// Fields that are present only for "high-profile family" inputs
    /// (per ITU-T H.264 §7.3.2.1.1 / ISO/IEC 14496-15 §5.3.3.1.2).
    public struct HighProfileFields: Sendable, Hashable, Equatable {
        public let chromaFormatIDC: UInt32
        /// Present iff `chromaFormatIDC == 3`.
        public let separateColourPlaneFlag: Bool?
        public let bitDepthLumaMinus8: UInt32
        public let bitDepthChromaMinus8: UInt32
        public let qpprimeYZeroTransformBypassFlag: Bool
        /// Sequence-level scaling matrix, present iff
        /// `seq_scaling_matrix_present_flag == 1`.
        public let scalingMatrix: AVCScalingMatrix?

        public init(
            chromaFormatIDC: UInt32,
            separateColourPlaneFlag: Bool? = nil,
            bitDepthLumaMinus8: UInt32,
            bitDepthChromaMinus8: UInt32,
            qpprimeYZeroTransformBypassFlag: Bool,
            scalingMatrix: AVCScalingMatrix? = nil
        ) {
            precondition(
                (chromaFormatIDC == 3) == (separateColourPlaneFlag != nil),
                "separateColourPlaneFlag present iff chromaFormatIDC == 3"
            )
            self.chromaFormatIDC = chromaFormatIDC
            self.separateColourPlaneFlag = separateColourPlaneFlag
            self.bitDepthLumaMinus8 = bitDepthLumaMinus8
            self.bitDepthChromaMinus8 = bitDepthChromaMinus8
            self.qpprimeYZeroTransformBypassFlag = qpprimeYZeroTransformBypassFlag
            self.scalingMatrix = scalingMatrix
        }
    }

    /// Picture-order-count parsing branch fields (§7.3.2.1.1).
    public enum PicOrderCntTypeFields: Sendable, Hashable, Equatable {
        case type0(log2MaxPicOrderCntLsbMinus4: UInt32)
        case type1(
            deltaPicOrderAlwaysZeroFlag: Bool,
            offsetForNonRefPic: Int32,
            offsetForTopToBottomField: Int32,
            offsetForRefFrames: [Int32]
        )
        case type2
    }

    /// Frame-cropping window (§7.4.2.1.1.1).
    public struct FrameCropping: Sendable, Hashable, Equatable {
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

    public let profileIDC: AVCProfileIndication
    public let constraintFlags: AVCProfileCompatibility
    public let levelIDC: AVCLevelIndication
    public let seqParameterSetID: UInt32
    public let highProfileFields: HighProfileFields?
    public let log2MaxFrameNumMinus4: UInt32
    public let picOrderCntType: UInt32
    public let picOrderCntTypeFields: PicOrderCntTypeFields
    public let maxNumRefFrames: UInt32
    public let gapsInFrameNumValueAllowedFlag: Bool
    public let picWidthInMbsMinus1: UInt32
    public let picHeightInMapUnitsMinus1: UInt32
    public let frameMbsOnlyFlag: Bool
    /// Present iff `!frameMbsOnlyFlag`.
    public let mbAdaptiveFrameFieldFlag: Bool?
    public let direct8x8InferenceFlag: Bool
    public let frameCropping: FrameCropping?
    public let vuiParameters: AVCVUIParameters?

    public init(
        profileIDC: AVCProfileIndication,
        constraintFlags: AVCProfileCompatibility,
        levelIDC: AVCLevelIndication,
        seqParameterSetID: UInt32,
        highProfileFields: HighProfileFields? = nil,
        log2MaxFrameNumMinus4: UInt32,
        picOrderCntType: UInt32,
        picOrderCntTypeFields: PicOrderCntTypeFields,
        maxNumRefFrames: UInt32,
        gapsInFrameNumValueAllowedFlag: Bool,
        picWidthInMbsMinus1: UInt32,
        picHeightInMapUnitsMinus1: UInt32,
        frameMbsOnlyFlag: Bool,
        mbAdaptiveFrameFieldFlag: Bool? = nil,
        direct8x8InferenceFlag: Bool,
        frameCropping: FrameCropping? = nil,
        vuiParameters: AVCVUIParameters? = nil
    ) {
        precondition(
            profileIDC.requiresHighProfileFields == (highProfileFields != nil),
            "highProfileFields presence must match profile family"
        )
        precondition(
            !frameMbsOnlyFlag == (mbAdaptiveFrameFieldFlag != nil),
            "mbAdaptiveFrameFieldFlag is present iff frameMbsOnlyFlag is false"
        )
        self.profileIDC = profileIDC
        self.constraintFlags = constraintFlags
        self.levelIDC = levelIDC
        self.seqParameterSetID = seqParameterSetID
        self.highProfileFields = highProfileFields
        self.log2MaxFrameNumMinus4 = log2MaxFrameNumMinus4
        self.picOrderCntType = picOrderCntType
        self.picOrderCntTypeFields = picOrderCntTypeFields
        self.maxNumRefFrames = maxNumRefFrames
        self.gapsInFrameNumValueAllowedFlag = gapsInFrameNumValueAllowedFlag
        self.picWidthInMbsMinus1 = picWidthInMbsMinus1
        self.picHeightInMapUnitsMinus1 = picHeightInMapUnitsMinus1
        self.frameMbsOnlyFlag = frameMbsOnlyFlag
        self.mbAdaptiveFrameFieldFlag = mbAdaptiveFrameFieldFlag
        self.direct8x8InferenceFlag = direct8x8InferenceFlag
        self.frameCropping = frameCropping
        self.vuiParameters = vuiParameters
    }

    /// Coded width × height in luma samples after cropping, per §7.4.2.1.1.1.
    /// Returns `nil` only for monochrome streams (`chromaFormatIDC == 0`)
    /// where chroma subsampling factors are undefined.
    public var codedDimensions: (width: Int, height: Int)? {
        let cf = highProfileFields?.chromaFormatIDC ?? 1  // default 4:2:0
        if cf == 0 { return nil }  // monochrome: width factors undefined
        // SubWidthC / SubHeightC per §6.2 Table 6-1.
        let subWidthC: Int
        let subHeightC: Int
        switch cf {
        case 1:
            subWidthC = 2
            subHeightC = 2
        case 2:
            subWidthC = 2
            subHeightC = 1
        case 3:
            subWidthC = 1
            subHeightC = 1
        default: return nil
        }
        let picWidthInMbs = Int(picWidthInMbsMinus1) + 1
        let picHeightInMapUnits = Int(picHeightInMapUnitsMinus1) + 1
        let frameHeightInMbs = picHeightInMapUnits * (frameMbsOnlyFlag ? 1 : 2)
        let rawWidth = picWidthInMbs * 16
        let rawHeight = frameHeightInMbs * 16
        guard let crop = frameCropping else {
            return (rawWidth, rawHeight)
        }
        let cropX = subWidthC * (Int(crop.leftOffset) + Int(crop.rightOffset))
        let cropY =
            subHeightC * (frameMbsOnlyFlag ? 1 : 2)
            * (Int(crop.topOffset) + Int(crop.bottomOffset))
        return (rawWidth - cropX, rawHeight - cropY)
    }

    public static func parse(rbsp: Data) throws -> AVCSequenceParameterSet {
        var reader = BitReader(rbsp)
        let profileRaw = UInt8(try reader.readBits(8))
        guard let profileIDC = AVCProfileIndication(rawValue: profileRaw) else {
            throw BitstreamError.unsupportedValue(
                codec: "AVC", field: "profile_idc", value: UInt64(profileRaw)
            )
        }
        let constraintByte = UInt8(try reader.readBits(8))
        let constraintFlags = AVCProfileCompatibility(rawValue: constraintByte)
        let levelRaw = UInt8(try reader.readBits(8))
        guard let levelIDC = AVCLevelIndication(rawValue: levelRaw) else {
            throw BitstreamError.unsupportedValue(
                codec: "AVC", field: "level_idc", value: UInt64(levelRaw)
            )
        }
        let spsID = try reader.readUnsignedExpGolomb()

        var highProfileFields: HighProfileFields?
        if profileIDC.requiresHighProfileFields {
            let cf = try reader.readUnsignedExpGolomb()
            var separate: Bool?
            if cf == 3 {
                separate = try reader.readBool()
            }
            let bdL = try reader.readUnsignedExpGolomb()
            let bdC = try reader.readUnsignedExpGolomb()
            let qp = try reader.readBool()
            var matrix: AVCScalingMatrix?
            if try reader.readBool() {
                matrix = try AVCScalingMatrix.parse(reader: &reader, chromaFormatIDC: cf)
            }
            highProfileFields = HighProfileFields(
                chromaFormatIDC: cf,
                separateColourPlaneFlag: separate,
                bitDepthLumaMinus8: bdL,
                bitDepthChromaMinus8: bdC,
                qpprimeYZeroTransformBypassFlag: qp,
                scalingMatrix: matrix
            )
        }

        let log2MaxFrameNumMinus4 = try reader.readUnsignedExpGolomb()
        let pocType = try reader.readUnsignedExpGolomb()
        let pocFields: PicOrderCntTypeFields
        switch pocType {
        case 0:
            let log2MaxLsb = try reader.readUnsignedExpGolomb()
            pocFields = .type0(log2MaxPicOrderCntLsbMinus4: log2MaxLsb)
        case 1:
            let alwaysZero = try reader.readBool()
            let offsetNonRef = try reader.readSignedExpGolomb()
            let offsetTopBottom = try reader.readSignedExpGolomb()
            let numRef = try reader.readUnsignedExpGolomb()
            var offsets: [Int32] = []
            offsets.reserveCapacity(Int(numRef))
            for _ in 0..<numRef {
                offsets.append(try reader.readSignedExpGolomb())
            }
            pocFields = .type1(
                deltaPicOrderAlwaysZeroFlag: alwaysZero,
                offsetForNonRefPic: offsetNonRef,
                offsetForTopToBottomField: offsetTopBottom,
                offsetForRefFrames: offsets
            )
        case 2:
            pocFields = .type2
        default:
            throw BitstreamError.unsupportedValue(
                codec: "AVC", field: "pic_order_cnt_type", value: UInt64(pocType)
            )
        }

        let maxRef = try reader.readUnsignedExpGolomb()
        let gaps = try reader.readBool()
        let picWidthMbs = try reader.readUnsignedExpGolomb()
        let picHeightMapUnits = try reader.readUnsignedExpGolomb()
        let frameMbsOnly = try reader.readBool()
        var mbAdaptive: Bool?
        if !frameMbsOnly { mbAdaptive = try reader.readBool() }
        let direct8x8 = try reader.readBool()
        var cropping: FrameCropping?
        if try reader.readBool() {
            cropping = FrameCropping(
                leftOffset: try reader.readUnsignedExpGolomb(),
                rightOffset: try reader.readUnsignedExpGolomb(),
                topOffset: try reader.readUnsignedExpGolomb(),
                bottomOffset: try reader.readUnsignedExpGolomb()
            )
        }
        var vui: AVCVUIParameters?
        if try reader.readBool() {
            vui = try AVCVUIParameters.parse(reader: &reader)
        }

        return AVCSequenceParameterSet(
            profileIDC: profileIDC,
            constraintFlags: constraintFlags,
            levelIDC: levelIDC,
            seqParameterSetID: spsID,
            highProfileFields: highProfileFields,
            log2MaxFrameNumMinus4: log2MaxFrameNumMinus4,
            picOrderCntType: pocType,
            picOrderCntTypeFields: pocFields,
            maxNumRefFrames: maxRef,
            gapsInFrameNumValueAllowedFlag: gaps,
            picWidthInMbsMinus1: picWidthMbs,
            picHeightInMapUnitsMinus1: picHeightMapUnits,
            frameMbsOnlyFlag: frameMbsOnly,
            mbAdaptiveFrameFieldFlag: mbAdaptive,
            direct8x8InferenceFlag: direct8x8,
            frameCropping: cropping,
            vuiParameters: vui
        )
    }

    public func encode() -> Data {
        var writer = BitWriter()
        writer.writeBits(UInt64(profileIDC.rawValue), count: 8)
        writer.writeBits(UInt64(constraintFlags.rawValue), count: 8)
        writer.writeBits(UInt64(levelIDC.rawValue), count: 8)
        writer.writeUnsignedExpGolomb(seqParameterSetID)
        if let hp = highProfileFields {
            writer.writeUnsignedExpGolomb(hp.chromaFormatIDC)
            if hp.chromaFormatIDC == 3 {
                writer.writeBool(hp.separateColourPlaneFlag ?? false)
            }
            writer.writeUnsignedExpGolomb(hp.bitDepthLumaMinus8)
            writer.writeUnsignedExpGolomb(hp.bitDepthChromaMinus8)
            writer.writeBool(hp.qpprimeYZeroTransformBypassFlag)
            writer.writeBool(hp.scalingMatrix != nil)
            hp.scalingMatrix?.encode(to: &writer)
        }
        writer.writeUnsignedExpGolomb(log2MaxFrameNumMinus4)
        writer.writeUnsignedExpGolomb(picOrderCntType)
        switch picOrderCntTypeFields {
        case .type0(let log2MaxLsb):
            writer.writeUnsignedExpGolomb(log2MaxLsb)
        case .type1(let alwaysZero, let offsetNonRef, let offsetTopBottom, let offsets):
            writer.writeBool(alwaysZero)
            writer.writeSignedExpGolomb(offsetNonRef)
            writer.writeSignedExpGolomb(offsetTopBottom)
            writer.writeUnsignedExpGolomb(UInt32(offsets.count))
            for v in offsets { writer.writeSignedExpGolomb(v) }
        case .type2:
            break
        }
        writer.writeUnsignedExpGolomb(maxNumRefFrames)
        writer.writeBool(gapsInFrameNumValueAllowedFlag)
        writer.writeUnsignedExpGolomb(picWidthInMbsMinus1)
        writer.writeUnsignedExpGolomb(picHeightInMapUnitsMinus1)
        writer.writeBool(frameMbsOnlyFlag)
        if !frameMbsOnlyFlag {
            writer.writeBool(mbAdaptiveFrameFieldFlag ?? false)
        }
        writer.writeBool(direct8x8InferenceFlag)
        writer.writeBool(frameCropping != nil)
        if let crop = frameCropping {
            writer.writeUnsignedExpGolomb(crop.leftOffset)
            writer.writeUnsignedExpGolomb(crop.rightOffset)
            writer.writeUnsignedExpGolomb(crop.topOffset)
            writer.writeUnsignedExpGolomb(crop.bottomOffset)
        }
        writer.writeBool(vuiParameters != nil)
        vuiParameters?.encode(to: &writer)
        // rbsp_trailing_bits()
        writer.writeBit(1)
        writer.byteAlign()
        return writer.data
    }
}

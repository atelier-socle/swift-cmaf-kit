// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AVCPictureParameterSet
//
// Reference: ITU-T H.264 §7.3.2.2 (pic_parameter_set_rbsp).
//
// Parses the PPS NAL unit's RBSP payload. The optional tail
// (`transform_8x8_mode_flag`, picture-level scaling matrix,
// `second_chroma_qp_index_offset`) is present iff `more_rbsp_data()`
// returns true at the corresponding position; CMAFKit captures its
// presence and content as ``OptionalTail``.

import Foundation

/// AVC picture parameter set per ITU-T H.264 §7.3.2.2.
public struct AVCPictureParameterSet: Sendable, Hashable, Equatable {

    /// Slice-group map (§7.4.2.2). Most streams set
    /// `num_slice_groups_minus1 == 0`, in which case `map` is `nil`.
    public enum SliceGroupMap: Sendable, Hashable, Equatable {
        case interleaved(runLengthMinus1: [UInt32])
        case dispersed
        case foregroundAndLeftover(topLeft: [UInt32], bottomRight: [UInt32])
        case changing(
            mapType: UInt32,
            changeDirectionFlag: Bool,
            changeRateMinus1: UInt32
        )
        case explicit(picSizeInMapUnitsMinus1: UInt32, sliceGroupID: [UInt32])
    }

    /// Optional tail present iff `more_rbsp_data()` is true after the
    /// required PPS fields.
    public struct OptionalTail: Sendable, Hashable, Equatable {
        public let transform8x8ModeFlag: Bool
        public let scalingMatrix: AVCScalingMatrix?
        public let secondChromaQPIndexOffset: Int32

        public init(
            transform8x8ModeFlag: Bool,
            scalingMatrix: AVCScalingMatrix? = nil,
            secondChromaQPIndexOffset: Int32
        ) {
            self.transform8x8ModeFlag = transform8x8ModeFlag
            self.scalingMatrix = scalingMatrix
            self.secondChromaQPIndexOffset = secondChromaQPIndexOffset
        }
    }

    public let picParameterSetID: UInt32
    public let seqParameterSetID: UInt32
    public let entropyCodingModeFlag: Bool
    public let bottomFieldPicOrderInFramePresentFlag: Bool
    public let numSliceGroupsMinus1: UInt32
    public let sliceGroupMap: SliceGroupMap?
    public let numRefIdxL0DefaultActiveMinus1: UInt32
    public let numRefIdxL1DefaultActiveMinus1: UInt32
    public let weightedPredFlag: Bool
    public let weightedBipredIDC: UInt8
    public let picInitQPMinus26: Int32
    public let picInitQSMinus26: Int32
    public let chromaQPIndexOffset: Int32
    public let deblockingFilterControlPresentFlag: Bool
    public let constrainedIntraPredFlag: Bool
    public let redundantPicCntPresentFlag: Bool
    public let tail: OptionalTail?

    public init(
        picParameterSetID: UInt32,
        seqParameterSetID: UInt32,
        entropyCodingModeFlag: Bool,
        bottomFieldPicOrderInFramePresentFlag: Bool,
        numSliceGroupsMinus1: UInt32,
        sliceGroupMap: SliceGroupMap? = nil,
        numRefIdxL0DefaultActiveMinus1: UInt32,
        numRefIdxL1DefaultActiveMinus1: UInt32,
        weightedPredFlag: Bool,
        weightedBipredIDC: UInt8,
        picInitQPMinus26: Int32,
        picInitQSMinus26: Int32,
        chromaQPIndexOffset: Int32,
        deblockingFilterControlPresentFlag: Bool,
        constrainedIntraPredFlag: Bool,
        redundantPicCntPresentFlag: Bool,
        tail: OptionalTail? = nil
    ) {
        precondition(
            (numSliceGroupsMinus1 > 0) == (sliceGroupMap != nil),
            "sliceGroupMap presence must match numSliceGroupsMinus1 > 0"
        )
        precondition(weightedBipredIDC <= 3, "weightedBipredIDC must fit 2 bits")
        self.picParameterSetID = picParameterSetID
        self.seqParameterSetID = seqParameterSetID
        self.entropyCodingModeFlag = entropyCodingModeFlag
        self.bottomFieldPicOrderInFramePresentFlag = bottomFieldPicOrderInFramePresentFlag
        self.numSliceGroupsMinus1 = numSliceGroupsMinus1
        self.sliceGroupMap = sliceGroupMap
        self.numRefIdxL0DefaultActiveMinus1 = numRefIdxL0DefaultActiveMinus1
        self.numRefIdxL1DefaultActiveMinus1 = numRefIdxL1DefaultActiveMinus1
        self.weightedPredFlag = weightedPredFlag
        self.weightedBipredIDC = weightedBipredIDC
        self.picInitQPMinus26 = picInitQPMinus26
        self.picInitQSMinus26 = picInitQSMinus26
        self.chromaQPIndexOffset = chromaQPIndexOffset
        self.deblockingFilterControlPresentFlag = deblockingFilterControlPresentFlag
        self.constrainedIntraPredFlag = constrainedIntraPredFlag
        self.redundantPicCntPresentFlag = redundantPicCntPresentFlag
        self.tail = tail
    }

    public static func parse(rbsp: Data) throws -> AVCPictureParameterSet {
        var reader = BitReader(rbsp)
        let ppsID = try reader.readUnsignedExpGolomb()
        let spsID = try reader.readUnsignedExpGolomb()
        let entropy = try reader.readBool()
        let bottomFieldPOC = try reader.readBool()
        let numSliceGroups = try reader.readUnsignedExpGolomb()
        var map: SliceGroupMap?
        if numSliceGroups > 0 {
            let mapType = try reader.readUnsignedExpGolomb()
            switch mapType {
            case 0:
                var runs: [UInt32] = []
                runs.reserveCapacity(Int(numSliceGroups) + 1)
                for _ in 0...numSliceGroups {
                    runs.append(try reader.readUnsignedExpGolomb())
                }
                map = .interleaved(runLengthMinus1: runs)
            case 1:
                map = .dispersed
            case 2:
                var topLefts: [UInt32] = []
                var bottomRights: [UInt32] = []
                topLefts.reserveCapacity(Int(numSliceGroups))
                bottomRights.reserveCapacity(Int(numSliceGroups))
                for _ in 0..<numSliceGroups {
                    topLefts.append(try reader.readUnsignedExpGolomb())
                    bottomRights.append(try reader.readUnsignedExpGolomb())
                }
                map = .foregroundAndLeftover(topLeft: topLefts, bottomRight: bottomRights)
            case 3, 4, 5:
                let changeDir = try reader.readBool()
                let changeRate = try reader.readUnsignedExpGolomb()
                map = .changing(
                    mapType: mapType,
                    changeDirectionFlag: changeDir,
                    changeRateMinus1: changeRate
                )
            case 6:
                let sizeMinus1 = try reader.readUnsignedExpGolomb()
                let bits = bitsForSliceGroupID(numSliceGroupsMinus1: numSliceGroups)
                var ids: [UInt32] = []
                ids.reserveCapacity(Int(sizeMinus1) + 1)
                for _ in 0...sizeMinus1 {
                    ids.append(UInt32(try reader.readBits(bits)))
                }
                map = .explicit(picSizeInMapUnitsMinus1: sizeMinus1, sliceGroupID: ids)
            default:
                throw BitstreamError.unsupportedValue(
                    codec: "AVC", field: "slice_group_map_type", value: UInt64(mapType)
                )
            }
        }
        let numRefL0 = try reader.readUnsignedExpGolomb()
        let numRefL1 = try reader.readUnsignedExpGolomb()
        let weightedPred = try reader.readBool()
        let weightedBipred = UInt8(try reader.readBits(2))
        let picInitQP = try reader.readSignedExpGolomb()
        let picInitQS = try reader.readSignedExpGolomb()
        let chromaQP = try reader.readSignedExpGolomb()
        let deblockFilter = try reader.readBool()
        let constrainedIntra = try reader.readBool()
        let redundantPic = try reader.readBool()

        var tail: OptionalTail?
        if reader.hasMoreRBSPData() {
            let transform8x8 = try reader.readBool()
            var matrix: AVCScalingMatrix?
            if try reader.readBool() {
                // The PPS scaling-matrix size depends on chroma format
                // and transform_8x8_mode_flag (§7.3.2.2): 6 4x4 lists
                // plus (transform_8x8_mode_flag ? (chroma != 3 ? 2 : 6) : 0)
                // 8x8 lists. CMAFKit captures every list signalled as
                // present; the chroma-format-driven sizing is enforced
                // at decode time by the codec.
                matrix = try AVCScalingMatrix.parse(
                    reader: &reader,
                    chromaFormatIDC: transform8x8 ? 1 : 3  // pick a count that yields 8 entries
                )
            }
            let secondChromaQP = try reader.readSignedExpGolomb()
            tail = OptionalTail(
                transform8x8ModeFlag: transform8x8,
                scalingMatrix: matrix,
                secondChromaQPIndexOffset: secondChromaQP
            )
        }

        return AVCPictureParameterSet(
            picParameterSetID: ppsID,
            seqParameterSetID: spsID,
            entropyCodingModeFlag: entropy,
            bottomFieldPicOrderInFramePresentFlag: bottomFieldPOC,
            numSliceGroupsMinus1: numSliceGroups,
            sliceGroupMap: map,
            numRefIdxL0DefaultActiveMinus1: numRefL0,
            numRefIdxL1DefaultActiveMinus1: numRefL1,
            weightedPredFlag: weightedPred,
            weightedBipredIDC: weightedBipred,
            picInitQPMinus26: picInitQP,
            picInitQSMinus26: picInitQS,
            chromaQPIndexOffset: chromaQP,
            deblockingFilterControlPresentFlag: deblockFilter,
            constrainedIntraPredFlag: constrainedIntra,
            redundantPicCntPresentFlag: redundantPic,
            tail: tail
        )
    }

    public func encode() -> Data {
        var writer = BitWriter()
        writer.writeUnsignedExpGolomb(picParameterSetID)
        writer.writeUnsignedExpGolomb(seqParameterSetID)
        writer.writeBool(entropyCodingModeFlag)
        writer.writeBool(bottomFieldPicOrderInFramePresentFlag)
        writer.writeUnsignedExpGolomb(numSliceGroupsMinus1)
        if let map = sliceGroupMap {
            switch map {
            case .interleaved(let runs):
                writer.writeUnsignedExpGolomb(0)
                for v in runs { writer.writeUnsignedExpGolomb(v) }
            case .dispersed:
                writer.writeUnsignedExpGolomb(1)
            case .foregroundAndLeftover(let tl, let br):
                writer.writeUnsignedExpGolomb(2)
                for i in 0..<tl.count {
                    writer.writeUnsignedExpGolomb(tl[i])
                    writer.writeUnsignedExpGolomb(br[i])
                }
            case .changing(let mapType, let dir, let rate):
                writer.writeUnsignedExpGolomb(mapType)
                writer.writeBool(dir)
                writer.writeUnsignedExpGolomb(rate)
            case .explicit(let sizeMinus1, let ids):
                writer.writeUnsignedExpGolomb(6)
                writer.writeUnsignedExpGolomb(sizeMinus1)
                let bits = Self.bitsForSliceGroupID(numSliceGroupsMinus1: numSliceGroupsMinus1)
                for id in ids {
                    writer.writeBits(UInt64(id), count: bits)
                }
            }
        }
        writer.writeUnsignedExpGolomb(numRefIdxL0DefaultActiveMinus1)
        writer.writeUnsignedExpGolomb(numRefIdxL1DefaultActiveMinus1)
        writer.writeBool(weightedPredFlag)
        writer.writeBits(UInt64(weightedBipredIDC & 0x03), count: 2)
        writer.writeSignedExpGolomb(picInitQPMinus26)
        writer.writeSignedExpGolomb(picInitQSMinus26)
        writer.writeSignedExpGolomb(chromaQPIndexOffset)
        writer.writeBool(deblockingFilterControlPresentFlag)
        writer.writeBool(constrainedIntraPredFlag)
        writer.writeBool(redundantPicCntPresentFlag)
        if let tail = tail {
            writer.writeBool(tail.transform8x8ModeFlag)
            writer.writeBool(tail.scalingMatrix != nil)
            tail.scalingMatrix?.encode(to: &writer)
            writer.writeSignedExpGolomb(tail.secondChromaQPIndexOffset)
        }
        // rbsp_trailing_bits()
        writer.writeBit(1)
        writer.byteAlign()
        return writer.data
    }

    /// Bit count for `slice_group_id[i]` per §7.3.2.2:
    /// `Ceil(Log2(num_slice_groups_minus1 + 1))`.
    fileprivate static func bitsForSliceGroupID(numSliceGroupsMinus1: UInt32) -> Int {
        let n = UInt64(numSliceGroupsMinus1) + 1
        return 64 - n.leadingZeroBitCount - (n.nonzeroBitCount == 1 ? 1 : 0)
    }
}

private func bitsForSliceGroupID(numSliceGroupsMinus1: UInt32) -> Int {
    AVCPictureParameterSet.bitsForSliceGroupID(numSliceGroupsMinus1: numSliceGroupsMinus1)
}

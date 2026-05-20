// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Coverage lift for ``AVCPictureParameterSet``. The parser
// dispatches on `slice_group_map_type` for 6 different map shapes
// (interleaved, dispersed, foreground+leftover, changing 3/4/5,
// explicit 6) and has an optional tail with scaling matrix and
// second_chroma_qp_index_offset. Each arm gets a round-trip test.

import Foundation
import Testing

@testable import CMAFKit

@Suite("AVCPictureParameterSet — coverage lift")
struct AVCPictureParameterSetCoverageLiftTests {

    private func makeBasePPS(
        sliceGroups: UInt32 = 0,
        map: AVCPictureParameterSet.SliceGroupMap? = nil,
        tail: AVCPictureParameterSet.OptionalTail? = nil
    ) -> AVCPictureParameterSet {
        AVCPictureParameterSet(
            picParameterSetID: 0,
            seqParameterSetID: 0,
            entropyCodingModeFlag: false,
            bottomFieldPicOrderInFramePresentFlag: false,
            numSliceGroupsMinus1: sliceGroups,
            sliceGroupMap: map,
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            weightedPredFlag: false,
            weightedBipredIDC: 0,
            picInitQPMinus26: 0,
            picInitQSMinus26: 0,
            chromaQPIndexOffset: 0,
            deblockingFilterControlPresentFlag: false,
            constrainedIntraPredFlag: false,
            redundantPicCntPresentFlag: false,
            tail: tail
        )
    }

    @Test
    func noSliceGroupsNoTailRoundTrip() throws {
        let pps = makeBasePPS()
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        #expect(decoded.numSliceGroupsMinus1 == 0)
        #expect(decoded.sliceGroupMap == nil)
        #expect(decoded.tail == nil)
    }

    @Test
    func interleavedSliceGroupMapRoundTrip() throws {
        let pps = makeBasePPS(
            sliceGroups: 2,
            map: .interleaved(runLengthMinus1: [10, 20, 30])
        )
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        if case let .interleaved(runs) = decoded.sliceGroupMap {
            #expect(runs == [10, 20, 30])
        } else {
            Issue.record("expected .interleaved")
        }
    }

    @Test
    func dispersedSliceGroupMapRoundTrip() throws {
        let pps = makeBasePPS(sliceGroups: 1, map: .dispersed)
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        if case .dispersed = decoded.sliceGroupMap {
        } else {
            Issue.record("expected .dispersed")
        }
    }

    @Test
    func foregroundAndLeftoverSliceGroupMapRoundTrip() throws {
        let pps = makeBasePPS(
            sliceGroups: 2,
            map: .foregroundAndLeftover(
                topLeft: [0, 5], bottomRight: [4, 9]
            )
        )
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        if case let .foregroundAndLeftover(tl, br) = decoded.sliceGroupMap {
            #expect(tl == [0, 5])
            #expect(br == [4, 9])
        } else {
            Issue.record("expected .foregroundAndLeftover")
        }
    }

    @Test
    func changingType3SliceGroupMapRoundTrip() throws {
        let pps = makeBasePPS(
            sliceGroups: 1,
            map: .changing(
                mapType: 3,
                changeDirectionFlag: true,
                changeRateMinus1: 7
            )
        )
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        if case let .changing(mapType, dir, rate) = decoded.sliceGroupMap {
            #expect(mapType == 3)
            #expect(dir == true)
            #expect(rate == 7)
        } else {
            Issue.record("expected .changing")
        }
    }

    @Test
    func changingType4SliceGroupMapRoundTrip() throws {
        let pps = makeBasePPS(
            sliceGroups: 1,
            map: .changing(
                mapType: 4, changeDirectionFlag: false, changeRateMinus1: 3
            )
        )
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        if case let .changing(mapType, dir, _) = decoded.sliceGroupMap {
            #expect(mapType == 4)
            #expect(dir == false)
        } else {
            Issue.record("expected .changing")
        }
    }

    @Test
    func changingType5SliceGroupMapRoundTrip() throws {
        let pps = makeBasePPS(
            sliceGroups: 1,
            map: .changing(
                mapType: 5, changeDirectionFlag: true, changeRateMinus1: 0
            )
        )
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        if case let .changing(mapType, _, _) = decoded.sliceGroupMap {
            #expect(mapType == 5)
        } else {
            Issue.record("expected .changing")
        }
    }

    @Test
    func explicitSliceGroupMapRoundTrip() throws {
        let pps = makeBasePPS(
            sliceGroups: 3,  // 4 groups, sliceGroupID bits = 2
            map: .explicit(
                picSizeInMapUnitsMinus1: 3,
                sliceGroupID: [0, 1, 2, 3]
            )
        )
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        if case let .explicit(size, ids) = decoded.sliceGroupMap {
            #expect(size == 3)
            #expect(ids == [0, 1, 2, 3])
        } else {
            Issue.record("expected .explicit")
        }
    }

    @Test
    func tailWithTransform8x8NoScalingMatrix() throws {
        let pps = makeBasePPS(
            tail: AVCPictureParameterSet.OptionalTail(
                transform8x8ModeFlag: true,
                scalingMatrix: nil,
                secondChromaQPIndexOffset: 5
            )
        )
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        #expect(decoded.tail?.transform8x8ModeFlag == true)
        #expect(decoded.tail?.scalingMatrix == nil)
        #expect(decoded.tail?.secondChromaQPIndexOffset == 5)
    }

    @Test
    func tailWithScalingMatrixRoundTrip() throws {
        let pps = makeBasePPS(
            tail: AVCPictureParameterSet.OptionalTail(
                transform8x8ModeFlag: true,
                scalingMatrix: AVCScalingMatrix(
                    lists4x4: [.useDefault, nil, nil, nil, nil, nil],
                    lists8x8: [.useDefault, nil]
                ),
                secondChromaQPIndexOffset: -3
            )
        )
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        #expect(decoded.tail?.transform8x8ModeFlag == true)
        #expect(decoded.tail?.scalingMatrix != nil)
        #expect(decoded.tail?.secondChromaQPIndexOffset == -3)
    }

    @Test
    func entropyCodingFlagsRoundTrip() throws {
        let pps = AVCPictureParameterSet(
            picParameterSetID: 5,
            seqParameterSetID: 1,
            entropyCodingModeFlag: true,
            bottomFieldPicOrderInFramePresentFlag: true,
            numSliceGroupsMinus1: 0,
            sliceGroupMap: nil,
            numRefIdxL0DefaultActiveMinus1: 4,
            numRefIdxL1DefaultActiveMinus1: 4,
            weightedPredFlag: true,
            weightedBipredIDC: 2,
            picInitQPMinus26: 6,
            picInitQSMinus26: -2,
            chromaQPIndexOffset: 3,
            deblockingFilterControlPresentFlag: true,
            constrainedIntraPredFlag: true,
            redundantPicCntPresentFlag: true
        )
        let decoded = try AVCPictureParameterSet.parse(rbsp: pps.encode())
        #expect(decoded.picParameterSetID == 5)
        #expect(decoded.seqParameterSetID == 1)
        #expect(decoded.entropyCodingModeFlag)
        #expect(decoded.bottomFieldPicOrderInFramePresentFlag)
        #expect(decoded.weightedPredFlag)
        #expect(decoded.weightedBipredIDC == 2)
        #expect(decoded.picInitQPMinus26 == 6)
        #expect(decoded.picInitQSMinus26 == -2)
        #expect(decoded.chromaQPIndexOffset == 3)
        #expect(decoded.deblockingFilterControlPresentFlag)
        #expect(decoded.constrainedIntraPredFlag)
        #expect(decoded.redundantPicCntPresentFlag)
    }
}

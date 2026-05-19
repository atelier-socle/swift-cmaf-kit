// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("HEVCPictureParameterSet")
struct HEVCPictureParameterSetTests {

    private static func minimal() -> HEVCPictureParameterSet {
        HEVCPictureParameterSet(
            ppsID: 0,
            spsID: 0,
            dependentSliceSegmentsEnabledFlag: false,
            outputFlagPresentFlag: false,
            numExtraSliceHeaderBits: 0,
            signDataHidingEnabledFlag: false,
            cabacInitPresentFlag: false,
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            initQPMinus26: 0,
            constrainedIntraPredFlag: false,
            transformSkipEnabledFlag: false,
            cuQPDeltaEnabledFlag: false,
            cbQPOffset: 0,
            crQPOffset: 0,
            sliceChromaQPOffsetsPresentFlag: false,
            weightedPredFlag: false,
            weightedBipredFlag: false,
            transquantBypassEnabledFlag: false,
            entropyCodingSyncEnabledFlag: false,
            loopFilterAcrossSlicesEnabledFlag: true,
            listsModificationPresentFlag: false,
            log2ParallelMergeLevelMinus2: 0,
            sliceSegmentHeaderExtensionPresentFlag: false
        )
    }

    @Test
    func minimalRoundTrip() throws {
        let pps = Self.minimal()
        let encoded = pps.encode()
        let decoded = try HEVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded == pps)
    }

    @Test
    func withTilesRoundTrip() throws {
        let pps = HEVCPictureParameterSet(
            ppsID: 0, spsID: 0,
            dependentSliceSegmentsEnabledFlag: false,
            outputFlagPresentFlag: false,
            numExtraSliceHeaderBits: 0,
            signDataHidingEnabledFlag: false,
            cabacInitPresentFlag: false,
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            initQPMinus26: 0,
            constrainedIntraPredFlag: false,
            transformSkipEnabledFlag: false,
            cuQPDeltaEnabledFlag: false,
            cbQPOffset: 0, crQPOffset: 0,
            sliceChromaQPOffsetsPresentFlag: false,
            weightedPredFlag: false, weightedBipredFlag: false,
            transquantBypassEnabledFlag: false,
            entropyCodingSyncEnabledFlag: false,
            tileInfo: HEVCPictureParameterSet.TileInfo(
                numTileColumnsMinus1: 1,
                numTileRowsMinus1: 1,
                uniformSpacingFlag: true,
                loopFilterAcrossTilesEnabledFlag: true
            ),
            loopFilterAcrossSlicesEnabledFlag: true,
            listsModificationPresentFlag: false,
            log2ParallelMergeLevelMinus2: 0,
            sliceSegmentHeaderExtensionPresentFlag: false
        )
        let encoded = pps.encode()
        let decoded = try HEVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded == pps)
        #expect(decoded.tileInfo?.numTileColumnsMinus1 == 1)
    }

    @Test
    func withDeblockingControlRoundTrip() throws {
        let pps = HEVCPictureParameterSet(
            ppsID: 0, spsID: 0,
            dependentSliceSegmentsEnabledFlag: false,
            outputFlagPresentFlag: false,
            numExtraSliceHeaderBits: 0,
            signDataHidingEnabledFlag: false,
            cabacInitPresentFlag: false,
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            initQPMinus26: 0,
            constrainedIntraPredFlag: false,
            transformSkipEnabledFlag: false,
            cuQPDeltaEnabledFlag: false,
            cbQPOffset: 0, crQPOffset: 0,
            sliceChromaQPOffsetsPresentFlag: false,
            weightedPredFlag: false, weightedBipredFlag: false,
            transquantBypassEnabledFlag: false,
            entropyCodingSyncEnabledFlag: false,
            loopFilterAcrossSlicesEnabledFlag: true,
            deblockingControl: HEVCPictureParameterSet.DeblockingControl(
                overrideEnabledFlag: true,
                disabledFlag: false,
                betaOffsetDiv2: -2,
                tcOffsetDiv2: 1
            ),
            listsModificationPresentFlag: false,
            log2ParallelMergeLevelMinus2: 0,
            sliceSegmentHeaderExtensionPresentFlag: false
        )
        let encoded = pps.encode()
        let decoded = try HEVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded == pps)
    }

    @Test
    func extensionPresentNoneEnabledRoundTrip() throws {
        let pps = HEVCPictureParameterSet(
            ppsID: 0, spsID: 0,
            dependentSliceSegmentsEnabledFlag: false,
            outputFlagPresentFlag: false,
            numExtraSliceHeaderBits: 0,
            signDataHidingEnabledFlag: false,
            cabacInitPresentFlag: false,
            numRefIdxL0DefaultActiveMinus1: 0,
            numRefIdxL1DefaultActiveMinus1: 0,
            initQPMinus26: 0,
            constrainedIntraPredFlag: false,
            transformSkipEnabledFlag: false,
            cuQPDeltaEnabledFlag: false,
            cbQPOffset: 0, crQPOffset: 0,
            sliceChromaQPOffsetsPresentFlag: false,
            weightedPredFlag: false, weightedBipredFlag: false,
            transquantBypassEnabledFlag: false,
            entropyCodingSyncEnabledFlag: false,
            loopFilterAcrossSlicesEnabledFlag: true,
            listsModificationPresentFlag: false,
            log2ParallelMergeLevelMinus2: 0,
            sliceSegmentHeaderExtensionPresentFlag: false,
            extensionFlags: HEVCPictureParameterSet.ExtensionFlags(
                rangeExtensionFlag: false,
                multilayerExtensionFlag: false,
                threeDExtensionFlag: false,
                screenContentExtensionFlag: false
            )
        )
        let encoded = pps.encode()
        let decoded = try HEVCPictureParameterSet.parse(rbsp: encoded)
        #expect(decoded == pps)
    }

    @Test
    func equalityAndHashing() {
        let a = Self.minimal()
        let b = Self.minimal()
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}
